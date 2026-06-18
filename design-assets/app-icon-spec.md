# Audiopig App Icon — Design Requirements

Canonical requirements derived from the **Original** icon (`Audiopig/Assets.xcassets/AppIcon.appiconset/Icon-1024.png`).

**Design intent:** unlockable icons are the **same pig** — same pose, same book, same headphones, same flesh tones — with something different on or around the head (a hat, crown, seasonal prop, franchise nod). AI-generated alternates tend to **tint or drift** the base pig; this spec exists to stop that. Variant-only elements may use **any colors** (a blue wizard hat, green holly, gold crown); the locked elements below may not.

Swift tokens for locked colors: `DS.Color.Icon.*` in `Design/DesignSystem.swift`.

---

## Locked vs variant

| Layer | What changes | Color rule |
|-------|----------------|------------|
| **Locked** | Salmon background, pig flesh, snout, inner ears, book, headphones, outlines, eyes, pose, line weight | **Exact hex values** in the table below — no drift |
| **Variant** | Head accessories, costumes, seasonal/franchise props *added on top* | **Any palette** — only the addition is free; it must not recolor locked elements |

The Original icon has no variant layer. Hour-tier icons may add subtle mileage flair; secret/seasonal icons add a recognizable head prop. In every case the pig underneath should be immediately recognizable as the same character.

---

## Canvas

| Property | Requirement |
|----------|-------------|
| Size | **1024 × 1024 px** (master); export all iOS `AppIcon` sizes from this master |
| Shape | Full-bleed square; no rounded corners in the PNG (iOS applies the mask) |
| Background | Solid flat **salmon** — no gradients, textures, or shadows on the canvas |
| Safe area | Pig centered; locked features legible under the iOS squircle mask (~10 % corner inset) |

---

## Locked color palette

These six fills apply to **every** icon — default, hour-tier, seasonal, and secret. All are **flat** (single hex per region). Anti-aliasing at stroke edges may blend adjacent colors; export from vector using these exact values.

| Role | Hex | RGB | Locked usage |
|------|-----|-----|----------------|
| **Salmon** (background) | `#F18470` | 241, 132, 112 | Entire canvas. Same as brand coral (`DS.Color.coral`). |
| **Pig body** | `#FAC0B0` | 250, 192, 176 | Head, cheeks, torso, arms/hooves holding the book. |
| **Nose** | `#F8BCB0` | 248, 188, 176 | Snout oval and inner ear triangles. |
| **Book** | `#805040` | 128, 80, 64 | Open book — cover and page block (one brown). |
| **Headphones** | `#32201A` | 50, 32, 26 | Headband, ear cups, cable. |
| **Outline** | `#302018` | 48, 32, 24 | All pig/book/headphone strokes, eye dots, nostrils. |

### Locked color rules

1. **Salmon** must be `#F18470` on every icon so alternates match in-app brand chrome.
2. **Pig flesh** uses exactly two pinks — body and nose — never salmon, book brown, or variant prop colors.
3. **Book and headphones** keep their locked browns on every variant; do not restyle them to match a hat or theme.
4. **Outlines** stay `#302018` with uniform weight on locked elements. Variant props get their own outlines in theme-appropriate colors if needed, but pig/book/headphone strokes do not shift.
5. **Eyes** remain small outline-filled dots — no white sclera, no recolor.
6. **No shading or gradients** on locked fills. Variant props may use simple flat fills or minimal two-tone flat shapes; avoid painterly rendering on the pig itself.

### Variant color rules

- **Allowed:** any color on head-only additions (hats, crowns, wigs, scars, glasses, holly, lightning bolt, etc.).
- **Forbidden:** tinting the pig pink toward peach/salmon, cooling the background, desaturating the book, or “harmonizing” locked elements with the variant palette.
- **AI prompt tip:** describe the locked hex values explicitly in the prompt; generate the base pig first, then composite or inpaint only the head accessory.

---

## Locked character composition

Every icon shares this skeleton. Variant art modifies **above the ears / hairline** unless the spec for that unlock says otherwise.

| Element | Requirement |
|---------|-------------|
| Pose | Symmetric, forward-facing, friendly |
| Headphones | Band over the head; circular cups at the ears; cable from one cup toward the back |
| Book | Held open below the face with both hooves; centered in the lower third |
| Face | Two small round **eye dots** (outline color); large horizontal **snout oval** with two nostril ovals |
| Ears | Rounded outer ears with inner-ear triangles in nose pink |
| Style | Bold sticker / line-art on locked elements: thick uniform strokes, simple shapes |

---

## Stroke & export

| Property | Requirement |
|----------|-------------|
| Outline weight (locked) | Consistent across pig, book, headphones (~3–4 % of canvas width at 1024 px) |
| Corners | Rounded caps and joins — no sharp miters on locked strokes |
| Format | PNG, sRGB |
| Transparency | **None** on the master iOS icon (opaque salmon square) |
| Compression | Lossless or high-quality; avoid shifts that move salmon toward `#F08070` |

---

## QA before merge (especially AI-generated art)

Spot-check pixels or eyedropper these regions on every new alternate:

| Check | Expected |
|-------|----------|
| Corner background | `#F18470` |
| Forehead / cheek fill | `#FAC0B0` |
| Snout / inner ear fill | `#F8BCB0` |
| Book fill | `#805040` |
| Headphone cup | `#32201A` |
| Pig outline stroke | `#302018` |
| Variant prop | Any color — **must not** replace locked fills above |

If the pig reads as a different character or the pinks/browns have shifted, reject and re-prompt with locked hex values — do not “fix in post” by globally color-grading the image.

---

## Asset wiring

| Asset | Location |
|-------|----------|
| Default icon | `Audiopig/Assets.xcassets/AppIcon.appiconset/` |
| Hour-tier unlockables | `AppIcon-{N}h.appiconset/` + `Gallery-{N}h.imageset/` |
| Secret achievements | `AppIcon-{Name}.appiconset/` + `Gallery-{Name}.imageset/` |
| Gallery thumbnails | Same art as the installed icon; scale only — do not recolor locked elements |

---

## Reference

- **Source of truth:** `AppIcon.appiconset/Icon-1024.png` (Original)
- **Swift tokens (locked only):** `DS.Color.Icon.salmon`, `.pigBody`, `.nose`, `.book`, `.headphones`, `.outline`
- **Agent recipe for secret icons:** `.cursor/rules/secret-achievements.mdc`
