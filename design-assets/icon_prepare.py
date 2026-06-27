"""Conservative app-icon prep: background salmon, watermark removal, light sharpen."""

from __future__ import annotations

from collections import deque
from pathlib import Path

from PIL import Image, ImageDraw, ImageFilter

SALMON = (241, 132, 112)
WATERMARK_BOX = 140
BG_TOLERANCE = 32


def dist(a: tuple[int, int, int], b: tuple[int, int, int]) -> float:
    return sum((x - y) ** 2 for x, y in zip(a, b)) ** 0.5


def is_salmon_family(c: tuple[int, int, int]) -> bool:
    r, g, b = c
    if r < 190 or g < 95 or b < 75:
        return False
    if r > 252 and g > 185 and b > 165:
        return False
    return dist(c, SALMON) <= BG_TOLERANCE


def background_mask(im: Image.Image) -> set[tuple[int, int]]:
    w, h = im.size
    mask: set[tuple[int, int]] = set()
    for cx, cy in ((0, 0), (w - 1, 0), (0, h - 1), (w - 1, h - 1)):
        if not is_salmon_family(im.getpixel((cx, cy))):
            continue
        queue: deque[tuple[int, int]] = deque([(cx, cy)])
        while queue:
            x, y = queue.popleft()
            if (x, y) in mask:
                continue
            c = im.getpixel((x, y))
            if not is_salmon_family(c):
                continue
            mask.add((x, y))
            if x > 0:
                queue.append((x - 1, y))
            if x + 1 < w:
                queue.append((x + 1, y))
            if y > 0:
                queue.append((x, y - 1))
            if y + 1 < h:
                queue.append((x, y + 1))
    return mask


def remove_watermark(im: Image.Image) -> None:
    draw = ImageDraw.Draw(im)
    w, h = im.size
    draw.rectangle([w - WATERMARK_BOX, h - WATERMARK_BOX, w, h], fill=SALMON)


def normalize_background(im: Image.Image) -> Image.Image:
    out = im.copy()
    mask = background_mask(out)
    px = out.load()
    for x, y in mask:
        px[x, y] = SALMON
    remove_watermark(out)
    return out


def sharpen_lines(im: Image.Image) -> Image.Image:
    return im.filter(ImageFilter.UnsharpMask(radius=1.2, percent=90, threshold=2))


def prepare_icon(source: Path, output: Path) -> None:
    im = Image.open(source).convert("RGB")
    if im.size != (1024, 1024):
        im = im.resize((1024, 1024), Image.Resampling.LANCZOS)
    im = normalize_background(im)
    im = sharpen_lines(im)
    im.save(output, format="PNG", optimize=True)
