#!/usr/bin/env python3
"""Door-to-door commute time (public transport and, optionally, e-bike) from the candidate's home
to a job location.

Usage: python3 -I scripts/commute.py "<workplace address or 'Company, City'>"

Prints one JSON object:
  {"destination": ..., "resolved": ..., "minutes": N, "route": "...", "departure": ...,
   "ebike_minutes": N|null, "best_minutes": N, "best_mode": "transit"|"ebike",
   "limit_minutes": N, "within_limit": true|false,
   "limit_minutes_3plus": N|null, "within_limit_3plus": true|false|null, "source": "transitous"}
minutes = public transport; ebike_minutes = e-bike estimate (straight-line distance x 1.35 road
factor at 20 km/h; null when "ebike" is false); best_minutes = the faster of the two. The limits
apply to best_minutes, one way: limit_minutes / within_limit = the limit for onsite 1-2 days a week,
limit_minutes_3plus / within_limit_3plus = the limit for onsite 3+ days a week. The full rules
(including "no limit" for monthly or remote) are in documents/job-preferences.md §Commute.
or {"error": "..."} with exit code 1 when the place cannot be found or routed.

Home and limits are read from documents/commute-home.json (personal data, gitignored; template in
documents.example/commute-home.json):
  {"address", "lat", "lon", "ebike": true|false,
   "limits_minutes": {"3plus_days": N, "1to2_days": N}}
Geocoding: Photon (komoot), then Nominatim (both OpenStreetMap). Routing:
Transitous (MOTIS, official timetable data) for the next Tuesday, departures 07:00-08:30
Europe/Berlin; the fastest itinerary counts, so results are comparable between jobs.
Results are cached in jobs/.commute-cache.json by destination text.
"""
import json
import math
import sys
import time
import urllib.parse
import urllib.request
from datetime import datetime, timedelta
from pathlib import Path
from zoneinfo import ZoneInfo

ROOT = Path(__file__).resolve().parent.parent
HOME_FILE = ROOT / "documents" / "commute-home.json"
CACHE_FILE = ROOT / "jobs" / ".commute-cache.json"
UA = "job-hunt-commute-check/1.0 (personal use)"
TZ = ZoneInfo("Europe/Berlin")


def get_json(url):
    req = urllib.request.Request(url, headers={"User-Agent": UA})
    with urllib.request.urlopen(req, timeout=30) as resp:
        return json.load(resp)


def geocode(text):
    q = urllib.parse.quote(text)
    try:
        feats = get_json(f"https://photon.komoot.io/api/?q={q}&limit=1&lang=de")["features"]
        if feats:
            lon, lat = feats[0]["geometry"]["coordinates"]
            p = feats[0]["properties"]
            name = ", ".join(str(p[k]) for k in ("name", "street", "housenumber", "postcode", "city", "country") if p.get(k))
            return lat, lon, name
    except Exception:
        pass
    time.sleep(1)  # Nominatim usage policy: max 1 request per second
    res = get_json(f"https://nominatim.openstreetmap.org/search?format=json&limit=1&q={q}")
    if res:
        return float(res[0]["lat"]), float(res[0]["lon"]), res[0]["display_name"]
    return None


def ebike_minutes(a, b):
    """E-bike estimate: haversine distance x 1.35 (road detour) at 20 km/h."""
    lat1, lon1, lat2, lon2 = map(math.radians, (a[0], a[1], b[0], b[1]))
    h = math.sin((lat2 - lat1) / 2) ** 2 + math.cos(lat1) * math.cos(lat2) * math.sin((lon2 - lon1) / 2) ** 2
    km = 2 * 6371 * math.asin(math.sqrt(h)) * 1.35
    return round(km / 20 * 60)


def next_tuesday_departures():
    now = datetime.now(TZ)
    days = (1 - now.weekday()) % 7 or 7
    day = (now + timedelta(days=days)).date()
    return [datetime(day.year, day.month, day.day, h, m, tzinfo=TZ) for h, m in ((7, 0), (7, 45), (8, 30))]


def route(home, dest):
    best = None
    for dep in next_tuesday_departures():
        t = dep.astimezone(ZoneInfo("UTC")).strftime("%Y-%m-%dT%H:%M:%SZ")
        url = (f"https://api.transitous.org/api/v5/plan?fromPlace={home[0]},{home[1]}"
               f"&toPlace={dest[0]},{dest[1]}&time={t}&numItineraries=3")
        for it in get_json(url).get("itineraries", []):
            minutes = round(it["duration"] / 60)
            if best is None or minutes < best["minutes"]:
                legs = [l.get("routeShortName") or l["mode"].lower() for l in it["legs"]]
                best = {"minutes": minutes, "route": " > ".join(legs), "departure": it["startTime"]}
        time.sleep(0.5)
    return best


def main():
    if len(sys.argv) != 2 or not sys.argv[1].strip():
        print(__doc__, file=sys.stderr)
        return 2
    dest_text = sys.argv[1].strip()
    cache = json.loads(CACHE_FILE.read_text()) if CACHE_FILE.exists() else {}
    if dest_text in cache:
        print(json.dumps({**cache[dest_text], "cached": True}, ensure_ascii=False))
        return 0
    home = json.loads(HOME_FILE.read_text())
    limits = home.get("limits_minutes") or {}
    if "1to2_days" not in limits:
        print(json.dumps({"error": f"limits_minutes.1to2_days missing in {HOME_FILE}"}))
        return 1
    limit = limits["1to2_days"]
    limit_3plus = limits.get("3plus_days")
    use_ebike = bool(home.get("ebike", False))
    geo = geocode(dest_text)
    if not geo:
        print(json.dumps({"error": f"location not found: {dest_text}"}))
        return 1
    best = route((home["lat"], home["lon"]), geo)
    bike = ebike_minutes((home["lat"], home["lon"]), geo) if use_ebike else None
    if not best and (bike is None or bike > limit):
        print(json.dumps({"error": f"no public-transport route found to {geo[2]}", "ebike_minutes": bike}, ensure_ascii=False))
        return 1
    transit = best["minutes"] if best else None
    fastest = min(m for m in (transit, bike) if m is not None)
    out = {"destination": dest_text, "resolved": geo[2], "minutes": transit,
           "route": best["route"] if best else None, "departure": best["departure"] if best else None,
           "ebike_minutes": bike, "best_minutes": fastest,
           "best_mode": "ebike" if bike is not None and (transit is None or bike < transit) else "transit",
           "limit_minutes": limit, "within_limit": fastest <= limit,
           "limit_minutes_3plus": limit_3plus,
           "within_limit_3plus": fastest <= limit_3plus if limit_3plus is not None else None,
           "source": "transitous"}
    cache[dest_text] = out
    CACHE_FILE.parent.mkdir(parents=True, exist_ok=True)
    CACHE_FILE.write_text(json.dumps(cache, ensure_ascii=False, indent=1))
    print(json.dumps(out, ensure_ascii=False))
    return 0


if __name__ == "__main__":
    sys.exit(main())
