# Design assets (source files)

PNG sources kept in the repo but **not wired into any Xcode target**. Runtime assets live in each target's `Assets.xcassets/`.

## Layout

| Path | Meaning |
|------|---------|
| `watch/reserved/` | Watch-related sources held for possible future use |

## Reserved assets

Not referenced by the app, widget, or Watch targets. Safe to keep for later; do not add to an `.appiconset` or `.imageset` until we deliberately adopt one.

| File | Status | Notes |
|------|--------|-------|
| [watch/reserved/AppIcon-Circular700-1024.png](watch/reserved/AppIcon-Circular700-1024.png) | **Reserved** | 1024×1024 lossless PNG. 700 px diameter circular crop centered on the pig; corners transparent. Derived from `AudiopigWatch/Assets.xcassets/AppIcon.appiconset/AppIcon-1024.png`. Candidate Watch app icon if we want a circular mask on watchOS. |
