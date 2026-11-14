"""The store page's media: the animated crest, the logos and the picture cards.

Run `python tests/kit/screens.py` first: the cards are made from the addon's own frames, drawn there
as sheets with the three looks side by side (Forever, Pixel, Smooth). The crest art comes from the
addon's own art code (tests/kit/make_media.py), so it stays the addon's.
"""
import math
import os
import sys

import numpy as np
from PIL import Image, ImageDraw, ImageFilter, ImageFont, ImageSequence

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.join(HERE, "..")
SHEETS = os.path.join(ROOT, "tests", "kit", "screens")
PIXEL_FONT = os.path.join(ROOT, "Media", "Fonts", "HeyCousinPixel.ttf")
BODY_FONT = r"C:\Windows\Fonts\segoeui.ttf"
sys.path.insert(0, os.path.join(ROOT, "tests", "kit"))

import make_media as art  # noqa: E402

GOLD = (240, 195, 90)
SILVER = (226, 232, 238)
INK = (28, 19, 20)
LABEL = 0.046  # the share of a sheet's height its look names take
W, H = 2560, 1440
MARGIN = 110


def save(image, name, **options):
    image.save(os.path.join(HERE, name), **options)
    print("drew", name, image.size, os.path.getsize(os.path.join(HERE, name)) // 1024, "KB")


# --- the crest ------------------------------------------------------------------------------------


def face(shape, field, metal, charge, shade=None):
    """A crest on the addon's 32 x 32 grid: its shape, its colors and a symbol."""
    make, (cx, cy) = art.PIXEL_SHAPES[shape]
    fill, extra = make()
    img = art.rgba(32, 32)
    art.paint(img, art.dilate(fill) & ~fill, INK)
    if extra is not None:
        art.paint(img, art.dilate(extra) & ~extra & ~fill, INK)
        art.paint(img, extra, metal)
    art.paint(img, fill, metal)
    inner = art.erode(fill, 2)
    art.paint(img, inner, field)
    big = np.zeros((32, 32), bool)
    big[cy - 8:cy + 8, cx - 8:cx + 8] = art.centered(art.grid(art.CHARGES[charge]), 16) == "#"
    dark = shade or tuple(int(c * 0.56) for c in field)
    art.paint(img, art.dilate(big) & ~big & inner, dark)
    art.paint(img, big, metal)
    return img


FACES = [
    ("Heater", (194, 59, 48), GOLD, "Heart"),
    ("Round", (46, 96, 186), GOLD, "Star"),
    ("Banner", (112, 62, 172), SILVER, "Crown"),
    ("Kite", (34, 134, 112), GOLD, "Key"),
]
# Frames: each face holds, then turns. Every frame lasts DELAY ms and every frame differs: CurseForge's
# thumbnails give all frames the first one's delay, and a GIF merges equal frames into a longer one,
# which made its loop three times slower.
HOLD, FLIP, DELAY = 18, 6, 60


def shine(img, at):
    """A band of light crossing the crest, at `at` from 0 to 1."""
    out = img.astype(float)
    ys, xs = np.mgrid[0:32, 0:32]
    road = xs + ys
    # (not the black outline: light on it reads as specks around the crest)
    outline = (img[..., 0] == INK[0]) & (img[..., 1] == INK[1]) & (img[..., 2] == INK[2])
    body = (img[..., 3] > 0) & ~outline
    # (always on this crest, whatever its shape: no two frames alike)
    middle = road[body].min() + at * (road[body].max() - road[body].min())
    band = np.clip(1 - np.abs(road - middle) / 5, 0, 1).round()
    lit = body & (band > 0)
    out[lit, :3] = out[lit, :3] * 0.5 + 255 * 0.5
    return out.astype(np.uint8)


def squeezed(img, share):
    """The crest turned edge-on by `share` (1: full), on the grid, so its pixels stay sharp."""
    width = max(2, int(round(32 * share)))
    small = Image.fromarray(img, "RGBA").resize((width, 32), Image.NEAREST)
    out = Image.new("RGBA", (32, 32), (0, 0, 0, 0))
    out.paste(small, ((32 - width) // 2, 0))
    return np.array(out)


def sparkle(img, at):
    """Little stars that wink as the light passes."""
    out = img.copy()
    for x, y, start in ((4, 5, 0.25), (27, 8, 0.45), (29, 23, 0.65)):
        phase = (at - start) / 0.25
        if 0 <= phase <= 1:
            arm = 2 if 0.3 < phase < 0.7 else 1
            for dx, dy in [(0, 0)] + [(s * k, 0) for s in (-1, 1) for k in range(1, arm)] + [(0, s * k) for s in (-1, 1) for k in range(1, arm)]:
                if out[y + dy, x + dx, 3] == 0:
                    out[y + dy, x + dx] = (255, 244, 200, 255)
    return out


def emblem(name="emblem.gif", size=480, hold=HOLD, flip=FLIP, delay=DELAY):
    """The animated crest, one seamless loop: each design shines, then turns into the next."""
    faces = [face(*spec) for spec in FACES]
    frames = []
    for index, img in enumerate(faces):
        for step in range(hold):
            at = step / (hold - 1)
            frames.append(sparkle(shine(img, at), at))
        following = faces[(index + 1) % len(faces)]
        for step in range(flip):
            turn = (step + 1) / (flip + 1) * math.pi
            frames.append(squeezed(img if turn < math.pi / 2 else following, abs(math.cos(turn))))
    out = []
    for frame in frames:
        big = Image.fromarray(frame, "RGBA").resize((size, size), Image.NEAREST)
        alpha = big.getchannel("A")
        indexed = big.convert("RGB").convert("P", palette=Image.ADAPTIVE, colors=255)
        indexed.paste(255, alpha.point(lambda a: 255 if a < 128 else 0))
        indexed.info["transparency"] = 255
        out.append(indexed)
    path = os.path.join(HERE, name)
    out[0].save(path, save_all=True, append_images=out[1:], duration=delay, loop=0, disposal=2, transparency=255,
                optimize=False)
    saved = Image.open(path)
    delays = [frame.info.get("duration") for frame in ImageSequence.Iterator(saved)]
    assert len(delays) == len(out) and set(delays) == {delay}, "the frames must stay apart, all " + str(delay) + " ms"
    print("drew", name, size, len(out), "frames at", delay, "ms,", sum(delays), "ms a loop,",
          os.path.getsize(path) // 1024, "KB")


def logos():
    """The logo, big: on its own, and on the addon's dark panel for sites that want a solid one."""
    crest = Image.fromarray(face(*FACES[0]), "RGBA").resize((896, 896), Image.NEAREST)
    clear = Image.new("RGBA", (1024, 1024), (0, 0, 0, 0))
    clear.paste(crest, (64, 64), crest)
    save(clear, "logo-transparent.png", optimize=True)
    solid = Image.new("RGBA", (1024, 1024), (44, 31, 31, 255))
    solid.alpha_composite(clear)
    save(solid.convert("RGB"), "logo.png", optimize=True)


# --- the picture cards ----------------------------------------------------------------------------


def column(name, index):
    """One look's column of a sheet (0: Forever, 1: Pixel, 2: Smooth), under its name."""
    image = Image.open(os.path.join(SHEETS, name)).convert("RGB")
    width, height = image.size
    return image.crop((index * width // 3, int(height * LABEL), (index + 1) * width // 3, height))


def window_of(image):
    """The window in a column: the sheet around it is bluer than any window's edge."""
    pixels = np.asarray(image).astype(int)
    warm = pixels[..., 0] >= pixels[..., 2]
    mid_x, mid_y = image.width // 2, image.height // 2
    xs = np.flatnonzero(warm[mid_y])
    ys = np.flatnonzero(warm[:, mid_x])
    return image.crop((xs[0], ys[0], xs[-1] + 1, ys[-1] + 1))


def font(path, size):
    return ImageFont.truetype(path, size)


def wrap(draw, text, face_, width):
    lines, line = [], ""
    for word in text.split(" "):
        test = (line + " " + word).strip()
        if draw.textlength(test, font=face_) > width and line:
            lines.append(line)
            line = word
        else:
            line = test
    return lines + [line]


def blank():
    card = Image.new("RGB", (W, H), (15, 12, 14))
    glow = Image.new("L", (W, H), 0)
    ImageDraw.Draw(glow).ellipse((-500, -700, 1500, 800), fill=60)
    glow = glow.filter(ImageFilter.GaussianBlur(220))
    card.paste(Image.new("RGB", (W, H), (74, 42, 34)), (0, 0), glow)
    # the addon's name, as on the addon's own title
    crest = Image.fromarray(face(*FACES[0]), "RGBA").resize((96, 96), Image.NEAREST)
    card.paste(crest, (MARGIN, 80), crest)
    ImageDraw.Draw(card).text((MARGIN + 116, 106), "HEY COUSIN!", font=font(PIXEL_FONT, 40), fill=GOLD)
    return card


def place(card, window, x, y, size=None):
    """A window on the card, with a soft shadow."""
    if size:
        window = window.resize(size, Image.LANCZOS)
    shadow = Image.new("L", (W, H), 0)
    ImageDraw.Draw(shadow).rectangle((x + 8, y + 16, x + window.width + 8, y + window.height + 16), fill=170)
    card.paste((0, 0, 0), (0, 0), shadow.filter(ImageFilter.GaussianBlur(26)))
    card.paste(window, (x, y))


def words(card, title, line, y, width):
    draw = ImageDraw.Draw(card)
    title_font, line_font = font(PIXEL_FONT, 88), font(BODY_FONT, 46)
    for text in wrap(draw, title, title_font, width):
        draw.text((MARGIN, y), text, font=title_font, fill=(244, 232, 208))
        y += 112
    y += 22
    for text in wrap(draw, line, line_font, width):
        draw.text((MARGIN, y), text, font=line_font, fill=(190, 178, 162))
        y += 64
    return y




def collage(name, title, line, columns):
    """Words across the top, and under them several windows side by side, one look each, at one scale
    (so they keep the sizes they have in the game). Each column is a list of (sheet, look) stacked."""
    card = blank()
    bottom = words(card, title, line, 250, W - MARGIN * 2) + 40
    gap = 44
    cols = [[window_of(column(sheet, look)) for sheet, look in col] for col in columns]
    widths = [max(win.width for win in col) for col in cols]
    heights = [sum(win.height for win in col) + gap * (len(col) - 1) for col in cols]
    room_w = W - MARGIN * 2 - gap * (len(cols) - 1)
    room_h = H - bottom - 70
    scale = min(1, room_w / sum(widths), room_h / max(heights))
    x = MARGIN + (room_w - sum(widths) * scale) / 2
    for col, width, height in zip(cols, widths, heights):
        y = bottom + (room_h - height * scale) / 2
        for win in col:
            size = (int(win.width * scale), int(win.height * scale))
            place(card, win, int(x + (width * scale - size[0]) / 2), int(y), size)
            y += size[1] + gap * scale
        x += width * scale + gap
    save(card, name, optimize=True)


def store_cards():
    """The store page's four pictures, one for each part of the addon (Pixel, Forever and Smooth mixed,
    to show the looks too)."""
    collage("find.png", "FIND YOUR FAMILY",
            "Everyone online with your surname, a page for every cousin, and a pop-up when you meet one.",
            [[("1b-found.png", 1)], [("2-cousin.png", 0)], [("3b-hey.png", 2), ("3c-reunion.png", 1)]])
    collage("together.png", "PLAY TOGETHER",
            "Family chat and groups, calls for help, who has an item, who crafts what, and quest buddies.",
            [[("1h-together-help.png", 1)], [("1g-together-crafts.png", 2)], [("1e-groups.png", 0)]])
    collage("everywhere.png", "SEE YOUR FAMILY EVERYWHERE",
            "Your cousins' crests on the world map, the minimap and nameplates.",
            [[("12-family-map.png", 1)], [("5f-settings-plates.png", 2)]])
    collage("house.png", "BUILD YOUR HOUSE",
            "A crest that grows with family achievements, a portrait to share, and your guild as a family tree.",
            [[("9b-grown.png", 1), ("2bd-achievements.png", 1)], [("2bc-portrait.png", 0)], [("2c-tree.png", 2)]])








def main():
    store_cards()
    if "--store" in sys.argv:
        return
    emblem()
    # for a logo, which CurseForge shows small: a lighter file, the same 5.8 seconds a loop
    emblem("emblem-small.gif", size=256, hold=12, flip=4, delay=90)
    logos()


if __name__ == "__main__":
    main()
