"""Generate SpaceSense AI launcher icons.

Design: indigo -> violet diagonal gradient, minimal white room glyph
(house outline) with a 4-point AI sparkle nested inside. Drawn at
4x supersampling and downscaled for smooth edges.
Outputs into mobile/assets/icon/:
  app_icon.png        full square icon (legacy launchers, store listing)
  app_icon_bg.png     gradient background layer (adaptive icon bg)
  app_icon_fg.png     glyph on transparency (adaptive icon fg)
"""
import math
import os
from PIL import Image, ImageDraw

OUT = os.path.join(
    os.path.dirname(os.path.dirname(os.path.abspath(__file__))),
    "assets", "icon",
)
os.makedirs(OUT, exist_ok=True)

S = 4                      # supersample factor
CANVAS = 1024 * S          # working canvas
FINAL = 1024

C1 = (99, 102, 241)        # #6366F1 indigo
C2 = (139, 92, 246)        # #8B5CF6 violet


def gradient(size: int) -> Image.Image:
    """Diagonal top-left -> bottom-right gradient."""
    w, h = size, size
    img = Image.new("RGB", (w, h))
    # vec from corner to corner
    vx, vy = w, h
    len2 = vx * vx + vy * vy
    px = img.load()
    for y in range(h):
        for x in range(0, w, 1):
            t = (x * vx + y * vy) / len2
            r = int(C1[0] + (C2[0] - C1[0]) * t)
            g = int(C1[1] + (C2[1] - C1[1]) * t)
            b = int(C1[2] + (C2[2] - C1[2]) * t)
            px[x, y] = (r, g, b)
    return img


def room_glyph(draw: ImageDraw.ImageDraw, scale: float, ox: int, oy: int, stroke: int):
    """Minimal room/house outline with rounded joints, white."""
    # House key points on a 1024 grid (design space)
    pts = [
        (292, 706),   # bottom-left
        (292, 486),   # left eave
        (512, 330),   # roof peak
        (732, 486),   # right eave
        (732, 706),   # bottom-right
    ]
    scaled = [(ox + x * scale, oy + y * scale) for x, y in pts]
    # outline, no bottom edge: open, modern look
    draw.line(scaled, fill=(255, 255, 255), width=int(stroke * scale), joint="curve")
    # round line caps
    r = stroke * scale / 2
    for p in (scaled[0], scaled[-1]):
        draw.ellipse(
            [p[0] - r, p[1] - r, p[0] + r, p[1] + r], fill=(255, 255, 255)
        )


def sparkle(draw: ImageDraw.ImageDraw, cx: float, cy: float, r: float):
    """4-point AI sparkle (star) with sharp tips."""
    k = 0.22  # concavity of the waist
    pts = [
        (cx, cy - r),
        (cx + k * r, cy - k * r),
        (cx + r, cy),
        (cx + k * r, cy + k * r),
        (cx, cy + r),
        (cx - k * r, cy + k * r),
        (cx - r, cy),
        (cx - k * r, cy - k * r),
    ]
    draw.polygon(pts, fill=(255, 255, 255))


def draw_glyph(img: Image.Image, glyph_scale: float, center: bool = True) -> Image.Image:
    layer = Image.new("RGBA", (CANVAS, CANVAS), (0, 0, 0, 0))
    d = ImageDraw.Draw(layer)
    if center:
        size = int(CANVAS * glyph_scale)
        ox, oy = (CANVAS - size) // 2, (CANVAS - size) // 2
    else:
        ox, oy = 0, 0
    s = (CANVAS * glyph_scale if center else CANVAS) / 1024

    room_glyph(d, s, ox, oy, 26)  # slim premium stroke

    # main AI sparkle nested in the room's central void
    sparkle(d, ox + 512 * s, oy + 590 * s, 95 * s)
    # small secondary sparkle, upper-left of the roof line
    sparkle(d, ox + 322 * s, oy + 376 * s, 40 * s)
    return layer


def finalize(img: Image.Image, rounded: bool) -> Image.Image:
    if rounded:
        mask = Image.new("L", (CANVAS, CANVAS), 0)
        ImageDraw.Draw(mask).rounded_rectangle(
            [0, 0, CANVAS - 1, CANVAS - 1], radius=int(CANVAS * 0.225), fill=255
        )
        img.putalpha(mask)
    return img.resize((FINAL, FINAL), Image.LANCZOS)


bg = gradient(CANVAS)

# 1) adaptive background layer: plain gradient (glyph drawn by fg layer)
finalize(bg.copy().convert("RGBA"), rounded=False).save(
    os.path.join(OUT, "app_icon_bg.png"), optimize=True
)

# 2) adaptive foreground: glyph only (scaled into the safe zone)
finalize(draw_glyph(bg.copy(), 0.62), rounded=False).save(
    os.path.join(OUT, "app_icon_fg.png"), optimize=True
)

# 3) full icon: gradient + glyph at full size, rounded corners
full = bg.copy().convert("RGBA")
glyph = draw_glyph(full, 0.82)
full.alpha_composite(glyph)
finalize(full, rounded=True).save(
    os.path.join(OUT, "app_icon.png"), optimize=True
)

print("icons written to", OUT)
