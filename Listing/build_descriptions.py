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
                 "https://cdn.wago.io/gallery/eQoZCxlAlIIByXkjVRSDpsgvlYD3f4jazsoHPffH.png"),
    "IMAGE_PAGE": ("https://media.forgecdn.net/attachments/2158/179/page-png.png",
                "https://cdn.wago.io/gallery/9E5Hof3CyirmOzjjQrTSC0cVDOcGFU4po9d1PfTD.png"),
    "IMAGE_CRESTS": ("https://media.forgecdn.net/attachments/2158/183/crests-png.png",
                  "https://cdn.wago.io/gallery/RB40UV4THOeEYToh4u3ZMkQ7wS3J7StLqs9esgvQ.png"),
    "IMAGE_TREE": ("https://media.forgecdn.net/attachments/2158/182/tree-png.png",
                "https://cdn.wago.io/gallery/5jwYdqlMJXqWFcM5nZuXcyz2C2oJ7ktGgFB057CJ.png"),
    "IMAGE_LOOKS": ("https://media.forgecdn.net/attachments/2158/181/looks-png.png",
                 "https://cdn.wago.io/gallery/7S7SNjmad6kuRNd6qTpKN119w0V2ouqQegdkkPnL.png"),
    "IMAGE_MAP": ("https://media.forgecdn.net/attachments/2158/174/map-png.png",
               "https://cdn.wago.io/gallery/EDmIIrZ3e5B34cS87PcidfQVOR7GhcEeYOeCQHWN.png"),
    "IMAGE_GROUPS": ("https://media.forgecdn.net/attachments/2158/176/groups-png.png",
                  "https://cdn.wago.io/gallery/aWdWNPweWkd7zpyacu1XbYZlhf8zV0RSBxmIXqyf.png"),
    "IMAGE_HEY": ("https://media.forgecdn.net/attachments/2158/175/hey-png.png",
               "https://cdn.wago.io/gallery/0s1CFNrh209gmZWHPjQuzpN7Y9cvI9FLop0MJncF.png"),
    "IMAGE_PLATES": ("https://media.forgecdn.net/attachments/2158/177/nameplates-png.png",
                  "https://cdn.wago.io/gallery/CyJEzayw9lByi8uQVbm4E8xBmYK1DqQpdqL8PT4E.png"),
    "IMAGE_RACE": ("https://media.forgecdn.net/attachments/2158/180/race-png.png",
                "https://cdn.wago.io/gallery/1kEGVIcyhDKD59vy2zFtMzDxERhHP1zyq7FkFgBX.png"),
    "IMAGE_REUNION": ("https://media.forgecdn.net/attachments/2175/370/reunion-png.png",
                  "https://cdn.wago.io/gallery/w72ndh8h3RogfLdDJ1FhU65bnYqY8GtJSwLeBTeM.png"),
    "IMAGE_ACHIEVEMENTS": ("https://media.forgecdn.net/attachments/2175/376/achievements-png.png",
                       "https://cdn.wago.io/gallery/r7Pd0vcAUDTsRFCrgOOniSBLLv3xGI9GQCjUVPD7.png"),
    "IMAGE_PORTRAIT": ("https://media.forgecdn.net/attachments/2175/384/portrait-png.png",
                    "https://cdn.wago.io/gallery/XL89VMKPxaVHuk4OSKbq70OqYwso4dUaOaU70pgH.png"),
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
