"""Generates the 1024x1024 app icon: a rounded floating ball with a keyhole,
matching the in-app floating control."""
from PIL import Image, ImageDraw
import math

S = 1024
img = Image.new("RGBA", (S, S), (0, 0, 0, 0))
d = ImageDraw.Draw(img)


def lerp(a, b, t):
    return tuple(int(a[i] + (b[i] - a[i]) * t) for i in range(3))


TOP = (46, 134, 245)      # bright blue
BOTTOM = (86, 66, 235)    # indigo


# --- background: vertical gradient inside a squircle-ish rounded rect ---
radius = int(S * 0.225)
bg = Image.new("RGB", (S, S))
bd = ImageDraw.Draw(bg)
for y in range(S):
    bd.line([(0, y), (S, y)], fill=lerp(TOP, BOTTOM, y / S))

mask = Image.new("L", (S, S), 0)
md = ImageDraw.Draw(mask)
md.rounded_rectangle([0, 0, S - 1, S - 1], radius=radius, fill=255)
img.paste(bg, (0, 0), mask)
d = ImageDraw.Draw(img)

# --- soft highlight in the upper-left ---
hi = Image.new("RGBA", (S, S), (0, 0, 0, 0))
hd = ImageDraw.Draw(hi)
hd.ellipse([-S * 0.35, -S * 0.55, S * 0.75, S * 0.45], fill=(255, 255, 255, 46))
img = Image.alpha_composite(img, hi)
d = ImageDraw.Draw(img)

# --- the floating ball ---
cx, cy = S * 0.5, S * 0.5
ball_r = S * 0.30

# shadow under the ball
sh = Image.new("RGBA", (S, S), (0, 0, 0, 0))
sd = ImageDraw.Draw(sh)
sd.ellipse([cx - ball_r, cy - ball_r + S * 0.045,
            cx + ball_r, cy + ball_r + S * 0.045],
           fill=(20, 20, 60, 70))
sh = sh.filter(__import__("PIL.ImageFilter", fromlist=["ImageFilter"]).GaussianBlur(28))
img = Image.alpha_composite(img, sh)
d = ImageDraw.Draw(img)

# ball body, lighter at the top
ball = Image.new("RGB", (S, S))
bl = ImageDraw.Draw(ball)
for y in range(int(cy - ball_r), int(cy + ball_r) + 1):
    t = (y - (cy - ball_r)) / (2 * ball_r)
    bl.line([(0, y), (S, y)], fill=lerp((255, 255, 255), (214, 228, 255), t))
bmask = Image.new("L", (S, S), 0)
ImageDraw.Draw(bmask).ellipse(
    [cx - ball_r, cy - ball_r, cx + ball_r, cy + ball_r], fill=255)
img.paste(ball, (0, 0), bmask)
d = ImageDraw.Draw(img)

# --- keyhole ---
hole_r = S * 0.072
hole_cy = cy - S * 0.035
d.ellipse([cx - hole_r, hole_cy - hole_r, cx + hole_r, hole_cy + hole_r],
          fill=(38, 84, 196, 255))
# stem of the keyhole, widening downward
top_w = S * 0.035
bot_w = S * 0.078
stem_top = hole_cy + hole_r * 0.35
stem_bot = hole_cy + S * 0.135
d.polygon([
    (cx - top_w, stem_top),
    (cx + top_w, stem_top),
    (cx + bot_w, stem_bot),
    (cx - bot_w, stem_bot),
], fill=(38, 84, 196, 255))

img.save(r"E:\222\TKFloatKey\TKFloatKey\Assets.xcassets\AppIcon.appiconset\icon1024.png")
print("icon written")
