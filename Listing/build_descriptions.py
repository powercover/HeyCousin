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
    "IMAGE_FIND": ("https://media.forgecdn.net/attachments/2206/410/find-png.png",
                   "https://cdn.wago.io/gallery/u6ZwgDzerRrLLLgmiuOY5IjSFRukXPQ43epbySbc.png"),
    "IMAGE_TOGETHER": ("https://media.forgecdn.net/attachments/2206/411/together-png.png",
                       "https://cdn.wago.io/gallery/dkin8PIqTsEFsDUVlyoQXPJJFSz8gGkmvUll4ZKx.png"),
    "IMAGE_EVERYWHERE": ("https://media.forgecdn.net/attachments/2206/413/everywhere-png.png",
                         "https://cdn.wago.io/gallery/SGbfK6tAlv47TyPSDDrNNR5BT0id1MkCZY24BTLb.png"),
    "IMAGE_HOUSE": ("https://media.forgecdn.net/attachments/2206/414/house-png.png",
                    "https://cdn.wago.io/gallery/YtI0RhPdf6XR0bVRH2HrIt27zHXGQcsDRzoV9iWQ.png"),
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
