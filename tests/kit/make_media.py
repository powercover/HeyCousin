"""Draws the addon's art for each theme and makes its sounds.

python make_media.py                  everything
python make_media.py --preview DIR    also preview sheets (PNG) in DIR, one per theme, at the
                                      sizes the addon shows them, on the theme's colors

Media/Pixel   the Pixel theme: drawn on a small grid of "art pixels" (a crest is 32 x 32, an icon
              16 x 16) and scaled up 2 times with no smoothing; the game shows it with nearest filtering, so edges stay crisp. Chunky dark
              outlines, flat shading, warm wood colors.
Media/Smooth  the Smooth theme: drawn 4 times larger and scaled down, so edges are smooth.
Media/Sounds  shared.

Tintable textures are white (the addon colors them in the game), with black where an outline
must stay dark under any tint. 32-bit TGA, uncompressed, power-of-two sizes. The symbols and
letters are drawn here by hand (the ASCII below), for both themes: Smooth rounds them off.
"""
import math
import os
import subprocess
import sys
import tempfile
import wave

import numpy as np
from PIL import Image, ImageChops, ImageDraw, ImageFilter

ROOT = os.environ.get("HC_ROOT", os.path.abspath(os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "..")))
MEDIA = os.path.join(ROOT, "Media")
UP = 2  # each art pixel is 2 texture pixels (the game shows them sharp: nearest filtering)
SS = 4  # smooth art: supersampling


def save(image, rel):
    path = os.path.join(MEDIA, rel.replace("/", os.sep) + ".tga")
    os.makedirs(os.path.dirname(path), exist_ok=True)
    image.save(path, format="TGA", rle=False)
    return path


# --- art-pixel helpers -------------------------------------------------------------------------

def grid(rows):
    """ASCII art to a char array: '.' empty, '#' body, 'k' black inside, 'w' body on black."""
    width = max(len(r) for r in rows)
    return np.array([list(r.ljust(width, ".")) for r in rows])


def centered(art, size):
    """An ASCII glyph centered on a size x size canvas (char array)."""
    h, w = art.shape
    out = np.full((size, size), ".", dtype="<U1")
    y, x = (size - h) // 2, (size - w) // 2
    out[y:y + h, x:x + w] = art
    return out


def dilate(mask, diagonal=True):
    p = np.pad(mask, 1)
    out = p[1:-1, 1:-1] | p[:-2, 1:-1] | p[2:, 1:-1] | p[1:-1, :-2] | p[1:-1, 2:]
    if diagonal:
        out = out | p[:-2, :-2] | p[:-2, 2:] | p[2:, :-2] | p[2:, 2:]
    return out


def erode(mask, times=1):
    for _ in range(times):
        p = np.pad(mask, 1)
        mask = p[1:-1, 1:-1] & p[:-2, 1:-1] & p[2:, 1:-1] & p[1:-1, :-2] & p[1:-1, 2:]
    return mask


def rgba(h, w):
    return np.zeros((h, w, 4), np.uint8)


def paint(img, mask, color, alpha=255):
    img[mask, 0], img[mask, 1], img[mask, 2] = color
    img[mask, 3] = alpha


def up(img, factor=UP):
    return Image.fromarray(np.repeat(np.repeat(img, factor, axis=0), factor, axis=1), "RGBA")


def two_tone(chars):
    """A glyph as a tintable texture: body white, its outline and 'k' parts black."""
    body = (chars == "#") | (chars == "w")
    black = chars == "k"
    shape = body | black
    outline = dilate(shape) & ~shape
    img = rgba(*chars.shape)
    paint(img, outline | black, (0, 0, 0))
    paint(img, body, (255, 255, 255))
    return img


# --- the pixel palette (the Pixel skin's colors in Lua match these) ----------------------------

INK = (28, 19, 20)
PANEL = (60, 43, 42)
CARD = (72, 52, 50)
CARD_HI = (88, 65, 61)
WELL = (44, 31, 31)
WELL_SHADE = (33, 23, 24)
TRIM = (186, 104, 56)
TRIM_DARK = (118, 64, 38)
WOOD = (212, 128, 64)
WOOD_HI = (238, 170, 106)
WOOD_LO = (150, 82, 40)
WOOD_HOVER = (226, 146, 80)
WOOD_HOVER_HI = (246, 186, 124)
WOOD_DOWN = (186, 108, 52)
DARK = (84, 61, 57)
DARK_HI = (106, 79, 73)
DARK_LO = (58, 41, 39)
DARK_HOVER = (98, 72, 67)
DARK_HOVER_HI = (122, 92, 85)
OFF = (92, 86, 83)
OFF_HI = (114, 107, 103)
OFF_LO = (66, 61, 59)
CREAM = (244, 228, 196)
CREAM_LO = (196, 176, 146)
BADGE = (205, 58, 46)
BADGE_HI = (236, 104, 86)
BADGE_LO = (140, 34, 28)


def shaded(mask, body, hi, lo, lip=2):
    """Cartoon shading on a shape: a light top row, a dark lip at the bottom, an ink outline."""
    above = np.zeros_like(mask)
    above[1:] = mask[:-1]
    img = rgba(*mask.shape)
    paint(img, dilate(mask) & ~mask, INK)
    paint(img, mask, body)
    paint(img, mask & ~above, hi)
    for n in range(1, lip + 1):
        below = np.zeros_like(mask)
        below[:-n] = mask[n:]
        paint(img, mask & ~below, lo)
    return img


def tile_mask(size=16):
    """A square with notched corners, inside a one-pixel border (where the outline goes)."""
    m = np.zeros((size, size), bool)
    m[1:-1, 1:-1] = True
    for y, x in ((1, 1), (1, size - 2), (size - 2, 1), (size - 2, size - 2)):
        m[y, x] = False
    return m


def edge_depth(mask):
    """How many pixels in from the shape's edge each pixel is (0 = on the edge)."""
    depth = np.full(mask.shape, -1)
    current, d = mask.copy(), 0
    while current.any():
        inner = erode(current)
        depth[current & ~inner] = d
        current, d = inner, d + 1
    return depth


def ui_tiles():
    out = {}
    m = tile_mask()
    depth = edge_depth(m)
    outline = dilate(m) & ~m

    def framed(colors, fill):
        img = rgba(16, 16)
        paint(img, outline, INK)
        paint(img, m, fill)
        for d, color in enumerate(colors):
            paint(img, depth == d, color)
        return img

    out["Panel"] = framed([TRIM, TRIM_DARK], PANEL)
    card = framed([CARD_HI], CARD)
    out["Card"] = card
    well = framed([], WELL)
    # an inset: its top edge in shade
    paint(well, m & (depth == 0) & (np.arange(16)[:, None] <= 2), WELL_SHADE)
    out["Well"] = well
    out["Frame"] = framed([TRIM, INK], WELL)
    shadow = rgba(16, 16)
    paint(shadow, m | outline, (255, 255, 255))
    out["Shadow"] = shadow
    out["Button"] = shaded(m, WOOD, WOOD_HI, WOOD_LO)
    out["ButtonHover"] = shaded(m, WOOD_HOVER, WOOD_HOVER_HI, WOOD_LO)
    out["ButtonDown"] = shaded(m, WOOD_DOWN, WOOD_DOWN, WOOD_DOWN, lip=0)
    out["ButtonOff"] = shaded(m, OFF, OFF_HI, OFF_LO)
    out["Dark"] = shaded(m, DARK, DARK_HI, DARK_LO)
    out["DarkHover"] = shaded(m, DARK_HOVER, DARK_HOVER_HI, DARK_LO)
    out["DarkDown"] = shaded(m, DARK_LO, DARK_LO, DARK_LO, lip=0)
    out["DarkOff"] = shaded(m, OFF_LO, OFF, OFF_LO)
    # a check box: an inset well, or wood with a cream check
    box = np.zeros((16, 16), bool)
    box[2:14, 2:14] = True
    for y, x in ((2, 2), (2, 13), (13, 2), (13, 13)):
        box[y, x] = False
    off = rgba(16, 16)
    paint(off, dilate(box) & ~box, INK)
    paint(off, box, WELL)
    paint(off, box & (np.arange(16)[:, None] == 2), WELL_SHADE)
    out["CheckOff"] = off
    on = shaded(box, WOOD, WOOD_HI, WOOD_LO)
    tick = centered(grid([
        ".......##",
        "......##.",
        "##...##..",
        ".##.##...",
        "..###....",
        "...#.....",
    ]), 16)
    tick_mask = np.roll(tick == "#", -1, axis=0)
    paint(on, dilate(tick_mask, diagonal=False) & ~tick_mask & box, WOOD_LO)
    paint(on, tick_mask, CREAM)
    out["CheckOn"] = on
    # a color to pick, and the frame around the chosen one (both tinted)
    swatch = np.zeros((16, 16), bool)
    swatch[3:13, 3:13] = True
    s = rgba(16, 16)
    paint(s, dilate(swatch) & ~swatch, (0, 0, 0))
    paint(s, swatch, (255, 255, 255))
    paint(s, swatch & (np.arange(16)[:, None] == 3), (255, 255, 255))
    out["Swatch"] = s
    ring = np.zeros((16, 16), bool)
    ring[0:16, 0:16] = True
    ring &= ~erode(ring, 1)
    ring[0, 0] = ring[0, 15] = ring[15, 0] = ring[15, 15] = False
    pick = rgba(16, 16)
    paint(pick, ring, (255, 255, 255))
    out["SwatchPick"] = pick
    # the "near" dot and the count badge
    dot = centered(grid(["####", "####", "####", "####"]), 8)
    out["Dot"] = two_tone(dot)
    badge = centered(grid([
        "..######..",
        ".########.",
        "##########",
        "##########",
        "##########",
        "##########",
        ".########.",
        "..######..",
    ]), 16) == "#"
    out["Badge"] = shaded(badge, BADGE, BADGE_HI, BADGE_LO, lip=1)
    # the minimap button: a round wooden plate
    plate = np.zeros((16, 16), bool)
    for y in range(16):
        for x in range(16):
            plate[y, x] = (x - 7.5) ** 2 + (y - 7.5) ** 2 <= 7.2 ** 2
    plate = erode(dilate(plate))
    mm = rgba(16, 16)
    paint(mm, dilate(plate) & ~plate, INK)
    paint(mm, plate, TRIM)
    paint(mm, erode(plate), TRIM_DARK)
    paint(mm, erode(plate, 2), WELL)
    out["Plate"] = mm
    # an arrow to flip through choices (it points left; the addon mirrors it for right)
    arrow = grid([
        "......##.......",
        ".....###.......",
        "....####.......",
        "...###########.",
        "..############.",
        ".#############.",
        "..############.",
        "...###########.",
        "....####.......",
        ".....###.......",
        "......##.......",
    ])
    a = centered(arrow, 16) == "#"
    out["Arrow"] = shaded(a, WOOD, WOOD_HI, WOOD_LO)
    out["ArrowHover"] = shaded(a, WOOD_HOVER, WOOD_HOVER_HI, WOOD_LO)
    # the motto ribbon: 32 x 16, cut in three (a tail, the stretching middle, a tail)
    band = np.zeros((16, 32), bool)
    band[3:12, 6:26] = True
    tails = np.zeros((16, 32), bool)
    for y in range(6, 15):
        notch = abs(y - 10) < 2
        tails[y, 1:7] = True
        tails[y, 25:31] = True
        if notch:
            tails[y, 1:3] = False
            tails[y, 29:31] = False
    tails &= ~band
    rib = rgba(16, 32)
    paint(rib, dilate(band | tails) & ~(band | tails), INK)
    paint(rib, tails, CREAM_LO)
    paint(rib, band, CREAM)
    paint(rib, band & (np.arange(16)[:, None] == 3), (255, 245, 222))
    paint(rib, band & (np.arange(16)[:, None] == 11), CREAM_LO)
    out["Ribbon"] = rib
    return {"Pixel/UI/" + key: up(img) for key, img in out.items()}


# --- pixel crests --------------------------------------------------------------------------------

def profile(rows, top, size=32, center=16):
    m = np.zeros((size, size), bool)
    for i, hw in enumerate(rows):
        m[top + i, center - hw:center + hw] = True
    return m


def circle(diameter, top, size=32):
    r = diameter / 2
    rows = [int(round(math.sqrt(max(0.0, r * r - (i + 0.5 - r) ** 2)))) for i in range(diameter)]
    return profile(rows, top, size, size // 2)


def banner(size=32):
    if size == 32:
        m = profile([11] * 25, 4, size)
        for i, n in enumerate(range(1, 8)):
            m[22 + i - 0, 16 - n:16 + n] = False
        rod = np.zeros_like(m)
        rod[2, 3:29] = True
        rod[1:4, 3:5] = True
        rod[1:4, 27:29] = True
    else:
        m = profile([5] * 13, 2, size, 8)
        for i, n in enumerate(range(1, 4)):
            m[12 + i, 8 - n:8 + n] = False
        rod = np.zeros_like(m)
        rod[1, 1:15] = True
    return m, rod


PIXEL_SHAPES = {
    # name: (mask, symbol center (x, y) in art pixels)
    "Heater": (lambda: (profile([11, 12, 12, 12, 12, 12, 12, 12, 12, 12, 12, 12, 12, 12, 12, 12, 11, 11, 11, 10, 10,
                                 9, 8, 7, 6, 4, 2], 2), None), (16, 13)),
    "Round": (lambda: (circle(26, 3), None), (16, 16)),
    "Kite": (lambda: (profile([4, 6, 8, 9, 10, 10, 11, 11, 11, 11, 11, 10, 10, 10, 9, 9, 8, 8, 7, 6, 6, 5, 4, 4, 3, 2,
                               1, 1], 2), None), (16, 12)),
    "Banner": (banner, (16, 14)),
}
SMALL_SHAPES = {
    "Heater": lambda: (profile([5, 6, 6, 6, 6, 6, 6, 6, 5, 5, 4, 3, 2, 1], 1, 16, 8), None),
    "Round": lambda: (circle(13, 1, 16), None),
    "Kite": lambda: (profile([2, 4, 5, 5, 5, 5, 5, 4, 4, 3, 3, 2, 1, 1], 1, 16, 8), None),
    "Banner": lambda: banner(16),
}
DIVISIONS = ["Pale", "Fess", "Bend", "Quarterly", "Chevron", "Cross"]


def division_mask(name, inner, cy):
    ys, xs = np.nonzero(inner)
    y0, y1, x0, x1 = ys.min(), ys.max(), xs.min(), xs.max()
    h, w = y1 - y0 + 1, x1 - x0 + 1
    yy, xx = np.mgrid[0:inner.shape[0], 0:inner.shape[1]]
    if name == "Pale":
        area = xx >= 16
    elif name == "Fess":
        area = yy >= cy
    elif name == "Bend":
        area = (yy - y0) * w > (xx - x0) * h
    elif name == "Quarterly":
        area = (xx >= 16) ^ (yy >= cy)
    elif name == "Chevron":
        apex = y0 + int(h * 0.32)
        line = apex + (np.abs(xx - 15.5) * 0.9).astype(int)
        area = (yy >= line) & (yy < line + 4)
    elif name == "Cross":
        area = (np.abs(xx - 15.5) < 2) | ((yy >= cy - 2) & (yy < cy + 2))
    return area & inner


def pixel_crests():
    out = {}
    for name, (make, (cx, cy)) in PIXEL_SHAPES.items():
        fill, rod = make()
        extra = rod if rod is not None else np.zeros_like(fill)
        inner = erode(fill, 2)
        rim = (fill & ~inner) | extra
        outline = dilate(fill | extra) & ~(fill | extra)
        frame = rgba(32, 32)
        paint(frame, outline, (0, 0, 0))
        paint(frame, rim, (255, 255, 255))
        out[name + "Frame"] = frame
        f = rgba(32, 32)
        paint(f, fill, (255, 255, 255))
        out[name + "Fill"] = f
        for div in DIVISIONS:
            d = rgba(32, 32)
            paint(d, division_mask(div, inner, cy), (255, 255, 255))
            out[name + div] = d
        # light on the top left: a line inside the rim and a glint in the corner
        above = np.zeros_like(inner)
        above[1:] = inner[:-1]
        leftside = np.zeros_like(inner)
        leftside[:, 1:] = inner[:, :-1]
        shine = rgba(32, 32)
        edge = inner & (~above | ~leftside)
        yy, xx = np.mgrid[0:32, 0:32]
        upper_left = (xx < 16) & (yy < cy)
        paint(shine, edge & upper_left, (255, 255, 255), 90)
        ys, xs = np.nonzero(inner)
        gy, gx = ys.min() + 1, xs[ys == ys.min()].min() + 1
        glint = np.zeros_like(inner)
        glint[gy:gy + 2, gx:gx + 1] = True
        glint[gy:gy + 1, gx:gx + 2] = True
        paint(shine, glint & inner, (255, 255, 255), 150)
        out[name + "Shine"] = shine
        shadow = rgba(32, 32)
        silhouette = fill | extra | outline
        moved = np.zeros_like(silhouette)
        moved[1:, 1:] = silhouette[:-1, :-1]
        paint(shadow, moved, (255, 255, 255))
        out[name + "Shadow"] = shadow
    for name, make in SMALL_SHAPES.items():
        fill, rod = make()
        extra = rod if rod is not None else np.zeros_like(fill)
        inner = erode(fill)
        chat = rgba(16, 16)
        paint(chat, dilate(fill | extra) & ~(fill | extra), (0, 0, 0))
        paint(chat, (fill & ~inner) | extra, (255, 255, 255))
        paint(chat, inner, (150, 150, 150))
        out["Chat" + name] = chat
    return {"Pixel/Crest/" + key: up(img) for key, img in out.items()}


# --- symbols, letters and icons: drawn by hand ---------------------------------------------------

CHARGES = {
    "Heart": [".##...##.", "####.####", "#########", "#########", ".#######.", "..#####..", "...###...", "....#...."],
    "Star": [".....#.....", "....###....", "....###....", "###########", ".#########.", "..#######..", "..#######..",
             ".####.####.", ".###...###.", ".#.......#."],
    "Crown": ["#....#....#", "##..###..##", "###.###.###", "###########", "###########", ".#########.",
              ".#########."],
    "Sword": ["...#...", "..###..", "..###..", "..###..", "..###..", "..###..", "..###..", "#######", "#######",
              "...#...", "...#...", "..###.."],
    "Key": ["..####..", ".##..##.", ".##..##.", "..####..", "...##...", "...##...", "...####.", "...##...",
            "...####.", "...##..."],
    "Moon": ["...#####..", "..####....", ".####.....", "####......", "####......", "####......", "####......",
             ".####.....", "..####....", "...#####.."],
    "Sun": ["....#....", ".#..#..#.", "..#####..", ".#######.", "#########", ".#######.", "..#####..", ".#..#..#.",
            "....#...."],
    "Tree": ["..##.##.##..", ".##########.", "############", "############", ".##########.", "..###..###..",
             ".....##.....", ".....##.....", "....####....", "...##..##..."],
    "Mushroom": ["...#####...", ".#########.", "##.#####.##", "###########", "###########", ".#########.",
                 "....###....", "....###....", "...#####..."],
    "Skull": ["..#####..", ".#######.", "#########", "##kk#kk##", "##kk#kk##", "#########", ".###k###.", "..#####..",
              "..#.#.#.."],
    "Axe": ["##..#..##", "###.#.###", "#########", "###.#.###", "##..#..##", "....#....", "....#....", "....#....",
            "....#....", "....#...."],
    "Tower": ["#.#.#.#", "#######", "#######", ".#####.", ".##k##.", ".##k##.", ".#####.", ".#####.", ".#kkk#.",
              ".#kkk#.", "#######"],
    "Flower": ["....##....", "...####...", ".##.##.##.", "##########", ".###kk###.", ".###kk###.", "##########",
               ".##.##.##.", "...####...", "....##...."],
    "Flame": [".....#....", "....##....", "....###...", "...####...", "..######..", "..###.##..", ".###..###.",
              ".##....##.", ".##....##.", "..######.."],
    "Bolt": ["....####", "...####.", "..####..", ".####...", "########", "...####.", "..####..", ".####...",
             "####....", "###....."],
    "Anchor": ["...###...", "...#.#...", "...###...", "....#....", ".#######.", "....#....", "#...#...#", "##..#..##",
               ".#######.", "..#####.."],
    "Cup": ["#########", "#########", ".#######.", ".#######.", "..#####..", "...###...", "....#....", "....#....",
            "..#####..", ".#######."],
    "Bell": ["....#....", "..#####..", ".#######.", ".#######.", ".#######.", ".#######.", "#########", "#########",
             "....#...."],
}

LETTERS = {
    "A": ["..####..", ".######.", "##....##", "##....##", "##....##", "########", "########", "##....##", "##....##",
          "##....##"],
    "B": ["######..", "#######.", "##....##", "##....##", "#######.", "#######.", "##....##", "##....##", "#######.",
          "######.."],
    "C": ["..#####.", ".#######", "##......", "##......", "##......", "##......", "##......", "##......", ".#######",
          "..#####."],
    "D": ["######..", "#######.", "##...###", "##....##", "##....##", "##....##", "##....##", "##...###", "#######.",
          "######.."],
    "E": ["########", "########", "##......", "##......", "######..", "######..", "##......", "##......", "########",
          "########"],
    "F": ["########", "########", "##......", "##......", "######..", "######..", "##......", "##......", "##......",
          "##......"],
    "G": ["..#####.", ".#######", "##......", "##......", "##..####", "##..####", "##....##", "##....##", ".#######",
          "..#####."],
    "H": ["##....##", "##....##", "##....##", "##....##", "########", "########", "##....##", "##....##", "##....##",
          "##....##"],
    "I": ["######", "######", "..##..", "..##..", "..##..", "..##..", "..##..", "..##..", "######", "######"],
    "J": ["....####", "....####", "......##", "......##", "......##", "......##", "##....##", "##....##", ".######.",
          "..####.."],
    "K": ["##....##", "##...###", "##..###.", "##.###..", "#####...", "#####...", "##.###..", "##..###.", "##...###",
          "##....##"],
    "L": ["##......", "##......", "##......", "##......", "##......", "##......", "##......", "##......", "########",
          "########"],
    "M": ["##......##", "###....###", "####..####", "##.####.##", "##..##..##", "##......##", "##......##",
          "##......##", "##......##", "##......##"],
    "N": ["##....##", "###...##", "####..##", "##.#..##", "##.##.##", "##..#.##", "##..####", "##...###", "##....##",
          "##....##"],
    "O": ["..####..", ".######.", "##....##", "##....##", "##....##", "##....##", "##....##", "##....##", ".######.",
          "..####.."],
    "P": ["######..", "#######.", "##....##", "##....##", "#######.", "######..", "##......", "##......", "##......",
          "##......"],
    "Q": ["..####..", ".######.", "##....##", "##....##", "##....##", "##....##", "##..#.##", "##...##.", ".#######",
          "..###.##"],
    "R": ["######..", "#######.", "##....##", "##....##", "#######.", "######..", "##.###..", "##..###.", "##...###",
          "##....##"],
    "S": [".######.", "########", "##......", "##......", "#######.", ".#######", "......##", "......##", "########",
          ".######."],
    "T": ["########", "########", "...##...", "...##...", "...##...", "...##...", "...##...", "...##...", "...##...",
          "...##..."],
    "U": ["##....##", "##....##", "##....##", "##....##", "##....##", "##....##", "##....##", "##....##", ".######.",
          "..####.."],
    "V": ["##....##", "##....##", "##....##", "##....##", "##....##", ".##..##.", ".##..##.", "..####..", "..####..",
          "...##..."],
    "W": ["##......##", "##......##", "##......##", "##......##", "##..##..##", "##..##..##", "##.####.##",
          "####..####", "###....###", "##......##"],
    "X": ["##....##", "##....##", ".##..##.", "..####..", "...##...", "...##...", "..####..", ".##..##.", "##....##",
          "##....##"],
    "Y": ["##....##", "##....##", ".##..##.", "..####..", "...##...", "...##...", "...##...", "...##...", "...##...",
          "...##..."],
    "Z": ["########", "########", ".....##.", "....##..", "...##...", "..##....", ".##.....", "##......", "########",
          "########"],
}

ICONS = {
    "Close": ["##....##", "###..###", ".######.", "..####..", "..####..", ".######.", "###..###", "##....##"],
    "Search": [".####....", "##..##...", "#....#...", "#....#...", "##..##...", ".#####...", ".....##..", "......##.",
               ".......##"],
    "ChevronDown": ["##....##", "###..###", ".######.", "..####..", "...##..."],
    "ChevronRight": ["##...", "###..", ".###.", "..###", "..###", ".###.", "###..", "##..."],
    "ChevronLeft": ["...##", "..###", ".###.", "###..", "###..", ".###.", "..###", "...##"],
    "Check": [".........##", "........###", "##.....###.", "###...###..", ".###.###...", "..#####....",
              "...###....."],
    "Gear": ["....###....", ".##.###.##.", ".#########.", "..##...##..", "###.....###", "###.....###", "###.....###",
             "..##...##..", ".#########.", ".##.###.##.", "....###...."],
    "Sound": ["....#.......", "...##...#...", "#####....#..", "#####..#.#..", "#####..#.#..", "#####....#..",
              "...##...#...", "....#......."],
    "Whisper": [".##########.", "############", "##kk#kk#kk##", "############", ".##########.", "...###......",
                "...##.......", "...#........"],
    "Invite": ["..###......", ".#####.....", ".#####..#..", "..###..###.", ".#####..#..", "#######....",
               "#######...."],
    "Star": CHARGES["Star"],
    "Crown": CHARGES["Crown"],
    "Sheep": ["...##.##......", ".#########....", "############kk", "###########kkk", "###########kwk",
              ".##########kk.", "..########....", "..k.k..k.k....", "..k.k..k.k...."],
    "Dice": [".########.", "##########", "#kk####kk#", "#kk####kk#", "####kk####", "####kk####", "#kk####kk#",
             "#kk####kk#", "##########", ".########."],
    "Play": ["##....", "####..", "######", "######", "####..", "##...."],
    "Portal": ["...####...", "..##..##..", ".##....##.", ".##....##.", ".##....##.", ".##....##.", "..##..##..",
               "...####..."],
}


def pixel_glyphs():
    out = {}
    for key, rows in CHARGES.items():
        out["Pixel/Charge/" + key] = up(two_tone(centered(grid(rows), 16)))
    for key, rows in LETTERS.items():
        out["Pixel/Letter/" + key] = up(two_tone(centered(grid(rows), 16)))
    for key, rows in ICONS.items():
        out["Pixel/UI/Icon" + key] = up(two_tone(centered(grid(rows), 16)))
    return out


def smooth_glyph(rows, size=64):
    """A hand-drawn glyph rounded off: blown up, blurred and cut again, with a soft dark rim."""
    chars = centered(grid(rows), 16)
    body = (chars == "#") | (chars == "w")
    black = chars == "k"
    scale = size * SS // 16

    def soft(mask, grow):
        big = Image.fromarray((np.repeat(np.repeat(mask, scale, 0), scale, 1) * 255).astype(np.uint8))
        big = big.filter(ImageFilter.GaussianBlur(scale * 0.42))
        return big.point(lambda v: 255 if v > 128 - grow else 0)

    shape = soft(body | black, 0)
    rim = soft(body | black, 92)
    inside = soft(black, 0)
    white = np.asarray(shape, np.uint8)
    dark = np.maximum(np.clip(np.asarray(rim, np.int16) - white, 0, 255), np.asarray(inside, np.int16)).astype(np.uint8)
    w = Image.fromarray(np.where(np.asarray(inside) > 0, 0, white).astype(np.uint8))
    alpha = Image.fromarray(np.maximum(white, dark).astype(np.uint8))
    img = Image.merge("RGBA", (w, w, w, alpha))
    return img.resize((size, size), Image.LANCZOS)


# --- the smooth theme (the first design) ---------------------------------------------------------

def canvas(size):
    return Image.new("L", (size * SS, size * SS) if isinstance(size, int) else (size[0] * SS, size[1] * SS), 0)


def shrink(mask, size):
    size = (size, size) if isinstance(size, int) else size
    return mask.resize(size, Image.LANCZOS)


def white_tex(mask):
    w = Image.new("L", mask.size, 255)
    return Image.merge("RGBA", (w, w, w, mask))


def soft_erode(mask, px):
    a = np.asarray(mask, np.uint8)
    for i in range(px):
        p = np.pad(a, 1)
        near = [p[1:-1, 1:-1], p[:-2, 1:-1], p[2:, 1:-1], p[1:-1, :-2], p[1:-1, 2:]]
        if i % 2:
            near += [p[:-2, :-2], p[:-2, 2:], p[2:, :-2], p[2:, 2:]]
        a = np.minimum.reduce(near)
    return Image.fromarray(a)


def subtract(a, b):
    return Image.fromarray(np.clip(np.asarray(a, np.int16) - np.asarray(b, np.int16), 0, 255).astype(np.uint8))


def multiply(a, b):
    return Image.fromarray((np.asarray(a, np.uint16) * np.asarray(b, np.uint16) // 255).astype(np.uint8))


def cubic(p0, p1, p2, p3, n=64):
    pts = []
    for i in range(1, n + 1):
        t = i / n
        m = 1 - t
        pts.append((m ** 3 * p0[0] + 3 * m * m * t * p1[0] + 3 * m * t * t * p2[0] + t ** 3 * p3[0],
                    m ** 3 * p0[1] + 3 * m * m * t * p1[1] + 3 * m * t * t * p2[1] + t ** 3 * p3[1]))
    return pts


def arc(cx, cy, r, a0, a1, n=24):
    return [(cx + r * math.cos(math.radians(a0 + (a1 - a0) * i / n)),
             cy + r * math.sin(math.radians(a0 + (a1 - a0) * i / n))) for i in range(n + 1)]


def polygon(points, size):
    mask = canvas(size)
    scale = size * SS
    ImageDraw.Draw(mask).polygon([(x * scale, y * scale) for x, y in points], fill=255)
    return mask


def s_heater():
    r = 0.035
    pts = arc(0.16 + r, 0.10 + r, r, 180, 270) + arc(0.84 - r, 0.10 + r, r, 270, 360) + [(0.84, 0.50)]
    pts += cubic((0.84, 0.50), (0.84, 0.75), (0.66, 0.85), (0.50, 0.93))
    pts += cubic((0.50, 0.93), (0.34, 0.85), (0.16, 0.75), (0.16, 0.50))
    return pts


def s_round():
    return arc(0.5, 0.51, 0.385, 0, 360, 120)


def s_kite():
    pts = [(0.21, 0.33)]
    pts += cubic((0.21, 0.33), (0.21, 0.17), (0.34, 0.08), (0.50, 0.08))
    pts += cubic((0.50, 0.08), (0.66, 0.08), (0.79, 0.17), (0.79, 0.33))
    pts += cubic((0.79, 0.33), (0.79, 0.58), (0.62, 0.80), (0.50, 0.95))
    pts += cubic((0.50, 0.95), (0.38, 0.80), (0.21, 0.58), (0.21, 0.33))
    return pts


def s_banner():
    r = 0.03
    pts = arc(0.19 + r, 0.13 + r, r, 180, 270) + arc(0.81 - r, 0.13 + r, r, 270, 360)
    return pts + [(0.81, 0.92), (0.50, 0.77), (0.19, 0.92)]


SMOOTH_SHAPES = {
    "Heater": (s_heater, (0.50, 0.44), (0.16, 0.10, 0.84, 0.93)),
    "Round": (s_round, (0.50, 0.51), (0.115, 0.125, 0.885, 0.895)),
    "Kite": (s_kite, (0.50, 0.40), (0.21, 0.08, 0.79, 0.95)),
    "Banner": (s_banner, (0.50, 0.44), (0.19, 0.13, 0.81, 0.92)),
}


def s_division(name, size, center, box):
    n = size * SS
    ys, xs = np.mgrid[0:n, 0:n] / n
    cx, cy = center
    x0, y0, x1, y1 = box
    w, h = x1 - x0, y1 - y0
    if name == "Pale":
        area = xs > cx
    elif name == "Fess":
        area = ys > cy
    elif name == "Bend":
        area = (ys - y0) / h > (xs - x0) / w
    elif name == "Quarterly":
        area = (xs > cx) ^ (ys > cy)
    elif name == "Chevron":
        line = y0 + 0.34 * h + np.abs(xs - cx) * (0.46 * h) / (0.5 * w)
        area = (ys > line) & (ys < line + 0.2 * h)
    else:
        area = (np.abs(xs - cx) < 0.095 * w) | (np.abs(ys - cy) < 0.095 * w)
    return Image.fromarray((area * 255).astype(np.uint8))


def smooth_crests(size=128):
    out = {}
    for name, (outline_fn, center, box) in SMOOTH_SHAPES.items():
        fill = polygon(outline_fn(), size)
        rim_px = int(size * SS * 0.042)
        inner = soft_erode(fill, rim_px)
        rim = subtract(fill, inner)
        line_out = soft_erode(fill, rim_px + int(size * SS * 0.022))
        line_in = soft_erode(line_out, max(1, int(size * SS * 0.010)))
        rim = Image.fromarray(np.maximum(np.asarray(rim), np.asarray(subtract(line_out, line_in).point(
            lambda v: int(v * 0.6)))))
        if name == "Banner":
            rod = canvas(size)
            d = ImageDraw.Draw(rod)
            s = size * SS
            d.rounded_rectangle((0.11 * s, 0.085 * s, 0.89 * s, 0.125 * s), radius=0.02 * s, fill=255)
            d.ellipse((0.07 * s, 0.075 * s, 0.13 * s, 0.135 * s), fill=255)
            d.ellipse((0.87 * s, 0.075 * s, 0.93 * s, 0.135 * s), fill=255)
            rim = Image.fromarray(np.maximum(np.asarray(rim), np.asarray(rod)))
            fill = Image.fromarray(np.maximum(np.asarray(fill), np.asarray(rod)))
        n = size * SS
        ys, xs = np.mgrid[0:n, 0:n] / n
        x0, y0, x1, y1 = box
        t = ((xs - x0) / (x1 - x0) + (ys - y0) / (y1 - y0)) / 2
        shine = multiply(Image.fromarray((np.clip(1 - t * 1.9, 0, 1) ** 1.6 * 0.42 * 255).astype(np.uint8)), inner)
        shadow = fill.filter(ImageFilter.GaussianBlur(size * SS * 0.035))
        shadow = shadow.transform(shadow.size, Image.AFFINE, (1, 0, 0, 0, 1, -size * SS * 0.03))
        layers = {"Fill": fill, "Rim": rim, "Shine": shine, "Shadow": shadow}
        for div in DIVISIONS:
            layers[div] = multiply(s_division(div, size, center, box), fill)
        for key, mask in layers.items():
            out["Smooth/Crest/" + name + key] = white_tex(shrink(mask, size))
        chat = polygon(outline_fn(), 64)
        body = soft_erode(chat, int(64 * SS * 0.085)).point(lambda v: int(v * 0.62))
        gray = Image.fromarray(np.maximum(np.asarray(subtract(chat, soft_erode(chat, int(64 * SS * 0.085)))),
                                          np.asarray(body)))
        out["Smooth/Crest/Chat" + name] = shrink(Image.merge("RGBA", (gray, gray, gray, chat)), 64)
    return out


def rounded(size, radius, stroke=None):
    mask = canvas(size)
    s = size * SS
    box = (0, 0, s - 1, s - 1)
    d = ImageDraw.Draw(mask)
    if stroke:
        d.rounded_rectangle(box, radius=radius * SS, outline=255, width=int(stroke * SS))
    else:
        d.rounded_rectangle(box, radius=radius * SS, fill=255)
    return mask


def smooth_ui():
    out = {}
    out["Round"] = shrink(rounded(64, 16), 64)
    out["RoundLine"] = shrink(rounded(64, 16, stroke=2), 64)
    shadow = canvas(64)
    ImageDraw.Draw(shadow).rounded_rectangle((16 * SS, 16 * SS, 48 * SS, 48 * SS), radius=8 * SS, fill=255)
    out["Shadow"] = shrink(shadow.filter(ImageFilter.GaussianBlur(7 * SS)), 64)
    c = canvas(64)
    ImageDraw.Draw(c).ellipse((1 * SS, 1 * SS, 63 * SS, 63 * SS), fill=255)
    out["Circle"] = shrink(c, 64)
    c = canvas(64)
    ImageDraw.Draw(c).ellipse((2 * SS, 2 * SS, 62 * SS, 62 * SS), outline=255, width=3 * SS)
    out["CircleLine"] = shrink(c, 64)
    out["Badge"] = out["Circle"]
    tex = {"Smooth/UI/" + k: white_tex(v) for k, v in out.items()}
    for key, rows in ICONS.items():
        tex["Smooth/UI/Icon" + key] = smooth_glyph(rows, 64)
    for key, rows in CHARGES.items():
        tex["Smooth/Charge/" + key] = smooth_glyph(rows, 64)
    return tex


# --- the Forever theme (WoW Forever's own look: the classic game's windows) ---------------------

BRONZE_HI = (240, 206, 128)
BRONZE = (184, 136, 62)
BRONZE_LO = (100, 68, 30)
BRONZE_DARK = (34, 24, 14)
STONE = (30, 26, 22)
STONE_LO = (17, 15, 13)
RED_HI = (200, 40, 26)
RED_LO = (92, 10, 6)
GOLD_TEXT = (255, 209, 0)


def f_canvas(size=64):
    return Image.new("RGBA", (size * SS, size * SS), (0, 0, 0, 0))


def f_shrink(img, size=64):
    return img.resize((size, size), Image.LANCZOS)


def f_gradient(size, top, bottom):
    """A picture of `size` (in art pixels) going from `top` to `bottom`, down."""
    n = size * SS
    t = np.linspace(0, 1, n)[:, None, None]
    rows = np.array(top, float) * (1 - t) + np.array(bottom, float) * t
    img = np.broadcast_to(rows, (n, n, 3)).astype(np.uint8)
    return Image.fromarray(np.dstack([img, np.full((n, n), 255, np.uint8)]), "RGBA")


def f_shape(size, box, radius, ellipse=False):
    """A mask (L) of a rounded box (or an ellipse) in art pixels."""
    mask = Image.new("L", (size * SS, size * SS), 0)
    draw = ImageDraw.Draw(mask)
    b = tuple(v * SS for v in box)
    if ellipse:
        draw.ellipse(b, fill=255)
    else:
        draw.rounded_rectangle(b, radius=radius * SS, fill=255)
    return mask


def f_layer(img, mask, fill):
    """Paints `fill` (a color, or a picture of the same size) on `img` through `mask`."""
    if isinstance(fill, tuple):
        fill = Image.new("RGBA", img.size, fill + (255,))
    img.paste(fill, (0, 0), mask)


def f_framed(band, groove, body, radius=6, studs=False, metal=(BRONZE_HI, BRONZE_LO), size=64):
    """A window, card or button: a dark outline, a beveled metal band (light above, dark below), a
    dark groove, and the body (a color, or a (top, bottom) gradient); rivets in the corners."""
    img = f_canvas(size)
    f_layer(img, f_shape(size, (0, 0, size, size), radius), BRONZE_DARK)
    f_layer(img, f_shape(size, (1, 1, size - 1, size - 1), radius - 1), f_gradient(size, *metal))
    f_layer(img, f_shape(size, (band, band, size - band, size - band), max(1, radius - band)), BRONZE_DARK)
    fill = f_gradient(size, *body) if isinstance(body[0], tuple) else body
    inset = band + groove
    f_layer(img, f_shape(size, (inset, inset, size - inset, size - inset), max(1, radius - inset)), fill)
    if studs:
        for cx, cy in ((4, 4), (size - 4, 4), (4, size - 4), (size - 4, size - 4)):
            f_layer(img, f_shape(size, (cx - 3, cy - 3, cx + 3, cy + 3), 0, ellipse=True), BRONZE_DARK)
            f_layer(img, f_shape(size, (cx - 2, cy - 2, cx + 2, cy + 2), 0, ellipse=True),
                    f_gradient(size, BRONZE_HI, BRONZE))
    return f_shrink(img, size)


def forever_ui(tex):
    out = {}
    out["Panel"] = f_framed(7, 1, (STONE, STONE_LO), radius=7, studs=True)
    out["Card"] = f_framed(4, 1, ((40, 34, 28), (26, 22, 19)), radius=5,
                           metal=((196, 160, 96), (92, 64, 30)))
    out["Tile"] = f_framed(3, 1, ((36, 31, 26), (26, 22, 19)), radius=5,
                           metal=((120, 96, 60), (60, 44, 24)))
    out["Frame"] = f_framed(6, 1, (STONE_LO, STONE_LO), radius=6)
    # an inset: dark, a shade along its top, a little light along its bottom
    well = f_canvas()
    f_layer(well, f_shape(64, (0, 0, 64, 64), 5), (54, 46, 36))
    f_layer(well, f_shape(64, (0, 0, 64, 62), 5), (6, 5, 4))
    f_layer(well, f_shape(64, (2, 3, 62, 62), 4), ((14, 12, 10)))
    out["Well"] = f_shrink(well)
    # the classic red buttons with a gold band, and dark ones; pressed, they turn their light down
    red, dark, off = (RED_HI, RED_LO), ((60, 51, 42), (30, 26, 22)), ((96, 92, 86), (54, 52, 49))
    for name, body, metal in (("Button", red, None), ("ButtonHover", ((236, 70, 46), (120, 16, 10)), None),
                              ("ButtonDown", ((110, 14, 8), (176, 34, 22)), None),
                              ("ButtonOff", off, ((150, 144, 132), (80, 76, 70))),
                              ("Dark", dark, None), ("DarkHover", ((84, 72, 58), (42, 36, 30)), None),
                              ("DarkDown", ((26, 22, 19), (52, 44, 36)), None),
                              ("DarkOff", ((52, 50, 47), (36, 35, 33)), ((96, 92, 86), (56, 54, 50)))):
        out[name] = f_framed(5, 0, body, radius=10, metal=metal or (BRONZE_HI, BRONZE_LO))
    # a check box: a bronze-rimmed well, with a gold check when it's on
    out["CheckOff"] = f_framed(6, 1, ((10, 9, 8), (22, 19, 16)), radius=6)
    on = f_canvas()
    on.alpha_composite(out["CheckOff"].resize(on.size, Image.LANCZOS))
    draw = ImageDraw.Draw(on)
    tick = [(18 * SS, 33 * SS), (28 * SS, 44 * SS), (47 * SS, 20 * SS)]
    draw.line(tick, fill=BRONZE_DARK + (255,), width=11 * SS, joint="curve")
    draw.line(tick, fill=GOLD_TEXT + (255,), width=6 * SS, joint="curve")
    out["CheckOn"] = f_shrink(on)
    # an arrow to flip through choices: a round bronze button, a gold chevron pointing left
    for name, inner, chevron in (("Arrow", STONE, (232, 190, 64)), ("ArrowHover", (58, 48, 38), GOLD_TEXT)):
        img = f_canvas()
        f_layer(img, f_shape(64, (2, 2, 62, 62), 0, ellipse=True), BRONZE_DARK)
        f_layer(img, f_shape(64, (3, 3, 61, 61), 0, ellipse=True), f_gradient(64, BRONZE_HI, BRONZE_LO))
        f_layer(img, f_shape(64, (9, 9, 55, 55), 0, ellipse=True), BRONZE_DARK)
        f_layer(img, f_shape(64, (10, 10, 54, 54), 0, ellipse=True), f_gradient(64, inner, STONE_LO))
        draw = ImageDraw.Draw(img)
        points = [(37 * SS, 20 * SS), (25 * SS, 32 * SS), (37 * SS, 44 * SS)]
        draw.line(points, fill=BRONZE_DARK + (255,), width=10 * SS, joint="curve")
        draw.line(points, fill=chevron + (255,), width=6 * SS, joint="curve")
        out[name] = f_shrink(img)
    # tinted: a color chip and the ring around the chosen one, a gem of a dot, a round badge, the
    # class ring around a portrait (lighter above), and a circle to cut portraits round
    chip = f_canvas()
    f_layer(chip, f_shape(64, (8, 8, 56, 56), 6), (0, 0, 0))
    f_layer(chip, f_shape(64, (11, 11, 53, 53), 4), f_gradient(64, (255, 255, 255), (200, 200, 200)))
    out["Swatch"] = f_shrink(chip)
    pick_mask = ImageChops.subtract(f_shape(64, (1, 1, 63, 63), 9), f_shape(64, (6, 6, 58, 58), 6))
    pick = f_canvas()
    f_layer(pick, pick_mask, (255, 255, 255))
    out["SwatchPick"] = f_shrink(pick)
    gem = f_canvas()
    f_layer(gem, f_shape(64, (4, 4, 60, 60), 0, ellipse=True), (70, 70, 70))
    f_layer(gem, f_shape(64, (8, 8, 56, 56), 0, ellipse=True), f_gradient(64, (255, 255, 255), (150, 150, 150)))
    f_layer(gem, f_shape(64, (18, 14, 34, 28), 0, ellipse=True), (255, 255, 255))
    out["Dot"] = f_shrink(gem)
    circle = f_canvas()
    f_layer(circle, f_shape(64, (1, 1, 63, 63), 0, ellipse=True), (255, 255, 255))
    out["Circle"] = f_shrink(circle)
    out["Badge"] = out["Circle"]
    ring_mask = ImageChops.subtract(f_shape(64, (1, 1, 63, 63), 0, ellipse=True),
                                    f_shape(64, (7, 7, 57, 57), 0, ellipse=True))
    ring = f_canvas()
    f_layer(ring, ring_mask, f_gradient(64, (255, 255, 255), (150, 150, 150)))
    out["Ring"] = f_shrink(ring)
    # the minimap button: the game's round bronze rim around a dark disc
    plate = f_canvas()
    f_layer(plate, f_shape(64, (0, 0, 64, 64), 0, ellipse=True), BRONZE_DARK)
    f_layer(plate, f_shape(64, (2, 2, 62, 62), 0, ellipse=True), f_gradient(64, BRONZE_HI, BRONZE_LO))
    f_layer(plate, f_shape(64, (8, 8, 56, 56), 0, ellipse=True), BRONZE_DARK)
    f_layer(plate, f_shape(64, (9, 9, 55, 55), 0, ellipse=True), f_gradient(64, (44, 38, 32), STONE_LO))
    out["Plate"] = f_shrink(plate)
    result = {"Forever/UI/" + key: image for key, image in out.items()}
    # the soft shadow, the icons, the crests and their symbols: Smooth's
    for key, image in tex.items():
        for part in ("UI/Shadow", "UI/Icon", "Crest/", "Charge/"):
            if key.startswith("Smooth/" + part):
                result["Forever/" + key[len("Smooth/"):]] = image
    return result


def shared_ui():
    out = {}
    n = 128 * SS
    ys, xs = np.mgrid[0:n, 0:n] / n
    r = np.sqrt((xs - 0.5) ** 2 + (ys - 0.5) ** 2) * 2
    out["UI/Glow"] = shrink(Image.fromarray((np.clip(1 - r, 0, 1) ** 2.2 * 255).astype(np.uint8)), 128)
    ys, xs = np.mgrid[0:64 * SS, 0:128 * SS]
    xs, ys = xs / (128 * SS), ys / (64 * SS)
    band = np.exp(-(((xs - 0.5) + (ys - 0.5) * 0.35) / 0.11) ** 2)
    out["UI/Sheen"] = shrink(Image.fromarray((band * 255).astype(np.uint8)), (128, 64))
    return {k: white_tex(v) for k, v in out.items()}


def addon_icon():
    """The addon's icon (the addon list, the addon menu): a red shield, a gold rim, a gold heart."""
    fill, _ = PIXEL_SHAPES["Heater"][0]()
    inner = erode(fill, 2)
    img = rgba(32, 32)
    paint(img, dilate(fill) & ~fill, INK)
    paint(img, fill, (240, 195, 90))
    paint(img, inner, (194, 59, 48))
    heart = centered(grid(CHARGES["Heart"]), 16) == "#"
    big = np.zeros((32, 32), bool)
    big[5:21, 8:24] = heart
    paint(img, dilate(big) & ~big & inner, (110, 30, 24))
    paint(img, big, (240, 195, 90))
    return {"Icon": up(img, 2)}


# --- sounds --------------------------------------------------------------------------------------

RATE = 44100


def bell(freq, length, partials):
    t = np.arange(int(RATE * length)) / RATE
    tone = np.zeros_like(t)
    for ratio, amp, decay in partials:
        tone += amp * np.sin(2 * np.pi * freq * ratio * t) * np.exp(-t * decay)
    return tone * np.clip(t / 0.004, 0, 1)


def write_ogg(samples, rel):
    pcm = (samples / np.max(np.abs(samples)) * 0.7 * 32767).astype(np.int16)
    path = os.path.join(MEDIA, rel.replace("/", os.sep) + ".ogg")
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with tempfile.TemporaryDirectory() as tmp:
        wav_path = os.path.join(tmp, "sound.wav")
        with wave.open(wav_path, "wb") as f:
            f.setnchannels(1)
            f.setsampwidth(2)
            f.setframerate(RATE)
            f.writeframes(pcm.tobytes())
        subprocess.run(["ffmpeg", "-y", "-loglevel", "error", "-i", wav_path, "-c:a", "libvorbis", "-q:a", "5", path],
                       check=True)


def sounds():
    soft = [(1, 1.0, 3.2), (2.0, 0.35, 5.0), (3.01, 0.12, 8.0), (4.2, 0.05, 11.0)]
    total = np.zeros(int(RATE * 1.5))
    # two warm notes, a rising third: "hey, cousin"
    for start, freq in ((0.0, 880.0), (0.13, 1108.73)):
        note = bell(freq, 1.5 - start, soft)
        i = int(RATE * start)
        total[i:i + len(note)] += note[:len(total) - i]
    write_ogg(total, "Sounds/Chime")
    write_ogg(bell(523.25, 2.2, [(1, 1.0, 1.6), (2.76, 0.4, 3.0), (5.4, 0.18, 6.0), (0.5, 0.25, 1.2)]), "Sounds/Bell")
    # a cartoon "boop": a short blip that bends up, for the Pixel theme
    t = np.arange(int(RATE * 0.32)) / RATE
    freq = 520 + 380 * np.clip(t / 0.08, 0, 1)
    blip = np.sign(np.sin(2 * np.pi * np.cumsum(freq) / RATE)) * 0.35 + np.sin(2 * np.pi * np.cumsum(freq) / RATE)
    write_ogg(blip * np.exp(-t * 9) * np.clip(t / 0.003, 0, 1), "Sounds/Boop")


# --- previews ------------------------------------------------------------------------------------

def tint(texture, rgb, alpha=1.0):
    r, g, b, a = texture.split()
    r = r.point(lambda v: v * rgb[0] // 255)
    g = g.point(lambda v: v * rgb[1] // 255)
    b = b.point(lambda v: v * rgb[2] // 255)
    if alpha != 1.0:
        a = a.point(lambda v: int(v * alpha))
    return Image.merge("RGBA", (r, g, b, a))


def nine(texture, w, h, corner, resample=Image.NEAREST):
    """A 9-slice drawn at w x h (corners `corner` px), as the game would: a quarter of the
    texture is each corner."""
    out = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    t = texture
    T = t.size[0]
    cut = T // 4
    xs = [(0, cut, 0, corner), (cut, T - cut, corner, w - corner), (T - cut, T, w - corner, w)]
    ys = [(0, cut, 0, corner), (cut, T - cut, corner, h - corner), (T - cut, T, h - corner, h)]
    for sx0, sx1, dx0, dx1 in xs:
        for sy0, sy1, dy0, dy1 in ys:
            if dx1 > dx0 and dy1 > dy0:
                piece = t.crop((sx0, sy0, sx1, sy1)).resize((dx1 - dx0, dy1 - dy0), resample)
                out.alpha_composite(piece, (dx0, dy0))
    return out


def three(texture, w, h, cut):
    """A 3-slice (the ribbon) drawn at w x h: the ends keep their shape, the middle stretches."""
    T, H = texture.size
    end = h * cut // H
    out = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    out.alpha_composite(texture.crop((0, 0, cut, H)).resize((end, h), Image.NEAREST), (0, 0))
    out.alpha_composite(texture.crop((cut, 0, T - cut, H)).resize((w - 2 * end, h), Image.NEAREST), (end, 0))
    out.alpha_composite(texture.crop((T - cut, 0, T, H)).resize((end, h), Image.NEAREST), (w - end, 0))
    return out


def preview_pixel(tex, path):
    bg = (30, 22, 23)
    sheet = Image.new("RGBA", (1000, 700), bg + (255,))
    sheet.alpha_composite(tint(nine(tex["Pixel/UI/Shadow"], 470, 330, 8), INK, 0.6), (24, 24))
    sheet.alpha_composite(nine(tex["Pixel/UI/Panel"], 470, 330, 8), (20, 20))
    combos = [("Heater", None, (194, 59, 48), (240, 195, 90), "Heart"),
              ("Heater", "Quarterly", (51, 99, 184), (216, 222, 227), "Crown"),
              ("Round", "Pale", (78, 154, 63), (240, 195, 90), "Tree"),
              ("Kite", "Bend", (125, 76, 168), (240, 195, 90), "Star"),
              ("Banner", "Chevron", (42, 34, 36), (194, 59, 48), "Moon")]
    x = 40
    for shape, div, field, second, charge in combos:
        size = 96
        layers = Image.new("RGBA", (size, size), (0, 0, 0, 0))

        def L(key):
            return tex["Pixel/Crest/" + shape + key].resize((size, size), Image.NEAREST)

        layers.alpha_composite(tint(L("Shadow"), INK, 0.55))
        layers.alpha_composite(tint(L("Fill"), field))
        if div:
            layers.alpha_composite(tint(L(div), second))
        layers.alpha_composite(L("Shine"))
        layers.alpha_composite(tint(L("Frame"), (240, 195, 90)))
        cy = PIXEL_SHAPES[shape][1][1]
        ch = tex["Pixel/Charge/" + charge].resize((size // 2, size // 2), Image.NEAREST)
        layers.alpha_composite(tint(ch, (240, 195, 90)), (size // 4, int((cy - 8) * size / 32)))
        sheet.alpha_composite(layers, (x, 40))
        x += 86
    # buttons and bits
    for i, key in enumerate(["Button", "ButtonHover", "ButtonDown", "Dark", "DarkHover", "ButtonOff"]):
        sheet.alpha_composite(nine(tex["Pixel/UI/" + key], 130, 34, 8), (40 + (i % 3) * 140, 160 + (i // 3) * 44))
    sheet.alpha_composite(nine(tex["Pixel/UI/Well"], 200, 34, 8), (40, 260))
    sheet.alpha_composite(nine(tex["Pixel/UI/Card"], 200, 60, 8), (260, 250))
    for i, key in enumerate(["CheckOff", "CheckOn", "Badge", "Plate"]):
        sheet.alpha_composite(tex["Pixel/UI/" + key].resize((32, 32), Image.NEAREST), (40 + i * 44, 320))
    arrow = tex["Pixel/UI/Arrow"].resize((48, 48), Image.NEAREST)
    sheet.alpha_composite(arrow, (230, 312))
    sheet.alpha_composite(arrow.transpose(Image.FLIP_LEFT_RIGHT), (284, 312))
    sheet.alpha_composite(three(tex["Pixel/UI/Ribbon"], 220, 32, tex["Pixel/UI/Ribbon"].size[0] // 4), (40, 400))
    for i, key in enumerate(sorted(k for k in tex if k.startswith("Pixel/UI/Icon"))):
        icon = tex[key].resize((32, 32), Image.NEAREST)
        sheet.alpha_composite(tint(icon, CREAM), (520 + (i % 8) * 56, 40 + (i // 8) * 48))
    for i, key in enumerate(sorted(k for k in tex if k.startswith("Pixel/Charge/"))):
        icon = tex[key].resize((32, 32), Image.NEAREST)
        sheet.alpha_composite(tint(icon, (240, 195, 90)), (520 + (i % 8) * 56, 160 + (i // 8) * 48))
    for i, key in enumerate(sorted(k for k in tex if k.startswith("Pixel/Letter/"))):
        icon = tex[key].resize((24, 24), Image.NEAREST)
        sheet.alpha_composite(tint(icon, CREAM), (520 + (i % 13) * 34, 330 + (i // 13) * 34))
    for i, shape in enumerate(PIXEL_SHAPES):
        chat = tex["Pixel/Crest/Chat" + shape].resize((16, 16), Image.LANCZOS)
        sheet.alpha_composite(tint(chat, (194, 59, 48)), (520 + i * 30, 420))
    sheet.alpha_composite(tex["Icon"].resize((64, 64), Image.NEAREST), (680, 410))
    sheet.convert("RGB").save(path)
    print("preview:", path)


def preview_smooth(tex, path):
    bg = (20, 17, 14)
    sheet = Image.new("RGBA", (1000, 420), bg + (255,))
    x = 30
    for shape, div, field, second in [("Heater", None, (163, 38, 42), (217, 174, 84)),
                                       ("Round", "Pale", (46, 125, 69), (217, 174, 84)),
                                       ("Kite", "Bend", (107, 58, 140), (217, 174, 84)),
                                       ("Banner", "Chevron", (30, 27, 26), (163, 38, 42))]:
        size = 96
        img = Image.new("RGBA", (size, size), (0, 0, 0, 0))

        def L(key):
            return tex["Smooth/Crest/" + shape + key].resize((size, size), Image.LANCZOS)

        img.alpha_composite(tint(L("Shadow"), (0, 0, 0), 0.7))
        img.alpha_composite(tint(L("Fill"), field))
        if div:
            img.alpha_composite(tint(L(div), second))
        img.alpha_composite(tint(L("Shine"), (255, 255, 255)))
        img.alpha_composite(tint(L("Rim"), (217, 174, 84)))
        sheet.alpha_composite(img, (x, 30))
        x += 120
    for i, key in enumerate(sorted(k for k in tex if k.startswith("Smooth/UI/Icon"))):
        sheet.alpha_composite(tint(tex[key].resize((32, 32), Image.LANCZOS), (242, 232, 216)),
                              (30 + (i % 12) * 50, 170 + (i // 12) * 44))
    for i, key in enumerate(sorted(k for k in tex if k.startswith("Smooth/Charge/"))):
        sheet.alpha_composite(tint(tex[key].resize((32, 32), Image.LANCZOS), (217, 174, 84)),
                              (30 + (i % 12) * 50, 280 + (i // 12) * 44))
    sheet.convert("RGB").save(path)
    print("preview:", path)


def theme_previews(tex):
    """A small picture of each theme for the setup's theme cards: a panel, a crest, a button."""
    out = {}
    w, h = 128, 64
    img = nine(tex["Pixel/UI/Panel"], w, h, 16)
    crest = Image.new("RGBA", (64, 64), (0, 0, 0, 0))

    def pix(key):
        return tex["Pixel/Crest/Heater" + key].resize((64, 64), Image.NEAREST)

    crest.alpha_composite(tint(pix("Shadow"), INK, 0.55))
    crest.alpha_composite(tint(pix("Fill"), (194, 59, 48)))
    crest.alpha_composite(pix("Shine"))
    crest.alpha_composite(tint(pix("Frame"), (240, 195, 90)))
    crest.alpha_composite(tint(tex["Pixel/Charge/Heart"].resize((32, 32), Image.NEAREST), (240, 195, 90)), (16, 10))
    img.alpha_composite(crest.resize((48, 48), Image.NEAREST), (10, 8))
    img.alpha_composite(nine(tex["Pixel/UI/Button"], 56, 24, 8), (62, 20))
    out["Pixel/UI/Preview"] = img
    img = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    img.alpha_composite(tint(nine(tex["Smooth/UI/Round"], w, h, 12, resample=Image.LANCZOS), (29, 24, 19)))
    img.alpha_composite(tint(nine(tex["Smooth/UI/RoundLine"], w, h, 12, resample=Image.LANCZOS), (217, 174, 84), 0.5))
    crest = Image.new("RGBA", (128, 128), (0, 0, 0, 0))

    def smo(key):
        return tex["Smooth/Crest/Heater" + key]

    crest.alpha_composite(tint(smo("Shadow"), (0, 0, 0), 0.7))
    crest.alpha_composite(tint(smo("Fill"), (163, 38, 42)))
    crest.alpha_composite(tint(smo("Shine"), (255, 255, 255)))
    crest.alpha_composite(tint(smo("Rim"), (217, 174, 84)))
    crest.alpha_composite(tint(tex["Smooth/Charge/Heart"], (217, 174, 84)), (32, 24))
    img.alpha_composite(crest.resize((52, 52), Image.LANCZOS), (8, 6))
    img.alpha_composite(tint(nine(tex["Smooth/UI/Round"], 56, 24, 8, resample=Image.LANCZOS), (163, 38, 42)), (62, 20))
    img.alpha_composite(tint(nine(tex["Smooth/UI/RoundLine"], 56, 24, 8, resample=Image.LANCZOS), (217, 174, 84), 0.6),
                        (62, 20))
    out["Smooth/UI/Preview"] = img
    img = nine(tex["Forever/UI/Panel"], w, h, 16, resample=Image.LANCZOS)
    img.alpha_composite(crest.resize((48, 48), Image.LANCZOS), (10, 8))
    img.alpha_composite(nine(tex["Forever/UI/Button"], 56, 24, 8, resample=Image.LANCZOS), (62, 20))
    out["Forever/UI/Preview"] = img
    return out


def main():
    tex = {}
    tex.update(ui_tiles())
    tex.update(pixel_crests())
    tex.update(pixel_glyphs())
    tex.update(smooth_crests())
    tex.update(smooth_ui())
    tex.update(forever_ui(tex))
    tex.update(shared_ui())
    tex.update(addon_icon())
    tex.update(theme_previews(tex))
    for key, image in tex.items():
        save(image, key)
    print(len(tex), "textures in", MEDIA)
    sounds()
    print("sounds: Chime, Bell, Boop")
    if "--preview" in sys.argv:
        out = sys.argv[sys.argv.index("--preview") + 1]
        os.makedirs(out, exist_ok=True)
        preview_pixel(tex, os.path.join(out, "preview_pixel.png"))
        preview_smooth(tex, os.path.join(out, "preview_smooth.png"))


if __name__ == "__main__":
    main()
