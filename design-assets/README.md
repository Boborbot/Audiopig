# Design assets (source files)

PNG sources kept in the repo but **not wired into any Xcode target**. Runtime assets live in each target's `Assets.xcassets/`.

## App icon spec

Locked pig palette, composition, and QA for default + unlockable icons: **[app-icon-spec.md](app-icon-spec.md)**. Six base fills are fixed on every variant; head props (hats, crowns, etc.) may use any color. Swift tokens: `DS.Color.Icon` (`Design/DesignSystem.swift`).

## Layout

| Path | Meaning |
|------|---------|
| `app-icons/` | Processed 1024×1024 PNG masters (watermark removed, spec-ready) |
| `archived/` | Retired icon art kept for reference — not wired into Xcode |
| `watch/reserved/` | Watch-related sources held for possible future use |

## Reserved assets

Not referenced by the app, widget, or Watch targets. Safe to keep for later; do not add to an `.appiconset` or `.imageset` until we deliberately adopt one.

| File | Status | Notes |
|------|--------|-------|
| [archived/AppIcon-20h-legacy-1024.png](archived/AppIcon-20h-legacy-1024.png) | **Archived** | Previous 20 Hour Club icon, replaced by chef-hat variant (2025-06). |
| [app-icons/AppIcon-20h-ChefPig-1024.png](app-icons/AppIcon-20h-ChefPig-1024.png) | **Source** | Chef-hat 20h tier master installed in `AppIcon-20h` / `Gallery-20h`. |
| [app-icons/AppIcon-Sherpig-1024.png](app-icons/AppIcon-Sherpig-1024.png) | **Source** | Deerstalker secret achievement master installed in `AppIcon-Sherpig` / `Gallery-Sherpig`. |
| [app-icons/AppIcon-1500h-FlyingPig-1024.png](app-icons/AppIcon-1500h-FlyingPig-1024.png) | **Source** | Aviator 1500h tier master (background normalized, watermark removed, light sharpen only). |
| [app-icons/AppIcon-200h-PartyPig-1024.png](app-icons/AppIcon-200h-PartyPig-1024.png) | **Source** | Party-hat 200h tier master (same minimal prep via `icon_prepare.py`). |
| [app-icons/AppIcon-1000h-WizardHat-1024.png](app-icons/AppIcon-1000h-WizardHat-1024.png) | **Source** | Wizard-hat icon at 1000h (moved from former 250h slot). |
| [app-icons/AppIcon-2000h-from-1000-1024.png](app-icons/AppIcon-2000h-from-1000-1024.png) | **Source** | Previous 1000h icon, now at 2000h. |
| [app-icons/AppIcon-2500h-1024.png](app-icons/AppIcon-2500h-1024.png) | **Source** | Previous 2000h icon at 2500h tier. |
| [archived/AppIcon-*-pre-cascade-1024.png](archived/) | **Archived** | Snapshot before mistaken full cascade (used to restore 500h–2000h art). |
| [watch/reserved/AppIcon-Circular700-1024.png](watch/reserved/AppIcon-Circular700-1024.png) | **Reserved** | 1024×1024 lossless PNG. 700 px diameter circular crop centered on the pig; corners transparent. Derived from `AudiopigWatch/Assets.xcassets/AppIcon.appiconset/AppIcon-1024.png`. Candidate Watch app icon if we want a circular mask on watchOS. |
