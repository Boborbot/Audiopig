# AudioPig — App Store Submission Guide

Step-by-step from a clean build to App Store Connect. Assumes Apple Developer Program membership and Xcode on your Mac.

---

## Before you archive

1. Complete `qa-checklist.md` on a physical device.
2. Legal pages are hosted on the `AudioPig` GitHub org (see `hosting-setup.md`):
   - Support: https://audiopig.github.io/
   - Privacy: https://audiopig.github.io/privacy-policy.html
   - Terms: https://audiopig.github.io/terms.html
3. Support email: `audiopigsupport@gmail.com`
4. Confirm bundle ID `com.nitay.Audiopig` matches your Developer account.
5. Confirm signing: Xcode → Audiopig target → Signing & Capabilities → Team selected, "Automatically manage signing" on.

---

## Version numbers

In Xcode → Audiopig target → General (all targets should match):

| Field | v1.1 (current) |
|---|---|
| Version | 1.1 |
| Build | 1 |

Increment **Build** for each upload to App Store Connect; increment **Version** for user-visible releases.

**Submitting 1.1 while 1.0 is in review:** upload build 1.1 (1), attach to a new version in Connect, or replace the build on the pending version if Apple has not started review yet. Paste **What's New** from `listing.md`.

---

## Screenshots

Required sizes change over time — check App Store Connect when submitting.

Typical minimum:

- 6.7" display (iPhone 15 Pro Max simulator or device)
- 6.5" display (if Connect still lists it)

Capture: Library, Player, Bookmarks or Stats, Settings or Folders.

Simulator: `Cmd+S` after `Window → Physical Size` for clean frames.

---

## Archive

1. Select **Any iOS Device (arm64)** (not a simulator) in the scheme destination menu.
2. **Product → Archive**
3. When Organizer opens, select the archive → **Distribute App**
4. **App Store Connect** → **Upload**
5. Defaults: include bitcode off (modern Xcode), manage symbols upload on, strip Swift symbols on
6. Sign with your distribution certificate
7. Upload; wait for processing (5–30 minutes)

---

## App Store Connect

1. [appstoreconnect.apple.com](https://appstoreconnect.apple.com) → **My Apps** → **+** → New App
2. Platform: iOS; Name: AudioPig; Primary language; Bundle ID: `com.nitay.Audiopig`
3. **App Information:** category Books; content rights as applicable; custom EULA URL `https://audiopig.github.io/terms.html`
4. **Pricing:** Free (or your choice)
5. **App Privacy:** No data collected (matches `PrivacyInfo.xcprivacy`)
6. **Age Rating:** complete questionnaire (typically 4+)
7. **Version 1.1** (or 1.0 for first release):
   - Paste copy from `listing.md`
   - **What's New:** paste v1.1 section from `listing.md` when updating an existing app
   - Privacy Policy URL (hosted HTML)
   - Support URL
   - Screenshots
8. **Build:** select the processed build from upload
9. **Export Compliance:** app uses only exempt encryption (`ITSAppUsesNonExemptEncryption` = false) — answer accordingly
10. **App Review Information:** paste notes from `listing.md`; add demo account only if needed (not required for AudioPig)
11. **Submit for Review**

---

## In-App Purchases (App Store Connect)

Create IAP products **before** TestFlight Sandbox testing or App Review. Local `Audiopig.storekit` only works for Xcode Run; uploaded builds load products from Connect.

### Subscription group

1. App Store Connect → your app → **Subscriptions** → **+** Subscription Group
2. Reference name: `audiopig_plus` (internal label; display name can be "AudioPig Plus")

### Products (IDs must match code exactly)

Source of truth: `AudiopigShared/ProductIdentifiers.swift`

| Type | Product ID | Suggested price | Notes |
|---|---|---|---|
| Auto-renewable subscription | `com.nitay.Audiopig.plus.monthly` | $3.99/month | Add **7-day free trial** introductory offer |
| Consumable | `com.nitay.Audiopig.tip.coffee` | $2.99 | Display name: Coffee |
| Consumable | `com.nitay.Audiopig.tip.lunch` | $6.99 | Display name: Lunch |
| Consumable | `com.nitay.Audiopig.tip.rent` | $14.99 | Display name: Today's Rent |

Copy for display names and descriptions is in `Audiopig/Audiopig.storekit` localizations.

### Subscription metadata

- **Subscription display name:** AudioPig Plus
- **Description:** Unlocks Smart Rewind (silence analysis) and on-device subtitles
- **Review screenshot:** capture the paywall from Simulator or device (required for subscription review)

### Sandbox testing (physical device)

1. Connect → **Users and Access** → **Sandbox** → create a Sandbox Apple ID
2. On iPhone: **Settings → App Store → Sandbox Account** → sign in with sandbox tester
3. Install via **TestFlight** (or Xcode Run with StoreKit config for local-only QA)
4. Verify per `qa-checklist.md` § StoreKit / Monetization:
   - Plus trial subscribe, restore, manage subscription link
   - All three tip tiers purchase and show thank-you UI
5. Do **not** use your real Apple ID for sandbox purchases

---

## TestFlight (recommended before public release)

1. After upload processes, enable **Internal Testing** for your team
2. Install via TestFlight on your phone
3. Complete IAP setup (see **In-App Purchases** above) before Sandbox testing on TestFlight builds
4. Smoke-test: import → playback → Smart Rewind → subtitles (iOS 26 device) → background audio → Watch remote playback
5. Sandbox IAP: Plus trial, restore, and tip purchase on the TestFlight build
6. Fix issues, increment build number, re-archive, re-upload

---

## After approval

- Release manually or automatically per Connect settings
- Monitor crash reports in Xcode Organizer and App Store Connect
- Update hosted privacy policy if permissions change (`support-site/` → GitHub Pages)

---

## Troubleshooting

| Issue | Fix |
|---|---|
| Upload fails signing | Re-download certificates in Xcode Settings → Accounts |
| Missing compliance | Answer encryption question in Connect |
| Build not appearing | Wait for processing; check email for ITMS errors |
| Invalid binary | Read email from Apple; often Info.plist or privacy manifest |
