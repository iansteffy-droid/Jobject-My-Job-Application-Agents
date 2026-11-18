# documents.example — blank templates for your personal data

This folder is committed to git and contains **no personal data**. It shows exactly which personal
files the agents expect and how they must look. Your real data goes into `documents/`, which is
gitignored and never leaves your machine:

```bash
cp -r documents.example documents   # then fill in every file in documents/
```

Keep the file names, the headings and the JSON keys exactly as they are: the agent instructions in
`agents/` point at them by name (e.g. "`documents/job-preferences.md` §Commute",
"`documents/about-me.md` section 4"). Replace every `<...>` placeholder; the `<!-- ... -->` comments
are guidance and may be deleted.

## Files

| File | Read by | What goes in |
|---|---|---|
| `about-me.md` | every agent that writes or checks letters, Fit Scorer, Researcher | your profile: situation and availability (§1), personal facts (§2), CV gap framing (§3), facts that must stay consistent (§4), your strongest work in depth (§5), what you look for (§6), writing preferences (§7), list of documents (§8) |
| `job-preferences.md` | all agents | your tunable job-search parameters: candidate name (§Candidate), commute limits per onsite frequency (§Commute), location score table (§Location score), what work the job must involve (§Target work), dealbreakers, role-level scale, bonus points, salary pitch policy, main-proof document, letter rules, and your Google Sheet (§Sheet: spreadsheet id, tab, header row, column map) |
| `search.json` | `scripts/scout.py` (Job Scout, Job Reviewer) | the job searches: `chunk_size`, `max_age_days`, `title_keywords` (a title must contain one; three letters or fewer match as a whole word) and `title_exclude`, `tier_order` (nearest first) with `local_places` per tier, `ba_searches` (Arbeitsagentur: `what`, optional `where` + `radius_km`, `homeoffice_only`, `tier`), `stepstone_searches` (same keys), `arbeitnow`, `recruiter_names` / `recruiter_hosts` + `max_recruiter_jobs_per_chunk` (recruiters and staffing agencies: listed last and only up to the limit; names of four letters or fewer match as a whole word), `aggregator_hosts` (sites whose copies of postings are never used), `web_queries` + `web_searches_per_run`, `target_companies_per_run`. The matching prose is job-preferences.md §Search |
| `sender.json` | Letter Writer | sender block printed on every letter: `name`, `street`, `city` (postcode + city), `phone`, `email`, `linkedin`, `place` (the city before the date); `name` also names the letter files (`<Firstname>-<Lastname>-Anschreiben`, `<Firstname>-<Lastname>-Cover-Letter`) |
| `commute-home.json` | `scripts/commute.py` (Intake) | `address`, `lat`, `lon` (decimal degrees of your home, e.g. from openstreetmap.org: right-click → "Show address"), `ebike` (`true` adds an e-bike estimate and uses the faster mode), `limits_minutes.3plus_days` / `.1to2_days` (same limits as job-preferences.md §Commute) |

## Folders

| Folder | What goes in |
|---|---|
| `cv/` | your current CVs as `.docx`/`.pdf` (e.g. an English CV and a German Lebenslauf) |
| `references/` | references / Arbeitszeugnisse as PDFs (any subfolder or file names; list them in about-me.md §8) |
| `certificates/` | certificates as PDFs |
| `text/` | **plain-text versions of every CV and reference** — the agents read only these, never the originals. CVs one paragraph per line, numbered `L1`, `L2`, … so agents can cite `CV L12`. `text/README.txt` lists every file, says which reference is the main proof for your target work and quotes its key statements |

The agents never edit anything in `documents/` (their permissions deny it). When you change a
document, press "Sync now" on the Paperclip Dashboard: the Coordinator notices the change and has
existing letters re-checked against it.

## Your Google Sheet

1. Use any sheet with one header row and one row per job. Required columns: the job URL, company,
   position and the date you applied; everything else is optional.
2. Put the spreadsheet id, the tab name and sheetId and the header row number into
   `job-preferences.md` §Sheet, and map each of your header texts to a role in the column map.
3. Connect the claude.ai Google Sheets connector (logged in as your Google account) on the Claude
   account the agents use. On its first sync the Coordinator adds the `Agent: …` columns right of
   yours (contract: `agents/_shared/SHEET.md`).
4. Optional: two more tabs you move rows into from the job tab, one for jobs you applied to (or are
   interviewing for) and one for jobs you rejected or won't apply to. Agents only read them; the next sync
   closes the moved job and files its folder under `jobs/applied/` or `jobs/rejected/`.
