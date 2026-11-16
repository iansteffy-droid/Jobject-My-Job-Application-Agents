// Plugin manifest: one dashboard widget, no worker features beyond a health check.
export default {
  id: "jobject.sync-button",
  apiVersion: 1,
  version: "0.1.0",
  displayName: "Sync now button",
  description: "Big Dashboard button that starts the Full refresh routine: sheet sync, document check, letter re-check.",
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
    ],
  },
};
