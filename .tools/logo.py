"""Draws the Extreme Angler logo: a fishing bobber on water with ripples and a
small lightning bolt (Smart Cast). Rendered at 4x and downscaled for clean edges."""
from PIL import Image, ImageDraw, ImageFilter
import sys

S = 2048                      # working size
OUT = sys.argv[1] if len(sys.argv) > 1 else "logo.png"

ACCENT = (64, 184, 255)
RED = (232, 72, 77)
WHITE = (244, 246, 250)
DARK = (12, 20, 32)


def lerp(a, b, t):
    return tuple(int(a[i] + (b[i] - a[i]) * t) for i in range(3))


img = Image.new("RGBA", (S, S), (0, 0, 0, 0))

# --- Background: rounded square with a vertical gradient ---
bg = Image.new("RGBA", (S, S))
top, bottom = (14, 26, 44), (8, 44, 74)
px = bg.load()
for y in range(S):
    c = lerp(top, bottom, y / S)
    for x in range(S):
        px[x, y] = (*c, 255)
mask = Image.new("L", (S, S), 0)
ImageDraw.Draw(mask).rounded_rectangle((0, 0, S - 1, S - 1), radius=int(S * 0.2), fill=255)
img.paste(bg, (0, 0), mask)

cx, water_y = S // 2, int(S * 0.62)   # bobber centre x, water line y

# --- Ripples (flattened rings around the bobber) ---
rip = Image.new("RGBA", (S, S), (0, 0, 0, 0))
rd = ImageDraw.Draw(rip)
for i, (rx, alpha) in enumerate([(0.24, 210), (0.33, 140), (0.42, 70)]):
    w, h = int(S * rx), int(S * rx * 0.28)
    rd.ellipse((cx - w, water_y - h, cx + w, water_y + h), outline=(*ACCENT, alpha), width=int(S * 0.018))
img.alpha_composite(rip)

# --- Bobber ---
r = int(S * 0.15)                     # horizontal radius
ry = int(S * 0.22)                    # vertical radius (tall, egg-like float)
by = water_y - int(ry * 0.30)         # sits slightly in the water
bob = Image.new("RGBA", (S, S), (0, 0, 0, 0))
bd = ImageDraw.Draw(bob)
# stick on top
stick_w = int(S * 0.028)
bd.rounded_rectangle((cx - stick_w // 2, by - ry - int(S * 0.13), cx + stick_w // 2, by - ry + 10),
                     radius=stick_w // 2, fill=(30, 36, 48, 255))
bd.ellipse((cx - stick_w, by - ry - int(S * 0.15), cx + stick_w, by - ry - int(S * 0.11)), fill=RED + (255,))
# body: white sphere, red top half
bd.ellipse((cx - r, by - ry, cx + r, by + ry), fill=WHITE + (255,))
top_half = Image.new("L", (S, S), 0)
ImageDraw.Draw(top_half).rectangle((0, 0, S, by - int(ry * 0.12)), fill=255)
red_disc = Image.new("RGBA", (S, S), (0, 0, 0, 0))
ImageDraw.Draw(red_disc).ellipse((cx - r, by - ry, cx + r, by + ry), fill=RED + (255,))
bob.paste(red_disc, (0, 0), Image.composite(top_half, Image.new("L", (S, S), 0), red_disc.split()[3]))
# middle band
clip = Image.new("L", (S, S), 0)
ImageDraw.Draw(clip).ellipse((cx - r, by - ry, cx + r, by + ry), fill=255)
clip.paste(255, (cx - stick_w, by - ry - int(S * 0.16), cx + stick_w, by - ry + 12))
bob.putalpha(Image.composite(bob.split()[3], Image.new("L", (S, S), 0), clip))
# highlight
hl = Image.new("RGBA", (S, S), (0, 0, 0, 0))
ImageDraw.Draw(hl).ellipse((cx - int(r * 0.62), by - int(ry * 0.75), cx - int(r * 0.15), by - int(ry * 0.35)),
                           fill=(255, 255, 255, 110))
hl = hl.filter(ImageFilter.GaussianBlur(S * 0.01))
bob.alpha_composite(hl)
img.alpha_composite(bob)

# --- Water in front of the bobber's bottom (it looks submerged) ---
water = Image.new("RGBA", (S, S), (0, 0, 0, 0))
wd = ImageDraw.Draw(water)
wd.rectangle((0, water_y, S, S), fill=(8, 44, 74, 170))
water.putalpha(Image.composite(water.split()[3], Image.new("L", (S, S), 0), mask))
img.alpha_composite(water)
# bright front edge of the inner ripple
front = Image.new("RGBA", (S, S), (0, 0, 0, 0))
w, h = int(S * 0.24), int(S * 0.24 * 0.28)
ImageDraw.Draw(front).arc((cx - w, water_y - h, cx + w, water_y + h), 0, 180, fill=(*ACCENT, 255), width=int(S * 0.02))
img.alpha_composite(front)

# --- Lightning bolt (Smart Cast), top right ---
ox, oy, k = int(S * 0.71), int(S * 0.08), S * 0.0011
bolt = [(60, 0), (0, 150), (48, 150), (20, 270), (120, 100), (70, 100), (100, 0)]
pts = [(ox + x * k * 1.35, oy + y * k * 1.35) for x, y in bolt]
glow = Image.new("RGBA", (S, S), (0, 0, 0, 0))
ImageDraw.Draw(glow).polygon(pts, fill=(*ACCENT, 160))
glow = glow.filter(ImageFilter.GaussianBlur(S * 0.02))
img.alpha_composite(glow)
ImageDraw.Draw(img).polygon(pts, fill=(*ACCENT, 255))

img = img.resize((512, 512), Image.LANCZOS)
img.save(OUT)
print("saved", OUT)
