#!/usr/bin/env python3
"""Star Breaker app icon (Guillaume's pick 2026-11-15, "Pod, 3/4"): the game's crystal pod,
seen at a three quarter angle with its ring and pink shards, with the ship docked behind it at
true scale (he asked for the ship "behind it at the right spot"), hovering over a dark violet
gradient (he asked for a darker background), with warp lines streaking past (option "C", then
spread out: nine evenly spaced lanes plus two on the left).

The pod and ship are renders of the game's own models: tools/icon_shots.gd writes store/pod.png
and store/ship-pod.png (run it again after changing a model), then this script builds every
icon from them.

Usage (from the repo root): python3 tools/icon.py
Writes icon.png (256, rounded: project icon and web favicon), icons/icon-192.png (legacy
launcher icon), icons/adaptive-{background,foreground,monochrome}-432.png (Android adaptive
layers, the pod stays inside the central safe circle) and store/icon-512.png (square, for
stores and previews). Needs Pillow.
"""
import math
import os
import sys

from PIL import Image, ImageDraw, ImageFilter

SS = 4                  # supersampling
N = 432 * SS            # adaptive layer canvas (108 dp)
U = N / 108.0           # one dp
VIS = 72 * U            # the part a launcher shows (72 dp square, centred)
TOP, BOTTOM = (0x1c, 0x0c, 0x3c), (0x5a, 0x24, 0x5e)


def background():
    """Vertical gradient running from the top to the bottom of the visible square."""
    col = Image.new('RGB', (1, N))
    for y in range(N):
        t = min(1.0, max(0.0, (y - (N - VIS) / 2) / VIS))
        col.putpixel((0, y), tuple(int(TOP[i] + (BOTTOM[i] - TOP[i]) * t) for i in range(3)))
    im = col.resize((N, N)).convert('RGBA')
    im.alpha_composite(warp_lines())
    return im


def warp_lines():
    """Thin white lines running along the pod's flight (20 degrees up to the right), as if it
    flies through hyperspace. One line per evenly spaced lane so they never cluster
    (Guillaume's pick: "B", nine lanes, then two lines added on the left and the one
    poking out of the pod's nose removed).
    Each line: lane offset across the flight (in visible squares), start and end along it,
    alpha, width."""
    layer = Image.new('RGBA', (N, N), (0, 0, 0, 0))
    d = ImageDraw.Draw(layer)
    a = math.radians(-20)
    c, s, nx, ny = math.cos(a), math.sin(a), -math.sin(a), math.cos(a)
    for b, t0, t1, alpha, width in WARP:
        def p(t):
            return (N / 2 + (c * t + nx * b) * VIS, N / 2 + (s * t + ny * b) * VIS)

        d.line([p(t0), p(t1)], fill=(255, 255, 255, alpha), width=int(width * VIS))
    return layer


WARP = [
    (-0.705, 0.554, -0.055, 177, 0.0092),
    (-0.535, 0.379, -0.301, 130, 0.0097),
    (-0.357, 0.253, -0.184, 141, 0.0091),
    (-0.193, 0.700, 0.252, 159, 0.0100),
    (-0.150, -0.250, -0.750, 150, 0.0110),  # a second extra line on the left
    (0.110, -0.250, -0.750, 150, 0.0120),   # the extra line on the left
    (0.203, 0.528, 0.176, 131, 0.0142),
    (0.344, 0.247, -0.439, 136, 0.0101),
    (0.558, 0.758, 0.339, 159, 0.0108),
    (0.704, -0.225, -0.633, 118, 0.0110),
]


ZOOM = 0.82             # the camera pulled back from the pod-only framing (pod 74% -> ~61%)
SHIFT = (0.12, 0.02)    # the pod and ship moved right (and a touch down), in visible squares


def subject(root):
    """The rendered pod, tilted 20 degrees and centred as in the pod-only icon, with the ship
    docked behind it at true scale (store/ship-pod.png shares the pod shot's projection, so
    the pod stays pixel for pixel the same), then pulled back by ZOOM and moved by SHIFT."""
    pod = Image.open(f'{root}/store/pod.png').convert('RGBA')
    bx = pod.getbbox()
    rot = pod.crop(bx).rotate(20, resample=Image.BICUBIC, expand=True)
    s = VIS * 0.74 / max(rot.size) * ZOOM
    big = Image.open(f'{root}/store/ship-pod.png').convert('RGBA')
    off = (big.size[0] - pod.size[0]) / 2
    cx, cy, h = off + (bx[0] + bx[2]) / 2, off + (bx[1] + bx[3]) / 2, 1500
    im = big.crop((int(cx - h), int(cy - h), int(cx + h), int(cy + h))).rotate(20, resample=Image.BICUBIC, expand=True)
    im = im.resize((int(im.size[0] * s), int(im.size[1] * s)), Image.LANCZOS)
    x, y = int(N / 2 + SHIFT[0] * VIS - im.size[0] / 2), int(N / 2 + SHIFT[1] * VIS - im.size[1] / 2)
    layer = Image.new('RGBA', (N, N), (0, 0, 0, 0))
    layer.alpha_composite(im, (x, y))
    return layer


def foreground(sh):
    im = Image.new('RGBA', (N, N), (0, 0, 0, 0))
    # soft shadow down and to the right, so the pod hovers over the gradient
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
    sh = subject(root)
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
