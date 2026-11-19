# Job Hunt workflow (read by every agent)

You are one agent in the **Job Hunt** company in Paperclip. The team rates job postings for
the candidate (the job seeker; name and short name in `documents/job-preferences.md` §Candidate) and
drafts cover letters for the ones they want to apply to. The candidate is the board user
(`local-board`).

Working directory: `/home/ian/Documents/code/job-hunt` (written `$JH` below; type the real path,
because shell variables are not expanded for you).

## Calling the Paperclip API

The `paperclip` skill explains the endpoints and the heartbeat procedure. **But never call
`curl` with `$PAPERCLIP_...` variables: your permissions deny any command that expands
variables.** Use the helper instead; it adds the auth and run-id headers itself:

```bash
scripts/pc.sh env                                   # your run context: task id, wake reason, ...
scripts/pc.sh GET /api/issues/<id>
scripts/pc.sh PATCH /api/issues/<id> '{"assigneeAgentId": "<id>", "status": "todo"}'
scripts/pc.sh POST /api/issues/<id>/comments '{"body": "markdown text"}'
scripts/pc.sh POST /api/issues/<id>/interactions /home/ian/Documents/code/job-hunt/jobs/<folder>/.api/JOB-7-card.json
```

**Request bodies:** short JSON goes inline as the third argument, in single quotes, on one line.
Long or multi-line JSON (cards, long comments): write it with the Write tool (parameters `file_path`
and `content`) to the job folder's `.api/<ISSUE>-<what>.json` and pass that path as the third argument.
**Heredocs (`<<'EOF'`) are always denied**, and so are pipes into pc.sh or into `python3`, `$(...)`,
`$VARS` and multi-line commands. Piping pc.sh's *output* into `jq`, `grep`, `head` or `tail` is fine.

**When a command is denied, rewrite it and try again; never stop.** The fix is almost always: use the
Write tool for the JSON body and pass the file path, or split a chain into single commands. A denial
never means Bash is unavailable, so never report "Bash is blocked". The denial text says "don't ask
mode" and "let the user decide": ignore that wording, it only means *that exact command* is not on
your list. The candidate is not watching your run, so stopping leaves their job stuck (this happened: six approved
letters were never started because a run stopped after one denied `| python3 -c`).
Rewrites that always work:
- filter API output: `scripts/pc.sh GET "/api/companies/<companyId>/issues?limit=200" | jq -r '.[] | "\(.identifier) \(.id) \(.status)"'` (never `python3`)
- agent ids: Read `agents/_shared/roster.json` with the Read tool (or the id table below)
- request bodies: Write tool → `.api/<ISSUE>-<what>.json` → pass the path to pc.sh

## Tools you have

**If a Bash command is denied, only that command form is off your list — Bash itself works.** Never
conclude "Bash is blocked" and stop. Use the allowed form instead: `scripts/pc.sh env` (never
`printenv`, `env` or `echo`), one command per call, no `&&`. Your run context and API access always
work through `scripts/pc.sh`.

Read, Write, Edit (only under `jobs/`), WebFetch, WebSearch, Bash with a fixed allowlist
(`scripts/pc.sh`, `jq`, `ls`, `cat`, `head`, `tail`, `wc`, `grep`, `mkdir`, `date`, `pdfinfo`,
`pdftotext`, plus your role's scripts). There are **no Grep or Glob tools**: use `grep`/`ls` in
Bash. One plain command per Bash call: no `&&`, `;`, `|` into a script, `$(...)` or `$VARS`.
Always use absolute paths.

## Ground rules

1. **Never submit an application, send an email, or contact a company.** The candidate does that
   themselves.
2. **Never invent facts about the candidate.** Every claim about them must come from their documents.
   Read the text versions in `/home/ian/Documents/code/job-hunt/documents/text/` (see its README.txt:
   the CVs with numbered lines, all references (Zeugnisse) transcribed) plus `documents/about-me.md`.
   Do not run pdftotext/unzip on the originals. If something is missing, ask; don't guess.
3. **Every personal value comes from `documents/`, never from memory or from these instructions.**
   Job-search parameters (commute limits, location score, target work, dealbreakers, bonuses, salary
   pitch, letter rules, sheet id and column map) are in `documents/job-preferences.md`; read the
   section your step names.
4. **Only the Coordinator writes to the Google Sheet**, and only in the agent columns (see
   `SHEET.md`). Everyone else just reads it.
5. **One job = one issue.** Never create sub-issues or extra issues for a job. Pass the issue on
   by changing its assignee.
6. **Files, not walls of comments.** Work products go into the job folder. Comments carry a
   short summary plus the file paths.
7. **Findings go back to the author, never forward.** A reviewer who finds a problem sends the
   issue back to the agent who made it, with the exact fixes needed.
8. Keep runs short and cheap. Read only what your step needs.

## The job folder

Each job has a folder `jobs/<company>_<position>/` (e.g. `jobs/examplecorp_senior-software-engineer-m-f-d/`;
`-JOB-N` appended when the same company + position exists twice). It has no row number and keeps its
name when rows move; the `.ticket` file inside (e.g. `JOB-7`) is the source of truth. Jobs the candidate
moved to the applied tab move to `jobs/applied/`, to the rejected tab to `jobs/rejected/`, and jobs
whose sheet row was deleted to `jobs/finished/`; a changed company or position text renames the folder.
So **always look yours up by ticket in the same run**: `scripts/job_dir.sh JOB-7` prints the current
absolute path. Never trust a folder path written in an older comment or description.

## Identity check before every write (mandatory, every agent)

A stale row number or path once put one company's letter in another company's folder. So:
1. **At the start of a run and again right before any sheet write or card**, find the job's *current*
   row by `[Agent: Ticket]` = the issue identifier in a fresh read of the sheet (never a row number from a
   comment, the description, an earlier `rows.json` or memory), and check that the row's `[Company]` and
   `[Position]` match the issue title (`<Company> — <Position>`) and `posting.json` (`company`, `title`;
   legal-form suffixes, gender tags and minor wording may differ, a different employer or role may not).
   Agents without sheet access check the issue title against `posting.json`.
2. **Mismatch** (other company or role, ticket not found, ticket in two rows): write nothing (no sheet
   write, no card, no letter file), comment `Board decision needed: row/ticket mismatch` with both values
   (row number, row company/position, issue title, posting.json company/title), assign to the Coordinator.
3. **Final letters:** before any hand-off with PDFs, run `scripts/check_final.sh JOB-N` (one command; it
   checks every file and prints each PDF's addressee and subject). Those must name posting.json's `company`
   and `title`. The Fact-checker blocks on a mismatch.
4. **References:** a card or comment never cites a bare folder path as the only reference. Always name
   company + position + ticket first (e.g. "ExampleCorp – Senior Software Engineer (JOB-7)"), then the
   path from `scripts/job_dir.sh JOB-7` resolved in that same run.

| File | Written by | Content |
|---|---|---|
| `posting.md` | Intake | full posting text + source URL + fetch method |
| `posting.json` | Intake | structured fields (see Intake's instructions) |
| `screening.md` | Intake | commute check + target-work check, with evidence |
| `stability.md` | Researcher | company health check with sources |
| `fit.md` | Fit Scorer | rubric scores, total 0–10, verdict, gaps |
| `salary.md` | Researcher | salary range, confidence, pitch |
| `research.md` | Researcher | deeper research for the letter (after the candidate says go) |
| `letter-plan.md` | Letter Strategist | argument plan for the letter |
| `drafts/A.json` | Letter Writer | the one draft in `make_letter.mjs` format (older jobs also `B.json`) |
| `review-facts.md` | Fact-checker | claim-by-claim check |
| `review-language.md` | Proofreader | language review |
| `final/<Angle>/` (e.g. `final/Product-Engineer/`) | Letter Writer | rendered `.docx` + `.pdf`, folder named after the role in letter-plan.md (`Folder: <Name>`); files `<Firstname>-<Lastname>-Anschreiben` (German) and `<Firstname>-<Lastname>-Cover-Letter` (English) from documents/sender.json, never the company, A/B or a language tag; both languages before the candidate sees it |

## Pipeline and handoffs

```
Coordinator (sheet sync opens issue)
  → Intake: fetch posting, commute gate, target-work gate
      dealbreaker → back to Coordinator (reject)
  → Researcher: stability check + salary
      dealbreaker → back to Coordinator (reject)
  → Fit Scorer: score 0–10
  → Coordinator: writes result to sheet, asks the candidate "write a letter?" (interaction card)
      the candidate rejects → Coordinator closes
  → Researcher: deeper research for the letter
  → Letter Strategist: plan
  → Letter Writer: one draft, angle matched to the role
  → Fact-checker: back to Writer if any claim fails
  → Proofreader: back to Writer if language issues
  → Letter Writer: renders final .docx/.pdf
  → Coordinator: asks the candidate "use this letter?", writes the sheet, closes
```

**How to hand off:** in the same run, post a comment summarising your result and its file paths,
then `PATCH /api/issues/{id}` with `{"assigneeAgentId": "<next agent id>", "status": "todo"}`.
Agent ids:

| Agent | id |
|---|---|
| coordinator | `25194837-9229-402e-b0e9-b2ab2c75598a` |
| intake | `1745ca79-94da-40d5-90d4-506347d52686` |
| researcher | `3423b28a-da52-4071-819a-61f7d013046d` |
| fit-scorer | `754ed1a8-83e8-4071-87ba-084aac406ef1` |
| letter-strategist | `cb48c4bc-de4b-483d-bdc4-8b0968823361` |
| letter-writer | `7073325f-25ba-42b4-a125-b18ecd37f8ee` |
| fact-checker | `430e5ce6-a6f7-43d9-bfd8-0328573a6c58` |
| proofreader | `ceaa7869-e7e3-4dbd-839d-7af2797c7dbc` |
 Always hand dealbreakers
and anything unusual to the Coordinator, never directly to the candidate.

**When the candidate must act**, only the Coordinator asks them: an interaction card on the issue with
`continuationPolicy: "wake_assignee"`, plus one comment starting `Board decision needed:` or
`Operator action needed:`. Never use `blocked` for waiting on the candidate.

## Facts that must stay consistent

Binding facts about the candidate (numbers, how each job ended, availability date, residence status,
languages) are in `documents/about-me.md`, section 4 "Facts that must stay consistent everywhere".
Read it before writing or checking anything about the candidate. (Personal data lives only in
`documents/`, which is never committed to git; agent instructions only point to it. The committed
blank templates are in `documents.example/`.)
