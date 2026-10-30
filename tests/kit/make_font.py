"""Builds the addon's own pixel font, Hey Cousin Pixel (Media/Fonts/HeyCousinPixel.ttf): every
letter drawn here by hand, then written as a TrueType file with no outside tool. It's part of
the addon, all rights reserved.

python make_font.py                  the font
python make_font.py --preview OUT    also a sample sheet (PNG) at OUT

All capitals, as Kingdom-style titles and buttons are: small letters show as capitals. A font
pixel is 100 units, the em 10 pixels (8 up, 2 down), capitals 6 pixels tall: at 20 px the
pixels are 2 screen pixels, at 30 px 3, so it stays sharp. Latin with the accents of Europe's
languages (Latin-1, Latin Extended-A), Cyrillic for Russian and Ukrainian, the punctuation the
addon's texts use. Accented letters are a base letter and an accent put together.
"""
import os
import struct
import sys
import time

ROOT = os.environ.get("HC_ROOT", os.path.abspath(os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "..")))
OUT = os.path.join(ROOT, "Media", "Fonts", "HeyCousinPixel.ttf")
PX = 100        # font units per pixel
CAP = 6         # capital height, in pixels
ASCENT, DESCENT = 8, 2
FAMILY = "Hey Cousin Pixel"
COPYRIGHT = "Copyright 2026 powercover. All rights reserved."

# --- the letters: rows from the top, '#' a pixel; (rows, top) where `top` is how many pixels
# above the baseline the first row starts (a capital: 6) --------------------------------------

def C(*rows):
    return (list(rows), CAP)


GLYPHS = {
    "A": C(".##.", "#..#", "#..#", "####", "#..#", "#..#"),
    "B": C("###.", "#..#", "###.", "#..#", "#..#", "###."),
    "C": C(".###", "#...", "#...", "#...", "#...", ".###"),
    "D": C("###.", "#..#", "#..#", "#..#", "#..#", "###."),
    "E": C("####", "#...", "###.", "#...", "#...", "####"),
    "F": C("####", "#...", "###.", "#...", "#...", "#..."),
    "G": C(".###", "#...", "#...", "#.##", "#..#", ".###"),
    "H": C("#..#", "#..#", "####", "#..#", "#..#", "#..#"),
    "I": C("###", ".#.", ".#.", ".#.", ".#.", "###"),
    "J": C("..##", "...#", "...#", "...#", "#..#", ".##."),
    "K": C("#..#", "#.#.", "##..", "#.#.", "#..#", "#..#"),
    "L": C("#...", "#...", "#...", "#...", "#...", "####"),
    "M": C("#...#", "##.##", "#.#.#", "#...#", "#...#", "#...#"),
    "N": C("#...#", "##..#", "#.#.#", "#..##", "#...#", "#...#"),
    "O": C(".##.", "#..#", "#..#", "#..#", "#..#", ".##."),
    "P": C("###.", "#..#", "#..#", "###.", "#...", "#..."),
    "Q": C(".##.", "#..#", "#..#", "#..#", "#.#.", ".#.#"),
    "R": C("###.", "#..#", "#..#", "###.", "#.#.", "#..#"),
    "S": C(".###", "#...", ".##.", "...#", "...#", "###."),
    "T": C("#####", "..#..", "..#..", "..#..", "..#..", "..#.."),
    "U": C("#..#", "#..#", "#..#", "#..#", "#..#", ".##."),
    "V": C("#...#", "#...#", "#...#", ".#.#.", ".#.#.", "..#.."),
    "W": C("#...#", "#...#", "#...#", "#.#.#", "##.##", "#...#"),
    "X": C("#...#", ".#.#.", "..#..", "..#..", ".#.#.", "#...#"),
    "Y": C("#...#", "#...#", ".#.#.", "..#..", "..#..", "..#.."),
    "Z": C("####", "...#", "..#.", ".#..", "#...", "####"),
    "0": C(".##.", "#..#", "#.##", "##.#", "#..#", ".##."),
    "1": C(".#.", "##.", ".#.", ".#.", ".#.", "###"),
    "2": C(".##.", "#..#", "...#", "..#.", ".#..", "####"),
    "3": C("###.", "...#", ".##.", "...#", "...#", "###."),
    "4": C("#..#", "#..#", "####", "...#", "...#", "...#"),
    "5": C("####", "#...", "###.", "...#", "...#", "###."),
    "6": C(".##.", "#...", "###.", "#..#", "#..#", ".##."),
    "7": C("####", "...#", "..#.", ".#..", ".#..", ".#.."),
    "8": C(".##.", "#..#", ".##.", "#..#", "#..#", ".##."),
    "9": C(".##.", "#..#", "#..#", ".###", "...#", ".##."),
    # punctuation
    "!": (["#", "#", "#", "#", ".", "#"], 6),
    '"': (["#.#", "#.#"], 6),
    "#": ([".#.#.", "#####", ".#.#.", "#####", ".#.#."], 5),
    "$": (["..#..", ".####", "#.#..", ".###.", "..#.#", "####.", "..#.."], 6),
    "%": (["#...#", "...#.", "..#..", ".#...", "#...#"], 5),
    "&": ([".##..", "#..#.", ".##..", "#.#.#", "#..#.", ".##.#"], 6),
    "'": (["#", "#"], 6),
    "(": ([".#", "#.", "#.", "#.", "#.", ".#"], 6),
    ")": (["#.", ".#", ".#", ".#", ".#", "#."], 6),
    "*": (["#.#", ".#.", "#.#"], 5),
    "+": ([".#.", "###", ".#."], 4),
    ",": ([".#", "#."], 1),
    "-": (["###"], 3),
    ".": (["#"], 1),
    "/": (["..#", "..#", ".#.", ".#.", "#..", "#.."], 6),
    ":": (["#", ".", "#"], 4),
    ";": ([".#", "..", ".#", "#."], 4),
    "<": (["..#", ".#.", "#..", ".#.", "..#"], 5),
    "=": (["###", "...", "###"], 4),
    ">": (["#..", ".#.", "..#", ".#.", "#.."], 5),
    "?": ([".##.", "#..#", "..#.", ".#..", "....", ".#.."], 6),
    "@": ([".###.", "#...#", "#.###", "#.#.#", "#.###", ".#..."], 6),
    "[": (["##", "#.", "#.", "#.", "#.", "##"], 6),
    "\\": (["#..", "#..", ".#.", ".#.", "..#", "..#"], 6),
    "]": (["##", ".#", ".#", ".#", ".#", "##"], 6),
    "^": ([".#.", "#.#"], 6),
    "_": (["####"], 0),
    "`": (["#.", ".#"], 6),
    "{": ([".##", ".#.", "#..", ".#.", ".#.", ".##"], 6),
    "|": (["#", "#", "#", "#", "#", "#"], 6),
    "}": (["##.", ".#.", "..#", ".#.", ".#.", "##."], 6),
    "~": ([".#.#", "#.#."], 4),
    "¡": (["#", ".", "#", "#", "#", "#"], 4),                   # ¡
    "¿": ([".#..", "....", ".#..", "#...", "#..#", ".##."], 4),  # ¿
    "«": ([".#.#", "#.#.", ".#.#"], 4),                         # «
    "»": (["#.#.", ".#.#", "#.#."], 4),                         # »
    "·": (["#"], 4),                                            # ·
    "°": (["###", "#.#", "###"], 6),                            # °
    "×": (["#.#", ".#.", "#.#"], 4),                            # ×
    "–": (["####"], 3),                                         # –
    "—": (["######"], 3),                                       # —
    "…": (["#.#.#"], 1),                                        # …
    "•": (["##", "##"], 4),                                     # •
    "‹": ([".#", "#.", ".#"], 4),                               # ‹
    "›": (["#.", ".#", "#."], 4),                               # ›
    "„": (["#.#", "#.#"], 1),                                   # „
    # letters of their own (Latin)
    "ß": C(".##.", "#..#", "#.#.", "#..#", "#..#", "#.#."),       # ß
    "Æ": C(".####", "#.#..", "#.##.", "###..", "#.#..", "#.###"),  # Æ
    "Ø": C(".###", "#.##", "#.##", "##.#", "##.#", "###."),       # Ø
    "Ð": C(".###.", ".#..#", "###.#", ".#..#", ".#..#", ".###."),  # Ð
    "Þ": C("#...", "###.", "#..#", "###.", "#...", "#..."),       # Þ
    "Œ": C(".####", "#.#..", "#.###", "#.#..", "#.#..", ".####"),  # Œ
    "Ł": C(".#..", ".#..", ".##.", "##..", ".#..", ".###"),       # Ł
    "Ħ": C("#..#", "####", "#..#", "####", "#..#", "#..#"),       # Ħ
    # Cyrillic letters of their own (the rest look like Latin ones)
    "Б": C("####", "#...", "###.", "#..#", "#..#", "###."),       # Б
    "Г": C("####", "#...", "#...", "#...", "#...", "#..."),       # Г
    "Ґ": (["...#", "####", "#...", "#...", "#...", "#...", "#..."], 7),  # Ґ
    "Д": (["..##.", ".#.#.", ".#.#.", ".#.#.", ".#.#.", "#####", "#...#"], 6),  # Д
    "Ж": C("#.#.#", "#.#.#", ".###.", ".###.", "#.#.#", "#.#.#"),  # Ж
    "З": C("###.", "...#", ".##.", "...#", "...#", "###."),       # З
    "И": C("#...#", "#..##", "#.#.#", "##..#", "#...#", "#...#"),  # И
    "Л": C("..###", ".#..#", ".#..#", ".#..#", ".#..#", "#...#"),  # Л
    "П": C("####", "#..#", "#..#", "#..#", "#..#", "#..#"),       # П
    "У": C("#..#", "#..#", "#..#", ".###", "...#", ".##."),       # У
    "Ф": C("..#..", ".###.", "#.#.#", "#.#.#", ".###.", "..#.."),  # Ф
    "Ц": (["#..#.", "#..#.", "#..#.", "#..#.", "#..#.", "#####", "....#"], 6),  # Ц
    "Ч": C("#..#", "#..#", "#..#", ".###", "...#", "...#"),       # Ч
    "Ш": C("#.#.#", "#.#.#", "#.#.#", "#.#.#", "#.#.#", "#####"),  # Ш
    "Щ": (["#.#.#.", "#.#.#.", "#.#.#.", "#.#.#.", "#.#.#.", "######", ".....#"], 6),  # Щ
    "Ъ": C("##...", ".#...", ".###.", ".#..#", ".#..#", ".###."),  # Ъ
    "Ы": C("#...#", "#...#", "###.#", "#..##", "#..##", "###.#"),  # Ы
    "Ь": C("#...", "#...", "###.", "#..#", "#..#", "###."),       # Ь
    "Э": C("###.", "...#", ".###", "...#", "...#", "###."),       # Э
    "Ю": C("#..#.", "#.#.#", "###.#", "#.#.#", "#.#.#", "#..#."),  # Ю
    "Я": C(".###", "#..#", "#..#", ".###", ".#.#", "#..#"),       # Я
    "Є": C(".###", "#...", "###.", "#...", "#...", ".###"),       # Є
}

# Cyrillic letters drawn as the Latin ones that look the same
SAME = {
    "А": "A", "В": "B", "Е": "E", "К": "K", "М": "M", "Н": "H", "О": "O",
    "Р": "P", "С": "C", "Т": "T", "Х": "X", "Ѕ": "S", "І": "I", "Ј": "J",
    # rare letters, drawn as their nearest
    "ı": "I", "ĸ": "K", "Ŀ": "L", "ŉ": "N", "Ŋ": "N", "Ŧ": "T", "ſ": "S",
    "Đ": "Ð", "Ĳ": "J",
    # quotes
    "‘": "'", "’": "'", "‚": ",", "“": '"', "”": '"', " ": " ",
}

ACCENTS = {
    "acute": [".#", "#."],
    "grave": ["#.", ".#"],
    "circumflex": [".#.", "#.#"],
    "caron": ["#.#", ".#."],
    "breve": ["#..#", ".##."],
    "tilde": [".#.#", "#.#."],
    "diaeresis": ["#.#"],
    "macron": ["###"],
    "dot": ["#"],
    "ring": ["##", "##"],
    "cedilla": [".#", "#."],   # below
    "ogonek": ["#.", ".#"],    # below, at the right
}
BELOW = {"cedilla", "ogonek"}

# accented capitals: the letter and its accent
COMPOSED = {}
for letters, accent in [
    ("ÀÈÌÒÙ", "grave"), ("ÁÉÍÓÚÝ", "acute"),
    ("ÂÊÎÔÛ", "circumflex"), ("ÃÑÕ", "tilde"),
    ("ÄËÏÖÜŸ", "diaeresis"), ("Å", "ring"), ("Ç", "cedilla"),
]:
    for ch in letters:
        base = {"À": "A", "Á": "A", "Â": "A", "Ã": "A", "Ä": "A", "Å": "A", "Ç": "C",
                "È": "E", "É": "E", "Ê": "E", "Ë": "E", "Ì": "I", "Í": "I", "Î": "I",
                "Ï": "I", "Ñ": "N", "Ò": "O", "Ó": "O", "Ô": "O", "Õ": "O", "Ö": "O",
                "Ù": "U", "Ú": "U", "Û": "U", "Ü": "U", "Ý": "Y", "Ÿ": "Y"}[ch]
        COMPOSED[ch] = (base, accent)
EXTENDED = {
    "Ā": ("A", "macron"), "Ă": ("A", "breve"), "Ą": ("A", "ogonek"), "Ć": ("C", "acute"),
    "Ĉ": ("C", "circumflex"), "Ċ": ("C", "dot"), "Č": ("C", "caron"), "Ď": ("D", "caron"),
    "Ē": ("E", "macron"), "Ĕ": ("E", "breve"), "Ė": ("E", "dot"), "Ę": ("E", "ogonek"),
    "Ě": ("E", "caron"), "Ĝ": ("G", "circumflex"), "Ğ": ("G", "breve"), "Ġ": ("G", "dot"),
    "Ģ": ("G", "cedilla"), "Ĥ": ("H", "circumflex"), "Ĩ": ("I", "tilde"), "Ī": ("I", "macron"),
    "Ĭ": ("I", "breve"), "Į": ("I", "ogonek"), "İ": ("I", "dot"), "Ĵ": ("J", "circumflex"),
    "Ķ": ("K", "cedilla"), "Ĺ": ("L", "acute"), "Ļ": ("L", "cedilla"), "Ľ": ("L", "caron"),
    "Ń": ("N", "acute"), "Ņ": ("N", "cedilla"), "Ň": ("N", "caron"), "Ō": ("O", "macron"),
    "Ŏ": ("O", "breve"), "Ő": ("O", "diaeresis"), "Ŕ": ("R", "acute"), "Ŗ": ("R", "cedilla"),
    "Ř": ("R", "caron"), "Ś": ("S", "acute"), "Ŝ": ("S", "circumflex"), "Ş": ("S", "cedilla"),
    "Š": ("S", "caron"), "Ţ": ("T", "cedilla"), "Ť": ("T", "caron"), "Ũ": ("U", "tilde"),
    "Ū": ("U", "macron"), "Ŭ": ("U", "breve"), "Ů": ("U", "ring"), "Ű": ("U", "diaeresis"),
    "Ų": ("U", "ogonek"), "Ŵ": ("W", "circumflex"), "Ŷ": ("Y", "circumflex"), "Ź": ("Z", "acute"),
    "Ż": ("Z", "dot"), "Ž": ("Z", "caron"),
    # Cyrillic
    "Ё": ("Е", "diaeresis"), "Ї": ("І", "diaeresis"), "Й": ("И", "breve"),
    "Ў": ("У", "breve"), "Ѐ": ("Е", "grave"), "Ѝ": ("И", "grave"),
    "Ѓ": ("Г", "acute"), "Ќ": ("К", "acute"),
}
COMPOSED.update(EXTENDED)


def bitmap(ch):
    """The letter as (rows, top), following look-alikes and putting accents on."""
    if ch in SAME:
        return bitmap(SAME[ch])
    if ch in GLYPHS:
        return GLYPHS[ch]
    if ch in COMPOSED:
        base, accent = COMPOSED[ch]
        rows, top = bitmap(base)
        width = max(len(r) for r in rows)
        mark = ACCENTS[accent]
        if accent == "diaeresis" and width >= 4:
            mark = ["#" + "." * (width - 2) + "#"]
        if accent == "macron":
            mark = ["#" * width]
        mw = max(len(r) for r in mark)
        if accent == "ogonek":
            x = width - mw
        else:
            x = (width - mw + 1) // 2
        rows = [r.ljust(width, ".") for r in rows]
        if accent in BELOW:
            # under the baseline: rows from `top` on
            out = rows + ["." * width] * max(0, top + len(mark) - len(rows))
            for i, line in enumerate(mark):
                row = list(out[top + i])
                for j, c in enumerate(line):
                    if c == "#":
                        row[x + j] = "#"
                out[top + i] = "".join(row)
            return out, top
        # above: a gap, then the accent
        lifted = [("." * x + line).ljust(width, ".") for line in mark]
        return lifted + ["." * width] + rows, top + len(mark) + 1
    return None


def characters():
    """Every character the font draws: its own and look-alike letters, accented ones, and the
    small letters (drawn as capitals)."""
    chars = {" ": None}
    for ch in list(GLYPHS) + list(SAME) + list(COMPOSED):
        chars[ch] = None if SAME.get(ch) == " " else ch
    for code in list(range(0x20, 0x7F)) + list(range(0xA0, 0x180)) + list(range(0x400, 0x460)) + [0x491]:
        ch = chr(code)
        upper = ch.upper()
        if ch not in chars and len(upper) == 1 and upper in chars:
            chars[ch] = upper
    return chars


# --- outlines ----------------------------------------------------------------------------------

def contours(rows, top):
    """The pixels as rectangles (a row's runs, merged down while they stay alike), each a
    clockwise contour."""
    open_rects, done = {}, []
    for r, line in enumerate(rows):
        runs, x = [], 0
        while x < len(line):
            if line[x] == "#":
                start = x
                while x < len(line) and line[x] == "#":
                    x += 1
                runs.append((start, x))
            else:
                x += 1
        y_top, y_bottom = top - r, top - r - 1
        still = {}
        for run in runs:
            if run in open_rects:
                still[run] = (open_rects[run][0], y_bottom)
            else:
                still[run] = (y_top, y_bottom)
        for run, ys in open_rects.items():
            if run not in still:
                done.append((run, ys))
        open_rects = still
    done += list(open_rects.items())
    out = []
    for (x0, x1), (y1, y0) in done:
        x0, x1, y0, y1 = x0 * PX, x1 * PX, y0 * PX, y1 * PX
        out.append([(x0, y1), (x1, y1), (x1, y0), (x0, y0)])
    return out


def glyph_data(paths):
    if not paths:
        return b"", (0, 0, 0, 0)
    xs = [p[0] for c in paths for p in c]
    ys = [p[1] for c in paths for p in c]
    box = (min(xs), min(ys), max(xs), max(ys))
    data = struct.pack(">hhhhh", len(paths), *box)
    ends, n = [], -1
    for c in paths:
        n += len(c)
        ends.append(n)
    data += struct.pack(">%dH" % len(ends), *ends)
    data += struct.pack(">H", 0)  # no instructions
    points = [p for c in paths for p in c]
    data += bytes([1] * len(points))  # on-curve, full 16-bit deltas
    last = 0
    for x, _ in points:
        data += struct.pack(">h", x - last)
        last = x
    last = 0
    for _, y in points:
        data += struct.pack(">h", y - last)
        last = y
    while len(data) % 4:
        data += b"\0"
    return data, box


# --- the TrueType file -------------------------------------------------------------------------

def checksum(data):
    data = data + b"\0" * (-len(data) % 4)
    return sum(struct.unpack(">%dI" % (len(data) // 4), data)) & 0xFFFFFFFF


def cmap_table(mapping):
    codes = sorted(c for c in mapping if c <= 0xFFFF)
    segments = []
    for code in codes:
        glyph = mapping[code]
        if segments and code == segments[-1][1] + 1 and glyph - code == segments[-1][2]:
            segments[-1][1] = code
        else:
            segments.append([code, code, glyph - code])
    segments.append([0xFFFF, 0xFFFF, 1])
    count = len(segments)
    search = 2 ** (count.bit_length() - 1) * 2
    sub = struct.pack(">HHHHHHH", 4, 16 + 8 * count, 0, count * 2, search, (search // 2).bit_length() - 1,
                      count * 2 - search)
    sub += struct.pack(">%dH" % count, *[s[1] for s in segments])
    sub += struct.pack(">H", 0)
    sub += struct.pack(">%dH" % count, *[s[0] for s in segments])
    sub += struct.pack(">%dH" % count, *[(s[2]) & 0xFFFF for s in segments])
    sub += struct.pack(">%dH" % count, *[0] * count)
    return struct.pack(">HH", 0, 2) + struct.pack(">HHI", 0, 3, 20) + struct.pack(">HHI", 3, 1, 20) + sub


def name_table():
    names = {0: COPYRIGHT, 1: FAMILY, 2: "Regular", 3: FAMILY + " 1.0", 4: FAMILY, 5: "Version 1.000",
             6: "HeyCousinPixel-Regular", 13: "All rights reserved."}
    records, storage = b"", b""
    for name_id, text in sorted(names.items()):
        raw = text.encode("utf-16-be")
        records += struct.pack(">HHHHHH", 3, 1, 0x409, name_id, len(raw), len(storage))
        storage += raw
    return struct.pack(">HHH", 0, len(names), 6 + len(names) * 12) + records + storage


def build():
    chars = characters()
    # glyph 0 is .notdef (a hollow box), glyph 1 the space
    images = {}
    for ch, source in chars.items():
        if source is not None and source not in images:
            images[source] = bitmap(source)
    order = sorted(images)
    glyph_of = {ch: i + 2 for i, ch in enumerate(order)}
    glyphs, metrics = [], []
    notdef = [[(0, 600), (400, 600), (400, 0), (0, 0)], [(100, 500), (100, 100), (300, 100), (300, 500)]]
    data, gbox = glyph_data(notdef)
    glyphs.append((data, gbox))
    metrics.append((500, 0))
    glyphs.append((b"", (0, 0, 0, 0)))
    metrics.append((3 * PX, 0))
    max_points = max_contours = 0
    for ch in order:
        rows, top = images[ch]
        paths = contours(rows, top)
        data, gbox = glyph_data(paths)
        glyphs.append((data, gbox))
        width = max(len(r) for r in rows)
        metrics.append(((width + 1) * PX, gbox[0] if paths else 0))
        max_points = max(max_points, sum(len(c) for c in paths))
        max_contours = max(max_contours, len(paths))
    mapping = {}
    for ch, source in chars.items():
        mapping[ord(ch)] = 1 if source is None else glyph_of[source]
    count = len(glyphs)
    glyf, loca, offset = b"", [], 0
    for data, _ in glyphs:
        loca.append(offset)
        glyf += data
        offset += len(data)
    loca.append(offset)
    boxes = [b for d, b in glyphs if d]
    x_min, y_min = min(b[0] for b in boxes), min(b[1] for b in boxes)
    x_max, y_max = max(b[2] for b in boxes), max(b[3] for b in boxes)
    advance_max = max(m[0] for m in metrics)
    now = int(time.time()) + 2082844800  # seconds since 1904
    head = struct.pack(">IIIIHHqqhhhhHHhhh", 0x00010000, 0x00010000, 0, 0x5F0F3CF5, 0x000B, 10 * PX, now, now,
                       x_min, y_min, x_max, y_max, 0, 8, 2, 1, 0)
    hhea = struct.pack(">IhhhHhhhhhhhhhhhH", 0x00010000, ASCENT * PX, -DESCENT * PX, 0, advance_max, 0, 0, x_max,
                       1, 0, 0, 0, 0, 0, 0, 0, count)
    maxp = struct.pack(">IHHHHHHHHHHHHHH", 0x00010000, count, max(max_points, 8), max(max_contours, 2), 0, 0, 2, 0,
                       0, 0, 0, 0, 0, 0, 0)
    hmtx = b"".join(struct.pack(">Hh", adv, lsb) for adv, lsb in metrics)
    average = sum(m[0] for m in metrics[2:]) // max(1, len(metrics) - 2)
    first, last = min(mapping), min(max(mapping), 0xFFFF)
    # version, average width, weight, width, embedding; sub- and superscript sizes and offsets;
    # strikeout size and place; family class
    os2 = struct.pack(">HhHHHhhhhhhhhhhh", 4, average, 400, 5, 0, 300, 300, 0, 75, 300, 300, 0, 350, 50, 300, 0)
    os2 += bytes(10)  # panose
    os2 += struct.pack(">IIII", (1 << 0) | (1 << 1) | (1 << 2) | (1 << 9) | (1 << 31), 0, 0, 0)
    os2 += b"HCSN"
    os2 += struct.pack(">HHHhhhHH", 0x0040, first, last, ASCENT * PX, -DESCENT * PX, 0, (ASCENT + 2) * PX,
                       (DESCENT + 1) * PX)
    os2 += struct.pack(">II", 0b111, 0)
    os2 += struct.pack(">hhHHH", CAP * PX, CAP * PX, 0, 32, 1)
    post = struct.pack(">IIhhIIIII", 0x00030000, 0, -PX, PX, 0, 0, 0, 0, 0)
    tables = {
        "OS/2": os2, "cmap": cmap_table(mapping), "glyf": glyf, "head": head, "hhea": hhea, "hmtx": hmtx,
        "loca": struct.pack(">%dI" % len(loca), *loca), "maxp": maxp, "name": name_table(), "post": post,
    }
    tags = sorted(tables)
    n = len(tags)
    search = 2 ** (n.bit_length() - 1) * 16
    font = struct.pack(">IHHHH", 0x00010000, n, search, (search // 16).bit_length() - 1, n * 16 - search)
    offset = 12 + 16 * n
    directory, body = b"", b""
    for tag in tags:
        data = tables[tag]
        directory += struct.pack(">4sIII", tag.encode("latin-1"), checksum(data), offset, len(data))
        padded = data + b"\0" * (-len(data) % 4)
        body += padded
        offset += len(padded)
    font += directory + body
    # the whole file's checksum goes in head's checkSumAdjustment
    head_at = 12 + 16 * n + sum(len(tables[t]) + (-len(tables[t]) % 4) for t in tags[:tags.index("head")])
    adjust = (0xB1B0AFBA - checksum(font)) & 0xFFFFFFFF
    font = font[:head_at + 8] + struct.pack(">I", adjust) + font[head_at + 12:]
    os.makedirs(os.path.dirname(OUT), exist_ok=True)
    with open(OUT, "wb") as f:
        f.write(font)
    print("%s: %d glyphs, %d characters, %d bytes" % (OUT, count, len(mapping), len(font)))
    return chars


def preview(path):
    from PIL import Image, ImageDraw, ImageFont
    lines = ["A cousin is near!  House Ashbrook", "Join their layer  Whisper  Invite  Next  Done",
             "Your cousin joined the Horde!  12 relatives", "Кузен рядом! "
             "Дім Ашбрук ЄІЇҐ щжфюя",
             "Ça va? ¿Primo? ÄÖÜ ß ÅÆØ Łódź "
             "Čřš 0123456789"]
    img = Image.new("RGB", (900, 330), (60, 43, 42))
    d = ImageDraw.Draw(img)
    y = 10
    for size in (20, 30):
        font = ImageFont.truetype(OUT, size)
        for line in lines:
            for dx, dy in ((-1, 0), (1, 0), (0, -1), (0, 1)):
                d.text((12 + dx, y + dy), line, font=font, fill=(28, 19, 20))
            d.text((12, y), line, font=font, fill=(244, 228, 196))
            y += int(size * 1.15) + 2
        y += 8
    img.save(path)
    print("preview:", path)


if __name__ == "__main__":
    build()
    if "--preview" in sys.argv:
        preview(sys.argv[sys.argv.index("--preview") + 1])
