# Audiopig — Public support site hosting

Legal and support pages are published from [`support-site/`](../support-site/) to the **`AudioPig`** GitHub organization — not the personal Boborbot account.

Public URLs:

| Page | URL |
|------|-----|
| Support | https://audiopig.github.io/ |
| Privacy | https://audiopig.github.io/privacy-policy.html |
| Terms | https://audiopig.github.io/terms.html |

In-app links use these URLs via [`AppSupport.swift`](../../Audiopig/Support/AppSupport.swift).

---

## One-time setup

### 1. Create the GitHub organization (free)

1. Open https://github.com/account/organizations/new
2. **Organization name:** `AudioPig` (GitHub serves Pages at `audiopig.github.io`)
3. **Plan:** Free
4. Complete the wizard (contact email can be `audiopigsupport@gmail.com`)

### 2. Publish the site

From the repo root (`Audiopig/`):

```bash
chmod +x scripts/publish-support-site.sh
./scripts/publish-support-site.sh
```

This creates or updates **`AudioPig/AudioPig.github.io`** and pushes the HTML.

### 3. Confirm GitHub Pages

1. Open https://github.com/AudioPig/AudioPig.github.io/settings/pages
2. **Source:** GitHub Actions (workflow `Deploy support site to Pages`)
3. Wait 1–2 minutes after publish; visit https://audiopig.github.io/

If the site **404s** but files are on `main`:

- Check **Actions** tab for a successful deploy (legacy “branch” deploy often fails on org repos — use GitHub Actions).
- Re-run the workflow: **Actions → Deploy support site to Pages → Run workflow**.

### 4. Retire Boborbot Pages (important)

On the **Boborbot/Audiopig** repo (if Pages was enabled):

**Settings → Pages → Source: None**

This stops `boborbot.github.io/Audiopig/` from serving old public URLs.

### 5. Update App Store Connect

Paste the new URLs into your app record:

- Support URL → `https://audiopig.github.io/`
- Privacy Policy URL → `https://audiopig.github.io/privacy-policy.html`
- Custom EULA → `https://audiopig.github.io/terms.html`

If the app binary is already uploaded, archive a **new build** so in-app Settings links match (they read from `AppSupport.swift`).

---

## Updating legal copy later

1. Edit `support-site/*.html` (keep in sync with `docs/app-store/*.html` if you maintain both).
2. Re-run `./scripts/publish-support-site.sh`.
