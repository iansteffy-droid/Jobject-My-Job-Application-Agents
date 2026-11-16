# About me — profile notes for the job-hunt agents

<!-- TEMPLATE. Copy documents.example/ to documents/ and fill this file in. documents/ is gitignored.
     Keep the numbered section headings: agents cite them ("about-me.md §4"). Everything here must
     be true and match your CVs and references; where they disagree, the documents win. -->

What the agents need to know about the candidate that is not already in the CVs, references and
certificates in this folder. Agent-facing reference, not an application document. The CVs in `cv/`
and the references in `references/` are the primary sources; where this file and those documents
disagree, the documents win and this file should be corrected.

Last updated: <YYYY-MM-DD>

---

## 1. Situation

- <Current or last employer, and how/when the job ends or ended, in the exact wording you want used.>
- <Anything that explains your dealbreakers, e.g. why company stability matters to you.>
- **Available from <DD.MM.YYYY>.** <Notice period, if any.>
- <What kind of role you are looking for; the job title you want to be presented with.>

## 2. Personal facts

| Fact | Value |
|---|---|
| Name | <Your Full Name> |
| Born | <DD.MM.YYYY, or leave out> |
| Home | <city / district; the exact address goes into commute-home.json and sender.json> |
| Phone / email | <"on the CV", or the values> |
| LinkedIn | <linkedin.com/in/...> |
| GitHub | <github.com/... or none; say whether agents may cite it> |
| Citizenship / work permit | <citizenship; residence or work permit; visa or sponsorship needed?> |
| Languages | <language: level (certificate, year)> |
| Education | <degree, institution, place, year> |
| Certificates | <name (date); see `certificates/`> |

## 3. Career gap explanation

<Any gap in the CV and the exact framing to use, or "none".>

## 4. Facts that must stay consistent everywhere

Letters, CV suggestions and interview prep must use these exact figures and wordings:

- <A number that must always be the same, e.g. team size, years of experience (since YYYY).>
- <How each job ended, in the exact wording to use, and wording that must never be used.>
- <Claims you removed from your CV that must not come back.>

## 5. Your strongest work in depth (material for letters and interviews)

The CV bullets are the claimable summary. Background for richer, concrete letters:

- **<Project or achievement>.** <What you built or did, scale, result, numbers.>
- **<Project or achievement>.** <...>
- **<A failure and what you learned (good interview story)>.** <...>

## 6. What I am looking for

- **Role:** <the work you want to do; this matches job-preferences.md §Target work>
- **Location, commute limits and dealbreakers:** in `job-preferences.md` (§Commute, §Location score,
  §Target work, §Dealbreakers), the single source for the agents.
- **Not yet known (ask me):** <e.g. salary floor, preferred company size or sectors, travel>

## 7. Writing preferences

- <How much help you want with letters, e.g. "agents plan, write and proofread the drafts".>
- <Delivery format, e.g. .docx and PDF.>
- Write letters in the posting's language (German or English). German letters follow German
  conventions (DIN 5008, Betreff line, one page).
- <What every letter should lead with.>

## 8. Documents in this folder

| Path | What |
|---|---|
| `cv/<CV file>` | <English CV (current)> |
| `cv/<Lebenslauf file>` | <German CV (current), if any> |
| `references/<file>.pdf` | <references / Arbeitszeugnisse: employer, which one is the main proof> |
| `text/` | text versions of the CVs and all references; agents read these |
| `certificates/<file>.pdf` | <certificates> |
| `about-me.md` | this file |
| `job-preferences.md` | tunable job-search parameters: commute limits, location score, dealbreakers, bonuses, salary pitch, letter rules, sheet id and column map |
| `sender.json`, `commute-home.json` | letter sender block; home location + commute limits for `scripts/commute.py` |
