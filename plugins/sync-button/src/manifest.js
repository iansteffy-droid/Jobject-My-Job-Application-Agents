// Plugin manifest: two dashboard widgets (Sync now, Find jobs), no worker features beyond a health check.
export default {
  id: "jobject.sync-button",
  apiVersion: 1,
  version: "0.2.0",
  displayName: "Sync now button",
  description: "Big Dashboard buttons: Sync now (Full refresh routine: sheet sync, document check, letter re-check) and Find jobs (scout a chunk of new jobs).",
  author: "job-hunt",
  categories: ["ui"],
  capabilities: ["ui.dashboardWidget.register"],
  entrypoints: {
    worker: "./dist/worker.js",
    ui: "./dist/ui",
  },
  ui: {
    slots: [
      {
        type: "dashboardWidget",
        id: "sync-now-widget",
        displayName: "Sync now",
        exportName: "SyncNowWidget",
      },
      {
        type: "dashboardWidget",
        id: "find-jobs-widget",
        displayName: "Find jobs",
        exportName: "FindJobsWidget",
      },
    ],
  },
};
