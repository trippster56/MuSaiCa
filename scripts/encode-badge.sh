#!/usr/bin/env bash
# Encode an SVG as a base64 data URI for use in a shields.io badge's
# `logo=` parameter. shields.io accepts simple-icons slugs or base64
# data URIs only — not external URLs — which is why we have to inline
# the SVG into the README rather than just linking to it.
#
# Usage:
#   ./scripts/encode-badge.sh docs/badges/snapmaker.svg
#
# Paste the resulting string into the README badge URL after
# `logo=data:image/svg+xml;base64,`.

set -euo pipefail

if [[ $# -ne 1 ]]; then
    echo "usage: $0 <path-to-svg>" >&2
    exit 1
fi

# URL-safe base64 (encode '+' '/' '=' as well so the result is safe to
# drop straight into a query parameter).
base64 -i "$1" | tr -d '\n' | python3 -c '
import sys, urllib.parse
print(urllib.parse.quote(sys.stdin.read(), safe=""))
'
