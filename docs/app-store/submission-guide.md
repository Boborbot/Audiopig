# Audiopig — App Store Submission Guide

Step-by-step from a clean build to App Store Connect. Assumes Apple Developer Program membership and Xcode on your Mac.

---

## Before you archive

1. Complete `qa-checklist.md` on a physical device.
2. Host `privacy-policy.html` (GitHub Pages, personal site, etc.).
3. Replace `support@example.com` in the privacy policy with your real email.
4. Confirm bundle ID `com.nitay.Audiopig` matches your Developer account.
5. Confirm signing: Xcode → Audiopig target → Signing & Capabilities → Team selected, "Automatically manage signing" on.

---

## Version numbers

In Xcode → Audiopig target → General:

| Field | Suggested v1.0 |
|---|---|
| Version | 1.0 |
| Build | 1 |

Increment **Build** for each upload; increment **Version** for user-visible releases.

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
2. Platform: iOS; Name: Audiopig; Primary language; Bundle ID: `com.nitay.Audiopig`
3. **App Information:** category Books; content rights as applicable
4. **Pricing:** Free (or your choice)
5. **App Privacy:** No data collected (matches `PrivacyInfo.xcprivacy`)
6. **Age Rating:** complete questionnaire (typically 4+)
7. **Version 1.0:**
   - Paste copy from `listing.md`
   - Privacy Policy URL (hosted HTML)
   - Support URL
   - Screenshots
8. **Build:** select the processed build from upload
9. **Export Compliance:** app uses only exempt encryption (`ITSAppUsesNonExemptEncryption` = false) — answer accordingly
10. **App Review Information:** paste notes from `listing.md`; add demo account only if needed (not required for Audiopig)
11. **Submit for Review**

---

## TestFlight (recommended before public release)

1. After upload processes, enable **Internal Testing** for your team
2. Install via TestFlight on your phone
3. Smoke-test import + playback + background audio
4. Fix issues, increment build number, re-archive, re-upload

---

## After approval

- Release manually or automatically per Connect settings
- Monitor crash reports in Xcode Organizer and App Store Connect
- Plan v1.1: per-book speed, tests, optional formats

---

## Troubleshooting

| Issue | Fix |
|---|---|
| Upload fails signing | Re-download certificates in Xcode Settings → Accounts |
| Missing compliance | Answer encryption question in Connect |
| Build not appearing | Wait for processing; check email for ITMS errors |
| Invalid binary | Read email from Apple; often Info.plist or privacy manifest |
