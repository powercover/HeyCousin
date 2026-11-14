"""Makes description-curseforge.md and description-wago.md from description.md.

Each picture's placeholder becomes its address on that site. A picture with no address there yet is left
out, so both files can be pasted at any time. When a site gives new addresses, change them here and run this.
"""
import os
import re

HERE = os.path.dirname(os.path.abspath(__file__))

# placeholder: (CurseForge, Wago); None until it's uploaded there
ADDRESSES = {
    "IMAGE_EMBLEM": (None, None),
    "IMAGE_FIND": (None, None),
    "IMAGE_TOGETHER": (None, None),
    "IMAGE_EVERYWHERE": (None, None),
    "IMAGE_HOUSE": (None, None),
}


def build(name, site):
    with open(os.path.join(HERE, "description.md"), encoding="utf-8", newline="") as source:
        text = source.read().replace("\r\n", "\n")
    for placeholder, addresses in ADDRESSES.items():
        address = addresses[site]
        if address:
            text = text.replace("(" + placeholder + ")", "(" + address + ")")
        else:
            text = re.sub(r"!\[[^\]]*\]\(" + placeholder + r"\)\n\n?", "", text)
    left = re.findall(r"IMAGE_[A-Z]+", text)
    assert not left, left
    text = text.lstrip("\n")
    with open(os.path.join(HERE, name), "w", encoding="utf-8", newline="\n") as out:
        out.write(text)
    print("wrote", name, sum(1 for line in text.split("\n") if line.startswith("![")), "pictures")


build("description-curseforge.md", 0)
build("description-wago.md", 1)
