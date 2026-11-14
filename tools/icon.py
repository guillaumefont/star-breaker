#!/usr/bin/env python3
"""Star Breaker app icon: the gunship and its crystal pod bursting out of a round medal,
in front of a dusk space scene. Same family as the Tether Rally and Aurite Front icons
(flat shaded emblem with a cream rim, scenic background with light beams, ridges and
particles).

Usage (from the repo root): python3 tools/icon.py
Writes icon.png (256, rounded: project icon and web favicon), icons/icon-192.png (legacy
launcher icon), icons/adaptive-{background,foreground,monochrome}-432.png (Android adaptive
layers, the emblem stays inside the central safe circle) and store/icon-512.png (square,
for stores and previews). Needs Pillow.
"""
import math
import os
import random
import sys

from PIL import Image, ImageDraw, ImageFilter

SS = 4                  # supersampling
N = 432 * SS            # adaptive layer canvas (108 dp)
U = N / 108.0           # one dp


def hexc(h, a=255):
    h = h.lstrip('#')
    return (int(h[0:2], 16), int(h[2:4], 16), int(h[4:6], 16), a)


def lerp(a, b, t):
    t = max(0.0, min(1.0, t))
    return tuple(int(a[i] + (b[i] - a[i]) * t) for i in range(4))


def layer():
    return Image.new('RGBA', (N, N), (0, 0, 0, 0))


def blurred(im, r):
    return im.filter(ImageFilter.GaussianBlur(r))


# ---------------------------------------------------------------- background

def ridge(x, base, amp, sd):
    q = x / U
    return base - amp * (math.sin(q * 0.09 + sd) * 0.55 + math.sin(q * 0.23 + sd * 2.3) * 0.3
                         + math.sin(q * 0.51 + sd * 4.1) * 0.15)


def background():
    im = layer()
    d = ImageDraw.Draw(im, 'RGBA')
    top, mid, low = hexc('0b0926'), hexc('2b1754'), hexc('c4568a')
    hz = 72 * U
    for y in range(N):
        t = y / hz
        c = lerp(top, mid, t / 0.55) if t < 0.55 else lerp(mid, low, (t - 0.55) / 0.45)
        d.line([(0, y), (N, y)], fill=c)
    # horizon glow
    glow = layer()
    ImageDraw.Draw(glow).ellipse([-10 * U, hz - 16 * U, N + 10 * U, hz + 14 * U], fill=(255, 140, 120, 120))
    im.alpha_composite(blurred(glow, 9 * U))
    # searchlight beams from the top, meeting behind the medal
    for ox, ang in ((0.5, 0.0), (0.2, 0.42), (0.8, -0.42)):
        b = layer()
        o = (N * ox, -4 * U)
        a = math.pi / 2 - ang
        w = 0.10 if ox == 0.5 else 0.06
        L = N * 1.2
        ImageDraw.Draw(b).polygon([o, (o[0] + math.cos(a - w) * L, o[1] + math.sin(a - w) * L),
                                   (o[0] + math.cos(a + w) * L, o[1] + math.sin(a + w) * L)],
                                  fill=(220, 210, 255, 34 if ox == 0.5 else 22))
        im.alpha_composite(blurred(b, 3 * U))
    # stars
    rnd = random.Random(11)
    for _ in range(70):
        x, y = rnd.uniform(0, N), rnd.uniform(0, 72 * U)
        r = rnd.uniform(0.18, 0.42) * U
        d.ellipse([x - r, y - r, x + r, y + r], fill=(255, 255, 255, rnd.randint(110, 230)))
    for x, y, s in ((26, 46, 1.4), (84, 25, 1.3), (82, 58, 1.0)):
        sparkle(d, x * U, y * U, s * U, (255, 255, 255, 230))
    # planet rim and low poly ridges
    d.ellipse([-40 * U, 75 * U, N + 40 * U, 200 * U], fill=hexc('3a2063'))
    d.arc([-40 * U, 75 * U, N + 40 * U, 200 * U], 200, 340, fill=hexc('ff9ccf'), width=int(0.8 * U))
    for base, amp, sd, step, col in ((81 * U, 3 * U, 1.3, 9, '2c1a52'), (86 * U, 3.5 * U, 4.2, 7, '1a1038'),
                                     (91 * U, 2.5 * U, 7.7, 6, '0d0924')):
        pts = [(x * U, ridge(x * U, base, amp, sd)) for x in range(-step, 108 + step, step)]
        d.polygon(pts + [(N, N), (0, N)], fill=hexc(col))
    # floating low poly rocks
    rock(d, 25 * U, 30 * U, 3.2 * U, 0.4)
    rock(d, 86 * U, 70 * U, 3.0 * U, 2.6)
    # drifting pink sparks low down
    for _ in range(18):
        x, y = rnd.uniform(0, N), rnd.uniform(66 * U, 92 * U)
        r = rnd.uniform(0.25, 0.55) * U
        d.ellipse([x - r, y - r, x + r, y + r], fill=(255, rnd.randint(130, 200), 220, rnd.randint(110, 200)))
    return im


def sparkle(d, x, y, s, col):
    d.polygon([(x, y - s), (x + s * 0.22, y), (x, y + s), (x - s * 0.22, y)], fill=col)
    d.polygon([(x - s, y), (x, y - s * 0.22), (x + s, y), (x, y + s * 0.22)], fill=col)


def rock(d, cx, cy, r, sd):
    pts = []
    for i in range(7):
        a = sd + i * math.tau / 7
        k = 0.8 + 0.25 * math.sin(sd * 3 + i * 2.1)
        pts.append((cx + math.cos(a) * r * k, cy + math.sin(a) * r * k))
    d.polygon(pts, fill=hexc('3b2b66'))
    # lit facets toward the top
    for i in range(7):
        p, q = pts[i], pts[(i + 1) % 7]
        if (p[1] + q[1]) / 2 < cy:
            d.polygon([(cx, cy), p, q], fill=hexc('5a4691') if i % 2 else hexc('4c3a80'))


# ---------------------------------------------------------------- foreground

MEDAL = (54 * U, 55 * U)
R_OUT, R_IN = 27 * U, 22.8 * U


def ship_xf(p, org, ang, L):
    x, y = p[0] * L, p[1] * L
    c, s = math.cos(ang), math.sin(ang)
    return (org[0] + x * c - y * s, org[1] + x * s + y * c)


def poly(d, pts, org, ang, L, col):
    d.polygon([ship_xf(p, org, ang, L) for p in pts], fill=col)


# ship in local units: tail at x = -0.5, nose at x = 0.5, y down
HULL_TOP = [(-0.43, -0.085), (-0.26, -0.135), (0.04, -0.145), (0.24, -0.13), (0.36, -0.105), (0.43, -0.07),
            (0.47, -0.03), (0.48, 0.0), (-0.43, 0.0)]
HULL_BOT = [(-0.43, 0.0), (0.48, 0.0), (0.47, 0.035), (0.43, 0.065), (0.34, 0.09), (0.2, 0.108), (0.0, 0.115),
            (-0.43, 0.095)]
HULL_MID = [(-0.43, -0.03), (0.46, -0.03), (0.48, 0.0), (0.47, 0.025), (-0.43, 0.02)]
CANOPY = [(-0.02, -0.135), (0.03, -0.19), (0.10, -0.205), (0.18, -0.19), (0.27, -0.11)]
CANOPY_HI = [(0.03, -0.15), (0.06, -0.182), (0.11, -0.19), (0.09, -0.15)]
FIN = [(-0.42, -0.08), (-0.37, -0.29), (-0.28, -0.29), (-0.17, -0.13)]
FIN_HI = [(-0.37, -0.29), (-0.28, -0.29), (-0.265, -0.26), (-0.355, -0.26)]
WING = [(-0.30, 0.06), (0.12, 0.075), (-0.04, 0.26), (-0.30, 0.28)]
WING_HI = [(-0.30, 0.06), (0.12, 0.075), (0.08, 0.12), (-0.30, 0.11)]
NAC = [(-0.47, 0.08), (-0.06, 0.085), (0.0, 0.1), (0.03, 0.12), (0.0, 0.145), (-0.06, 0.16), (-0.47, 0.16)]
NAC_HI = [(-0.47, 0.08), (-0.06, 0.085), (0.0, 0.1), (0.03, 0.12), (-0.47, 0.113)]
NOZZLE = [(-0.50, -0.07), (-0.43, -0.085), (-0.43, 0.095), (-0.50, 0.08)]
NOZZLE2 = [(-0.52, 0.09), (-0.47, 0.08), (-0.47, 0.16), (-0.52, 0.15)]
# the crystal pod ahead of the nose (octahedron seen from the side)
POD_C = (0.71, -0.005)
POD_R = 0.14


def ship(scale_flame=1.0):
    im = layer()
    org = (52 * U, 58 * U)
    ang = math.radians(-27)
    L = 40 * U
    # exhaust flame and engine glow
    fl = layer()
    fd = ImageDraw.Draw(fl)
    for k, col, w in ((1.0, (255, 140, 60, 210), 0.085), (0.75, (255, 200, 90, 235), 0.06), (0.5, (255, 246, 205, 255), 0.035)):
        for cy, wy in ((0.005, w * 1.1), (0.12, w * 0.8)):
            tail = -0.5 - 0.32 * k * scale_flame
            fd.polygon([ship_xf(p, org, ang, L) for p in
                        [(-0.47, cy - wy), (-0.47 - 0.1 * k, cy - wy * 0.9), (tail, cy), (-0.47 - 0.1 * k, cy + wy * 0.9), (-0.47, cy + wy)]],
                       fill=col)
    gl = layer()
    gx, gy = ship_xf((-0.56, 0.05), org, ang, L)
    ImageDraw.Draw(gl).ellipse([gx - 9 * U, gy - 9 * U, gx + 9 * U, gy + 9 * U], fill=(255, 150, 70, 150))
    im.alpha_composite(blurred(gl, 4 * U))
    im.alpha_composite(blurred(fl, 0.5 * U))
    d = ImageDraw.Draw(im, 'RGBA')
    poly(d, WING, org, ang, L, hexc('4a4a68'))
    poly(d, WING_HI, org, ang, L, hexc('6a6b8c'))
    poly(d, FIN, org, ang, L, hexc('565874'))
    poly(d, FIN_HI, org, ang, L, hexc('7a7c9c'))
    poly(d, NOZZLE, org, ang, L, hexc('3e3f58'))
    poly(d, HULL_BOT, org, ang, L, hexc('b9b2dc'))
    poly(d, HULL_TOP, org, ang, L, hexc('f6f3ff'))
    poly(d, HULL_MID, org, ang, L, hexc('ddd7f3'))
    poly(d, CANOPY, org, ang, L, hexc('42d9ef'))
    poly(d, CANOPY_HI, org, ang, L, hexc('b8fbff'))
    poly(d, NOZZLE2, org, ang, L, hexc('3e3f58'))
    poly(d, NAC, org, ang, L, hexc('cfc8ec'))
    poly(d, NAC_HI, org, ang, L, hexc('efebff'))
    # panel line
    d.line([ship_xf(p, org, ang, L) for p in ((-0.12, -0.115), (-0.12, 0.08))], fill=hexc('a9a1d0'), width=int(0.35 * U))
    return im, org, ang, L


def pod(org, ang, L):
    im = layer()
    c = ship_xf(POD_C, org, ang, L)
    r = POD_R * L
    halo = layer()
    ImageDraw.Draw(halo).ellipse([c[0] - r * 1.9, c[1] - r * 1.9, c[0] + r * 1.9, c[1] + r * 1.9], fill=(90, 245, 255, 150))
    im.alpha_composite(blurred(halo, 3.2 * U))
    d = ImageDraw.Draw(im, 'RGBA')

    def P(x, y):
        return ship_xf((POD_C[0] + x * POD_R, POD_C[1] + y * POD_R), org, ang, L)

    top, bot, lf, rt, mid = P(0, -1.25), P(0, 1.25), P(-1, 0), P(1, 0), P(0.12, 0)
    d.polygon([top, lf, mid], fill=hexc('c9feff'))
    d.polygon([top, mid, rt], fill=hexc('7cf3ff'))
    d.polygon([bot, lf, mid], fill=hexc('3fd3ec'))
    d.polygon([bot, mid, rt], fill=hexc('1ea8cf'))
    # spin ring
    ring = [P(math.cos(t) * 0.42, math.sin(t) * 1.6) for t in [i * math.tau / 48 for i in range(49)]]
    d.line(ring, fill=(255, 255, 255, 235), width=int(0.55 * U), joint='curve')
    # orbiting pink shards
    for sy, sx in ((-1.9, 0.15), (1.9, -0.15)):
        a, b2 = P(sx - 0.55, sy), P(sx + 0.25, sy - 0.32 * (1 if sy < 0 else -1))
        e, f = P(sx + 0.55, sy), P(sx - 0.25, sy + 0.32 * (1 if sy < 0 else -1))
        d.polygon([a, b2, e, f], fill=hexc('ff6fd2'))
        d.polygon([a, b2, e], fill=hexc('ffa6e6'))
    return im


def medal():
    im = layer()
    cx, cy = MEDAL
    sh = layer()
    ImageDraw.Draw(sh).ellipse([cx - R_OUT, cy - R_OUT + 1.8 * U, cx + R_OUT, cy + R_OUT + 1.8 * U], fill=(0, 0, 0, 150))
    im.alpha_composite(blurred(sh, 1.8 * U))
    d = ImageDraw.Draw(im, 'RGBA')
    # cream rim, a shade darker on its lower half
    d.ellipse([cx - R_OUT, cy - R_OUT, cx + R_OUT, cy + R_OUT], fill=hexc('e9e0cb'))
    d.chord([cx - R_OUT, cy - R_OUT, cx + R_OUT, cy + R_OUT], 20, 160, fill=hexc('cfc4ab'))
    hi = 24.9 * U
    d.arc([cx - hi, cy - hi, cx + hi, cy + hi], 200, 320, fill=hexc('fbf6ea'), width=int(1.0 * U))
    # deep space inside
    inner = layer()
    idr = ImageDraw.Draw(inner, 'RGBA')
    for i in range(40, 0, -1):
        t = i / 40
        rr = R_IN * t
        idr.ellipse([cx - rr, cy - rr - (1 - t) * 3 * U, cx + rr, cy + rr - (1 - t) * 3 * U], fill=lerp(hexc('1e2c4f'), hexc('0b1230'), t))
    mask = Image.new('L', (N, N), 0)
    ImageDraw.Draw(mask).ellipse([cx - R_IN, cy - R_IN, cx + R_IN, cy + R_IN], fill=255)
    rnd = random.Random(5)
    for _ in range(26):
        a, rr = rnd.uniform(0, math.tau), R_IN * math.sqrt(rnd.uniform(0, 1))
        x, y = cx + math.cos(a) * rr, cy + math.sin(a) * rr
        s = rnd.uniform(0.15, 0.32) * U
        idr.ellipse([x - s, y - s, x + s, y + s], fill=(255, 255, 255, rnd.randint(120, 230)))
    # speed lines streaking past behind the ship
    for y0, x0, x1, al in ((47, 36, 54, 120), (66, 44, 64, 90), (72, 50, 62, 70)):
        idr.line([(x0 * U, y0 * U), (x1 * U, (y0 - (x1 - x0) * 0.51) * U)], fill=(160, 230, 255, al), width=int(0.5 * U))
    inner.putalpha(Image.composite(inner.getchannel('A'), Image.new('L', (N, N), 0), mask))
    im.alpha_composite(inner)
    # thin inner rule
    rr = R_IN - 1.6 * U
    d.ellipse([cx - rr, cy - rr, cx + rr, cy + rr], outline=(150, 175, 220, 90), width=int(0.35 * U))
    d.ellipse([cx - R_IN, cy - R_IN, cx + R_IN, cy + R_IN], outline=hexc('a99f86'), width=int(0.5 * U))
    return im


def foreground():
    im = medal()
    s, org, ang, L = ship()
    sh = layer()
    sh.paste((0, 0, 0, 140), mask=s.getchannel('A'))
    im.alpha_composite(blurred(sh, 1.2 * U).transform((N, N), Image.AFFINE, (1, 0, 0, 0, 1, -1.4 * U)))
    im.alpha_composite(s)
    im.alpha_composite(pod(org, ang, L))
    return im


def monochrome(fg):
    a = fg.getchannel('A').point(lambda v: 255 if v > 150 else 0)
    im = Image.new('RGBA', (N, N), (255, 255, 255, 0))
    im.putalpha(a)
    return im


def rounded(full, size):
    m = int(N * 18 / 108)
    sq = full.crop((m, m, N - m, N - m))
    mask = Image.new('L', sq.size, 0)
    ImageDraw.Draw(mask).rounded_rectangle([0, 0, sq.size[0] - 1, sq.size[1] - 1], radius=int(sq.size[0] * 0.22), fill=255)
    sq = sq.copy()
    sq.putalpha(mask)
    return sq.resize((size, size), Image.LANCZOS)


def main(root):
    bg, fg = background(), foreground()
    os.makedirs(f'{root}/icons', exist_ok=True)
    os.makedirs(f'{root}/store', exist_ok=True)
    bg.convert('RGB').resize((432, 432), Image.LANCZOS).save(f'{root}/icons/adaptive-background-432.png')
    fg.resize((432, 432), Image.LANCZOS).save(f'{root}/icons/adaptive-foreground-432.png')
    monochrome(fg).resize((432, 432), Image.LANCZOS).save(f'{root}/icons/adaptive-monochrome-432.png')
    full = bg.copy()
    full.alpha_composite(fg)
    rounded(full, 192).save(f'{root}/icons/icon-192.png')
    rounded(full, 256).save(f'{root}/icon.png')
    m = int(N * 18 / 108)
    full.crop((m, m, N - m, N - m)).resize((512, 512), Image.LANCZOS).save(f'{root}/store/icon-512.png')
    print('icons written')


if __name__ == '__main__':
    main(sys.argv[1] if len(sys.argv) > 1 else '.')
