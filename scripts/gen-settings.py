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
SHEETS_WRITE = ["mcp__claude_ai_Google_Sheets__update_values", "mcp__claude_ai_Google_Sheets__update_spreadsheet"]

BASE = (["Read", "Glob", "Grep", "WebFetch", "WebSearch", f"Edit(/{J}/jobs/**)"]
        + bash(*script("scripts/pc.sh"), *script("scripts/job_dir.sh"), "jq", "mkdir", "ls", "date", "cat", "head", "tail", "wc", "grep",
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
}

DENY = (bash("git push", "rm -rf")
        + [f"Edit(/{J}/{d}/**)" for d in ("documents", "agents", "scripts", "config", "paperclip")])

out = JH / "config" / "claude-settings"
out.mkdir(parents=True, exist_ok=True)
for role, allow in ROLES.items():
    (out / f"{role}.json").write_text(json.dumps(
        {"permissions": {"allow": allow, "deny": DENY, "defaultMode": "dontAsk"},
         # The operator's own hooks (RTK command rewriting, superpowers gate) must not run in agent
         # sessions: RTK rewrites e.g. `cat` to `rtk read`, which then fails the allowlist.
         "disableAllHooks": True}, indent=1) + "\n")
print("wrote", ", ".join(ROLES))
