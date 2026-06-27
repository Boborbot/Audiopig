#!/usr/bin/env python3
"""Fix mistaken full cascade — party pig at 200h only; old 200→250, old 2000→2500."""

from __future__ import annotations

import shutil
from pathlib import Path

BASE = Path(__file__).resolve().parent.parent
ASSETS = BASE / "Audiopig/Assets.xcassets"
ARCHIVE = Path(__file__).resolve().parent / "archived"
DESIGN = Path(__file__).resolve().parent / "app-icons"


def install(hours: int, src: Path) -> None:
    for dest in (
        ASSETS / f"AppIcon-{hours}h.appiconset/Icon-1024.png",
        ASSETS / f"Gallery-{hours}h.imageset/Icon-1024.png",
    ):
        dest.parent.mkdir(parents=True, exist_ok=True)
        shutil.copy2(src, dest)
    print(f"  {hours}h <- {src.name}")


def ensure_folder(hours: int, template_hours: int) -> None:
    for kind in ("AppIcon", "Gallery"):
        folder = f"{kind}-{hours}h.{'appiconset' if kind == 'AppIcon' else 'imageset'}"
        dest_dir = ASSETS / folder
        dest_dir.mkdir(parents=True, exist_ok=True)
        template = ASSETS / f"{kind}-{template_hours}h.{'appiconset' if kind == 'AppIcon' else 'imageset'}/Contents.json"
        contents = dest_dir / "Contents.json"
        if not contents.exists():
            shutil.copy2(template, contents)


def main() -> None:
    party = DESIGN / "AppIcon-200h-PartyPig-1024.png"
    if not party.exists():
        raise SystemExit(f"Missing party pig master: {party}")

    ensure_folder(250, 200)
    ensure_folder(2500, 2000)

    print("Restoring correct tier art:")
    install(200, party)
    install(250, ARCHIVE / "AppIcon-200h-pre-cascade-1024.png")
    install(500, ARCHIVE / "AppIcon-500h-pre-cascade-1024.png")
    install(1000, ARCHIVE / "AppIcon-1000h-pre-cascade-1024.png")
    install(1500, ARCHIVE / "AppIcon-1500h-pre-cascade-1024.png")
    install(2000, ARCHIVE / "AppIcon-2000h-pre-cascade-1024.png")
    install(2500, ARCHIVE / "AppIcon-2000h-pre-cascade-1024.png")
    print("Done.")


if __name__ == "__main__":
    main()
