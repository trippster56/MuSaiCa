#!/usr/bin/env bash
# Build Mainsail and copy its dist/ into the slicer's webview resources.
# Run from anywhere; paths are resolved relative to the repo root.

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
MAINSAIL_DIR="${REPO_ROOT}/mainsail"
SLICER_WEBVIEW_DIR="${REPO_ROOT}/slicer/resources/webviews/mainsail"

if [[ ! -d "${MAINSAIL_DIR}" ]]; then
    echo "error: ${MAINSAIL_DIR} not found" >&2
    exit 1
fi

echo "==> Building Mainsail (vite build --base=./)"
# Mainsail's default build emits absolute /assets/ paths; under file:// those
# resolve to filesystem root and 404. Build with a relative base instead.
( cd "${MAINSAIL_DIR}" \
    && npm install --no-audit --no-fund \
    && rm -rf dist \
    && npx vite build --base=./ \
    && (cd dist && zip -qr mainsail.zip ./ -x '**.DS_Store' ./) )

if [[ ! -d "${MAINSAIL_DIR}/dist" ]]; then
    echo "error: build produced no dist/" >&2
    exit 1
fi

echo "==> Copying dist/ into ${SLICER_WEBVIEW_DIR}"
rm -rf "${SLICER_WEBVIEW_DIR}"
mkdir -p "${SLICER_WEBVIEW_DIR}"
# rsync preserves perms and is faster than cp -R on rebuilds
rsync -a --delete "${MAINSAIL_DIR}/dist/" "${SLICER_WEBVIEW_DIR}/"

echo "==> Bundled $(du -sh "${SLICER_WEBVIEW_DIR}" | cut -f1) into slicer resources"
