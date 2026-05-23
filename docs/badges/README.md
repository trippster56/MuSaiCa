# Badge assets

Brand SVGs used as logos in the main README's shields.io badges.

shields.io's `logo=` parameter only accepts simple-icons slugs or base64
data URIs — not external URLs — so the SVGs are inlined into the README
badge URLs. The source files live here so we don't lose track of them.

To re-encode after editing an SVG:

```bash
./scripts/encode-badge.sh docs/badges/snapmaker.svg
```

Paste the output into the matching README badge after
`logo=data:image/svg+xml;base64,`.
