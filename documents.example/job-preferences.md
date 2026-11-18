# Job preferences — tunable job-search parameters (personal, gitignored)

<!-- TEMPLATE. Copy documents.example/ to documents/ and fill this file in. documents/ is gitignored.
     Keep every heading exactly as it is: the agent instructions point at them by name
     ("job-preferences.md §Commute"). Replace every <...> placeholder; delete the guidance comments
     if you like. -->

The committed agent instructions (`agents/`) hold only the generic rules. Every personal value they
need comes from this file; they point at its sections by name ("job-preferences.md §Commute").
Facts about the candidate (CV facts, proof points, availability, consistency facts) are in
`about-me.md`; this file holds the job-search choices.

Last updated: <YYYY-MM-DD>

## Candidate

- **Name** (in prose: "the candidate"): <Your Full Name>. Full sender block for letters: `sender.json`.
- **Short name** (`<name>` in the sheet stage labels and in card/comment wording): `<FirstName>`
  <!-- Stage labels become e.g. "waiting for <FirstName>", "needs <FirstName> (yellow)". -->
- The candidate is the Paperclip board user (`local-board`).

## Commute

Measured one way from home (`commute-home.json`), by `scripts/commute.py`. Modes: public transport
<and e-bike / only>. <!-- With "ebike": true in commute-home.json the limits apply to best_minutes,
the faster of public transport and the e-bike estimate; with false, to public transport only. -->
The same limits are mirrored, machine-readable, in `commute-home.json` → `limits_minutes` (keep both
in sync).

The limit depends on how often the candidate must be onsite:

| Onsite frequency | Limit | Rule |
|---|---|---|
| **3 or more days a week** (incl. fully onsite) | <e.g. 45 min> | over **<N> min** = **dealbreaker**; <optional: a band just below the limit that passes with a note, e.g. `commute at the limit`> |
| **1–2 days a week** | <e.g. 75 min> | over **<N> min** = **dealbreaker** |
| **Less than weekly** (monthly, quarterly team days) or fully remote | <none / N min> | <e.g. always PASS> |
| Unclear wording ("flexible", "occasional office days", no location) | — | never reject; mark it `unclear` and let it pass (the Fit Scorer weighs it, the Coordinator flags it) |

If the posting offers several locations or remote as an option, use the best option the candidate could choose.

## Location score

Row "Location and commute" (weight 15 %) of the Fit Scorer rubric. 0–10 per case; use
`best_minutes` and the onsite frequency from screening.md.

- **Workplace in <your city>: <score>** <!-- e.g. 10 -->
- **Commute under <N> min: <score>**
- **Full remote, or onsite less than weekly: <score>** <!-- optionally by office distance -->
- **Onsite 1–2 days a week:** <bands, e.g. 30–60 min 7, 60–75 min 5>
- **Onsite 3+ days a week:** <bands, e.g. 30–45 min 6>
- Unclear onsite frequency: **<score, e.g. 7>** (never score a far office low only because the frequency is unknown)

Sheet-note shorthand for a local office: `<e.g. "Hometown office">`.

## Target work

What the candidate's next job must involve. The agents write this as "target work".

- **Label** (`<label>` in agent notes and verdicts): `<e.g. Data>` → note `<label> in title only`,
  verdict `Dealbreaker: no <label> work`.
- **Counts as target work:** <one or two sentences: the hands-on work that must be part of the job,
  and what does not count (e.g. a buzzword only in the company slogan)>
- **Title keywords:** <comma-separated words that, in a job title, signal the target work>
- **Title rule:** <e.g. a job whose title contains a title keyword is never rejected for missing
  target work; it only loses points when the duties show little real target work>
- **Letter focus:** <what every letter leads with; which claims rest on the main-proof document (§Main proof)>
- **Letter research focus:** <what the Researcher looks for, e.g. what the product or team does with X>

## Dealbreakers

Exactly these three, and nothing stricter:

1. **Commute too long for the onsite days:** limits in §Commute.
2. **No real target work** (§Target work), but only when the job title has no title keyword.
3. **Unstable company:** the Researcher's RED verdict (insolvency, restructuring proceedings,
   acute money trouble). Layoffs alone are a watch flag, not a rejection. <Why it matters to you,
   or a pointer to about-me.md §1.>

Weighted, not dealbreakers: <e.g. salary, company size, sector, exact location>.

## Role level

Row "Role type and level" (weight 15 %) of the Fit Scorer rubric; judge only by what the posting states:

- <role type, e.g. Senior / lead engineering>: **<score range, e.g. 8–10>**
- <role type>: **<score range>** <!-- e.g. roles your CV shows experience in -->
- <role type>: **<score range>**
- Junior or working-student roles: **<score>**

## Bonuses

Added to the Fit Scorer's weighted average, then the total is capped at 10.0. The bonuses add up.
Short name = how the bonus appears in the score breakdown (`Base 8.1 + <short name> 0.5 = 8.6`).
<!-- Leave the table empty (header only) if you want no bonuses. -->

| Bonus | Short name | Points | When (quote the posting) |
|---|---|---|---|
| <what the job offers> | `<short>` | **+<points>** | <exact condition the posting must state> |

## Salary

Pitch policy for the Researcher's `salary.md`: <your seniority in one line and where in a credible
range to aim, e.g. "upper third, but inside the range">. For tariff jobs, name the pay group and level
to ask for. Salary floor: <amount or "not set">. When a posting asks for a salary expectation, the letter
names the pitch from the job's `salary.md`; without salary.md the sentence is left out. Never a placeholder.

## Main proof

- **Main-proof document for the target work:** `text/<file>.txt` <!-- the reference/document that best
  proves your target work in someone else's words -->. Its key statements are listed in
  `text/README.txt`. Letter Strategist, Writer and Fact-checker read it in full for every letter.
- Availability, consistency facts and the strongest proof points: `about-me.md` §1, §4, §5.

## Letters

- Letter language = the posting's language (German posting → German letter).
- **Both languages for every letter:** <always / never> <!-- "always" = every angle gets a German and an
  English letter, whatever the posting's language (e.g. because your German is limited) -->
- <How much the agents should do: plan, write and proofread the letters for you; see about-me.md §7.>
- Own writing samples to study the voice: <path under documents/, or "none">

## Search

Used by the scouting team (Job Scout, Job Reviewer; `agents/_shared/SCOUTING.md`). The machine-readable
part is `search.json`: chunk size, maximum posting age, title keywords and exclusions, the job-board
searches per tier, the web queries, how many target companies to check per run, and the lists of
recruiters and aggregator sites.

- **Chunk:** <e.g. 10 jobs per run, once a day, plus the "Find jobs" button; runs queue one after another>
- **Posting age:** <e.g. at most 30 days since first publication; no date on the posting: include it, marked `date unknown`>
- **Where to look, in this order of preference** (<your rule, date>): <e.g. your home town, then anywhere inside the commute limits of §Commute, then remote in your country, then remote abroad. Point at §Commute and §Location score; do not repeat their numbers>
- **Sources:** <e.g. Arbeitsagentur, Arbeitnow and StepStone (through `scripts/scout.py search`), general web search for postings on employers' own sites, careers pages of the companies in your target-company tab. Copies on aggregator sites (`aggregator_hosts` in search.json) are never used>
- **Recruiters:** <your rule, e.g.: postings of the real employer come before postings of recruiters,
  headhunters and staffing agencies; at most `max_recruiter_jobs_per_chunk` (search.json) recruiter
  postings per chunk, always marked `(recruiter; client: ...)` and rated one match level lower. Or: never
  list recruiter postings (set the limit to 0).> Known agencies: `recruiter_names`, `recruiter_hosts` in search.json.
- **Never:** LinkedIn (no search, no fetch, no LinkedIn URL in the sheet).
- **After the review:** the candidate reads the scout tab and moves the rows they want to the job tab
  themselves. The scouting team never writes to the job tab.

### Scout tab

- **Tab:** `<scout tab name>` (sheetId `<sheetId>`), same spreadsheet as §Sheet. Header row **<n>**, data from row <n+1>.
- **Read-only tabs the Scout checks for jobs the candidate already has:** the job tab, the applied tab and
  the rejected tab (§Sheet), columns A to G.
- **Target-company tab (read-only):** `<tab with your target companies, or: none>` (header row <n>: company, industry, site URL, location).

| Role | Exact header | Today | Who writes |
|---|---|---|---|
| `[Position]` | `Position` | B | Job Scout; Reviewer corrects |
| `[Company]` | `Company` | D | Job Scout; Reviewer corrects |
| `[URL]` | `URL` | E | Job Scout; **the key used to find a row** |
| `[Work mode]` | `Remote/ inhouse ` | F | Job Scout; Reviewer corrects (header has a trailing space) |
| `[Languages]` | `Lang req` | H | Job Scout; Reviewer corrects |
| `[Location]` | `Location` | I | Job Scout; Reviewer corrects |
| `[Cons]` | `Cons` | J | Job Scout |
| `[Positives]` | `Positives / Notes ` | K | Job Scout (header has a trailing space) |
| review verdict | `Scout: Review` | Y | Job Reviewer |
| match level | `Scout: Match` | Z | Job Reviewer |
| review notes | `Scout: Review notes` | AA | Job Reviewer |
| commute | `Scout: Commute` | AB | Job Reviewer |
| posting date | `Scout: Posted` | AC | Job Scout; Reviewer corrects |
| date found | `Scout: Found` | AD | Job Scout |
| where found | `Scout: Source` | AE | Job Scout |
| chunk | `Scout: Chunk` | AF | Job Scout (the chunk's issue identifier) |

**Never-write columns in the scout tab:** <your own marker columns, e.g. `Date Applied`, your own score> and every `Agent:` column. The `Agent:` columns stay empty in the scout tab; the Coordinator fills them after you moved the row to the job tab.

## Sheet

- **Spreadsheet:** <sheet name>, id `<spreadsheet id from the sheet URL: docs.google.com/spreadsheets/d/<id>/edit>`
- **Job tab:** `<tab name>` (sheetId `<number after #gid= in the tab URL; the first tab is usually 0>`).
  Access through the `mcp__claude_ai_Google_Sheets__*` tools (connector logged in as your Google account).
- **Header row:** **<row number, e.g. 1>** <!-- rows above it, if any, are ignored -->. Data starts in the next row.
- **Applied tab (read-only):** `<tab name>` or none <!-- you move a job's row here from the job tab once you applied or are interviewing; same header row -->
- **Rejected tab (read-only):** `<tab name>` or none <!-- you move a job's row here when you rejected it or won't apply; same header row; its column order may differ, agents find columns by header -->
- **Notes tab (read-only, Letter Strategist):** `<tab name>` or none <!-- notes from earlier applications -->
- **Agent columns:** today `<first letter>`–`<last letter>` (headers starting with `Agent:`, right of
  your columns; the Coordinator adds the headers on its first sync, see agents/_shared/SHEET.md).
- **Abbreviations in your cells that are not errors:** <e.g. "Ber" = Berlin, or none>

### Column map

The agent instructions use the role names in the first column. Each role maps to the **exact** header
text in your header row (copy it character for character, trailing spaces included). Columns are
always found by header text; "Today" is only the current layout and may be outdated. Remove rows for
columns your sheet does not have; `[URL]`, `[Company]`, `[Position]` and `[Date Applied]` are required.
Further private-note columns can be added with a role name of your choice (e.g. `[Referral]`).

| Role | Exact header | Today | Access for agents |
|---|---|---|---|
| `[Action]` | `<header>` | <col> | never write (your action marker) |
| `[Position]` | `<header>` | <col> | read; job title, used for folder names; written only in rows the agents created |
| `[Date Applied]` | `<header>` | <col> | never write; filled = you already applied |
| `[Last Event Date]` | `<header>` | <col> | never write |
| `[Status]` | `<header>` | <col> | never write (your status) |
| `[Company]` | `<header>` | <col> | read; **the cell agents colour yellow** (background only); written only in rows the agents created |
| `[URL]` | `<header>` | <col> | read; the posting, **the key used to find a row** |
| `[Work mode]` | `<header>` | <col> | agents fill/correct from the posting |
| `[Own score]` | `<header>` | <col> | never write, never copy anywhere: your private 0–10 rating |
| `[Languages]` | `<header>` | <col> | agents fill/correct from the posting |
| `[Location]` | `<header>` | <col> | agents fill/correct from the posting |
| `[Cons]` | `<header>` | <col> | private note; written only in rows the agents created |
| `[Positives]` | `<header>` | <col> | private note; written only in rows the agents created |
| `[Commute]` | `<header>` | <col> | private note; written only in rows the agents created |
| `[Pitched salary]` | `<header>` | <col> | private note; written only in rows the agents created |
| `[How to apply]` | `<header>` | <col> | private note; written only in rows the agents created |

**Never-write columns** (even in rows the agents created): `[Action]`, `[Date Applied]`,
`[Last Event Date]`, `[Status]`, `[Own score]`.
