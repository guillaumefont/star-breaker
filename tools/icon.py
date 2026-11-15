#!/usr/bin/env python3
"""Star Breaker app icon ("Straight up", Guillaume's pick 2026-11-15): the real low poly ship
with its crystal pod docked at the nose, seen from above and pointing straight up, hovering
over a clean violet-to-orange gradient.

The ship is a render of the game's own models: tools/icon_shots.gd writes store/ship-top.png
(run it again after changing the ship or pod), then this script builds every icon from it.

Usage (from the repo root): python3 tools/icon.py
Writes icon.png (256, rounded: project icon and web favicon), icons/icon-192.png (legacy
launcher icon), icons/adaptive-{background,foreground,monochrome}-432.png (Android adaptive
layers, the ship stays inside the central safe circle) and store/icon-512.png (square, for
stores and previews). Needs Pillow.
"""
import os
import sys

from PIL import Image, ImageDraw, ImageFilter

SS = 4                  # supersampling
N = 432 * SS            # adaptive layer canvas (108 dp)
U = N / 108.0           # one dp
VIS = 72 * U            # the part a launcher shows (72 dp square, centred)
TOP, BOTTOM = (0x5a, 0x1a, 0x8a), (0xff, 0x9a, 0x5a)


def background():
    """Vertical gradient running from the top to the bottom of the visible square."""
    col = Image.new('RGB', (1, N))
    for y in range(N):
        t = min(1.0, max(0.0, (y - (N - VIS) / 2) / VIS))
        col.putpixel((0, y), tuple(int(TOP[i] + (BOTTOM[i] - TOP[i]) * t) for i in range(3)))
    return col.resize((N, N)).convert('RGBA')


def ship(root):
    """The rendered ship, nose up, 84% of the visible width tall, centred a little low."""
    im = Image.open(f'{root}/store/ship-top.png').convert('RGBA')
    im = im.crop(im.getbbox()).rotate(90, resample=Image.BICUBIC, expand=True)
    h = int(VIS * 0.84)
    im = im.resize((int(im.size[0] * h / im.size[1]), h), Image.LANCZOS)
    x, y = int(N / 2 - im.size[0] / 2), int(N / 2 + VIS * 0.02 - im.size[1] / 2)
    layer = Image.new('RGBA', (N, N), (0, 0, 0, 0))
    layer.alpha_composite(im, (x, y))
    return layer


def foreground(sh):
    im = Image.new('RGBA', (N, N), (0, 0, 0, 0))
    # soft shadow down and to the right, so the ship hovers over the gradient
    shadow = Image.new('RGBA', (N, N), (0, 0, 0, 0))
    shadow.paste((15, 5, 40, 110), mask=sh.getchannel('A'))
    shadow = shadow.transform((N, N), Image.AFFINE, (1, 0, -1.6 * U, 0, 1, -2.3 * U))
    im.alpha_composite(shadow.filter(ImageFilter.GaussianBlur(1.15 * U)))
    im.alpha_composite(sh)
    return im


def monochrome(sh):
    a = sh.getchannel('A').point(lambda v: 255 if v > 128 else 0)
    im = Image.new('RGBA', (N, N), (255, 255, 255, 0))
    im.putalpha(a)
    return im


def rounded(full, size):
    m = int((N - VIS) / 2)
    sq = full.crop((m, m, N - m, N - m))
    mask = Image.new('L', sq.size, 0)
    ImageDraw.Draw(mask).rounded_rectangle([0, 0, sq.size[0] - 1, sq.size[1] - 1], radius=int(sq.size[0] * 0.22), fill=255)
    sq = sq.copy()
    sq.putalpha(mask)
    return sq.resize((size, size), Image.LANCZOS)


def main(root):
    sh = ship(root)
    bg, fg = background(), foreground(sh)
    os.makedirs(f'{root}/icons', exist_ok=True)
    bg.convert('RGB').resize((432, 432), Image.LANCZOS).save(f'{root}/icons/adaptive-background-432.png')
    fg.resize((432, 432), Image.LANCZOS).save(f'{root}/icons/adaptive-foreground-432.png')
    monochrome(sh).resize((432, 432), Image.LANCZOS).save(f'{root}/icons/adaptive-monochrome-432.png')
    full = bg.copy()
    full.alpha_composite(fg)
    rounded(full, 192).save(f'{root}/icons/icon-192.png')
    rounded(full, 256).save(f'{root}/icon.png')
    m = int((N - VIS) / 2)
    full.crop((m, m, N - m, N - m)).resize((512, 512), Image.LANCZOS).save(f'{root}/store/icon-512.png')
    print('icons written')


if __name__ == '__main__':
    main(sys.argv[1] if len(sys.argv) > 1 else '.')
