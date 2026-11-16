// The host requires a worker; the button itself calls the routine API from the browser.
import { definePlugin, runWorker } from "@paperclipai/plugin-sdk";

const plugin = definePlugin({
  async setup(ctx) {
    ctx.logger.info("sync-button ready");
  },
  async onHealth() {
    return { status: "ok", message: "sync-button ready" };
  },
});

export default plugin;
runWorker(plugin, import.meta.url);
