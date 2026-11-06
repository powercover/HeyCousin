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
    "IMAGE_FOUND": ("https://media.forgecdn.net/attachments/2158/173/found-png.png",
                 "https://cdn.wago.io/gallery/HO2UjIkBq20Z4TB2bGA95Z8NBsl0raaFjRWZiMqi.png"),
    "IMAGE_PAGE": ("https://media.forgecdn.net/attachments/2158/179/page-png.png",
                "https://cdn.wago.io/gallery/LzjDreoTZii1dGhgdgtKZbmq9k0HoJQG9wHSsna7.png"),
    "IMAGE_CRESTS": ("https://media.forgecdn.net/attachments/2158/183/crests-png.png",
                  "https://cdn.wago.io/gallery/HHHBUQ9XK1szpaVraUmtZo1jrvJGgFBfRJCSXArS.png"),
    "IMAGE_TREE": ("https://media.forgecdn.net/attachments/2158/182/tree-png.png",
                "https://cdn.wago.io/gallery/KmflmYpZWqHuVA7N3IkpoGIsCYfdcFMcWPVmNRcv.png"),
    "IMAGE_LOOKS": ("https://media.forgecdn.net/attachments/2158/181/looks-png.png",
                 "https://cdn.wago.io/gallery/1wiWqHacqtD5SbhnZ36LuSg5db75LpdidglQ1f4G.png"),
    "IMAGE_MAP": ("https://media.forgecdn.net/attachments/2158/174/map-png.png",
               None),
    "IMAGE_GROUPS": ("https://media.forgecdn.net/attachments/2158/176/groups-png.png",
                  None),
    "IMAGE_HEY": ("https://media.forgecdn.net/attachments/2158/175/hey-png.png",
               None),
    "IMAGE_PLATES": ("https://media.forgecdn.net/attachments/2158/177/nameplates-png.png",
                  None),
    "IMAGE_RACE": ("https://media.forgecdn.net/attachments/2158/180/race-png.png",
                None),
    "IMAGE_PORTRAIT": ("https://media.forgecdn.net/attachments/2158/178/portrait-png.png",
                    None),
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
