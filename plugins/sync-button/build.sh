#!/usr/bin/env bash
# Build the Sync now plugin into dist/ and (re)install it into the job-hunt instance (:3300).
# Usage: plugins/sync-button/build.sh [--no-install]
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PC="$HERE/../../paperclip"
ESBUILD="$(ls -d "$PC"/node_modules/.pnpm/esbuild@0.2*/node_modules/esbuild/bin/esbuild | tail -n1)"

rm -rf "$HERE/dist" && mkdir -p "$HERE/dist/ui"
cp "$HERE/src/manifest.js" "$HERE/dist/manifest.js"
cp "$HERE/src/ui/index.js" "$HERE/dist/ui/index.js"
# The worker bundles the plugin SDK so the plugin folder needs no node_modules of its own.
NODE_PATH="$PC/packages/plugins/sdk/node_modules:$PC/node_modules" "$ESBUILD" "$HERE/src/worker.js" \
  --bundle --platform=node --format=esm --target=node20 --outfile="$HERE/dist/worker.js" \
  --alias:@paperclipai/plugin-sdk="$PC/packages/plugins/sdk/dist/index.js" \
  --banner:js="import { createRequire as __cr } from 'module'; const require = __cr(import.meta.url);" \
  --log-level=warning
echo "built $HERE/dist"

[ "${1:-}" = "--no-install" ] && exit 0
cd "$PC"
pnpm -s paperclipai plugin uninstall jobject.sync-button --force --api-base http://127.0.0.1:3300 >/dev/null 2>&1 || true
pnpm -s paperclipai plugin install "$HERE" --api-base http://127.0.0.1:3300
