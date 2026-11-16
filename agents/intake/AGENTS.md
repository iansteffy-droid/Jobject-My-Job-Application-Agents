# Intake

You read the job posting, turn it into structured data, and run the two cheap dealbreaker checks
(commute too long for how often the candidate must be onsite, and missing target work) before anyone
spends effort on the job.

Read first: `/home/ian/Documents/code/job-hunt/agents/_shared/WORKFLOW.md`, then
`/home/ian/Documents/code/job-hunt/documents/job-preferences.md` §Commute and §Target work (the
candidate's limits and target work; personal, gitignored).
Your job folder: `scripts/job_dir.sh <identifier>` (as the issue description says), resolved in this run.

## Steps

1. **Fetch the posting, word for word.** `posting.md` must contain the employer's own text
   verbatim, because every later quote, score and letter hook comes from it. WebFetch always returns
   a model-written summary, so it is **not** allowed as the source of posting.md.
   - Run `/home/ian/Documents/code/job-hunt/scripts/fetch_page.sh "<url>"` (headless Chrome, prints the
     page text). For Ashby links ending in `/application`, use the URL without `/application`.
   - If the page is an aggregator (StepStone, Indeed, jobware, empfehlungsbund, studysmarter, ...),
     also look for the employer's own posting (careers page) and prefer that text when it exists.
   - Use WebFetch/WebSearch only to *find* the right page, never as the posting text.
   - If the candidate pasted the posting as a comment, use their text verbatim.
   - **Check that the posting is still open:** an application deadline in the past, "not available",
     "Stelle ist besetzt", or interview dates in the past mean you must check the employer's own job
     page. Closed there (or removed) → handled like a dead link below.
   **If the link is dead (404, 410, "no longer available", redirect to the job list), search for the
   same posting elsewhere before giving up:** the company's careers page, then a WebSearch for
   `"<company>" "<job title>"` (job boards such as StepStone, Indeed, LinkedIn, Arbeitnow,
   remotely.de, Arbeitsagentur, devjobs). If you find a live copy, use it and note its URL.
   - Found only archived or expired copies everywhere → hand to the **coordinator** with the comment
     `Posting closed: <each place checked and what it showed>`.
   - Login wall or bot block (posting probably still live) → hand to the **coordinator** with
     `Cannot read posting: <reason>` (the Coordinator marks the row yellow for the candidate).
2. **posting.md:** the full posting text exactly as fetched (only navigation, cookie banners and
   footer junk removed; never reworded or shortened), then a footer with the source URL, the fetch
   method and today's date.
3. **posting.json:**
   ```json
   {"company": "", "title": "", "url": "", "language": "de|en", "locations": [""],
    "work_model": "remote|hybrid|onsite|unclear", "onsite_frequency": "e.g. 2 days/week, quarterly, none, unclear",
    "onsite_address": "street + city if stated, else company office city",
    "salary": "as stated or null", "seniority": "", "employment": "full-time|part-time|contract",
    "must_have": [""], "nice_to_have": [""], "ai_work": [""], "tech_stack": [""],
    "languages_required": [""], "deadline": null, "contact_person": null, "how_to_apply": ""}
   ```
   `locations`, `work_model`, `onsite_frequency` and `languages_required` feed the candidate's sheet
   columns `[Location]`, `[Work mode]` and `[Languages]` (SHEET.md), so fill them precisely from the posting text (quote-level
   accuracy; `unclear` / empty when the posting does not say).
4. **Commute gate.** Decide how often the candidate would have to be onsite.
   Always run `python3 -I /home/ian/Documents/code/job-hunt/scripts/commute.py "<onsite address or Company, City>"`
   for the office. **Check the `resolved` field** names the right town (and street, if you gave
   one); if not, retry with a more precise address. The script gives public transport (`minutes`),
   an e-bike estimate (`ebike_minutes`; `null` when the candidate has no e-bike) and `best_minutes`
   (the faster). The limits apply to `best_minutes`, one way. Record all three and the onsite
   frequency in screening.md. If the script errors or cannot resolve the right place, mark the commute
   `unclear` (never a dealbreaker).
   The candidate's limits depend on how often they must be onsite: apply the table in
   **job-preferences.md §Commute** exactly as written there (the limit per onsite frequency, which
   values are a **dealbreaker**, the note to add near the limit, and the "no limit" cases such as
   monthly onsite or fully remote). Two rules always hold:
   - Unclear wording ("flexible", "occasional office days", no location): never reject. Mark it
     `unclear` and let it pass; the Fit Scorer weighs it and the Coordinator flags it for the candidate.
   - If the posting offers several locations or remote as an option, use the best option the candidate could choose.
5. **Target-work gate.** job-preferences.md §Target work defines what counts as the candidate's
   target work, its label (`<label>` below) and the title keywords; the title rule there decides the
   first case.
   - **The job title contains a title keyword:** always **PASS**, never a dealbreaker (the candidate's
     rule). If the duties show little real target work, PASS with the note `<label> in title only` and
     quote the duties; the Fit Scorer deducts points for it.
   - **No title keyword:** the role must involve real hands-on target work as defined there. A mention
     only in the company slogan, or tools merely used for productivity, does not count. Quote the
     posting lines that decide it. No real target work is a **dealbreaker**. Borderline: PASS with a note.
6. **screening.md:** both checks, each with verdict (PASS / DEALBREAKER / UNCLEAR), the evidence
   (quoted posting lines, the commute JSON) and one sentence of reasoning.
7. **Hand off.**
   - Dealbreaker: to **coordinator**, comment `Dealbreaker: commute too long for onsite days|no <label> work — <one sentence>`.
   - Otherwise: to **researcher**, comment with a 3-line summary (title, work model + commute, target work).
