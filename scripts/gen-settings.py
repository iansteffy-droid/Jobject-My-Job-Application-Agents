#!/usr/bin/env python3
"""Generate config/claude-settings/<agent>.json: each agent's Claude Code permission allowlist.

Run after changing the rules: python3 -I scripts/gen-settings.py
Agents run headless in "dontAsk" mode, so anything not allowed here is denied.

Notes from testing (2026-11-13):
- The operator's RTK hook rewrote shell commands (`cat` -> `rtk read`), which broke the allowlist
  at random; agent settings set disableAllHooks. The `rtk ` rule variants stay as a harmless fallback.
- Commands that expand $VARIABLES are never auto-approved; agents call the Paperclip API through
  scripts/pc.sh, which reads the PAPERCLIP_* variables itself.
- File-writing permissions are expressed as Edit(path) rules (they cover Write too).
- No curl/sed/unzip (review 2026-11-13): curl could exfiltrate documents if a fetched posting carries a
  prompt injection, and `sed -i` bypasses the Edit denies. The API goes through pc.sh, the web through
  WebFetch / fetch_page.sh, the candidate's documents are pre-extracted in documents/text/.
"""
import json
import re
from pathlib import Path

JH = Path(__file__).resolve().parent.parent
J = str(JH)


def bash(*prefixes):
    rules = []
    for p in prefixes:
        rules += [f"Bash({p}:*)", f"Bash(rtk {p}:*)"]
    return rules


def script(rel):
    return (rel, f"{J}/{rel}")


SHEETS_READ = ["mcp__claude_ai_Google_Sheets__get_values", "mcp__claude_ai_Google_Sheets__get_spreadsheet"]
# update_spreadsheet: only for colouring a Company cell yellow (Coordinator instructions, SHEET.md).
SHEETS_UPDATE = ["mcp__claude_ai_Google_Sheets__update_values"]
SHEETS_WRITE = SHEETS_UPDATE + ["mcp__claude_ai_Google_Sheets__update_spreadsheet"]

BASE = (["Read", "Glob", "Grep", "WebFetch", "WebSearch", f"Edit(/{J}/jobs/**)"]
        + bash(*script("scripts/pc.sh"), *script("scripts/job_dir.sh"), *script("scripts/check_final.sh"), *script("scripts/check_postings.sh"), "jq", "mkdir", "ls", "date", "cat", "head", "tail", "wc", "grep",
               "pdftotext", "pdfinfo")
        + SHEETS_READ)

ROLES = {
    "coordinator": BASE + SHEETS_WRITE + bash("python3 -I scripts/sync_folders.py", f"python3 -I {J}/scripts/sync_folders.py"),
    "intake": BASE + bash(f"python3 -I scripts/commute.py", f"python3 -I {J}/scripts/commute.py",
                          *script("scripts/fetch_page.sh")),
    "researcher": BASE + bash(*script("scripts/fetch_page.sh")),
    "fit-scorer": BASE,
    "letter-strategist": BASE,
    "letter-writer": BASE + bash("node scripts/letter/make_letter.mjs", f"node {J}/scripts/letter/make_letter.mjs"),
    "fact-checker": BASE,
    "proofreader": BASE,
    # Scouting team (agents/_shared/SCOUTING.md): both write only the scout tab; no colouring, so no update_spreadsheet.
    "job-scout": BASE + SHEETS_UPDATE + bash("python3 -I scripts/scout.py", f"python3 -I {J}/scripts/scout.py", "python3 scripts/scout.py", f"python3 {J}/scripts/scout.py",
                                             *script("scripts/fetch_page.sh")),
    "job-reviewer": BASE + SHEETS_UPDATE + bash("python3 -I scripts/scout.py", f"python3 -I {J}/scripts/scout.py", "python3 scripts/scout.py", f"python3 {J}/scripts/scout.py",
                                                "python3 -I scripts/commute.py", f"python3 -I {J}/scripts/commute.py"),
}

DENY = (bash("git push", "rm -rf")
        + [f"Edit(/{J}/{d}/**)" for d in ("documents", "agents", "scripts", "config", "paperclip")])

# Each agent's model comes from the ROSTER table in scripts/provision.sh (the single source).
MODELS = dict(re.findall(r"^(?:ROSTER=\")?([a-z-]+)\|[^|]*\|[^|]*\|([^|]+)\|", (JH / "scripts" / "provision.sh").read_text(), re.M))


def superpowers_on(model):
    """~/.claude/MODEL-POLICY.md: superpowers ON for Claude 4.x and older, OFF for the 5 generation and newer.
    Bare aliases (opus, sonnet, haiku, fable, mythos) resolve to the newest generation, so they count as OFF."""
    m = re.match(r"claude-[a-z]+-(\d+)", model)
    return bool(m) and int(m.group(1)) <= 4


out = JH / "config" / "claude-settings"
out.mkdir(parents=True, exist_ok=True)
for role, allow in ROLES.items():
    settings = {"permissions": {"allow": allow, "deny": DENY, "defaultMode": "dontAsk"},
                # The operator's own hooks (RTK command rewriting, superpowers gate) must not run in agent
                # sessions: RTK rewrites e.g. `cat` to `rtk read`, which then fails the allowlist.
                "disableAllHooks": True}
    # Agents share the operator's ~/.claude, where superpowers is enabled; with hooks off the model gate
    # cannot run, so apply the policy here per agent model.
    if not superpowers_on(MODELS[role]):
        settings["enabledPlugins"] = {"superpowers@claude-plugins-official": False}
    (out / f"{role}.json").write_text(json.dumps(settings, indent=1) + "\n")
print("wrote", ", ".join(f"{r} ({MODELS[r]}, superpowers {'on' if superpowers_on(MODELS[r]) else 'off'})" for r in ROLES))
