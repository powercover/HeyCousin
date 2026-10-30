"""Links the game's AddOns folders to this project with junctions, so the game reads the project
folder itself and nothing is copied. A change needs a /reload; a new file or a TOC change, a game
restart.

python link.py            WoW Forever (_forever_)
python link.py --retail   Retail too, for the test mode. Retail reads HeyCousin_Standard.toc (the
                          Forever client never does), written here from HeyCousin.toc with Retail's
                          interface versions. It stays on this computer (.gitignore): the packager
                          reads every TOC in the repository, and the release stays Forever only.
python link.py --check    whether HeyCousin_Standard.toc, if there is one, still matches HeyCousin.toc

HC_GAME overrides the game folder. A folder already in the link's place is left as it is.
"""
import os
import subprocess
import sys

ROOT = os.environ.get("HC_ROOT", os.path.abspath(os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "..")))
GAME = os.environ.get("HC_GAME", r"C:\Program Files (x86)\World of Warcraft")
ADDON = "HeyCousin"
TOC = os.path.join(ROOT, ADDON + ".toc")
STANDARD_TOC = os.path.join(ROOT, ADDON + "_Standard.toc")
# Retail's interface versions, as the other addon projects list them
RETAIL_INTERFACE = "120100, 120105, 120107"


def standard_toc():
    """HeyCousin.toc as Retail's test mode reads it."""
    lines = ["# Written by tests/kit/link.py --retail from HeyCousin.toc, for Retail's test mode. Never",
             "# committed (.gitignore). Change HeyCousin.toc, then run link.py --retail again.", ""]
    for line in open(TOC, encoding="utf-8").read().splitlines():
        if line.startswith("## Interface:"):
            line = "## Interface: " + RETAIL_INTERFACE
        elif line.startswith("## AllowLoadGameType:"):
            continue
        elif line.startswith("## Title:"):
            line += " (test mode)"
        lines.append(line)
    return "\n".join(lines) + "\n"


def write_standard_toc():
    with open(STANDARD_TOC, "w", encoding="utf-8", newline="\n") as f:
        f.write(standard_toc())
    print("wrote", os.path.basename(STANDARD_TOC))


def link(client):
    addons = os.path.join(GAME, client, "Interface", "AddOns")
    if not os.path.isdir(addons):
        print("%s: no AddOns folder at %s" % (client, addons))
        return False
    path = os.path.join(addons, ADDON)
    if os.path.isjunction(path) or os.path.islink(path):
        target = os.path.realpath(path)
        if os.path.normcase(target) == os.path.normcase(os.path.realpath(ROOT)):
            print("%s: already linked" % client)
            return True
        print("%s: %s links to %s, not this project: left as it is" % (client, path, target))
        return False
    if os.path.exists(path):
        print("%s: a folder is in the link's place (%s): left as it is" % (client, path))
        return False
    subprocess.run(["cmd", "/c", "mklink", "/J", path, ROOT], check=True, capture_output=True)
    print("%s: linked %s -> %s" % (client, path, ROOT))
    return True


def main():
    args = sys.argv[1:]
    if "--check" in args:
        if not os.path.exists(STANDARD_TOC):
            print("standard toc: ok (none here: Retail's test mode isn't linked)")
            return 0
        if open(STANDARD_TOC, encoding="utf-8").read() != standard_toc():
            print("STANDARD TOC FAIL: HeyCousin_Standard.toc doesn't match HeyCousin.toc: run link.py --retail")
            return 1
        print("standard toc: ok (matches HeyCousin.toc)")
        return 0
    ok = link("_forever_")
    if "--retail" in args:
        write_standard_toc()
        ok = link("_retail_") and ok
    return 0 if ok else 1


if __name__ == "__main__":
    sys.exit(main())
