"""The addon's translation keys (its English text), and a check of every locale file against them.

python locale_keys.py                     list the keys
python locale_keys.py --check             check Locales/*.lua: unknown keys, placeholders, color codes
python locale_keys.py --check --release   and every text translated: the check before a release

Texts are written in English while the addon is built and translated before it's released, so a
missing translation fails only with --release.
"""
import glob
import os
import re
import sys

ROOT = os.environ.get("HC_ROOT", os.path.abspath(os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "..")))
os.chdir(ROOT)

LUA_STRING = r'"((?:[^"\\]|\\.)*)"'
# Labels kept in tables and translated where they're shown (L[option.label] and the like).
TABLE_LABELS = []


def unescape(text):
    return text.encode("utf-8").decode("unicode_escape").encode("latin-1").decode("utf-8")


def code_keys():
    keys = set(TABLE_LABELS)
    for path in glob.glob("*.lua"):
        source = open(path, encoding="utf-8").read()
        for match in re.finditer(r'\bL\[' + LUA_STRING + r'\]', source):
            keys.add(unescape(match.group(1)))
    return keys


def placeholders(text):
    return re.findall(r"%[-+ #0]*\d*(?:\.\d+)?[sdifxq]|%%", text)


def color_codes(text):
    return (len(re.findall(r"\|c[0-9a-fA-F]{8}", text)), text.count("|r"))


def locale_strings(path):
    source = open(path, encoding="utf-8").read()
    pairs = re.findall(r'\[' + LUA_STRING + r'\]\s*=\s*' + LUA_STRING, source)
    return [(unescape(key), unescape(value)) for key, value in pairs]


def check(release):
    keys = code_keys()
    problems = 0
    untranslated = {}
    for path in sorted(glob.glob("Locales/*.lua")):
        if path.endswith("Locales.lua"):
            continue
        pairs = locale_strings(path)
        seen = {}
        for key, value in pairs:
            if key in seen:
                print(f"{path}: duplicate key {key!r}")
                problems += 1
            seen[key] = value
            if key not in keys:
                print(f"{path}: unknown key {key!r}")
                problems += 1
                continue
            if placeholders(key) != placeholders(value):
                print(f"{path}: placeholders differ for {key!r}: {placeholders(key)} vs {placeholders(value)}")
                problems += 1
            if color_codes(key) != color_codes(value):
                print(f"{path}: color codes differ for {key!r}")
                problems += 1
            if not value.strip():
                print(f"{path}: empty translation for {key!r}")
                problems += 1
        missing = sorted(keys - set(seen))
        print(f"{os.path.basename(path)}: {len(seen)} translated, {len(missing)} missing")
        if release:
            for key in missing:
                print(f"    missing: {key!r}")
            problems += len(missing)
        elif missing:
            untranslated[os.path.basename(path)] = len(missing)
    if untranslated:
        print(f"not translated yet: up to {max(untranslated.values())} texts in {len(untranslated)} languages"
              " (--release fails on them)")
    print("locale problems:", problems)
    return problems


if __name__ == "__main__":
    if "--check" in sys.argv:
        sys.exit(1 if check("--release" in sys.argv) else 0)
    for key in sorted(code_keys(), key=str.lower):
        print(key)
    print(len(code_keys()), "keys", file=sys.stderr)
