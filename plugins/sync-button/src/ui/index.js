// Dashboard widgets: one big button per routine ("Full refresh", "Find jobs"), plus its latest run.
// They run inside the Paperclip page (same origin), so they call the board API directly.
import { createElement as h, useCallback, useEffect, useState } from "react";

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

function RoutineButton({ context, routineTitle: ROUTINE_TITLE, heading, text, label, started }) {
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
      setMessage(started);
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
    { "aria-label": label, style: { display: "grid", gap: 12 } },
    h("strong", { style: { fontSize: 16 } }, heading),
    h(
      "div",
      { style: { fontSize: 13, opacity: 0.8 } },
      text,
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
      busy ? "Starting…" : label,
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

export function SyncNowWidget({ context }) {
  return h(RoutineButton, {
    context,
    routineTitle: "Full refresh",
    heading: "Job hunt: full refresh",
    text: "Checks the sheet, your CVs and documents, re-sorts by Fit and re-checks letters if your documents changed.",
    label: "Sync now",
    started: "Started. The Coordinator is on it.",
  });
}

export function FindJobsWidget({ context }) {
  return h(RoutineButton, {
    context,
    routineTitle: "Find jobs",
    heading: "Job hunt: find new jobs",
    text: "Finds one chunk of new jobs for the scout tab and reviews it. Pressed again, the next chunk waits until this one is reviewed.",
    label: "Find jobs",
    started: "Started. The Job Scout is on it; a chunk still running finishes first.",
  });
}
