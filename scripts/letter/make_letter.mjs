#!/usr/bin/env node
// Render a cover letter from JSON into .docx and .pdf (A4, DIN 5008-style layout).
//
// Usage: node scripts/letter/make_letter.mjs <letter.json> <out-basename>
//   writes <out-basename>.docx and <out-basename>.pdf
//
// letter.json:
// {
//   "language": "de" | "en",
//   "sender":    { "name", "street", "city", "phone", "email", "linkedin" },
//   "recipient": { "company", "contact"?, "street"?, "city"? },
//   "place": "Musterstadt", "date": "13.11.2026",
//   "subject": "Bewerbung als ...",
//   "salutation": "Sehr geehrte Frau ...,",
//   "paragraphs": ["...", "..."],
//   "closing": "Mit freundlichen Grüßen",
//   "attachments": ["Lebenslauf", "Arbeitszeugnisse"]   (optional)
// }
// The PDF is printed from an equivalent HTML page with headless Chrome.
import { readFileSync, writeFileSync, mkdtempSync, rmSync } from "node:fs";
import { execFileSync } from "node:child_process";
import { tmpdir } from "node:os";
import { join, resolve } from "node:path";
import { Document, Packer, Paragraph, TextRun, AlignmentType } from "docx";

const [, , inFile, outBase] = process.argv;
if (!inFile || !outBase) {
  console.error("usage: make_letter.mjs <letter.json> <out-basename>");
  process.exit(2);
}
const L = JSON.parse(readFileSync(inFile, "utf8"));
for (const k of ["sender", "recipient", "date", "subject", "salutation", "paragraphs", "closing"]) {
  if (!L[k]) { console.error(`letter.json is missing "${k}"`); process.exit(2); }
}
const s = L.sender, r = L.recipient;
const senderLine = [s.name, s.street, s.city].filter(Boolean).join(" · ");
const contactLine = [s.phone, s.email, s.linkedin].filter(Boolean).join(" · ");
const recipientLines = [r.company, r.contact, r.street, r.city].filter(Boolean);
const dateLine = [L.place, L.date].filter(Boolean).join(", ");
const attachLabel = L.language === "en" ? "Enclosures" : "Anlagen";

// ---- docx ----
const FONT = "Calibri", SIZE = 21; // 10.5 pt
const p = (text, opts = {}) => new Paragraph({
  alignment: opts.align, spacing: { after: opts.after ?? 0 },
  children: [new TextRun({ text, font: FONT, size: opts.size ?? SIZE, bold: opts.bold })],
});
const children = [
  p(s.name, { bold: true, size: 28 }),
  p(senderLine, { size: 18 }),
  p(contactLine, { size: 18, after: 400 }),
  ...recipientLines.map((t, i) => p(t, { after: i === recipientLines.length - 1 ? 320 : 0 })),
  p(dateLine, { align: AlignmentType.RIGHT, after: 240 }),
  p(L.subject, { bold: true, after: 240 }),
  p(L.salutation, { after: 140 }),
  ...L.paragraphs.map((t) => new Paragraph({
    alignment: AlignmentType.JUSTIFIED, spacing: { after: 140, line: 259 },
    children: [new TextRun({ text: t, font: FONT, size: SIZE })],
  })),
  p(L.closing, { after: 480 }),
  p(s.name),
];
if (L.attachments?.length) {
  children.push(p("", { after: 120 }), p(`${attachLabel}: ${L.attachments.join(", ")}`, { size: 19 }));
}
const doc = new Document({
  sections: [{
    properties: { page: { size: { width: 11906, height: 16838 }, margin: { top: 850, bottom: 794, left: 1418, right: 1134 } } },
    children,
  }],
});
writeFileSync(`${outBase}.docx`, await Packer.toBuffer(doc));

// ---- pdf via HTML ----
const esc = (t) => String(t).replace(/&/g, "&amp;").replace(/</g, "&lt;").replace(/>/g, "&gt;");
const html = `<!doctype html><html lang="${L.language || "de"}"><meta charset="utf-8"><title>${esc(L.subject)}</title><style>
@page { size: A4; margin: 15mm 20mm 14mm 25mm; }
body { font: 10.5pt/1.32 Calibri, Carlito, "Liberation Sans", Arial, sans-serif; color: #111; }
.name { font-size: 14pt; font-weight: bold; } .small { font-size: 9pt; color: #333; }
.rcpt { margin-top: 9mm; margin-bottom: 6mm; } .date { text-align: right; margin-bottom: 5mm; }
.subj { font-weight: bold; margin-bottom: 5mm; } p { margin: 0 0 2.6mm; text-align: justify; hyphens: auto; }
.close { margin-top: 3mm; margin-bottom: 9mm; } .att { margin-top: 5mm; font-size: 9.5pt; }
</style><body>
<div class="name">${esc(s.name)}</div><div class="small">${esc(senderLine)}</div><div class="small">${esc(contactLine)}</div>
<div class="rcpt">${recipientLines.map(esc).join("<br>")}</div>
<div class="date">${esc(dateLine)}</div><div class="subj">${esc(L.subject)}</div>
<p>${esc(L.salutation)}</p>${L.paragraphs.map((t) => `<p>${esc(t)}</p>`).join("")}
<div class="close">${esc(L.closing)}</div><div>${esc(s.name)}</div>
${L.attachments?.length ? `<div class="att"><b>${attachLabel}:</b> ${L.attachments.map(esc).join(", ")}</div>` : ""}
</body></html>`;
const tmp = mkdtempSync(join(tmpdir(), "letter-"));
try {
  writeFileSync(join(tmp, "letter.html"), html);
  execFileSync("google-chrome", ["--headless=new", "--disable-gpu", "--no-first-run", `--user-data-dir=${join(tmp, "profile")}`,
    "--no-pdf-header-footer", `--print-to-pdf=${resolve(outBase)}.pdf`, `file://${join(tmp, "letter.html")}`], { stdio: "ignore" });
} finally {
  rmSync(tmp, { recursive: true, force: true });
}
const pages = (execFileSync("pdfinfo", [`${outBase}.pdf`]).toString().match(/Pages:\s+(\d+)/) || [])[1];
const words = L.paragraphs.join(" ").split(/\s+/).filter(Boolean).length;
console.log(`wrote ${outBase}.docx and ${outBase}.pdf — body ${words} words, PDF pages: ${pages}${pages === "1" ? "" : "  ** TOO LONG: shorten the body **"}`);
