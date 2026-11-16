// Dashboard widget: one big button that runs the "Full refresh" routine, plus its latest run.
// Runs inside the Paperclip page (same origin), so it calls the board API directly.
import { createElement as h, useCallback, useEffect, useState } from "react";

const ROUTINE_TITLE = "Full refresh";

async function api(path, init) {
  const res = await fetch(`/api${path}`, {
    credentials: "same-origin",
    headers: { "Content-Type": "application/json" },
    ...init,
  });
  if (!res.ok) throw new Error(`${res.status} ${await res.text()}`);
  return res.json();
}

function when(ts) {
  return ts ? new Date(ts).toLocaleString() : "";
}

export function SyncNowWidget({ context }) {
  const companyId = context.companyId;
  const [routine, setRoutine] = useState(null);
  const [lastRun, setLastRun] = useState(null);
  const [busy, setBusy] = useState(false);
  const [message, setMessage] = useState("");

  const load = useCallback(async () => {
    if (!companyId) return;
    try {
      const routines = await api(`/companies/${companyId}/routines`);
      const r = routines.find((x) => x.title === ROUTINE_TITLE) ?? null;
      setRoutine(r);
      if (!r) {
        setMessage(`Routine "${ROUTINE_TITLE}" not found. Run scripts/provision.sh.`);
        return;
      }
      const detail = await api(`/routines/${r.id}`);
      setLastRun(detail.recentRuns?.[0] ?? null);
    } catch (e) {
      setMessage(String(e.message ?? e));
    }
  }, [companyId]);

  useEffect(() => {
    load();
    const t = setInterval(load, 15000);
    return () => clearInterval(t);
  }, [load]);

  const run = async () => {
    if (!routine) return;
    setBusy(true);
    setMessage("");
    try {
      await api(`/routines/${routine.id}/run`, { method: "POST", body: JSON.stringify({ source: "manual" }) });
      setMessage("Started. The Coordinator is on it.");
      await load();
    } catch (e) {
      setMessage(`Could not start: ${e.message ?? e}`);
    } finally {
      setBusy(false);
    }
  };

  const issue = lastRun?.linkedIssue;
  const issueLink = issue?.identifier
    ? h("a", { href: `/JOB/issues/${issue.identifier}`, style: { textDecoration: "underline" } }, issue.identifier)
    : null;

  return h(
    "section",
    { "aria-label": "Sync now", style: { display: "grid", gap: 12 } },
    h("strong", { style: { fontSize: 16 } }, "Job hunt: full refresh"),
    h(
      "div",
      { style: { fontSize: 13, opacity: 0.8 } },
      "Checks the sheet, your CVs and documents, re-sorts by Fit and re-checks letters if your documents changed.",
    ),
    h(
      "button",
      {
        type: "button",
        onClick: run,
        disabled: busy || !routine,
        className: "bg-primary text-primary-foreground",
        style: {
          fontSize: 20,
          fontWeight: 700,
          padding: "18px 24px",
          borderRadius: 10,
          border: "none",
          cursor: busy || !routine ? "default" : "pointer",
          opacity: busy || !routine ? 0.6 : 1,
          width: "100%",
        },
      },
      busy ? "Starting…" : "Sync now",
    ),
    lastRun
      ? h(
          "div",
          { style: { fontSize: 13 } },
          "Last run: ",
          when(lastRun.triggeredAt),
          ` · ${issue?.status ?? lastRun.status}`,
          issueLink ? " · " : "",
          issueLink,
        )
      : null,
    message ? h("div", { style: { fontSize: 13 } }, message) : null,
  );
}
