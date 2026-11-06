"""Draws the addon's screens as pictures, from its own frames.

The addon runs on mock_wow.lua, as in the smoke test, and screens.lua opens each screen as a
player would. Every frame, texture and text the addon made is then laid out by its anchors, by
the game's rules (points on opposite sides stretch a region, else its own size holds), and drawn
with the art in Media/ and the Pixel theme's own font. The game packs its fonts, so Georgia
stands in for Friz Quadrata and Morpheus; the game's own parts (the minimap, chat, the tooltip,
class icons, 3D models) are plain stand-ins. A text that doesn't fit its box is printed.

python screens.py [OUT]   pictures in OUT (default: tests/kit/screens/, not committed)
"""
import os
import re
import sys

import numpy as np
from lupa.lua51 import LuaRuntime
from PIL import Image, ImageDraw, ImageFont

sys.stdout.reconfigure(encoding="utf-8")
HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.environ.get("HC_ROOT", os.path.abspath(os.path.join(HERE, "..", "..")))
WINFONTS = os.path.join(os.environ.get("WINDIR", r"C:\Windows"), "Fonts")
BODY, DISPLAY, CHAT = (os.path.join(WINFONTS, name) for name in ("georgia.ttf", "georgiab.ttf", "arial.ttf"))
PIXEL_FONT = os.path.join(ROOT, "Media", "Fonts", "HeyCousinPixel.ttf")
# Korean and Chinese: the game draws them in its own fonts (a font family's other members), and so
# does the Pixel theme; Windows' fonts stand in
KOREAN, HANS, HANT = (os.path.join(WINFONTS, name) for name in ("malgun.ttf", "msyh.ttc", "msjh.ttc"))
UI_W, UI_H = 1366, 768  # the game's screen at UI scale 1: 768 points high
SKINS = ("forever", "pixel", "smooth")

POINTS = {"TOPLEFT": ("l", "t"), "TOP": ("c", "t"), "TOPRIGHT": ("r", "t"), "LEFT": ("l", "m"),
          "CENTER": ("c", "m"), "RIGHT": ("r", "m"), "BOTTOMLEFT": ("l", "b"), "BOTTOM": ("c", "b"),
          "BOTTOMRIGHT": ("r", "b")}
EDGE = {"l": lambda box: box[0], "c": lambda box: (box[0] + box[2]) / 2, "r": lambda box: box[2],
        "b": lambda box: box[1], "m": lambda box: (box[1] + box[3]) / 2, "t": lambda box: box[3]}
STRATA = ["BACKGROUND", "LOW", "MEDIUM", "HIGH", "DIALOG", "FULLSCREEN", "FULLSCREEN_DIALOG", "TOOLTIP"]
LAYERS = {"BACKGROUND": 0, "BORDER": 1, "ARTWORK": 2, "OVERLAY": 3, "HIGHLIGHT": 4}
CHAT_COLORS = {"CHAT_MSG_SAY": (1, 1, 1), "CHAT_MSG_GUILD": (0.25, 1, 0.25), "CHAT_MSG_CHANNEL": (1, 0.75, 0.75)}
CHAT_FORMATS = {"CHAT_MSG_SAY": "[{name}] says: {text}", "CHAT_MSG_GUILD": "[Guild] [{name}]: {text}",
                "CHAT_MSG_CHANNEL": "[2. Trade] [{name}]: {text}"}

LUA_SETUP = r"""
table.unpack = table.unpack or unpack
table.pack = table.pack or function(...) return { n = select("#", ...), ... } end
utf8 = utf8 or { len = function(s) local _, n = string.gsub(s, "[^\128-\191]", "") return n end }
"""
# the mock's sizes and string widths come from the layout here, as the game's do
LUA_HOOKS = r"""
local classes = Mock.classes
function classes.Region:GetWidth() return PyWidth(self) end
function classes.Region:GetHeight() return PyHeight(self) end
function classes.Region:GetCenter() return PyCenter(self) end
function classes.FontString:GetStringWidth() return PyStringWidth(self) end
"""


def span(known, size, lo, mid, hi):
    if lo in known and hi in known:
        return known[lo], known[hi]
    if lo in known:
        return known[lo], known[lo] + size
    if hi in known:
        return known[hi] - size, known[hi]
    return known[mid] - size / 2, known[mid] + size / 2


def items(table):
    """A Lua array as a list."""
    if table is None:
        return []
    return [table[i] for i in range(1, len(table) + 1)]


def color(table, default=(1, 1, 1, 1)):
    if table is None:
        return default
    values = [table[i] for i in range(1, 5)]
    return tuple(default[i] if values[i] is None else values[i] for i in range(4))


def tokens(text):
    """WoW's text codes: |cAARRGGBB colors until |r, |T textures |t, |n new lines, || a bar."""
    out, buffer, current, i = [], [], None, 0

    def flush():
        if buffer:
            out.append(("t", "".join(buffer), current))
            buffer.clear()
    while i < len(text):
        char = text[i]
        code = text[i + 1] if char == "|" and i + 1 < len(text) else None
        if code == "c" and i + 10 <= len(text):
            flush()
            hexes = text[i + 4:i + 10]
            current = tuple(int(hexes[k:k + 2], 16) / 255 for k in (0, 2, 4))
            i += 10
        elif code == "r":
            flush()
            current = None
            i += 2
        elif code == "T":
            end = text.find("|t", i)
            end = len(text) if end < 0 else end
            flush()
            out.append(("tex", text[i + 2:end], None))
            i = end + 2
        elif code == "n" or char == "\n":
            flush()
            out.append(("br", None, None))
            i += 2 if code == "n" else 1
        elif code == "H":
            end = text.find("|h", i)
            i = len(text) if end < 0 else end + 2
        elif code == "h":
            i += 2
        elif code == "|":
            buffer.append("|")
            i += 2
        else:
            buffer.append(char)
            i += 1
    flush()
    return out


def texture_code(code, line_height):
    """|Tpath:height:width:x:y:texWidth:texHeight:left:right:top:bottom:r:g:b|t"""
    parts = code.split(":")

    def number(index, default):
        return float(parts[index]) if len(parts) > index and parts[index] != "" else default
    height = number(1, 0) or line_height
    width = number(2, 0) or height
    tex_w, tex_h = number(5, 0), number(6, 0)
    coords = (0, 1, 0, 1)
    if tex_w and tex_h:
        coords = (number(7, 0) / tex_w, number(8, tex_w) / tex_w, number(9, 0) / tex_h, number(10, tex_h) / tex_h)
    tint = (number(11, 255) / 255, number(12, 255) / 255, number(13, 255) / 255)
    return {"file": parts[0], "w": width, "h": height, "x": number(3, 0), "y": number(4, 0), "coords": coords,
            "color": tint}


def overlap(a, b):
    return min(a[2], b[2]) - max(a[0], b[0]) > 1 and min(a[3], b[3]) - max(a[1], b[1]) > 1


class Painter:
    def __init__(self):
        self.lang = None
        self.lua = LuaRuntime(unpack_returned_tuples=True)
        os.chdir(ROOT)
        self.lua.execute(LUA_SETUP)
        for name in ("mock_wow.lua", "screens.lua"):
            self.lua.execute(open(os.path.join(HERE, name), encoding="utf-8").read())
        self.G = self.lua.globals()
        self.G.PyWidth = lambda region: self.width(region)
        self.G.PyHeight = lambda region: self.height(region)
        self.G.PyCenter = self.center
        self.G.PyStringWidth = lambda region: self.text_size(self.text_of(region), None)[0]
        self.lua.execute(LUA_HOOKS)
        self.kinds, self.fonts, self.images = {}, {}, {}
        self.cache, self.busy, self.notes = None, set(), []
        self.scale = 2

    # --- layout ------------------------------------------------------------------------------

    def kind(self, obj):
        key = obj["serial"]
        if key not in self.kinds:
            self.kinds[key] = self.G.Screens.Kind(obj)
        return self.kinds[key]

    def rect(self, region):
        """(left, bottom, right, top) in UI points, or None while it has no place."""
        if region is None or region["serial"] is None:
            return None
        key = region["serial"]
        if self.cache is not None and key in self.cache:
            return self.cache[key]
        if key in self.busy:
            return None
        self.busy.add(key)
        try:
            box = self.solve(region)
        finally:
            self.busy.discard(key)
        if self.cache is not None:
            self.cache[key] = box
        return box

    def solve(self, region):
        if region["frameName"] == "UIParent":
            return (0.0, 0.0, float(UI_W), float(UI_H))
        xs, ys = {}, {}
        anchors = region["anchors"]
        for point, anchor in (anchors.items() if anchors is not None else []):
            to = anchor["to"]
            if to is None:
                to = region["parent"]
            elif isinstance(to, str):
                to = self.G[to]
            box = self.rect(to)
            if box is None:
                continue
            at_x, at_y = POINTS[anchor["at"]]
            px, py = POINTS[point]
            xs[px] = EDGE[at_x](box) + (anchor["x"] or 0)
            ys[py] = EDGE[at_y](box) + (anchor["y"] or 0)
        if not xs:
            return None
        text = self.kind(region) == "FontString"
        width = region["w"]
        if width is None:
            width = self.text_size(self.text_of(region), None)[0] if text else 0
        left, right = span(xs, width, "l", "c", "r")
        height = region["h"]
        if height is None:
            fixed = ("l" in xs and "r" in xs) or region["w"] is not None
            height = self.text_size(self.text_of(region), right - left if fixed else None)[1] if text else 0
        bottom, top = span(ys, height, "b", "m", "t")
        return (left, bottom, right, top)

    def width(self, region):
        box = self.rect(region)
        if box:
            return box[2] - box[0]
        if region["w"] is not None:
            return region["w"]
        return self.text_size(self.text_of(region), None)[0] if self.kind(region) == "FontString" else 0

    def height(self, region):
        box = self.rect(region)
        if box:
            return box[3] - box[1]
        return region["h"] or 0

    def center(self, region):
        box = self.rect(region)
        if box:
            return (box[0] + box[2]) / 2, (box[1] + box[3]) / 2
        return None

    # --- text --------------------------------------------------------------------------------

    def font(self, path, height):
        size = max(1, round(height * self.scale))
        key = (path, size)
        if key not in self.fonts:
            self.fonts[key] = ImageFont.truetype(path, size)
        return self.fonts[key]

    def cjk(self, text):
        """The stand-in font for a Korean or Chinese text (screens.py --lang), else None."""
        han = False
        for char in text:
            code = ord(char)
            if 0xAC00 <= code <= 0xD7AF or 0x3130 <= code <= 0x318F:
                return KOREAN
            han = han or 0x3000 <= code <= 0x9FFF or 0xFF00 <= code <= 0xFFEF
        if not han:
            return None
        return KOREAN if self.lang == "koKR" else HANT if self.lang == "zhTW" else HANS

    def text_of(self, obj, edit=False):
        """What a font string (or a text box) shows, and in which font."""
        font = obj["font"]
        member = font
        cjk = self.cjk(str(obj["text"] or ""))
        # (Korean and Chinese take their alphabet's member: the theme makes them a little taller)
        alphabet = {KOREAN: "korean", HANS: "simplifiedchinese", HANT: "traditionalchinese"}.get(cjk, "roman")
        if font is not None and font["members"] is not None:
            member = font["members"][alphabet] or font["members"]["roman"] or font
        file = (member and member["file"]) or "Fonts\\FRIZQT__.TTF"
        low = file.replace("/", "\\").lower()
        if low.startswith("interface\\addons\\heycousin\\"):
            path = os.path.join(ROOT, *file.replace("/", "\\").split("\\")[3:])
        else:
            path = DISPLAY if "morpheus" in low else BODY
        path = cjk or path
        shadow = obj["shadowOffset"] if obj["shadowOffset"] is not None else (member and member["shadowOffset"])
        return {
            "text": str(obj["text"] or ""), "path": path, "height": (member and member["height"]) or 12,
            "flags": (member and member["flags"]) or "",
            "color": color(obj["textColor"] if obj["textColor"] is not None else (member and member["textColor"])),
            "shadow": (shadow[1] or 0, shadow[2] or 0) if shadow is not None else (0, 0),
            "shadowColor": color(obj["shadowColor"] if obj["shadowColor"] is not None
                                 else (member and member["shadowColor"]), (0, 0, 0, 1)),
            "justifyH": obj["justifyH"] or ("LEFT" if edit else "CENTER"), "justifyV": obj["justifyV"] or "MIDDLE",
            "wrap": False if edit else obj["wrap"] is not False, "spacing": obj["spacing"] or 0,
        }

    def lines(self, info, width):
        """The text in lines, each a list of (kind, value, color, width); wrapped at `width`."""
        font = self.font(info["path"], info["height"])
        rows = [[]]
        for kind, value, tint in tokens(info["text"]):
            if kind == "br":
                rows.append([])
            elif kind == "tex":
                code = texture_code(value, info["height"])
                rows[-1].append(("tex", code, None, code["w"]))
            elif width is None or not info["wrap"]:
                rows[-1].append(("t", value, tint, font.getlength(value) / self.scale))
            else:
                # (Chinese has no spaces: the game breaks a line between any two of its characters)
                for word in re.split(r"( +|[　-〿㐀-鿿＀-￯])", value):
                    if not word:
                        continue
                    size = font.getlength(word) / self.scale
                    used = sum(part[3] for part in rows[-1])
                    if not word.isspace() and rows[-1] and used + size > width + 0.05:
                        while rows[-1] and rows[-1][-1][0] == "t" and rows[-1][-1][1].isspace():
                            rows[-1].pop()
                        rows.append([])
                    if word.isspace() and not rows[-1]:
                        continue
                    rows[-1].append(("t", word, tint, size))
        return rows

    def text_size(self, info, width):
        rows = self.lines(info, width)
        if not info["text"]:
            return 0, 0
        widest = max(sum(part[3] for part in row) for row in rows)
        return widest, len(rows) * info["height"] + (len(rows) - 1) * info["spacing"]

    def fit(self, info, rows, width, height, where):
        """Cuts what doesn't fit, as the game does ("..."), and notes it."""
        font = self.font(info["path"], info["height"])
        dots = font.getlength("...") / self.scale
        short = info["text"][:40].replace("\n", " ")
        line = info["height"] + info["spacing"]
        room = int((height + info["spacing"] + 0.5) // line) if height is not None else len(rows)
        if room < len(rows):
            self.notes.append(f"{where}: {len(rows)} lines, room for {room}: {short!r}")
            rows = rows[:max(room, 0)]
        for index, row in enumerate(rows):
            used = sum(part[3] for part in row)
            if width is None or used <= width + 0.5:
                continue
            self.notes.append(f"{where}: cut to fit {width:.0f} points (needs {used:.0f}): {short!r}")
            row = list(row)
            while row and sum(part[3] for part in row) + dots > width:
                kind, value, tint, size = row[-1]
                if kind != "t" or len(value) <= 1:
                    row.pop()
                    continue
                value = value[:-1]
                row[-1] = ("t", value, tint, font.getlength(value) / self.scale)
            last_tint = next((part[2] for part in reversed(row) if part[0] == "t"), None)
            row.append(("t", "...", last_tint, dots))
            rows[index] = row
        return rows

    # --- drawing -----------------------------------------------------------------------------

    def px(self, box):
        s = self.scale
        return (round(box[0] * s), round((UI_H - box[3]) * s), round(box[2] * s), round((UI_H - box[1]) * s))

    def blit(self, layer, x0, y0, alpha=1.0, clip=None, add=False):
        """Puts an RGBA layer (floats, straight alpha) on the canvas at pixel (x0, y0)."""
        h, w = layer.shape[:2]
        cx0, cy0, cx1, cy1 = 0, 0, self.canvas.shape[1], self.canvas.shape[0]
        if clip:
            cx0, cy0, cx1, cy1 = max(cx0, clip[0]), max(cy0, clip[1]), min(cx1, clip[2]), min(cy1, clip[3])
        ix0, iy0, ix1, iy1 = max(x0, cx0), max(y0, cy0), min(x0 + w, cx1), min(y0 + h, cy1)
        if ix0 >= ix1 or iy0 >= iy1:
            return
        src = layer[iy0 - y0:iy1 - y0, ix0 - x0:ix1 - x0]
        a = src[..., 3:4] * alpha
        dst = self.canvas[iy0:iy1, ix0:ix1]
        if add:
            np.minimum(dst + src[..., :3] * a, 1, out=dst)
        else:
            dst[...] = src[..., :3] * a + dst * (1 - a)

    def image(self, file):
        if file in self.images:
            return self.images[file]
        if isinstance(file, (int, float)):
            # a game file by its number (an item's icon): a plain stand-in
            icon = Image.new("RGBA", (32, 32), (88, 96, 110, 255))
            draw = ImageDraw.Draw(icon)
            draw.rectangle((3, 3, 28, 28), fill=(120, 130, 146, 255))
            draw.rectangle((9, 9, 22, 22), fill=(150, 160, 176, 255))
            self.images[file] = icon
            return icon
        low = file.replace("/", "\\").lower()
        image = None
        if low == "interface\\buttons\\white8x8":
            image = Image.new("RGBA", (8, 8), (255, 255, 255, 255))
        elif "ui-charactercreate-classes" in low:
            image = self.class_sheet()
        elif low.startswith("interface\\addons\\heycousin\\"):
            base = os.path.join(ROOT, *file.replace("/", "\\").split("\\")[3:])
            for path in (base, base + ".tga", base + ".png"):
                if os.path.isfile(path):
                    image = Image.open(path).convert("RGBA")
                    break
        if image is None:
            self.notes.append(f"no art for {file}")
        self.images[file] = image
        return image

    def class_sheet(self):
        """Stand-in class icons: the class's color with its first letter."""
        sheet = Image.new("RGBA", (256, 256), (0, 0, 0, 0))
        draw = ImageDraw.Draw(sheet)
        font = ImageFont.truetype(DISPLAY, 34)
        for name, cell in self.G.Screens.CLASS_CELLS.items():
            tint = tuple(int(c * 255) for c in color(self.G.Screens.CLASS_COLORS[name])[:3])
            dark = tuple(int(c * 0.42) for c in tint)
            x0, x1, y0, y1 = (int(cell[i] * 256) for i in (1, 2, 3, 4))
            draw.rectangle((x0, y0, x1 - 1, y1 - 1), fill=dark + (255,))
            draw.rectangle((x0 + 3, y0 + 3, x1 - 4, y1 - 4), outline=tint + (255,), width=3)
            draw.text(((x0 + x1) / 2, (y0 + y1) / 2 + 1), name[0], font=font, fill=tint + (255,), anchor="mm")
        return sheet

    def texture_layer(self, file, size, coords, filter_name, tint):
        image = self.image(file)
        w, h = size
        if image is None or w <= 0 or h <= 0:
            return None
        left, right, top, bottom = coords
        flip_x, flip_y = left > right, top > bottom
        box = (min(left, right) * image.width, min(top, bottom) * image.height,
               max(left, right) * image.width, max(top, bottom) * image.height)
        if box[2] - box[0] <= 0 or box[3] - box[1] <= 0:
            return None
        resample = Image.NEAREST if filter_name == "NEAREST" else Image.BILINEAR
        part = image.resize((w, h), resample, box=box)
        if flip_x:
            part = part.transpose(Image.FLIP_LEFT_RIGHT)
        if flip_y:
            part = part.transpose(Image.FLIP_TOP_BOTTOM)
        layer = np.asarray(part, dtype=np.float32) / 255
        layer[..., :3] *= np.array(tint[:3], dtype=np.float32)
        layer[..., 3] *= tint[3]
        return layer

    def coords(self, region):
        values = items(region["coords"])
        if len(values) == 8:
            return (values[0], values[4], values[1], values[3])
        if len(values) == 4:
            return tuple(values)
        return (0, 1, 0, 1)

    def draw_texture(self, region, box, alpha, clip):
        file = region["file"]
        if region["atlas"] is not None and file is None:
            self.notes.append(f"atlas {region['atlas']} (the game's, not drawn)")
            return
        if not isinstance(file, (str, int, float)):
            return
        x0, y0, x1, y1 = self.px(box)
        layer = self.texture_layer(file, (x1 - x0, y1 - y0), self.coords(region), region["filter"],
                                   color(region["color"]))
        if layer is None:
            return
        mask = region["mask"]
        if mask is not None and isinstance(mask["file"], str) and self.rect(mask):
            mx0, my0, mx1, my1 = self.px(self.rect(mask))
            cut = self.texture_layer(mask["file"], (mx1 - mx0, my1 - my0), (0, 1, 0, 1), "LINEAR", (1, 1, 1, 1))
            full = np.zeros(layer.shape[:2], dtype=np.float32)
            if cut is not None:
                ox0, oy0 = max(mx0, x0), max(my0, y0)
                ox1, oy1 = min(mx1, x1), min(my1, y1)
                if ox0 < ox1 and oy0 < oy1:
                    full[oy0 - y0:oy1 - y0, ox0 - x0:ox1 - x0] = cut[oy0 - my0:oy1 - my0, ox0 - mx0:ox1 - mx0, 3]
            layer[..., 3] *= full
        self.blit(layer, x0, y0, alpha, clip, add=region["blend"] == "ADD")

    def draw_text(self, info, box, alpha, clip, where):
        """Draws the text in `box`; returns where its letters are (UI points)."""
        if not info["text"]:
            return None
        s = self.scale
        width, height = box[2] - box[0], box[3] - box[1]
        rows = self.fit(info, self.lines(info, width), width, height, where)
        if not rows:
            return None
        line_h, spacing = info["height"], info["spacing"]
        block = len(rows) * line_h + (len(rows) - 1) * spacing
        top = box[3] if info["justifyV"] == "TOP" else box[1] + block if info["justifyV"] == "BOTTOM" else \
            box[3] - (height - block) / 2
        font = self.font(info["path"], line_h)
        ascent, descent = font.getmetrics()
        ratio = ascent / max(1, ascent + descent)
        pad = 8
        x_min, x_max = box[0] - 2, box[2] + 2
        placed = []
        for index, row in enumerate(rows):
            used = sum(part[3] for part in row)
            x = box[0] if info["justifyH"] == "LEFT" else box[2] - used if info["justifyH"] == "RIGHT" else \
                box[0] + (width - used) / 2
            line_top = top - index * (line_h + spacing)
            placed.append((x, line_top, row))
            x_min, x_max = min(x_min, x), max(x_max, x + used)
        y_top, y_bottom = top + 2, top - block - 2
        ox, oy = int(x_min * s) - pad, int((UI_H - y_top) * s) - pad
        w, h = int((x_max - x_min) * s) + 2 * pad + 2, int((y_top - y_bottom) * s) + 2 * pad + 2
        canvas = Image.new("RGBA", (max(1, w), max(1, h)), (0, 0, 0, 0))
        draw = ImageDraw.Draw(canvas)
        if "MONOCHROME" in info["flags"]:
            draw.fontmode = "1"
        stroke = 2 if "THICKOUTLINE" in info["flags"] else 1 if "OUTLINE" in info["flags"] else 0
        base = info["color"]
        for shadow_pass in (True, False):
            dx, dy = info["shadow"]
            if shadow_pass and not (dx or dy):
                continue
            for x, line_top, row in placed:
                cursor = x
                baseline = round((UI_H - line_top) * s + ratio * line_h * s) - oy
                for kind, value, tint, size in row:
                    if kind == "t":
                        rgb = tint or base[:3]
                        if shadow_pass:
                            fill = tuple(int(c * 255) for c in info["shadowColor"][:3]) + (
                                int(info["shadowColor"][3] * base[3] * 255),)
                            spot = (round(cursor * s) - ox + round(dx * s), baseline - round(dy * s))
                        else:
                            fill = tuple(int(c * 255) for c in rgb) + (int(base[3] * 255),)
                            spot = (round(cursor * s) - ox, baseline)
                        draw.text(spot, value, font=font, fill=fill, anchor="ls", stroke_width=stroke,
                                  stroke_fill=(0, 0, 0, fill[3]) if stroke else None)
                    elif not shadow_pass:
                        code = value
                        tw, th = round(code["w"] * s), round(code["h"] * s)
                        layer = self.texture_layer(code["file"], (tw, th), code["coords"], "LINEAR",
                                                   code["color"] + (1,))
                        if layer is not None:
                            piece = Image.fromarray((layer * 255).astype(np.uint8), "RGBA")
                            tx = round(cursor * s) - ox
                            ty = round((UI_H - line_top + (line_h - code["h"]) / 2 - code["y"]) * s) - oy
                            canvas.alpha_composite(piece, (max(0, tx), max(0, ty)))
                    cursor += size
        self.blit(np.asarray(canvas, dtype=np.float32) / 255, ox, oy, alpha, clip)
        return (min(x for x, _, _ in placed), top - block,
                max(x + sum(part[3] for part in row) for x, _, row in placed), top)

    def draw_model(self, box, alpha, clip):
        """A stand-in for a 3D model: a head and shoulders."""
        x0, y0, x1, y1 = self.px(box)
        w, h = x1 - x0, y1 - y0
        if w <= 0 or h <= 0:
            return
        k = 4
        bust = Image.new("RGBA", (w * k, h * k), (0, 0, 0, 0))
        draw = ImageDraw.Draw(bust)
        W, H = w * k, h * k
        draw.ellipse((W * 0.08, H * 0.66, W * 0.92, H * 1.35), fill=(118, 126, 140, 255))
        draw.ellipse((W * 0.3, H * 0.16, W * 0.7, H * 0.68), fill=(150, 158, 172, 255))
        draw.ellipse((W * 0.36, H * 0.22, W * 0.56, H * 0.42), fill=(176, 184, 196, 255))
        bust = bust.resize((w, h), Image.LANCZOS)
        self.blit(np.asarray(bust, dtype=np.float32) / 255, x0, y0, alpha, clip)

    # --- one screen --------------------------------------------------------------------------

    def chain(self, region):
        """Shown, the alpha it's drawn with, and the box its frames clip it to."""
        alpha, clip = region["alpha"] if region["alpha"] is not None else 1, None
        if not region["shown"]:
            return False, 0, None
        frame = region["parent"]
        while frame is not None:
            if not frame["shown"]:
                return False, 0, None
            alpha *= frame["alpha"] if frame["alpha"] is not None else 1
            if frame["clips"] and self.rect(frame):
                box = self.px(self.rect(frame))
                clip = box if clip is None else (max(clip[0], box[0]), max(clip[1], box[1]), min(clip[2], box[2]),
                                                 min(clip[3], box[3]))
            frame = frame["parent"]
        return True, alpha, clip

    def own_clip(self, frame, clip):
        if frame["clips"] and self.rect(frame):
            box = self.px(self.rect(frame))
            return box if clip is None else (max(clip[0], box[0]), max(clip[1], box[1]), min(clip[2], box[2]),
                                             min(clip[3], box[3]))
        return clip

    def strata(self, frame):
        while frame is not None:
            if frame["strata"]:
                return frame["strata"]
            frame = frame["parent"]
        return "MEDIUM"

    def settle(self):
        """Lets the screen come to rest: timers, eased motion, and the size changes the game
        reports (OnSizeChanged) once frames have their places."""
        mock = self.G.Mock
        mock.Advance(0.5)
        seen = {}
        for _ in range(8):
            mock.Tick(2, 0.03)
            fired = False
            for frame in items(mock.frames):
                script = frame["scripts"]["OnSizeChanged"]
                if script is None:
                    continue
                size = (round(self.width(frame), 2), round(self.height(frame), 2))
                if seen.get(frame["serial"]) != size:
                    seen[frame["serial"]] = size
                    script(frame, size[0], size[1])
                    fired = True
            if not fired:
                break
        mock.Tick(30, 0.03)

    def background(self, world):
        h, w = UI_H * self.scale, UI_W * self.scale
        y = np.linspace(0, 1, h, dtype=np.float32)[:, None, None]
        if not world:
            top, bottom = np.array([62, 68, 80]) / 255, np.array([30, 33, 40]) / 255
            return np.broadcast_to(top + (bottom - top) * y, (h, w, 3)).astype(np.float32).copy()
        sky_top, sky_low = np.array([92, 120, 150]) / 255, np.array([178, 170, 150]) / 255
        canvas = np.broadcast_to(sky_top + (sky_low - sky_top) * y, (h, w, 3)).astype(np.float32).copy()
        x = np.linspace(0, 1, w, dtype=np.float32)
        for base, wave, tint in ((0.52, 0.05, (84, 104, 98)), (0.62, 0.07, (60, 82, 66)), (0.74, 0.04, (46, 64, 50))):
            ridge = (base + wave * np.sin(x * 9.0 + base * 20) + wave * 0.5 * np.sin(x * 23.0)) * h
            below = np.arange(h)[:, None] >= ridge[None, :]
            canvas[below] = np.array(tint, dtype=np.float32) / 255
        return canvas

    def minimap(self):
        box = self.rect(self.G.Minimap)
        x0, y0, x1, y1 = self.px(box)
        k = 3
        disc = Image.new("RGBA", ((x1 - x0) * k, (y1 - y0) * k), (0, 0, 0, 0))
        draw = ImageDraw.Draw(disc)
        W, H = disc.size
        draw.ellipse((0, 0, W - 1, H - 1), fill=(70, 62, 48, 255))
        draw.ellipse((W * 0.03, H * 0.03, W * 0.97, H * 0.97), fill=(64, 92, 60, 255))
        draw.ellipse((W * 0.2, H * 0.55, W * 0.6, H * 0.85), fill=(84, 110, 70, 255))
        draw.polygon([(W * 0.5, H * 0.44), (W * 0.46, H * 0.54), (W * 0.54, H * 0.54)], fill=(250, 220, 90, 255))
        disc = disc.resize((x1 - x0, y1 - y0), Image.LANCZOS)
        self.blit(np.asarray(disc, dtype=np.float32) / 255, x0, y0)

    def plain_text(self, text, x, top, path, height, tint, shadow=True):
        info = {"text": text, "path": path, "height": height, "flags": "", "color": tint + (1,),
                "shadow": (1, -1) if shadow else (0, 0), "shadowColor": (0, 0, 0, 0.9), "justifyH": "LEFT",
                "justifyV": "TOP", "wrap": False, "spacing": 0}
        w, h = self.text_size(info, None)
        self.draw_text(info, (x, top - h, x + w + 1, top), 1, None, "stand-in")
        return w, h

    def chat(self, lines):
        """The chat frame, bottom left, with the addon's lines as the game shows them."""
        left, bottom, width, line_h = 24, 150, 460, 16
        box = (left - 6, bottom - 6, left + width, bottom + line_h * len(lines) + 6)
        x0, y0, x1, y1 = self.px(box)
        self.blit(np.full((y1 - y0, x1 - x0, 4), (0, 0, 0, 0.35), dtype=np.float32), x0, y0)
        for index, line in enumerate(lines):
            tint = CHAT_COLORS.get(line["event"], (1, 1, 1))
            name_rgb = color(self.G.Screens.CLASS_COLORS[line["class"]])
            name = "|cff%02x%02x%02x%s|r" % (*(int(c * 255) for c in name_rgb[:3]), line["name"])
            text = CHAT_FORMATS[line["event"]].format(name=name, text=line["text"])
            self.plain_text(text, left, bottom + line_h * (len(lines) - index), CHAT, 14, tint)
        return box

    def tooltip(self):
        """GameTooltip, at its usual place over the bags, with its lines."""
        tooltip = self.G.GameTooltip
        lines, tints = items(tooltip["lines"]), items(tooltip["colors"])
        infos = []
        for index, text in enumerate(lines):
            tint = color(tints[index] if index < len(tints) else None)[:3]
            infos.append((text, 14 if index == 0 else 12, tint))
        sizes = [self.text_size({"text": t, "path": self.cjk(t) or BODY, "height": h, "flags": "", "color": (1, 1, 1, 1),
                                 "shadow": (0, 0), "shadowColor": (0, 0, 0, 1), "justifyH": "LEFT",
                                 "justifyV": "TOP", "wrap": False, "spacing": 0}, None) for t, h, _ in infos]
        width = max(w for w, _ in sizes) + 20
        height = sum(h for _, h in sizes) + 2 * (len(sizes) - 1) + 18
        right, bottom = UI_W - 60, 120
        box = (right - width, bottom, right, bottom + height)
        x0, y0, x1, y1 = self.px(box)
        k = 2
        panel = Image.new("RGBA", ((x1 - x0) * k, (y1 - y0) * k), (0, 0, 0, 0))
        ImageDraw.Draw(panel).rounded_rectangle((0, 0, panel.width - 1, panel.height - 1), radius=5 * self.scale * k,
                                                fill=(8, 8, 14, 235), outline=(140, 140, 150, 255), width=k * 2)
        panel = panel.resize((x1 - x0, y1 - y0), Image.LANCZOS)
        self.blit(np.asarray(panel, dtype=np.float32) / 255, x0, y0)
        top = box[3] - 9
        for (text, size, tint), (_, h) in zip(infos, sizes):
            self.plain_text(text, box[0] + 10, top, self.cjk(text) or BODY, size, tint, shadow=False)
            top -= h + 2
        return box

    def root_of(self, frame, roots):
        """The window (one of the scene's `roots`) that `frame` is in, if any."""
        while frame is not None:
            for root in roots:
                if frame["serial"] == root["serial"]:
                    return root
            frame = frame["parent"]
        return None

    def check(self, scene, inks, roots=()):
        """Notes texts that run into each other, labels wider than their buttons, and texts that run
        out of their window."""
        for index, (frame, region, ink, clip) in enumerate(inks):
            root = self.root_of(frame, roots)
            edge = root is not None and self.rect(root)
            if clip is not None:
                # (a clip is in pixels: back to points, the way px() went)
                s = self.scale
                clip = (clip[0] / s, UI_H - clip[3] / s, clip[2] / s, UI_H - clip[1] / s)
            seen = ink if clip is None else (max(ink[0], clip[0]), max(ink[1], clip[1]), min(ink[2], clip[2]),
                                             min(ink[3], clip[3]))
            if edge and seen[0] < seen[2] and seen[1] < seen[3] and (seen[0] < edge[0] - 1 or seen[2] > edge[2] + 1
                                                                     or seen[1] < edge[1] - 1 or seen[3] > edge[3] + 1):
                self.notes.append(f"{scene}: {str(region['text'])[:40]!r} runs out of its window")
            box = self.rect(frame)
            if self.kind(frame) == "Button" and (ink[0] < box[0] - 1 or ink[2] > box[2] + 1):
                self.notes.append(f"{scene}: {str(region['text'])[:40]!r} is wider than its button "
                                  f"({ink[2] - ink[0]:.0f} > {box[2] - box[0]:.0f})")
            for other_frame, other, other_ink, _ in inks[index + 1:]:
                if other_frame["serial"] == frame["serial"] and overlap(ink, other_ink):
                    self.notes.append(f"{scene}: {str(region['text'])[:30]!r} runs into {str(other['text'])[:30]!r}")

    def render(self, scene, skin, scale):
        """One scene in one theme: (the picture, the boxes of its parts in pixels)."""
        self.scale, self.cache, self.kinds, self.notes = scale, None, {}, []
        result = self.G.Screens[scene](skin)
        self.settle()
        self.cache = {}
        self.canvas = self.background(bool(result["full"]))
        parts = {}
        if result["minimap"]:
            self.minimap()
            parts["minimap"] = self.px(self.rect(self.G.Minimap))
        if result["chat"] is not None:
            parts["chat"] = self.px(self.chat(items(result["chat"])))
        shown, inks = [], []
        for frame in items(self.G.Mock.frames):
            visible, alpha, clip = self.chain(frame)
            if visible and self.rect(frame) is not None:
                level = frame["GetFrameLevel"](frame)
                shown.append(((STRATA.index(self.strata(frame)), level, frame["serial"]), frame, alpha, clip))
        for _, frame, alpha, clip in sorted(shown, key=lambda entry: entry[0]):
            box = self.rect(frame)
            kind = self.kind(frame)
            if kind == "Model" and frame["unit"] is not None:
                self.draw_model(box, alpha, clip)
            if kind == "EditBox":
                self.draw_text(self.text_of(frame, edit=True), box, alpha, clip, f"{scene} text box")
            regions = items(frame["regions"])
            order = sorted(regions, key=lambda r: (LAYERS.get(r["layer"] or "ARTWORK", 2), r["sublevel"] or 0,
                                                   r["serial"]))
            for region in order:
                if region["layer"] == "HIGHLIGHT" or not region["shown"]:
                    continue
                region_box = self.rect(region)
                if region_box is None:
                    if region["file"] or region["text"]:
                        self.notes.append(f"{scene}: a region with no place: {region['file'] or region['text']}")
                    continue
                a = alpha * (region["alpha"] if region["alpha"] is not None else 1)
                if a <= 0.001:
                    continue
                if self.kind(region) == "Texture":
                    self.draw_texture(region, region_box, a, self.own_clip(frame, clip))
                else:
                    own = self.own_clip(frame, clip)
                    ink = self.draw_text(self.text_of(region), region_box, a, own, scene)
                    if ink:
                        inks.append((frame, region, ink, own))
        self.check(scene, inks, [] if result["full"] else items(result["frames"]))
        if result["tooltip"]:
            parts["tooltip"] = self.px(self.tooltip())
        for error in items(self.G.Screens.HC.errors):
            self.notes.append(f"{scene}: the addon caught an error: {error['label']}: {error['message']}")
        picture = Image.fromarray((np.clip(self.canvas, 0, 1) * 255).astype(np.uint8), "RGB")
        if result["full"]:
            return picture, parts
        boxes = [self.px(self.rect(frame)) for frame in items(result["frames"]) if self.rect(frame)]
        margin = 24 * scale
        crop = (max(0, min(b[0] for b in boxes) - margin), max(0, min(b[1] for b in boxes) - margin),
                min(picture.width, max(b[2] for b in boxes) + margin),
                min(picture.height, max(b[3] for b in boxes) + margin))
        return picture.crop(crop), parts


# --- pictures ----------------------------------------------------------------------------------

def label_font(size):
    return ImageFont.truetype(PIXEL_FONT, size)


def sheet(rows, columns, gap=36):
    """Pictures in a grid under the column names (the themes)."""
    heads = 64
    widths = [max(row[i].width for row in rows) for i in range(len(columns))]
    heights = [max(image.height for image in row) for row in rows]
    out = Image.new("RGB", (sum(widths) + gap * (len(widths) + 1), heads + sum(heights) + gap * len(rows) + gap // 2),
                    (22, 20, 24))
    draw = ImageDraw.Draw(out)
    x = gap
    for index, name in enumerate(columns):
        draw.text((x, 18), name.upper(), font=label_font(40), fill=(236, 224, 200))
        y = heads
        for row, height in zip(rows, heights):
            image = row[index]
            out.paste(image, (x + (widths[index] - image.width) // 2, y + (height - image.height) // 2))
            y += height + gap
        x += widths[index] + gap
    return out


def main():
    # --lang CODE: every screen in that language (its translation, Locales/CODE.lua), in screens/CODE/
    args = sys.argv[1:]
    lang = None
    if "--lang" in args:
        at = args.index("--lang")
        lang = args[at + 1]
        del args[at:at + 2]
    out = os.path.abspath(args[0]) if args else os.path.join(HERE, "screens", *([lang] if lang else []))
    os.makedirs(out, exist_ok=True)
    painter = Painter()
    painter.lang = lang
    painter.G.Screens.LANGUAGE = lang
    notes = []

    def shot(scene, skin, scale=2):
        picture, parts = painter.render(scene, skin, scale)
        notes.extend(f"[{skin}] {note}" for note in painter.notes)
        return picture, parts

    def pair(name, scene):
        sheet([[shot(scene, skin)[0] for skin in SKINS]], SKINS).save(os.path.join(out, name))
        print("drew", name)

    for old in os.listdir(out):
        if old.endswith(".png"):
            os.remove(os.path.join(out, old))
    pair("1-family.png", "family")
    pair("1b-found.png", "found")
    pair("1c-found-page.png", "foundpage")
    pair("1d-recruit.png", "recruit")
    pair("2-cousin.png", "cousin")
    pair("2b-stats.png", "stats")
    pair("2c-tree.png", "tree")
    rows = [[shot(scene, skin)[0] for skin in SKINS] for scene in ("near", "new", "sheep", "alliance", "ask")]
    sheet(rows, SKINS).save(os.path.join(out, "3-pop-ups.png"))
    print("drew 3-pop-ups.png")
    pair("4-setup-crest.png", "crest")
    pair("5-setup-alerts.png", "alerts")
    pair("5b-setup-map.png", "mapstep")
    pair("5c-setup-guild.png", "guild")
    bits = []
    for skin in SKINS:
        picture, parts = shot("world", skin)
        bits.append([picture.crop((max(0, box[0] - 60), max(0, box[1] - 60), min(picture.width, box[2] + 60),
                                   min(picture.height, box[3] + 60)))
                     for box in (parts["minimap"], parts["tooltip"], parts["chat"])])
    rows = [[bit[i] for bit in bits] for i in range(3)]
    sheet(rows, SKINS).save(os.path.join(out, "6-minimap-tooltip-chat.png"))
    print("drew 6-minimap-tooltip-chat.png")
    for index, skin in enumerate(SKINS):
        name = f"{7 + index}-world-{skin}.png"
        shot("world", skin, 1)[0].save(os.path.join(out, name))
        print("drew", name)
    pair("9-crests.png", "crests")
    pair("10-empty.png", "empty")
    pair("10b-tree-empty.png", "treeless")
    pair("11-probe.png", "probe")
    pair("12-family-map.png", "map")
    for note in dict.fromkeys(notes):
        print("note:", note)


if __name__ == "__main__":
    main()
