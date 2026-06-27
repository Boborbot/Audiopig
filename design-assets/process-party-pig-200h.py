#!/usr/bin/env python3
"""Party pig at 200h; old 2000h -> 2500h; all other hour tiers unchanged."""

from __future__ import annotations

import shutil
import sys
from pathlib import Path

from icon_prepare import prepare_icon

BASE = Path(__file__).resolve().parent.parent
ASSETS = BASE / "Audiopig/Assets.xcassets"
DESIGN = Path(__file__).resolve().parent / "app-icons"
ARCHIVE = Path(__file__).resolve().parent / "archived"


def icon_png(hours: int) -> Path:
    return ASSETS / f"AppIcon-{hours}h.appiconset/Icon-1024.png"


def install_hours(hours: int, png: Path) -> None:
    for dest in (
        icon_png(hours),
        ASSETS / f"Gallery-{hours}h.imageset/Icon-1024.png",
    ):
        dest.parent.mkdir(parents=True, exist_ok=True)
        shutil.copy2(png, dest)


def ensure_asset_folders(hours: int, template_hours: int) -> None:
    for kind, ext in (("AppIcon", "appiconset"), ("Gallery", "imageset")):
        dest = ASSETS / f"{kind}-{hours}h.{ext}"
        dest.mkdir(parents=True, exist_ok=True)
        contents = dest / "Contents.json"
        if not contents.exists():
            shutil.copy2(ASSETS / f"{kind}-{template_hours}h.{ext}/Contents.json", contents)


def archive_if_present(hours: int) -> None:
    ARCHIVE.mkdir(parents=True, exist_ok=True)
    src = icon_png(hours)
    if src.exists():
        shutil.copy2(src, ARCHIVE / f"AppIcon-{hours}h-pre-party-1024.png")


def apply_party_pig(source: Path) -> None:
    DESIGN.mkdir(parents=True, exist_ok=True)
    archive_if_present(200)
    archive_if_present(2000)

    old_200 = icon_png(200)
    old_2000 = icon_png(2000)
    if not old_200.exists() or not old_2000.exists():
        raise SystemExit("Expected existing AppIcon-200h and AppIcon-2000h before install.")

    saved_2000 = ARCHIVE / "AppIcon-2000h-pre-party-1024.png"
    shutil.copy2(old_2000, saved_2000)

    party_out = DESIGN / "AppIcon-200h-PartyPig-1024.png"
    prepare_icon(source, party_out)

    ensure_asset_folders(2500, 2000)

    install_hours(200, party_out)
    install_hours(2500, saved_2000)

    shutil.copy2(saved_2000, DESIGN / "AppIcon-2500h-1024.png")

    print("200h  <- party pig (new)")
    print("2500h <- previous 2000h (bumped one slot)")
    print("500h–2000h unchanged by this script")


def main() -> None:
    default_source = (
        Path("/Users/nitay/.cursor/projects/Users-nitay-Projects-Audiopig/assets")
        / "PartyPig-0ca79d8c-2295-4469-9cd6-a64c1fd41aea.png"
    )
    source = Path(sys.argv[1]) if len(sys.argv) > 1 else default_source
    apply_party_pig(source)


if __name__ == "__main__":
    main()
