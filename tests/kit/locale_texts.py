"""Every text the addon shows (its translation keys), for translators: in the order the game loads
the addon's files, each with where it shows (its file, line and line of code), grouped by file.

python locale_texts.py                  every text
python locale_texts.py --missing CODE   only the texts Locales/CODE.lua doesn't translate yet

The labels kept in tables (locale_keys.TABLE_LABELS) show with the line their table is on.
"""
import os
import re
import sys

from locale_keys import LUA_STRING, TABLE_LABELS, locale_strings, unescape

sys.stdout.reconfigure(encoding="utf-8")


def toc_files():
    files = []
    for raw in open("HeyCousin.toc", encoding="utf-8"):
        line = raw.strip()
        if line and not line.startswith("#") and not line.lower().startswith("locales"):
            files.append(line.replace("\\", "/"))
    return files


def texts():
    seen, order = {}, []
    sources = {path: open(path, encoding="utf-8").read().split("\n") for path in toc_files()}
    for path, lines in sources.items():
        for number, line in enumerate(lines, 1):
            for match in re.finditer(r'\bL\[' + LUA_STRING + r'\]', line):
                key = unescape(match.group(1))
                if key in seen:
                    seen[key]["also"].append(f"{path}:{number}")
                    continue
                seen[key] = {"key": key, "file": path, "line": number, "code": line.strip(), "also": []}
                order.append(seen[key])
    for label in TABLE_LABELS:
        if label in seen:
            continue
        for path, lines in sources.items():
            number = next((n for n, line in enumerate(lines, 1) if f'"{label}"' in line), None)
            if number:
                seen[label] = {"key": label, "file": path, "line": number, "code": lines[number - 1].strip(),
                               "also": [], "table": True}
                order.append(seen[label])
                break
    # in the order of the files, each file's texts in the order of their lines
    rank = {path: index for index, path in enumerate(toc_files())}
    order.sort(key=lambda entry: (rank[entry["file"]], entry["line"]))
    return order


def main():
    only = None
    if "--missing" in sys.argv:
        code = sys.argv[sys.argv.index("--missing") + 1]
        done = {key for key, _ in locale_strings(os.path.join("Locales", code + ".lua"))}
        only = lambda key: key not in done
    current = None
    count = 0
    for entry in texts():
        if only and not only(entry["key"]):
            continue
        if entry["file"] != current:
            current = entry["file"]
            print(f"\n== {current} ==")
        count += 1
        print(f"- {entry['key']!r}")
        where = "in a table of labels, " if entry.get("table") else ""
        print(f"    {where}line {entry['line']}: {entry['code'][:150]}")
        if entry["also"]:
            print(f"    also: {', '.join(entry['also'][:4])}")
    print(f"\n{count} texts", file=sys.stderr)


if __name__ == "__main__":
    main()
