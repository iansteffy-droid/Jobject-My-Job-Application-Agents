# The job sheet contract

Every value specific to the candidate's sheet lives in `documents/job-preferences.md` §Sheet
(gitignored). Read it first; this file only holds the rules.

- **Spreadsheet id, job tab name and sheetId, header row, agent-column range:** job-preferences.md
  §Sheet. Below, `<tab>` = the job tab name, `<H>` = the header row number (data starts in row
  `<H>+1`), `<sheetId>` = the tab's sheetId. Access through the `mcp__claude_ai_Google_Sheets__*` tools
  (the connector is logged in as the candidate's Google account).
- `<name>` = the candidate's short name (job-preferences.md §Candidate), used in the stage labels below.

## Tabs: open jobs, applied, rejected

- **`<tab>`** (the job tab) holds only **open** jobs. It is the only tab agents write to (agent columns
  and the exceptions below) and the only one the Fit sort reorders.
- **`<applied tab>`** and **`<rejected tab>`** (names in job-preferences.md §Sheet, same header row): the
  candidate *moves* a job's row there once they applied or are interviewing, or rejected it / won't apply.
  A row may appear in both tabs or twice; `Agent: Ticket` (JOB-N), else `URL`, identifies the job. Their
  column order differs from `<tab>` and from each other, so locate columns by header there too.
  **Read-only for agents:** never write, colour, sort or reformat any cell in them. The Coordinator reads
  them on every sync to close moved jobs (Coordinator instructions, section A step 7).

## Columns are found by header name, never by letter

The candidate moves columns. Always read the header row first and locate every column by its exact
header text. Any letters in job-preferences.md are only the current layout and may be outdated.

**Role names.** The candidate's columns are written as role names in square brackets: `[URL]`,
`[Company]`, `[Position]`, `[Date Applied]`, `[Location]`, `[Languages]`, `[Work mode]`, `[Own score]`,
`[Cons]`, `[Positives]`, `[Commute]`, `[Pitched salary]`, `[How to apply]`, … The **column map** in
job-preferences.md §Sheet gives the exact header text for each role and what agents may do with it.
Agent columns are written with their own header text: `[Agent: Stage]` etc.

## The candidate's columns (read-only, except `[Location]`, `[Languages]`, `[Work mode]`: see below)

- `[URL]` is the posting and **the key used to find a row**.
- `[Company]` is **the cell agents colour yellow** (background only).
- `[Position]` is the job title; used for folder names.
- `[Date Applied]` filled = the candidate already applied.
- `[Own score]` (if the sheet has one) is the candidate's own 0–10 rating: private, never copy it anywhere.
- All other columns of the candidate's are private notes. Their access rules are in the column map.

## Location, Languages, Work mode: agents fill and correct (the candidate's rule)

The candidate allows three of their columns to be filled by the agents, from the posting:
`[Location]`, `[Languages]`, `[Work mode]`. Source: `posting.json` in the job folder (Intake).
- **Empty** → fill it. **Factually wrong** (contradicts the posting) → correct it, and put the old
  value in the issue comment (`Work mode: "full remote possible" → "Hybrid, 2 days/week onsite"`).
- **Not wrong:** the candidate's own abbreviations and shorthand (listed in job-preferences.md
  §Sheet). Leave them. Only change a value when the facts differ.
- When the posting does not say, leave the cell as it is.
- Formats, short like the candidate's: `[Location]` = city (several: `Hamburg / Berlin`); `[Languages]` =
  e.g. `DE C1, EN fluent`, `EN only`, `not specified`; `[Work mode]` = `Full remote`, `Hybrid, 2 days/week
  onsite`, `Onsite`, `Remote possible (frequency unclear)`.
- Everything else in the candidate's columns stays read-only.

## Rows the agents create from the candidate's URL list

When the candidate hands the Coordinator a list of job URLs, the Coordinator adds one row per job and,
for those rows only, also fills the candidate's columns `[Company]`, `[Position]`, `[URL]`,
`[Work mode]`, `[Languages]`, `[Location]`, `[Cons]`, `[Positives]` and the private-note columns the
column map marks "written only in rows the agents created" (`[Commute]`, `[Pitched salary]`,
`[How to apply]`, ...). The never-write columns listed in the column map (e.g. `[Date Applied]`,
`[Status]`, `[Own score]`) always stay the candidate's. Details: Coordinator instructions, section D.

## Agent columns: written by the Coordinator only

They sit right of the candidate's columns (current range: job-preferences.md §Sheet). Header cells in
the header row (exact text):

| Header | Content |
|---|---|
| `Agent: Ticket` | issue identifier, e.g. `JOB-12` |
| `Agent: Stage` | `queued` · `needs <name> (yellow)` · `waiting for <name>` · `writing letter` · `letter ready` · `rejected` · `posting closed` · `skipped by <name>` · `stopped by <name>` · `duplicate of JOB-N` (same posting as another row; `Agent: Why` says which) |
| `Agent: Fit (0-10)` | the Fit Scorer's total (capped at 10), one decimal, as a number |
| `Agent: Verdict` | `Strong fit` · `Good fit` · `Partial fit` · `Weak fit` · `Check eligibility` (older jobs only; WORKFLOW.md rule 10) · `Dealbreaker: commute too long for onsite days` · `Dealbreaker: no <label> work` (label from job-preferences.md §Target work) · `Dealbreaker: unstable company` · `Dealbreaker: consulting role (<why>)` (job-preferences.md §Search, Consulting roles) · `Posting closed` |
| `Agent: Why` | starts with the score breakdown, e.g. `Base 8.7 + bonus 1.5.` (bonus short names from job-preferences.md §Bonuses) then 1–2 sentences **about the job** (duties, match); for dealbreakers and closed postings, the evidence; an unmet formal requirement adds `Eligibility: … May still qualify: …` (WORKFLOW.md rule 10) |
| `Agent: Commute` | e.g. `52 min ÖPNV (Bus 3 > RE > U1) ✓`, `209 min ✗`, `remote`; add `, onsite frequency unclear` when screening says so |
| `Agent: Company stability` | e.g. `OK: profitable, 2,000 staff` / `RED: insolvency filed 2026-05` |
| `Agent: Gaps` | must-haves from the posting that the candidate's documents don't cover, e.g. `Java (required), SAP` ; `none` if they cover all |
| `Agent: Letter` | chosen letter relative to the job folder's `final/` (e.g. `Builder/<Firstname>-<Lastname>-Anschreiben.pdf`) |
| `Agent: Updated` | date `YYYY-MM-DD` |
| `Agent: Sort key` | number used to sort the rows by Fit (Coordinator, sheet sync step 6) |
| `Agent: Salary range` | from salary.md: range + confidence + main source, e.g. `75–90k € (tariff: TV-V EG 13–14)` or `80–95k € (estimate: StepStone, Kununu)` |
| `Agent: Pitch` | from salary.md: the number to pitch + a few words, e.g. `88k € – upper third, rare skill set` |

**Row order (the candidate's rule):** on every sync the Coordinator sorts the rows by Fit, highest
first, then unscored, yellow, rejected/closed, red, rows without URL, empty rows. Whole rows move; job
folders keep their names (they carry no row number), so row numbers are valid only within one read.

## Yellow rows

A yellow `[Company]` cell means "waiting for the candidate": an agent found something unclear (e.g. no
posting at the URL), coloured the cell yellow and wrote in `[Agent: Why]` what the candidate must fix.
The candidate fixes it and sets the cell back to white; the next sync continues the job. The
Coordinator may set the background of the `[Company]` cell to yellow and nothing else in the
candidate's columns. The candidate may also colour a row yellow themselves to pause it.

## Red rows

A red background on the `[Company]` or `[Position]` cell means the candidate does not want that job:
the agents never open, rate or write to such a row. Detection rule: Coordinator instructions, section A.

## Rules for writing

- **Find the row by URL every time** (search the `[URL]` column); never cache row numbers, because the
  candidate sorts and inserts rows. Row number = `<H>` + index in the `A<H>:AZ` result (the header row
  itself is index 0). If the URL appears twice, use the first match and mention it in the sync summary.
  For a row that already has a ticket, find it by `[Agent: Ticket]` and run the identity check
  (WORKFLOW.md) before writing: `[Company]`/`[Position]` must match the issue and posting.json.
- **Never comment on, correct or suggest changes to the candidate's columns**, except filling/correcting
  `[Location]`, `[Languages]` and `[Work mode]` from the posting (section above). Everything else the
  agents write goes into the agent columns and is about the job posting itself.
- Write only the agent columns of that row (headers starting with `Agent:`). `update_values` takes exactly `spreadsheetId`, `range` and
  `values` (no `valueInputOption`: it makes the call fail). In `values`, use `null` for every cell you
  do not mean to change; an empty string `""` clears the cell. Example (a layout where `Agent: Stage`
  is column S and `Agent: Updated` is column AA), setting only those two in row 12: range
  `'<tab>'!S12:AA12`, values `[["writing letter", null, null, null, null, null, null, null, "2026-11-13"]]`.
- If the header row lacks an agent header, add it right after the last agent column (exact text above). Nothing else in the header row.
- Never insert or delete rows or columns, and never touch other tabs (the read-only notes tab named in
  job-preferences.md §Sheet may be read; so may `<applied tab>` and `<rejected tab>`, never written).
