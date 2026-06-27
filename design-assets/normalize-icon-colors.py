#!/usr/bin/env python3
"""Snap locked app-icon fills to spec hex values; preserve variant head props."""

from __future__ import annotations

import shutil
from pathlib import Path

from PIL import Image

SPEC = {
    "salmon": (241, 132, 112),
    "pig_body": (250, 192, 176),
    "nose": (248, 188, 176),
    "book": (128, 80, 64),
    "headphones": (50, 32, 26),
    "outline": (48, 32, 24),
}
LOCKED = tuple(SPEC.keys())
ORIG_THRESHOLD = 30
NEW_SNAP_THRESHOLD = 28
VARIANT_DIST = 40
HAT_Y = 420

BASE = Path(__file__).resolve().parent.parent
ORIGINAL = BASE / "Audiopig/Assets.xcassets/AppIcon.appiconset/Icon-1024.png"


def dist(a: tuple[int, int, int], b: tuple[int, int, int]) -> float:
    return sum((x - y) ** 2 for x, y in zip(a, b)) ** 0.5


def classify(c: tuple[int, int, int]) -> tuple[str, float]:
    role = min(SPEC, key=lambda r: dist(c, SPEC[r]))
    return role, dist(c, SPEC[role])


def min_locked_dist(c: tuple[int, int, int]) -> float:
    return min(dist(c, SPEC[r]) for r in LOCKED)


def is_variant_pixel(
    orig_role: str,
    orig_d: float,
    new_c: tuple[int, int, int],
    y: int,
) -> bool:
    if orig_d > ORIG_THRESHOLD:
        return False

    if dist(new_c, SPEC[orig_role]) >= VARIANT_DIST:
        return True

    # Chef toque — near-white on background or head.
    if new_c[0] >= 235 and new_c[1] >= 235 and new_c[2] >= 230:
        if orig_role in ("salmon", "pig_body", "nose", "outline"):
            return True

    # Deerstalker — browns/tans in the head band, not exact locked fills.
    if y < HAT_Y and orig_role in ("salmon", "pig_body", "nose"):
        if min_locked_dist(new_c) > 16:
            return True
        if orig_role in ("pig_body", "nose") and y < 360:
            if dist(new_c, SPEC["pig_body"]) > 14 and dist(new_c, SPEC["nose"]) > 14:
                return True

    return False


def normalize_icon(new_path: Path, out_path: Path, original_path: Path = ORIGINAL) -> None:
    orig = Image.open(original_path).convert("RGB")
    new = Image.open(new_path).convert("RGB")
    w, h = orig.size
    out = Image.new("RGB", (w, h))

    for y in range(h):
        for x in range(w):
            orig_role, orig_d = classify(orig.getpixel((x, y)))
            new_c = new.getpixel((x, y))

            if is_variant_pixel(orig_role, orig_d, new_c, y):
                out.putpixel((x, y), new_c)
                continue

            if orig_d <= ORIG_THRESHOLD:
                out.putpixel((x, y), SPEC[orig_role])
                continue

            new_role, new_d = classify(new_c)
            if new_d <= NEW_SNAP_THRESHOLD:
                out.putpixel((x, y), SPEC[new_role])
            else:
                out.putpixel((x, y), new_c)

    out.save(out_path, format="PNG", optimize=True)


def install(processed: Path, *destinations: Path) -> None:
    for dest in destinations:
        dest.parent.mkdir(parents=True, exist_ok=True)
        shutil.copy2(processed, dest)


def main() -> None:
    design = Path(__file__).resolve().parent / "app-icons"
    assets = BASE / "Audiopig/Assets.xcassets"

    jobs = [
        (
            design / "AppIcon-20h-ChefPig-1024.png",
            design / "AppIcon-20h-ChefPig-1024-normalized.png",
            [
                design / "AppIcon-20h-ChefPig-1024.png",
                assets / "AppIcon-20h.appiconset/Icon-1024.png",
                assets / "Gallery-20h.imageset/Icon-1024.png",
            ],
        ),
        (
            design / "AppIcon-Sherpig-1024.png",
            design / "AppIcon-Sherpig-1024-normalized.png",
            [
                design / "AppIcon-Sherpig-1024.png",
                assets / "AppIcon-Sherpig.appiconset/Icon-1024.png",
                assets / "Gallery-Sherpig.imageset/Icon-1024.png",
            ],
        ),
    ]

    for source, temp_out, destinations in jobs:
        normalize_icon(source, temp_out)
        install(temp_out, *destinations)
        temp_out.unlink()
        print(f"Normalized {source.name} -> {len(destinations)} destinations")


if __name__ == "__main__":
    main()
