"""Aus Phone Towers app icon: the single source for the mark, for both apps.

The mark is the three carrier pins the map draws (Telstra, Optus, Vodafone, in the exact
colours from TelcoHelper) standing on a contour map. It is designed as SVG: a true teardrop
whose tails are tangent to the head, a vertical tonal gradient and a soft top-left
highlight on each pin, one light source, an offset shadow that separates the overlapping
pins and a small contact shadow under each tip. The ground is a radial gradient carrying
faint topographic contour lines (a real height-field, iso-lines by marching squares) so the
launcher's parallax moves the map under the pins.

Each app has its own variant of the mark (Brad's choice, 2026-09-06): this Flutter app keeps
the T O V initials, set as vector outlines of Segoe UI Bold baked into the SVG so the render
does not depend on the machine's fonts; the Java app has hollow centres. Both stand on the
same night-blue contour map.

Outputs (all from the same SVG, rendered by ImageMagick's librsvg delegate):

  assets/appicon.png              1024 RGB   iOS, web, App Store master
  assets/appicon_foreground.png   1024 RGBA  Android adaptive foreground (108 dp canvas)
  assets/appicon_background.png   1024 RGB   Android adaptive background (ground + contours)
  assets/appicon_monochrome.png   1024 RGBA  Android 13+ themed icon
  assets/appicon_macos.png        1024 RGBA  macOS (Big Sur rounded square with shadow)
  tool/appicon/flutter/*.svg      the vector sources, for a designer or a future tweak
  tool/appicon/android/*.svg      the Java app's set (written with --android)

then `dart run flutter_launcher_icons` fans those out. With --android <repo> it also writes
the Java app's mipmaps (webp), the Play Store icon and feature graphic and the two 512 px
masters that repo keeps.

Requires: Pillow, numpy, scipy, fonttools (letters variants only) and ImageMagick 7 with
the RSVG delegate (`magick -list format | findstr RSVG`). The design is deterministic
(seeded noise).

    python tool/make_app_icon.py [assets] [--android ../aus_phone_towers_java]
                                 [--variant dark:letters:7] [--android-variant dark:hollow:7]
                                 [--from-svg]
"""
import argparse
import math
import os
import shutil
import subprocess
import sys
import tempfile

import numpy as np
from PIL import Image, ImageDraw, ImageFilter, ImageFont
from scipy.ndimage import gaussian_filter

S = 1024                     # design canvas; for the adaptive layers it is the 108 dp canvas
TELSTRA = (13, 84, 255)      # #0D54FF Blue Ribbon
OPTUS = (0, 127, 135)        # #007F87, see TelcoHelper for why not the brand yellow
VODAFONE = (230, 0, 0)       # #E60000 Pantone 485

GROUNDS = {
    "dark": dict(top="#1E2742", bottom="#101627", contour="#FFFFFF", c_op=0.085,
                 shadow_op=0.42, tip_op=0.42, text="#FFFFFF", subtext="#B7C0D8"),
    "light": dict(top="#FAF8F3", bottom="#E9E6DE", contour="#1F2A44", c_op=0.10,
                  shadow_op=0.26, tip_op=0.30, text="#2B2B6B", subtext="#4A4A5A"),
}
DEFAULT_VARIANT = "dark:letters:7"          # this app: T O V initials
DEFAULT_ANDROID_VARIANT = "dark:hollow:7"    # aus_phone_towers_java: hollow centres
LETTER_FONTS = ("C:/Windows/Fonts/segoeuib.ttf", "/Library/Fonts/Segoe UI Bold.ttf",
                "C:/Windows/Fonts/arialbd.ttf", "/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf")

MARK_SCALE = 1.15            # the mark's size in the full icon relative to the design units
PIVOT_Y = 505                # the mark's optical centre on the full canvas
FG_SCALE = 0.74              # adaptive foreground relative to the full icon: keeps the mark
                             # inside the 66 dp safe circle of the 108 dp canvas


# ----------------------------------------------------------------------------- helpers
def hexc(rgb):
    return "#%02X%02X%02X" % tuple(int(round(max(0, min(255, c)))) for c in rgb)


def mix(rgb, other, t):
    return tuple(rgb[i] + (other[i] - rgb[i]) * t for i in range(3))


def parse_hex(h):
    return tuple(int(h[i:i + 2], 16) for i in (1, 3, 5))


# ----------------------------------------------------------------------------- contours
def heightfield(n=160, seed=7):
    rng = np.random.default_rng(seed)
    y, x = np.mgrid[0:n, 0:n] / (n - 1)
    h = np.zeros((n, n))
    for (cx, cy, sx, sy, a) in [(0.26, 0.74, 0.34, 0.30, 1.0), (0.80, 0.20, 0.26, 0.24, 0.75),
                                (0.62, 0.95, 0.30, 0.20, 0.45)]:
        h += a * np.exp(-(((x - cx) / sx) ** 2 + ((y - cy) / sy) ** 2))
    noise = gaussian_filter(rng.standard_normal((n, n)), n / 11)
    noise /= np.abs(noise).max()
    h += 0.22 * noise
    return h


def marching_squares(h, level):
    """Polylines (grid coordinates) of the iso-line h == level."""
    n, m = h.shape
    segs = []

    def interp(p, q, vp, vq):
        t = (level - vp) / (vq - vp) if vq != vp else 0.5
        return (p[0] + (q[0] - p[0]) * t, p[1] + (q[1] - p[1]) * t)

    for i in range(n - 1):
        for j in range(m - 1):
            v = [h[i, j], h[i, j + 1], h[i + 1, j + 1], h[i + 1, j]]
            pts = [(j, i), (j + 1, i), (j + 1, i + 1), (j, i + 1)]
            inside = [vv >= level for vv in v]
            if all(inside) or not any(inside):
                continue
            edges = []
            for k in range(4):
                a, b = k, (k + 1) % 4
                if inside[a] != inside[b]:
                    edges.append(interp(pts[a], pts[b], v[a], v[b]))
            if len(edges) == 2:
                segs.append((edges[0], edges[1]))
            elif len(edges) == 4:          # saddle: split by the cell's mean
                if ((sum(v) / 4) >= level) == inside[0]:
                    segs.append((edges[0], edges[3]))
                    segs.append((edges[1], edges[2]))
                else:
                    segs.append((edges[0], edges[1]))
                    segs.append((edges[2], edges[3]))

    key = lambda p: (round(p[0], 4), round(p[1], 4))
    adj = {}
    for a, b in segs:
        adj.setdefault(key(a), []).append((a, b))
        adj.setdefault(key(b), []).append((b, a))
    used = set()
    lines = []
    for a, b in segs:
        if (key(a), key(b)) in used or (key(b), key(a)) in used:
            continue
        line = [a, b]
        used.add((key(a), key(b)))
        for direction in (1, -1):
            while True:
                end = line[-1] if direction == 1 else line[0]
                nxt = None
                for p, q in adj.get(key(end), []):
                    if (key(p), key(q)) in used or (key(q), key(p)) in used:
                        continue
                    nxt = q
                    used.add((key(p), key(q)))
                    break
                if nxt is None:
                    break
                if direction == 1:
                    line.append(nxt)
                else:
                    line.insert(0, nxt)
        if len(line) > 6:
            lines.append(line)
    return lines


def smooth(line, k=3):
    if len(line) < 2 * k + 1:
        return line
    closed = math.hypot(line[0][0] - line[-1][0], line[0][1] - line[-1][1]) < 1e-3
    pts = line[:-1] if closed else line
    n = len(pts)
    out = []
    for i in range(n):
        xs = ys = 0.0
        cnt = 0
        for d in range(-k, k + 1):
            j = i + d
            if closed:
                j %= n
            elif j < 0 or j >= n:
                continue
            xs += pts[j][0]
            ys += pts[j][1]
            cnt += 1
        out.append((xs / cnt, ys / cnt))
    if closed:
        out.append(out[0])
    return out


_H = None


def contours_svg(ground, width=S, height=S, stroke_w=2.2, n_levels=15):
    """Contour lines covering width x height (the height-field is stretched over a square
    of side max(width, height) so the feature graphic shares the icon's map)."""
    global _H
    if _H is None:
        _H = heightfield()
    g = GROUNDS[ground]
    n = _H.shape[0]
    side = max(width, height)
    margin = side * 0.08
    lo, hi = np.percentile(_H, 3), np.percentile(_H, 99)
    out = ['<g fill="none" stroke="%s" stroke-opacity="%.3f" stroke-width="%.2f" '
           'stroke-linejoin="round" stroke-linecap="round">' % (g["contour"], g["c_op"], stroke_w)]
    for lv in np.linspace(lo, hi, n_levels):
        for line in marching_squares(_H, lv):
            line = smooth(line)
            d = " ".join(("M" if i == 0 else "L") + "%.1f %.1f" % (
                -margin + p[0] / (n - 1) * (side + 2 * margin),
                -margin + p[1] / (n - 1) * (side + 2 * margin)) for i, p in enumerate(line))
            out.append('<path d="%s"/>' % d)
    out.append("</g>")
    return "\n".join(out)


def ground_svg(ground, width=S, height=S):
    g = GROUNDS[ground]
    defs = ('<radialGradient id="bg" cx="0.5" cy="0.38" r="0.85">'
            '<stop offset="0" stop-color="%s"/><stop offset="1" stop-color="%s"/></radialGradient>'
            % (g["top"], g["bottom"]))
    body = '<rect width="%d" height="%d" fill="url(#bg)"/>' % (width, height)
    return defs, body


# ----------------------------------------------------------------------------- letters
_GLYPHS = {}


def glyph_outline(ch):
    """(path d in font units, y up), (xMin, xMax), cap height, units per em: the initial's
    outline from the first font in LETTER_FONTS that exists, so the SVG carries the shape."""
    if ch in _GLYPHS:
        return _GLYPHS[ch]
    try:
        from fontTools.pens.boundsPen import BoundsPen
        from fontTools.pens.svgPathPen import SVGPathPen
        from fontTools.ttLib import TTFont
    except ImportError:
        sys.exit("letters variants need fonttools: python -m pip install fonttools")
    path = next((f for f in LETTER_FONTS if os.path.exists(f)), None)
    if path is None:
        sys.exit("no font found for the initials; see LETTER_FONTS")
    font = TTFont(path)
    glyph_set = font.getGlyphSet()
    name = font.getBestCmap()[ord(ch)]
    pen = SVGPathPen(glyph_set)
    glyph_set[name].draw(pen)
    bounds = BoundsPen(glyph_set)
    glyph_set[name].draw(bounds)
    x_min, _, x_max, _ = bounds.bounds
    cap = getattr(font["OS/2"], "sCapHeight", 0) or int(font["head"].unitsPerEm * 0.7)
    _GLYPHS[ch] = (pen.getCommands(), (x_min, x_max), cap, font["head"].unitsPerEm)
    return _GLYPHS[ch]


def letter_svg(ch, cx, cy, font_px):
    """The initial as a filled path, its cap-height box centred on (cx, cy)."""
    d, (x_min, x_max), cap, upem = glyph_outline(ch)
    k = font_px / upem
    tx = cx - (x_min + x_max) / 2 * k
    ty = cy + cap / 2 * k
    return ('<path d="%s" fill="#FFFFFF" transform="translate(%.2f %.2f) scale(%.5f %.5f)"/>'
            % (d, tx, ty, k, -k))


# ----------------------------------------------------------------------------- pins
def pin_path(cx, cy, r, L, hole_r=None):
    """Teardrop: head centre (cx, cy), radius r, tip at (cx, cy + L); the tails leave the
    head at its tangent points so the join is smooth. An optional hole is a second subpath
    (fill-rule evenodd) so it is transparent in the adaptive layers."""
    py = r * r / L
    px = math.sqrt(max(0.0, r * r - py * py))
    d = "M%.2f %.2f L%.2f %.2f A%.2f %.2f 0 1 1 %.2f %.2f Z" % (
        cx, cy + L, cx - px, cy + py, r, r, cx + px, cy + py)
    if hole_r:
        d += " M%.2f %.2f a%.2f %.2f 0 1 0 %.2f 0 a%.2f %.2f 0 1 0 %.2f 0 Z" % (
            cx - hole_r, cy, hole_r, hole_r, 2 * hole_r, hole_r, hole_r, -2 * hole_r)
    return d


def pins_svg(ground, centre, tilt, scale=1.0, mono=False, shadow=True, dx=0.0, dy=0.0):
    """The three pins. scale is relative to the full icon; dx/dy shift the whole mark."""
    g = GROUNDS[ground]
    scale = scale * MARK_SCALE
    r0 = 132 * scale
    L0 = 2.0 * r0
    baseline = 712
    cx0 = 512 + dx

    def T(y):
        return PIVOT_Y + dy + (y - PIVOT_Y) * scale

    specs = [
        # name, colour, cx, tip_y, r, L, rotation about the tip, letter
        ("telstra", TELSTRA, cx0 - 178 * scale, T(baseline - 52), r0 * 0.91, L0 * 0.91, -tilt, "T"),
        ("vodafone", VODAFONE, cx0 + 178 * scale, T(baseline - 52), r0 * 0.91, L0 * 0.91, tilt, "V"),
        ("optus", OPTUS, cx0, T(baseline), r0, L0, 0, "O"),   # drawn last, in front
    ]
    hole_frac = 0.36 if centre == "hollow" else 0.0
    defs, body = [], []
    if shadow and not mono:
        defs.append('<filter id="sh" x="-40%%" y="-40%%" width="180%%" height="180%%">'
                    '<feGaussianBlur stdDeviation="%.1f"/></filter>' % (10 * scale))
        defs.append('<filter id="tip" x="-60%%" y="-200%%" width="220%%" height="500%%">'
                    '<feGaussianBlur stdDeviation="%.1f"/></filter>' % (4 * scale))
    for name, col, cx, tip_y, r, L, rot, letter in specs:
        cy = tip_y - L
        d = pin_path(cx, cy, r, L, r * hole_frac if hole_frac else None)
        tr = ' transform="rotate(%.1f %.2f %.2f)"' % (rot, cx, tip_y) if rot else ""
        if mono:
            body.append('<path d="%s" fill="#FFFFFF" fill-rule="evenodd"%s/>' % (d, tr))
            continue
        defs.append('<linearGradient id="g_%s" x1="0" y1="0" x2="0" y2="1">'
                    '<stop offset="0" stop-color="%s"/><stop offset="0.55" stop-color="%s"/>'
                    '<stop offset="1" stop-color="%s"/></linearGradient>' % (
                        name, hexc(mix(col, (255, 255, 255), 0.16)), hexc(col), hexc(mix(col, (0, 0, 0), 0.24))))
        defs.append('<radialGradient id="hl_%s" cx="%.2f" cy="%.2f" r="%.2f" gradientUnits="userSpaceOnUse">'
                    '<stop offset="0" stop-color="#FFFFFF" stop-opacity="0.20"/>'
                    '<stop offset="1" stop-color="#FFFFFF" stop-opacity="0"/></radialGradient>' % (
                        name, cx - r * 0.30, cy - r * 0.55, r * 0.95))
        if shadow:
            body.append('<ellipse cx="%.2f" cy="%.2f" rx="%.2f" ry="%.2f" fill="#000" opacity="%.2f" '
                        'filter="url(#tip)"/>' % (cx, tip_y + 3 * scale, r * 0.34, r * 0.085, g["tip_op"]))
            body.append('<g%s><path d="%s" fill="#000" fill-rule="evenodd" opacity="%.2f" '
                        'filter="url(#sh)" transform="translate(0 %.1f)"/></g>' % (
                            tr, d, g["shadow_op"], 13 * scale))
        body.append('<g%s>' % tr)
        body.append('<path d="%s" fill="url(#g_%s)" fill-rule="evenodd"/>' % (d, name))
        body.append('<path d="%s" fill="url(#hl_%s)" fill-rule="evenodd"/>' % (d, name))
        body.append('<path d="%s" fill="none" stroke="#000" stroke-opacity="0.10" stroke-width="%.1f"/>'
                    % (d, 2.0 * scale))
        if centre == "letters":
            body.append(letter_svg(letter, cx, cy, r * 1.18))
        body.append('</g>')
    return "\n".join(defs), "\n".join(body)


def svg_doc(defs, body, width=S, height=S):
    return ('<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 %d %d" width="%d" height="%d">\n'
            '<defs>\n%s\n</defs>\n%s\n</svg>\n' % (width, height, width, height, "\n".join(defs), "\n".join(body)))


def design(ground, centre, tilt):
    """The four vector sources as {name: svg text}."""
    out = {}
    gd, gb = ground_svg(ground)
    pd, pb = pins_svg(ground, centre, tilt)
    out["full"] = svg_doc([gd, pd], [gb, contours_svg(ground), pb])
    out["background"] = svg_doc([gd], [gb, contours_svg(ground)])
    pd, pb = pins_svg(ground, centre, tilt, scale=FG_SCALE)
    out["foreground"] = svg_doc([pd], [pb])
    pd, pb = pins_svg(ground, centre, tilt, scale=FG_SCALE, mono=True, shadow=False)
    out["monochrome"] = svg_doc([pd], [pb])
    # feature graphic ground: 1024 x 500 with the mark at the left third
    gd, gb = ground_svg(ground, 1024, 500)
    pd, pb = pins_svg(ground, centre, tilt, scale=0.42, dx=-512 + 250, dy=-505 + 250)
    out["feature"] = svg_doc([gd, pd], [gb, contours_svg(ground, 1024, 500, stroke_w=1.6), pb], 1024, 500)
    return out


# ----------------------------------------------------------------------------- rendering
def render_svg(svg_path, size_w, size_h=None):
    size_h = size_h or size_w
    if shutil.which("magick") is None:
        sys.exit("ImageMagick 7 (magick) is required, with the RSVG delegate")
    fd, png = tempfile.mkstemp(suffix=".png")
    os.close(fd)
    subprocess.run(["magick", "-density", "%.4f" % (96.0 * size_w / S), "-background", "none",
                    svg_path, "-resize", "%dx%d!" % (size_w, size_h), png], check=True)
    im = Image.open(png).convert("RGBA")
    im.load()
    os.remove(png)
    return im


def rounded_mask(size, radius_frac, ss=4):
    m = Image.new("L", (size * ss, size * ss), 0)
    ImageDraw.Draw(m).rounded_rectangle([0, 0, size * ss - 1, size * ss - 1],
                                        radius=int(size * ss * radius_frac), fill=255)
    return m.resize((size, size), Image.LANCZOS)


def circle_mask(size, ss=4):
    m = Image.new("L", (size * ss, size * ss), 0)
    ImageDraw.Draw(m).ellipse([0, 0, size * ss - 1, size * ss - 1], fill=255)
    return m.resize((size, size), Image.LANCZOS)


def macos_icon(full):
    """Apple's Big Sur template: an 824 px rounded square centred on a 1024 canvas, with a
    soft drop shadow, so the icon sits in the Dock like the system ones."""
    canvas = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    inner = 824
    art = full.resize((inner, inner), Image.LANCZOS)
    art.putalpha(rounded_mask(inner, 0.2237))
    shadow = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    plate = Image.new("RGBA", (inner, inner), (0, 0, 0, 90))
    plate.putalpha(rounded_mask(inner, 0.2237).point(lambda a: a * 90 // 255))
    shadow.alpha_composite(plate, ((S - inner) // 2, (S - inner) // 2 + 12))
    shadow = shadow.filter(ImageFilter.GaussianBlur(14))
    canvas.alpha_composite(shadow)
    canvas.alpha_composite(art, ((S - inner) // 2, (S - inner) // 2))
    return canvas


def font(name, px):
    try:
        return ImageFont.truetype(name, px)
    except OSError:
        return ImageFont.truetype("arial.ttf", px)


def feature_graphic(ground, feature_png):
    g = GROUNDS[ground]
    im = feature_png.convert("RGB")
    d = ImageDraw.Draw(im)
    x, right = 470, 1024 - 56
    size = 72
    while size > 40 and font("segoeuib.ttf", size).getlength("Aus Phone Towers") > right - x:
        size -= 2
    title = font("segoeuib.ttf", size)
    body = font("segoeui.ttf", 34)
    d.text((x, 160), "Aus Phone Towers", font=title, fill=parse_hex(g["text"]))
    d.text((x, 262), "Every mobile tower in Australia,", font=body, fill=parse_hex(g["subtext"]))
    d.text((x, 308), "and the one you're connected to.", font=body, fill=parse_hex(g["subtext"]))
    return im


def save_webp(im, path):
    im.save(path, "WEBP", quality=92, method=6)


def write_android(repo, full, fg, bg, mono, feature):
    res = os.path.join(repo, "app", "src", "main", "res")
    densities = {"mdpi": 1, "hdpi": 1.5, "xhdpi": 2, "xxhdpi": 3, "xxxhdpi": 4}
    for name, mult in densities.items():
        d = os.path.join(res, "mipmap-" + name)
        os.makedirs(d, exist_ok=True)
        legacy = int(48 * mult)
        layer = int(108 * mult)
        save_webp(full.convert("RGB").resize((legacy, legacy), Image.LANCZOS), os.path.join(d, "ic_launcher.webp"))
        rnd = full.resize((legacy, legacy), Image.LANCZOS)
        rnd.putalpha(circle_mask(legacy))
        save_webp(rnd, os.path.join(d, "ic_launcher_round.webp"))
        save_webp(fg.resize((layer, layer), Image.LANCZOS), os.path.join(d, "ic_launcher_foreground.webp"))
        save_webp(bg.convert("RGB").resize((layer, layer), Image.LANCZOS), os.path.join(d, "ic_launcher_background.webp"))
        save_webp(mono.resize((layer, layer), Image.LANCZOS), os.path.join(d, "ic_launcher_monochrome.webp"))
    main = os.path.join(repo, "app", "src", "main")
    full.convert("RGB").resize((512, 512), Image.LANCZOS).save(os.path.join(main, "ic_launcher-playstore.png"))
    web = full.resize((512, 512), Image.LANCZOS)
    web.putalpha(rounded_mask(512, 0.2237))
    web.save(os.path.join(main, "ic_launcher-web.png"))
    play = os.path.join(repo, "store", "play")
    os.makedirs(play, exist_ok=True)
    full.convert("RGB").resize((512, 512), Image.LANCZOS).save(os.path.join(play, "icon-512.png"))
    feature.save(os.path.join(play, "feature-graphic-1024x500.png"))
    # the adaptive background is a bitmap now (it carries the contour lines), not a colour
    old_xml = os.path.join(res, "drawable", "ic_launcher_background.xml")
    if os.path.exists(old_xml):
        os.remove(old_xml)
    for xml in ("ic_launcher.xml", "ic_launcher_round.xml"):
        p = os.path.join(res, "mipmap-anydpi-v26", xml)
        if os.path.exists(p):
            s = open(p, encoding="utf-8").read().replace('@drawable/ic_launcher_background', '@mipmap/ic_launcher_background')
            open(p, "w", encoding="utf-8").write(s)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("out", nargs="?", default="assets")
    ap.add_argument("--variant", default=DEFAULT_VARIANT,
                    help="this app's ground:centre:tilt, e.g. dark:letters:7")
    ap.add_argument("--android-variant", default=DEFAULT_ANDROID_VARIANT,
                    help="the Java app's ground:centre:tilt, e.g. dark:hollow:7")
    ap.add_argument("--from-svg", action="store_true", help="render tool/appicon/*/*.svg as they are")
    ap.add_argument("--android", help="path of the aus_phone_towers_java checkout to write mipmaps into")
    args = ap.parse_args()

    here = os.path.dirname(os.path.abspath(__file__))
    os.makedirs(args.out, exist_ok=True)

    def build(variant, svg_dir):
        ground, centre, tilt = variant.split(":")
        os.makedirs(svg_dir, exist_ok=True)
        if not args.from_svg:
            for name, text in design(ground, centre, float(tilt)).items():
                with open(os.path.join(svg_dir, name + ".svg"), "w", encoding="utf-8") as f:
                    f.write(text)
        return (render_svg(os.path.join(svg_dir, "full.svg"), S),
                render_svg(os.path.join(svg_dir, "foreground.svg"), S),
                render_svg(os.path.join(svg_dir, "background.svg"), S),
                render_svg(os.path.join(svg_dir, "monochrome.svg"), S),
                feature_graphic(ground, render_svg(os.path.join(svg_dir, "feature.svg"), 1024, 500)))

    full, fg, bg, mono, feature = build(args.variant, os.path.join(here, "appicon", "flutter"))

    # RGB, not RGBA, for the masters: the App Store rejects icons carrying an alpha channel
    full.convert("RGB").save(os.path.join(args.out, "appicon.png"))
    fg.save(os.path.join(args.out, "appicon_foreground.png"))
    bg.convert("RGB").save(os.path.join(args.out, "appicon_background.png"))
    mono.save(os.path.join(args.out, "appicon_monochrome.png"))
    macos_icon(full).save(os.path.join(args.out, "appicon_macos.png"))
    store = os.path.join(here, "..", "store", "app-store")
    if os.path.isdir(store):
        full.convert("RGB").save(os.path.join(store, "icon-1024.png"))
    web = os.path.join(here, "..", "web")
    if os.path.isdir(web):
        # files flutter_launcher_icons does not manage but the web folder ships
        icons = os.path.join(web, "icons")
        full.convert("RGB").resize((192, 192), Image.LANCZOS).save(os.path.join(icons, "android-chrome-192x192.png"))
        full.convert("RGB").resize((512, 512), Image.LANCZOS).save(os.path.join(icons, "android-chrome-512x512.png"))
        full.convert("RGB").resize((180, 180), Image.LANCZOS).save(os.path.join(icons, "apple-touch-icon.png"))
        full.convert("RGB").resize((48, 48), Image.LANCZOS).save(
            os.path.join(web, "favicon.ico"), sizes=[(16, 16), (32, 32), (48, 48)])
    print("wrote", args.out + "/appicon{,_foreground,_background,_monochrome,_macos}.png and tool/appicon/flutter")

    if args.android:
        if args.android_variant != args.variant:
            full, fg, bg, mono, feature = build(args.android_variant, os.path.join(here, "appicon", "android"))
        write_android(args.android, full, fg, bg, mono, feature)
        print("wrote Android launcher assets (%s) into %s" % (args.android_variant, args.android))
    print("now run: dart run flutter_launcher_icons")


if __name__ == "__main__":
    main()
