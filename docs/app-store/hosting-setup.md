# Audiopig — Public support site hosting

Legal and support pages are published from [`support-site/`](../support-site/) to the **`audiopig-app`** GitHub organization — not the personal Boborbot account.

Public URLs:

| Page | URL |
|------|-----|
| Support | https://audiopig-app.github.io/ |
| Privacy | https://audiopig-app.github.io/privacy-policy.html |
| Terms | https://audiopig-app.github.io/terms.html |

In-app links use these URLs via [`AppSupport.swift`](../../Audiopig/Support/AppSupport.swift).

---

## One-time setup

### 1. Create the GitHub organization (free)

1. Open https://github.com/account/organizations/new
2. **Organization name:** `audiopig-app`
3. **Plan:** Free
4. Complete the wizard (contact email can be `audiopigsupport@gmail.com`)

### 2. Publish the site

From the repo root (`Audiopig/`):

```bash
chmod +x scripts/publish-support-site.sh
./scripts/publish-support-site.sh
```

This creates or updates **`audiopig-app/audiopig-app.github.io`** and pushes the HTML.

### 3. Confirm GitHub Pages

1. Open https://github.com/audiopig-app/audiopig-app.github.io/settings/pages
2. **Source:** Deploy from branch `main`, folder `/ (root)`
3. Wait 1–2 minutes; visit https://audiopig-app.github.io/

### 4. Retire Boborbot Pages (important)

On the **Boborbot/Audiopig** repo (if Pages was enabled):

**Settings → Pages → Source: None**

This stops `boborbot.github.io/Audiopig/` from serving old public URLs.

### 5. Update App Store Connect

Paste the new URLs into your app record:

- Support URL → `https://audiopig-app.github.io/`
- Privacy Policy URL → `https://audiopig-app.github.io/privacy-policy.html`
- Custom EULA → `https://audiopig-app.github.io/terms.html`

If the app binary is already uploaded, archive a **new build** so in-app Settings links match (they read from `AppSupport.swift`).

---

## Updating legal copy later

1. Edit `support-site/*.html` (keep in sync with `docs/app-store/*.html` if you maintain both).
2. Re-run `./scripts/publish-support-site.sh`.
