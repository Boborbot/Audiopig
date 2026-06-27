#!/usr/bin/env python3
"""Minimal prep for the 1500h aviator icon — background, watermark, light sharpen only."""

from __future__ import annotations

import shutil
import sys
from pathlib import Path

from icon_prepare import prepare_icon

BASE = Path(__file__).resolve().parent.parent
ASSETS = BASE / "Audiopig/Assets.xcassets"
DESIGN = Path(__file__).resolve().parent / "app-icons"


def install_1500(processed: Path) -> None:
    DESIGN.mkdir(parents=True, exist_ok=True)
    shutil.copy2(processed, DESIGN / "AppIcon-1500h-FlyingPig-1024.png")
    for dest in (
        ASSETS / "AppIcon-1500h.appiconset/Icon-1024.png",
        ASSETS / "Gallery-1500h.imageset/Icon-1024.png",
    ):
        shutil.copy2(processed, dest)
    print(f"Installed {processed.name} -> AppIcon-1500h + Gallery-1500h")


def main() -> None:
    default_source = (
        Path("/Users/nitay/.cursor/projects/Users-nitay-Projects-Audiopig/assets")
        / "FlyingPig-2d38a82c-b162-4b38-9cbc-c601a137cb7e.png"
    )
    source = Path(sys.argv[1]) if len(sys.argv) > 1 else default_source
    temp = DESIGN / "AppIcon-1500h-FlyingPig-1024-temp.png"
    prepare_icon(source, temp)
    install_1500(temp)
    temp.unlink(missing_ok=True)


if __name__ == "__main__":
    main()
