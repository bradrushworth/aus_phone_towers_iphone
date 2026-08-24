"""Aus Phone Towers icon — the app's own map pins, drawn properly.

The outgoing icon already had the right idea (three carrier pins) but was a blurred
screenshot of the map behind them: contour lines, a baked-in "~2.9m" label, pastel
washed-out pins, and two pin tips running off the bottom edge where launcher masks crop.

This keeps the idea and rebuilds it as a mark: the same three teardrop pins the map
draws, with the same white initial inside, in the exact colours from TelcoHelper —

    Telstra  RGB(13, 84, 255)  #0D54FF   "T"
    Optus    RGB(0, 127, 135)  #007F87   "O"
    Vodafone RGB(230, 0, 0)   #E60000   "V"

— on a clean warm-white ground echoing the terrain basemap, with everything inside the
central safe zone so nothing clips when Android masks it or iOS rounds the corners.

Drawn at 4x and Lanczos-downsampled.
"""
import os
import sys

from PIL import Image, ImageDraw, ImageFilter, ImageFont

OUT = sys.argv[1] if len(sys.argv) > 1 else "assets"
LETTERS = (sys.argv[2] if len(sys.argv) > 2 else "yes") == "yes"
os.makedirs(OUT, exist_ok=True)

S = 4096

TELSTRA = (13, 84, 255)   # #0D54FF Blue Ribbon
OPTUS = (0, 127, 135)
VODAFONE = (230, 0, 0)    # #E60000 Pantone 485
GROUND_TOP = (252, 251, 248)
GROUND_BOTTOM = (231, 231, 226)


def ground():
    img = Image.new("RGB", (S, S), GROUND_TOP)
    d = ImageDraw.Draw(img)
    for y in range(S):
        t = (y / (S - 1)) ** 0.9
        d.line([(0, y), (S, y)], fill=tuple(
            int(GROUND_TOP[i] + (GROUND_BOTTOM[i] - GROUND_TOP[i]) * t) for i in range(3)))
    return img


def pin_shape(d, cx, cy, r, tip_y, fill):
    """A map teardrop: a disc with a tail converging to a point at tip_y."""
    # Tangent points where the tail meets the disc, so the join is smooth rather than
    # a triangle stuck on the bottom of a circle.
    import math
    dy = tip_y - cy
    if dy <= r:
        dy = r * 1.6
    alpha = math.asin(min(1.0, r / dy))
    for sign in (-1, 1):
        pass
    ang = math.pi / 2 - alpha
    lx = cx - r * math.cos(ang)
    ly = cy + r * math.sin(ang)
    rx = cx + r * math.cos(ang)
    ry = ly
    d.polygon([(lx, ly), (rx, ry), (cx, cy + dy)], fill=fill)
    d.ellipse([cx - r, cy - r, cx + r, cy + r], fill=fill)


def font_for(px):
    for name in ("arialbd.ttf", "Arial Bold.ttf", "seguisb.ttf", "segoeuib.ttf", "arial.ttf"):
        try:
            return ImageFont.truetype(name, px)
        except Exception:
            continue
    return None


def draw_pins(img, shadow=True):
    d = ImageDraw.Draw(img)
    # Sized so the group spans roughly 28%-75% vertically and 14%-86% horizontally:
    # optically centred, with enough margin that the adaptive-icon inset below pulls it
    # inside the 66% safe zone without further shrinking.
    r = S * 0.155          # disc radius
    tail = S * 0.272       # disc centre -> tip
    baseline = S * 0.745   # where every tip lands

    # Centre pin sits slightly forward and higher; the outer two flank it. Overlap is
    # deliberate so the three read as one mark rather than three separate stickers.
    spread = S * 0.205
    specs = [
        (S * 0.5 - spread, baseline - S * 0.035, TELSTRA, "T"),
        (S * 0.5 + spread, baseline - S * 0.035, VODAFONE, "V"),
        (S * 0.5, baseline, OPTUS, "O"),          # drawn last => on top
    ]

    if shadow:
        sh = Image.new("L", (S, S), 0)
        sd = ImageDraw.Draw(sh)
        for cx, tip_y, _, _ in specs:
            er = r * 0.62
            sd.ellipse([cx - er, tip_y - er * 0.30, cx + er, tip_y + er * 0.30], fill=90)
        sh = sh.filter(ImageFilter.GaussianBlur(S * 0.016))
        img.paste(Image.new("RGB", (S, S), (120, 118, 130)), (0, 0), sh)
        d = ImageDraw.Draw(img)

    f = font_for(int(r * 1.28)) if LETTERS else None
    for cx, tip_y, colour, letter in specs:
        cy = tip_y - tail
        pin_shape(d, cx, cy, r, tip_y, colour)
        if f is not None:
            bbox = d.textbbox((0, 0), letter, font=f)
            d.text((cx - (bbox[0] + bbox[2]) / 2, cy - (bbox[1] + bbox[3]) / 2),
                   letter, font=f, fill=(255, 255, 255))
        else:
            hr = r * 0.42
            d.ellipse([cx - hr, cy - hr, cx + hr, cy + hr], fill=(255, 255, 255))
    return img


def render(size=1024):
    return draw_pins(ground()).resize((size, size), Image.LANCZOS)


def render_layer(inset_frac=0.16, mono=False):
    rgba = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    draw_pins(rgba, shadow=False)
    if mono:
        alpha = rgba.split()[3]
        rgba = Image.new("RGBA", (S, S), (255, 255, 255, 255))
        rgba.putalpha(alpha)
    inset = int(S * inset_frac)
    shrunk = rgba.resize((S - 2 * inset, S - 2 * inset), Image.LANCZOS)
    canvas = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    canvas.paste(shrunk, (inset, inset), shrunk)
    return canvas.resize((1024, 1024), Image.LANCZOS)


if __name__ == "__main__":
    # RGB, not RGBA: the App Store rejects icons carrying an alpha channel, and
    # flutter_launcher_icons' remove_alpha_ios only strips it on the iOS copies.
    render().convert("RGB").save(os.path.join(OUT, "appicon.png"))
    render_layer().save(os.path.join(OUT, "appicon_foreground.png"))
    render_layer(mono=True).save(os.path.join(OUT, "appicon_monochrome.png"))

    print("wrote", OUT + "/appicon{,_foreground,_monochrome}.png")
    print("now run: dart run flutter_launcher_icons")
