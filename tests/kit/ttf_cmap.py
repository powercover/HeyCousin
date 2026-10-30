"""The characters a TrueType font can draw: its character map (cmap, formats 4 and 12).

python ttf_cmap.py FONT.ttf [TEXT]    how many characters it has, and which of TEXT's it lacks
"""
import struct
import sys


def characters(path):
    data = open(path, "rb").read()
    tables = {}
    count = struct.unpack_from(">H", data, 4)[0]
    for i in range(count):
        tag, _, offset, length = struct.unpack_from(">4sIII", data, 12 + i * 16)
        tables[tag.decode("latin-1")] = (offset, length)
    base = tables["cmap"][0]
    subtables = struct.unpack_from(">H", data, base + 2)[0]
    best = None
    for i in range(subtables):
        platform, encoding, offset = struct.unpack_from(">HHI", data, base + 4 + i * 8)
        fmt = struct.unpack_from(">H", data, base + offset)[0]
        if platform in (0, 3) and fmt in (4, 12) and (best is None or fmt == 12):
            best = (fmt, base + offset)
    if best is None:
        raise ValueError("no Unicode character map in " + path)
    fmt, at = best
    chars = set()
    if fmt == 12:
        groups = struct.unpack_from(">I", data, at + 12)[0]
        for g in range(groups):
            start, end, glyph = struct.unpack_from(">III", data, at + 16 + g * 12)
            for code in range(start, end + 1):
                if glyph + code - start:
                    chars.add(code)
        return chars
    segments = struct.unpack_from(">H", data, at + 6)[0] // 2
    ends = struct.unpack_from(">%dH" % segments, data, at + 14)
    starts = struct.unpack_from(">%dH" % segments, data, at + 16 + segments * 2)
    deltas = struct.unpack_from(">%dh" % segments, data, at + 16 + segments * 4)
    range_at = at + 16 + segments * 6
    offsets = struct.unpack_from(">%dH" % segments, data, range_at)
    for i in range(segments):
        for code in range(starts[i], ends[i] + 1):
            if code == 0xFFFF:
                continue
            if offsets[i] == 0:
                glyph = (code + deltas[i]) & 0xFFFF
            else:
                where = range_at + i * 2 + offsets[i] + (code - starts[i]) * 2
                glyph = struct.unpack_from(">H", data, where)[0]
                if glyph:
                    glyph = (glyph + deltas[i]) & 0xFFFF
            if glyph:
                chars.add(code)
    return chars


if __name__ == "__main__":
    sys.stdout.reconfigure(encoding="utf-8")
    found = characters(sys.argv[1])
    print(len(found), "characters")
    if len(sys.argv) > 2:
        missing = sorted({c for c in sys.argv[2] if ord(c) not in found and not c.isspace()})
        print("missing:", " ".join("%s U+%04X" % (c, ord(c)) for c in missing) or "none")
