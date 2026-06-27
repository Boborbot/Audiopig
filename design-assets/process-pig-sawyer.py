#!/usr/bin/env python3
"""Prepare Pig Sawyer secret achievement icon."""

from __future__ import annotations

import shutil
import sys
from pathlib import Path

from icon_prepare import prepare_icon

BASE = Path(__file__).resolve().parent.parent
ASSETS = BASE / "Audiopig/Assets.xcassets"
DESIGN = Path(__file__).resolve().parent / "app-icons"


def main() -> None:
    default_source = (
        Path("/Users/nitay/.cursor/projects/Users-nitay-Projects-Audiopig/assets")
        / "PigSawyer-3518931e-a025-43ca-82c0-6024e94997ad.png"
    )
    source = Path(sys.argv[1]) if len(sys.argv) > 1 else default_source
    DESIGN.mkdir(parents=True, exist_ok=True)
    out = DESIGN / "AppIcon-PigSawyer-1024.png"
    prepare_icon(source, out)

    for kind, ext in (("AppIcon", "appiconset"), ("Gallery", "imageset")):
        dest_dir = ASSETS / f"{kind}-PigSawyer.{ext}"
        dest_dir.mkdir(parents=True, exist_ok=True)
        template = ASSETS / f"{kind}-Sherpig.{ext}/Contents.json"
        contents = dest_dir / "Contents.json"
        if not contents.exists():
            shutil.copy2(template, contents)
        shutil.copy2(out, dest_dir / "Icon-1024.png")

    print(f"Installed Pig Sawyer -> AppIcon-PigSawyer + Gallery-PigSawyer")


if __name__ == "__main__":
    main()
