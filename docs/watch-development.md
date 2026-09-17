# Apple Watch development

## Player architecture

`WatchRootView` opens `WatchPlayerPagerView` only after book selection succeeds. The
pager mounts one page at a time instead of keeping multiple player pages in a
`TabView`.

Player page order is defined by `WatchPlayerPageLayout`:

- Artwork Off: speed → controls → chapters
- Artwork Replace: speed → artwork → chapters
- Artwork Add: speed → artwork → controls → chapters

The up/down buttons always change pages. Vertical swipes also work on speed,
controls, and artwork; the chapter page reserves gestures for its list.
The player Back button and a rightward finger swipe return directly to the
iPhone Recent Books list.

## Digital Crown ownership

Only the visible page owns Crown input:

- Speed uses the system `Stepper`.
- Controls and artwork use one pager-owned volume handler with an ascending
  `0...1` range. The pager waits for its navigation transition to settle before
  activating that handler. Three Crown detents cover half of one system-volume
  step, making volume adjustment deliberately gradual.
- Chapters use the system `List` scrolling behavior.

Do not use descending `digitalCrownRotation` bounds or mount Crown handlers on
multiple hidden pages.

## Player preferences

Find Breaks is hidden from Watch transport controls by default. The **Hide Find
Breaks** toggle is available in both iPhone Settings → Apple Watch and Watch
Settings. The iPhone persists the preference and publishes it in
`WatchSettingsSnapshot`; missing values from older payloads resolve to hidden.

## Build numbers and installation

The iPhone app, widget extension, and Watch app must have the same
`CURRENT_PROJECT_VERSION`. Increment all target configurations together before
a physical-device build. Do not mutate built `Info.plist` files in a run-script
phase; doing so can create mismatched versions or invalidate embedded signatures.

The Watch stabilization baseline is `1.1.3 (6)`. The patch-version bump is
intentional: development builds of `1.1.2` briefly used timestamp build numbers,
so a newer marketing version is needed to update those installations while
returning to an App Store-safe build number.

Running the iPhone scheme installs the iPhone app immediately, but transfer of
the embedded Watch companion is asynchronous. A higher shared build number lets
the Watch app recognize the companion as an update. Deleting the iPhone app is
never part of Watch troubleshooting because it removes the user’s library.

## Simulator smoke test

Debug builds include a player-only harness so all player pages can be mounted
without a phone library:

```bash
xcodebuild -project Audiopig.xcodeproj -scheme AudiopigWatch \
  -destination 'platform=watchOS Simulator,id=<WATCH_SIMULATOR_UDID>' build

xcrun simctl install <WATCH_SIMULATOR_UDID> \
  <DERIVED_DATA>/Build/Products/Debug-watchsimulator/AudiopigWatch.app

xcrun simctl launch --terminate-running-process <WATCH_SIMULATOR_UDID> \
  com.nitay.Audiopig.watchkitapp \
  --watch-player-smoke-page=media --watch-player-smoke-cycle
```

Valid page values are `speed`, `media`, and `chapters`. The optional
`--watch-player-smoke-cycle` argument transitions through all three.

Before a physical Watch test:

1. Build the signed iPhone scheme.
2. Confirm iPhone, widget, and embedded Watch `CFBundleVersion` values match.
3. Confirm the embedded Watch app has
   `WKCompanionAppBundleIdentifier = com.nitay.Audiopig`.
4. Install/update the iPhone app without deleting it.
5. Let the iPhone Watch app finish the companion update and confirm Watch
   Settings → About shows `Version 1.1.3 (6)`.
6. Test book selection, all player pages, and Crown behavior.
