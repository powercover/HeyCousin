"""The store page's pictures, from the sheets tests/kit/screens.py draws (run that first).

Each sheet has the three looks side by side under their names: Forever, Pixel, Smooth. Most pictures
are the Pixel column, the default look; looks.png is all three. The logo is the addon's icon, big.
"""
import os

from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))
SHEETS = os.path.join(HERE, "..", "tests", "kit", "screens")
ICON = os.path.join(HERE, "..", "Media", "Icon.tga")
LABEL = 0.046  # the share of a sheet's height its look names take


def sheet(name):
    return Image.open(os.path.join(SHEETS, name)).convert("RGB")


def pixel_column(image):
    width, height = image.size
    return image.crop((width // 3, int(height * LABEL), 2 * width // 3, height))


def save(image, name):
    image.save(os.path.join(HERE, name), optimize=True)
    print("drew", name, image.size)


def main():
    save(pixel_column(sheet("1b-found.png")), "found.png")
    save(pixel_column(sheet("1c-found-page.png")), "page.png")
    save(pixel_column(sheet("2c-tree.png")), "tree.png")
    save(pixel_column(sheet("4-setup-crest.png")), "setup.png")
    save(sheet("1-family.png"), "looks.png")
    icon = Image.open(ICON).convert("RGBA")
    save(icon.resize((1024, 1024), Image.NEAREST), "logo.png")


if __name__ == "__main__":
    main()
