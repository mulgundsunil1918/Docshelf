"""tools/play_assets.py — Play Store asset pack for DocShelf.

Usage:
    PYTHONIOENCODING=utf-8 python tools/play_assets.py

Produces ./play-assets/ with:
    icon-512.png                     (sourced from assets/icon/app_icon.png)
    feature-graphic-1024x500.png
    phone-1-intro.png  … phone-7-reminders.png       1080×1920
    tablet-7-1.png     … tablet-7-7.png              1200×1920
    tablet-10-1.png    … tablet-10-7.png             1800×2880
    short_description.txt
    full_description.txt
… and zips it to ./play-assets.zip.
"""
from __future__ import annotations

import math
import os
import shutil
import sys
import zipfile
from pathlib import Path

from PIL import Image, ImageDraw, ImageFilter, ImageFont

# ──────────────────────────────────────────────────────────────────────
# Brand constants
# ──────────────────────────────────────────────────────────────────────
APP_NAME       = "DocShelf"
WORDMARK       = "DOCSHELF"
INITIAL        = "D"
TAGLINE        = "Files organized · Offline"
ONE_LINE_PITCH = "Every important document of your life — in one offline vault."

PRIMARY        = (61, 90, 254)      # #3D5AFE
PRIMARY_DARK   = (45, 63, 184)      # #2D3FB8
ACCENT         = (255, 179, 0)      # #FFB300
ACCENT_DARK    = (255, 143, 0)      # #FF8F00
NAVY           = (18, 21, 42)       # #12152A
NAVY_HEADER    = (24, 28, 48)
NAVY_LIGHTER   = (32, 38, 60)
DANGER         = (211, 47, 47)
SUCCESS        = (46, 125, 50)
WARNING_AMBER  = (249, 168, 37)
GRAY_DARK      = (92, 102, 120)
GRAY_LIGHT     = (210, 215, 225)
WHITE          = (255, 255, 255)
DARK_TEXT      = (26, 31, 54)
EYEBROW_PILL   = (255, 235, 196)    # warm amber pill bg (per trap #10)

DOMAIN         = "mulgundsunil1918.github.io/Docshelf"
SUPPORT_EMAIL  = "mulgundsunil@gmail.com"

ROOT          = Path(__file__).resolve().parents[1]
APP_ICON_SRC  = ROOT / "assets" / "icon" / "app_icon.png"
OUT_DIR       = ROOT / "play-assets"
ZIP_PATH      = ROOT / "play-assets.zip"

# ──────────────────────────────────────────────────────────────────────
# Cross-platform font loader
# ──────────────────────────────────────────────────────────────────────
WIN_FONTS = Path("C:/Windows/Fonts")
MAC_FONTS = Path("/System/Library/Fonts")
LIN_FONTS = Path("/usr/share/fonts/truetype/dejavu")


def _first_existing(*candidates):
    for p in candidates:
        if Path(p).exists():
            return Path(p)
    return None


_BLACK = _first_existing(
    WIN_FONTS / "seguibl.ttf",
    WIN_FONTS / "ariblk.ttf",
    MAC_FONTS / "Helvetica.ttc",
    LIN_FONTS / "DejaVuSans-Bold.ttf",
)
_BOLD = _first_existing(
    WIN_FONTS / "seguisb.ttf",
    WIN_FONTS / "arialbd.ttf",
    MAC_FONTS / "Helvetica.ttc",
    LIN_FONTS / "DejaVuSans-Bold.ttf",
)
_REG = _first_existing(
    WIN_FONTS / "segoeui.ttf",
    WIN_FONTS / "arial.ttf",
    MAC_FONTS / "Helvetica.ttc",
    LIN_FONTS / "DejaVuSans.ttf",
)

# Colour emoji font + its native bitmap size.
# Per trap #9: colour glyphs only render with embedded_color=True at the
# font's native size, so we always rasterise at native and LANCZOS-downscale.
_EMOJI = _first_existing(
    WIN_FONTS / "seguiemj.ttf",
    MAC_FONTS / "Apple Color Emoji.ttc",
    Path("/usr/share/fonts/truetype/noto/NotoColorEmoji.ttf"),
)
_EMOJI_NATIVE = 109  # Segoe UI Emoji native bitmap size; Apple uses 137.
_emoji_cache: dict = {}


def render_emoji(char: str, size: int) -> Image.Image:
    """Rasterise a single-codepoint emoji at `size`×`size` pixels (RGBA).

    Returns a transparent square if the OS has no colour-emoji font.
    Cached, since the same emojis recur across slide variants.
    """
    if (char, size) in _emoji_cache:
        return _emoji_cache[(char, size)]
    if _EMOJI is None:
        out = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    else:
        fnt = ImageFont.truetype(str(_EMOJI), _EMOJI_NATIVE)
        canvas = Image.new(
            "RGBA", (_EMOJI_NATIVE, _EMOJI_NATIVE), (0, 0, 0, 0)
        )
        d = ImageDraw.Draw(canvas)
        try:
            d.text(
                (_EMOJI_NATIVE / 2, _EMOJI_NATIVE / 2),
                char,
                font=fnt,
                embedded_color=True,
                anchor="mm",
            )
        except Exception:
            d.text(
                (_EMOJI_NATIVE / 2, _EMOJI_NATIVE / 2),
                char,
                font=fnt,
                anchor="mm",
            )
        out = canvas.resize((size, size), Image.LANCZOS)
    _emoji_cache[(char, size)] = out
    return out


def paste_emoji(img: Image.Image, char: str, xy, size: int):
    """Paste an emoji centred inside the box (xy, size, size) on `img`."""
    glyph = render_emoji(char, size)
    img.paste(glyph, (int(xy[0]), int(xy[1])), glyph)


def F(weight: str, size: int) -> ImageFont.FreeTypeFont:
    """Resolve a font for one of: 'black' / 'bold' / 'regular'."""
    chosen = {"black": _BLACK, "bold": _BOLD, "regular": _REG}[weight]
    if chosen is None:
        return ImageFont.load_default()
    return ImageFont.truetype(str(chosen), size)


# ──────────────────────────────────────────────────────────────────────
# Helpers — the trap-avoidance utilities the prompt insisted on
# ──────────────────────────────────────────────────────────────────────
def tint(rgb, alpha: int):
    """Pre-mix `rgb` with white at the given alpha (0–255). RGB-mode safe.

    Pillow's RGB mode silently drops alpha from fill tuples — this helper
    converts an "I want a 30-alpha tint" intent into the equivalent solid
    blended RGB.
    """
    return tuple(
        int(c + (255 - c) * (1 - alpha / 255))
        for c in rgb
    )


def text_centered(d: ImageDraw.ImageDraw, xy, w: int, h: int,
                  text: str, fnt, fill):
    """Draw `text` visually centred in the box (xy, w, h)."""
    cx = xy[0] + w / 2
    cy = xy[1] + h / 2
    d.text((cx, cy), text, font=fnt, fill=fill, anchor="mm")


def fit_font(text: str, max_w: int, weight: str,
             start: int, min_size: int = 24):
    """Auto-shrink font until `text` fits in `max_w`."""
    sz = start
    while sz >= min_size:
        f = F(weight, sz)
        l, t, r, b = f.getbbox(text)
        if (r - l) <= max_w:
            return f
        sz -= 4
    return F(weight, min_size)


def rounded(d, xy, radius, **kw):
    d.rounded_rectangle(xy, radius=radius, **kw)


def shadow_under(canvas: Image.Image, xy, radius: int, blur: int = 30,
                 alpha: int = 90, dy: int = 14):
    """Soft drop-shadow under a rounded rect, used for the phone frame."""
    x0, y0, x1, y1 = xy
    pad = blur * 2
    layer = Image.new("RGBA", (x1 - x0 + pad * 2, y1 - y0 + pad * 2),
                      (0, 0, 0, 0))
    sd = ImageDraw.Draw(layer)
    sd.rounded_rectangle(
        [pad, pad + dy, pad + (x1 - x0), pad + (y1 - y0) + dy],
        radius=radius, fill=(0, 0, 0, alpha),
    )
    layer = layer.filter(ImageFilter.GaussianBlur(blur))
    canvas.alpha_composite(layer, (x0 - pad, y0 - pad))


# ──────────────────────────────────────────────────────────────────────
# Existing app icon — load + resize on demand
# ──────────────────────────────────────────────────────────────────────
_app_icon_full: Image.Image | None = None


def _icon_full() -> Image.Image:
    global _app_icon_full
    if _app_icon_full is None:
        if not APP_ICON_SRC.exists():
            sys.exit(f"App icon source missing: {APP_ICON_SRC}")
        _app_icon_full = Image.open(APP_ICON_SRC).convert("RGBA")
    return _app_icon_full


def app_icon(size: int) -> Image.Image:
    return _icon_full().resize((size, size), Image.LANCZOS)


# ──────────────────────────────────────────────────────────────────────
# (a) Icon — copy + resize the existing app icon
# ──────────────────────────────────────────────────────────────────────
def make_icon():
    icon = app_icon(512).convert("RGB")
    icon.save(OUT_DIR / "icon-512.png", "PNG", optimize=True)


# ──────────────────────────────────────────────────────────────────────
# (b) Feature graphic 1024×500
# ──────────────────────────────────────────────────────────────────────
def make_feature_graphic():
    W, H = 1024, 500
    img = Image.new("RGB", (W, H), PRIMARY_DARK)

    # Subtle radial light from the top-left corner (atmosphere, not banner)
    glow = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    gd = ImageDraw.Draw(glow)
    for r in range(900, 0, -30):
        a = int(60 * (1 - r / 900))
        gd.ellipse([-200 - r, -200 - r, 380 + r, 380 + r],
                   fill=(255, 255, 255, a))
    img.paste(glow.filter(ImageFilter.GaussianBlur(70)),
              (0, 0), glow.filter(ImageFilter.GaussianBlur(70)))

    d = ImageDraw.Draw(img, "RGBA")

    # ─── LEFT HALF — brand block ─────────────────────────────────────
    icon_size = 132
    icon_x, icon_y = 64, 90
    img.paste(app_icon(icon_size), (icon_x, icon_y), app_icon(icon_size))

    wm_x = icon_x + icon_size + 28
    fwm = F("black", 64)
    d.text((wm_x, icon_y + 4), APP_NAME, font=fwm, fill=WHITE, anchor="lt")
    ftag = F("bold", 22)
    d.text((wm_x, icon_y + 80), TAGLINE.upper(),
           font=ftag, fill=tint(WHITE, 200), anchor="lt")

    # Bottom-left value prop + sub
    d.text((64, H - 116),
           "Every important document, in one offline vault.",
           font=F("black", 32), fill=WHITE, anchor="lt")
    d.text((64, H - 70),
           "No accounts. No cloud. No tracking. Just your phone.",
           font=F("regular", 19), fill=tint(WHITE, 200), anchor="lt")

    # ─── RIGHT HALF — three stacked document cards ───────────────────
    card_w, card_h = 320, 84
    card_x = W - 60 - card_w
    base_y = 60
    items = [
        ("I", "Aadhaar.pdf",   "Identity",  ACCENT),
        ("W", "Offer letter",  "Work",      tint(WHITE, 230)),
        ("H", "Lab report",    "Health",    SUCCESS),
    ]

    # Soft shadow blob behind card stack
    sh = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    sd = ImageDraw.Draw(sh)
    for i in range(len(items)):
        cy = base_y + i * (card_h + 18)
        sd.rounded_rectangle(
            [card_x + 6, cy + 14, card_x + card_w + 6, cy + card_h + 14],
            radius=18, fill=(0, 0, 0, 80),
        )
    img.paste(sh.filter(ImageFilter.GaussianBlur(16)),
              (0, 0), sh.filter(ImageFilter.GaussianBlur(16)))

    d = ImageDraw.Draw(img, "RGBA")
    for i, (letter, name, cat, accent) in enumerate(items):
        cy = base_y + i * (card_h + 18)
        rounded(d, [card_x, cy, card_x + card_w, cy + card_h],
                18, fill=WHITE)
        rounded(d, [card_x, cy, card_x + 8, cy + card_h], 0, fill=accent)

        tile_size = 50
        tx, ty = card_x + 22, cy + (card_h - tile_size) // 2
        rounded(d, [tx, ty, tx + tile_size, ty + tile_size],
                12, fill=tint(accent, 70))
        text_centered(d, (tx, ty), tile_size, tile_size,
                      letter, F("black", 26), accent if accent != tint(WHITE, 230) else PRIMARY)

        d.text((tx + tile_size + 18, cy + 16), name,
               font=F("bold", 22), fill=DARK_TEXT, anchor="lt")
        d.text((tx + tile_size + 18, cy + 46), cat,
               font=F("regular", 16), fill=GRAY_DARK, anchor="lt")

    img.save(OUT_DIR / "feature-graphic-1024x500.png", "PNG", optimize=True)


# ──────────────────────────────────────────────────────────────────────
# Slide canvas (deep navy + vignette + corner glow)
# ──────────────────────────────────────────────────────────────────────
def slide_canvas(W: int, H: int) -> Image.Image:
    # Vertical gradient: top brighter to bottom darker (~18% delta)
    img = Image.new("RGB", (W, H), NAVY)
    grad = Image.new("RGB", (1, H), NAVY)
    gd = ImageDraw.Draw(grad)
    for y in range(H):
        t = y / H
        c = tuple(int(NAVY_HEADER[i] * (1 - t) + NAVY[i] * t) for i in range(3))
        gd.point((0, y), fill=c)
    img.paste(grad.resize((W, H), Image.NEAREST), (0, 0))

    # Soft brand-primary glow in upper-right corner
    glow = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    gd = ImageDraw.Draw(glow)
    rad = max(W, H) // 2
    for r in range(rad, 0, -20):
        a = int(70 * (1 - r / rad))
        gd.ellipse([W - rad, -rad, W + rad - r, rad - r],
                   fill=(*PRIMARY, a))
    img.paste(glow.filter(ImageFilter.GaussianBlur(80)),
              (0, 0), glow.filter(ImageFilter.GaussianBlur(80)))
    return img


def draw_brand_header(d: ImageDraw.ImageDraw, canvas: Image.Image,
                      W: int, H: int):
    pad = max(32, W // 36)
    header_h = max(70, H // 24)
    # Logo tile
    tile_size = header_h
    canvas.paste(app_icon(tile_size), (pad, pad), app_icon(tile_size))
    # Wordmark
    fwm = F("black", int(tile_size * 0.5))
    spacing_px = int(tile_size * 0.10)
    text = WORDMARK
    spaced = text  # rendered once with letterspacing trick below
    x = pad + tile_size + 16
    y = pad + tile_size // 2
    # Manual letter-spacing for the wordmark so it reads "DOCSHELF" big
    cur_x = x
    for ch in text:
        d.text((cur_x, y), ch, font=fwm, fill=WHITE, anchor="lm")
        cw = fwm.getbbox(ch)[2] - fwm.getbbox(ch)[0]
        cur_x += cw + spacing_px
    # Divider line
    div_y = pad + tile_size + 12
    d.line([(pad, div_y), (W - pad, div_y)],
           fill=tint(PRIMARY, 90), width=2)


# ──────────────────────────────────────────────────────────────────────
# Slide 1 — Intro
# ──────────────────────────────────────────────────────────────────────
def slide_intro(W: int, H: int) -> Image.Image:
    img = slide_canvas(W, H)
    d = ImageDraw.Draw(img, "RGBA")

    # Big logo block centered
    icon_size = int(W * 0.34)
    ix = (W - icon_size) // 2
    iy = int(H * 0.22)
    img.paste(app_icon(icon_size), (ix, iy), app_icon(icon_size))

    # Wordmark below icon
    wm_size = int(W * 0.10)
    fwm = F("black", wm_size)
    text_centered(d, (0, iy + icon_size + int(H * 0.04)),
                  W, wm_size + 20, APP_NAME, fwm, WHITE)

    # Tagline
    tag_y = iy + icon_size + int(H * 0.04) + wm_size + 24
    ftag = F("bold", int(W * 0.030))
    text_centered(d, (0, tag_y), W, int(W * 0.040),
                  TAGLINE, ftag, ACCENT)

    # One-line pitch
    sub_y = tag_y + int(W * 0.060)
    fsub = fit_font(ONE_LINE_PITCH, int(W * 0.84), "regular",
                    int(W * 0.026), min_size=18)
    text_centered(d, (0, sub_y), W, int(W * 0.040),
                  ONE_LINE_PITCH, fsub, tint(WHITE, 215))

    # Three feature pills
    pills = ["OFFLINE", "PRIVATE", "FOREVER"]
    pill_y = int(H * 0.86)
    fp = F("black", int(W * 0.020))
    pad_x = int(W * 0.030)
    pad_y = int(W * 0.012)
    gaps = int(W * 0.020)

    pill_dims = []
    total_w = 0
    for p in pills:
        bbox = fp.getbbox(p)
        text_w = bbox[2] - bbox[0]
        text_h = bbox[3] - bbox[1]
        pw = text_w + pad_x * 2
        ph = max(int(W * 0.036), text_h + pad_y * 2)
        pill_dims.append((p, pw, ph, text_w, text_h))
        total_w += pw
    total_w += gaps * (len(pills) - 1)
    cur_x = (W - total_w) // 2
    for p, pw, ph, _, _ in pill_dims:
        rounded(d, [cur_x, pill_y, cur_x + pw, pill_y + ph],
                ph // 2, fill=PRIMARY)
        text_centered(d, (cur_x, pill_y), pw, ph, p, fp, WHITE)
        cur_x += pw + gaps

    return img


# ──────────────────────────────────────────────────────────────────────
# Slide 2 — Problem statement (5 numbered pain cards)
# ──────────────────────────────────────────────────────────────────────
PAIN_CARDS = [
    ("01", "Scattered everywhere",
     "PDFs in WhatsApp, photos in Gallery, scans in Drive — same doc, three places."),
    ("02", "Missing when you need it",
     "Bank desk · airport · doctor — every reminder of a doc you can't find."),
    ("03", "Cloud apps you don't trust",
     "Free vaults read your data. Paid ones lock it behind a subscription."),
    ("04", "Expiry dates you forget",
     "Passport, insurance, license, lease — each renewal is a separate panic."),
    ("05", "Sharing is awkward",
     "You re-export, re-rename, re-upload every time someone needs a copy."),
]


def slide_problem(W: int, H: int) -> Image.Image:
    img = slide_canvas(W, H)
    d = ImageDraw.Draw(img, "RGBA")
    draw_brand_header(d, img, W, H)

    # Eyebrow pill — "THE PROBLEM" in warm amber on light pill
    eb_text = "THE PROBLEM"
    eb_font = F("black", int(W * 0.020))
    bbox = eb_font.getbbox(eb_text)
    eb_tw, eb_th = bbox[2] - bbox[0], bbox[3] - bbox[1]
    pad_x, pad_y = int(W * 0.024), int(W * 0.012)
    eb_w = eb_tw + pad_x * 2
    eb_h = eb_th + pad_y * 2
    eb_x = (W - eb_w) // 2
    eb_y = int(H * 0.10)
    rounded(d, [eb_x, eb_y, eb_x + eb_w, eb_y + eb_h],
            eb_h // 2, fill=EYEBROW_PILL)
    text_centered(d, (eb_x, eb_y), eb_w, eb_h,
                  eb_text, eb_font, ACCENT_DARK)

    # Headline + sub
    headline = "You already have the docs."
    sub = "You just can't find them."
    h_y = eb_y + eb_h + int(H * 0.025)
    fh = fit_font(headline, int(W * 0.90), "black",
                  int(W * 0.060), min_size=32)
    text_centered(d, (0, h_y), W, int(W * 0.08), headline, fh, WHITE)
    fs = F("regular", int(W * 0.030))
    text_centered(d, (0, h_y + int(W * 0.080)),
                  W, int(W * 0.04), sub, fs, tint(WHITE, 200))

    # 5 numbered cards
    margin = int(W * 0.06)
    card_x0 = margin
    card_x1 = W - margin
    list_y = h_y + int(W * 0.140)
    card_h = (H - list_y - int(H * 0.10)) // len(PAIN_CARDS) - 12
    if card_h < 80:
        card_h = 80

    for i, (num, title, body) in enumerate(PAIN_CARDS):
        cy = list_y + i * (card_h + 12)
        # White card
        rounded(d, [card_x0, cy, card_x1, cy + card_h],
                int(card_h * 0.18), fill=WHITE)
        # Left amber stripe
        rounded(d, [card_x0, cy, card_x0 + 8, cy + card_h], 0, fill=ACCENT)
        # Number tile
        tile_size = int(card_h * 0.62)
        tx = card_x0 + int(W * 0.022)
        ty = cy + (card_h - tile_size) // 2
        rounded(d, [tx, ty, tx + tile_size, ty + tile_size],
                int(tile_size * 0.22), fill=ACCENT)
        text_centered(d, (tx, ty), tile_size, tile_size,
                      num, F("black", int(tile_size * 0.46)), WHITE)
        # Title + body — both auto-shrink so long titles don't overflow.
        text_x = tx + tile_size + int(W * 0.022)
        right_pad = int(W * 0.030)
        avail_w = card_x1 - text_x - right_pad
        title_font = fit_font(title, avail_w, "black",
                              int(card_h * 0.30), min_size=18)
        d.text((text_x, cy + int(card_h * 0.18)), title,
               font=title_font, fill=DARK_TEXT, anchor="lt")
        body_font = fit_font(body, avail_w, "regular",
                             int(card_h * 0.22), min_size=13)
        d.text((text_x, cy + int(card_h * 0.55)), body,
               font=body_font, fill=GRAY_DARK, anchor="lt")

    # Closing line in brand accent
    closing = "→ DocShelf fixes that."
    cy = int(H * 0.94)
    text_centered(d, (0, cy - int(H * 0.02)), W, int(H * 0.04),
                  closing, F("black", int(W * 0.030)), ACCENT)

    return img


# ──────────────────────────────────────────────────────────────────────
# Phone frame — Android punch-hole
# ──────────────────────────────────────────────────────────────────────
def render_phone_in_frame(inner: Image.Image,
                          frame_w: int, frame_h: int) -> Image.Image:
    """Wrap `inner` (already rendered at frame inner-screen size) in an
    Android-style frame with bezel, rounded corners, punch-hole, and
    side-button slivers. Returns an RGBA image (frame_w × frame_h)."""
    bezel = max(10, int(frame_w * 0.020))
    radius = int(frame_w * 0.085)

    # Body
    body = Image.new("RGBA", (frame_w, frame_h), (0, 0, 0, 0))
    d = ImageDraw.Draw(body)
    d.rounded_rectangle([0, 0, frame_w, frame_h],
                        radius=radius, fill=(20, 25, 40, 255))

    # Inner screen well
    sx0 = bezel
    sy0 = bezel
    sx1 = frame_w - bezel
    sy1 = frame_h - bezel
    sw = sx1 - sx0
    sh = sy1 - sy0
    inner_resized = inner.resize((sw, sh), Image.LANCZOS).convert("RGBA")
    # Round screen corners
    mask = Image.new("L", (sw, sh), 0)
    md = ImageDraw.Draw(mask)
    md.rounded_rectangle([0, 0, sw, sh],
                         radius=int(radius * 0.80), fill=255)
    body.paste(inner_resized, (sx0, sy0), mask)

    # Punch-hole front camera (small dark circle, slight inner highlight)
    hole_r = max(8, int(frame_w * 0.022))
    hole_cx = frame_w // 2
    hole_cy = bezel + int(frame_w * 0.040)
    d.ellipse([hole_cx - hole_r, hole_cy - hole_r,
               hole_cx + hole_r, hole_cy + hole_r],
              fill=(8, 10, 18, 255))
    inner_r = int(hole_r * 0.55)
    d.ellipse([hole_cx - inner_r, hole_cy - inner_r,
               hole_cx + inner_r, hole_cy + inner_r],
              fill=(28, 32, 50, 255))

    # Right-edge buttons: power + 2 volume slivers
    btn_x0 = frame_w - bezel - 2
    btn_x1 = frame_w + 4
    # Power
    py0 = int(frame_h * 0.30)
    py1 = py0 + int(frame_h * 0.06)
    d.rounded_rectangle([btn_x0, py0, btn_x1, py1],
                        radius=4, fill=(28, 32, 52, 255))
    # Vol up
    vy0 = py1 + int(frame_h * 0.04)
    vy1 = vy0 + int(frame_h * 0.05)
    d.rounded_rectangle([btn_x0, vy0, btn_x1, vy1],
                        radius=4, fill=(28, 32, 52, 255))
    # Vol down
    wy0 = vy1 + int(frame_h * 0.012)
    wy1 = wy0 + int(frame_h * 0.05)
    d.rounded_rectangle([btn_x0, wy0, btn_x1, wy1],
                        radius=4, fill=(28, 32, 52, 255))

    return body


# ──────────────────────────────────────────────────────────────────────
# Inner UI mockup helpers
# ──────────────────────────────────────────────────────────────────────
def status_bar(d: ImageDraw.ImageDraw, w: int, light: bool = False):
    """Time on left, signal+battery on right."""
    bar_h = max(38, w // 22)
    fg = WHITE if not light else DARK_TEXT
    f = F("bold", int(bar_h * 0.50))
    d.text((bar_h * 0.6, bar_h / 2), "9:41", font=f, fill=fg, anchor="lm")
    # Right: signal bars + battery
    rx = w - bar_h * 0.6
    # Battery
    bw, bh = bar_h * 1.0, bar_h * 0.40
    bx0 = rx - bw
    by = bar_h / 2 - bh / 2
    d.rounded_rectangle([bx0, by, rx, by + bh], radius=4, outline=fg, width=2)
    d.rectangle([rx, by + bh * 0.25, rx + 4, by + bh * 0.75], fill=fg)
    d.rounded_rectangle([bx0 + 2, by + 2, bx0 + bw - 8, by + bh - 2],
                        radius=2, fill=fg)
    # Signal bars (4 ascending)
    sx = bx0 - 12
    sh = bar_h * 0.55
    for i in range(4):
        h = sh * (0.30 + i * 0.22)
        bw_b = bar_h * 0.15
        by0 = bar_h / 2 + sh / 2 - h
        d.rectangle([sx - (3 - i) * (bw_b + 4) - bw_b,
                     by0,
                     sx - (3 - i) * (bw_b + 4),
                     bar_h / 2 + sh / 2],
                    fill=fg)
    return bar_h


def mock_appbar(d, w: int, y: int, title: str, badge: str | None = None,
                primary_bg: bool = True):
    h = int(w * 0.13)
    bg = PRIMARY if primary_bg else WHITE
    fg = WHITE if primary_bg else DARK_TEXT
    d.rectangle([0, y, w, y + h], fill=bg)
    pad = int(w * 0.04)
    f = F("black", int(h * 0.40))
    d.text((pad, y + h / 2), title, font=f, fill=fg, anchor="lm")
    if badge:
        bf = F("black", int(h * 0.26))
        bbox = bf.getbbox(badge)
        bw = bbox[2] - bbox[0] + int(w * 0.040)
        bh = int(h * 0.45)
        bx = w - pad - bw
        by = y + (h - bh) // 2
        rounded(d, [bx, by, bx + bw, by + bh], bh // 2, fill=ACCENT)
        text_centered(d, (bx, by), bw, bh, badge, bf, DARK_TEXT)
    return h


def mock_bottom_nav(d, w: int, h: int, active_idx: int = 0):
    """5-item bottom nav. Returns the y where the nav starts."""
    nav_h = int(h * 0.085)
    ny = h - nav_h
    d.rectangle([0, ny, w, h], fill=WHITE)
    d.line([(0, ny), (w, ny)], fill=tint(GRAY_LIGHT, 230), width=1)
    items = ["Home", "Library", "Scan", "Search", "Settings"]
    iw = w / len(items)
    for i, label in enumerate(items):
        cx = int(iw * (i + 0.5))
        active = i == active_idx
        # Dot icon
        rad = int(nav_h * 0.14)
        col = PRIMARY if active else GRAY_DARK
        d.ellipse([cx - rad, ny + int(nav_h * 0.20),
                   cx + rad, ny + int(nav_h * 0.20) + rad * 2],
                  fill=col)
        # Label
        f = F("black" if active else "regular", int(nav_h * 0.18))
        d.text((cx, ny + int(nav_h * 0.74)),
               label, font=f, fill=col, anchor="mm")
    return ny


# ─── Mock 1: Camera scanner ──────────────────────────────────────────
def screen_scan(w: int, h: int) -> Image.Image:
    img = Image.new("RGB", (w, h), (12, 14, 28))
    d = ImageDraw.Draw(img, "RGBA")
    status_bar(d, w, light=False)

    # Faux viewfinder — slight gradient, document outline + corner brackets
    vf_x0 = int(w * 0.10)
    vf_y0 = int(h * 0.20)
    vf_x1 = int(w * 0.90)
    vf_y1 = int(h * 0.74)
    # Document — white-ish rectangle at slight tilt
    paper_pad = int(w * 0.04)
    rounded(d, [vf_x0 + paper_pad, vf_y0 + paper_pad,
                vf_x1 - paper_pad, vf_y1 - paper_pad],
            int(w * 0.02), fill=tint(WHITE, 240))
    # Faux text lines on the paper
    line_x0 = vf_x0 + paper_pad + int(w * 0.05)
    line_x1 = vf_x1 - paper_pad - int(w * 0.05)
    for i, frac in enumerate([0.18, 0.30, 0.42, 0.54, 0.66, 0.78]):
        ly = int(vf_y0 + (vf_y1 - vf_y0) * frac)
        line_w_factor = 1.0 if i % 3 != 2 else 0.65
        d.line([(line_x0, ly),
                (line_x0 + (line_x1 - line_x0) * line_w_factor, ly)],
               fill=tint(GRAY_DARK, 180), width=int(w * 0.008))

    # Auto-detected corner brackets in amber
    bracket = int(w * 0.06)
    bw = int(w * 0.012)
    for (cx, cy, dx, dy) in [
        (vf_x0, vf_y0, +1, +1),
        (vf_x1, vf_y0, -1, +1),
        (vf_x0, vf_y1, +1, -1),
        (vf_x1, vf_y1, -1, -1),
    ]:
        d.line([(cx, cy), (cx + dx * bracket, cy)], fill=ACCENT, width=bw)
        d.line([(cx, cy), (cx, cy + dy * bracket)], fill=ACCENT, width=bw)

    # Status pill above viewfinder
    pill_text = "Auto-detecting edges…"
    pf = F("bold", int(w * 0.028))
    bbox = pf.getbbox(pill_text)
    pw = bbox[2] - bbox[0] + int(w * 0.04)
    ph = int(w * 0.060)
    px = (w - pw) // 2
    py = vf_y0 - ph - int(w * 0.02)
    rounded(d, [px, py, px + pw, py + ph], ph // 2, fill=tint(NAVY, 220))
    text_centered(d, (px, py), pw, ph, pill_text, pf, WHITE)

    # Bottom: capture button + multi-page toggle
    cap_r = int(w * 0.10)
    cx = w // 2
    cy = int(h * 0.86)
    d.ellipse([cx - cap_r - 8, cy - cap_r - 8,
               cx + cap_r + 8, cy + cap_r + 8],
              outline=WHITE, width=int(w * 0.010))
    d.ellipse([cx - cap_r, cy - cap_r, cx + cap_r, cy + cap_r],
              fill=ACCENT)

    # Multi-page chip on left
    chip_text = "Multi-page · ON"
    cf = F("bold", int(w * 0.024))
    bbox = cf.getbbox(chip_text)
    cw_p = bbox[2] - bbox[0] + int(w * 0.04)
    ch_p = int(w * 0.052)
    cx_p = int(w * 0.06)
    cy_p = cy - ch_p // 2
    rounded(d, [cx_p, cy_p, cx_p + cw_p, cy_p + ch_p],
            ch_p // 2, fill=tint(PRIMARY, 170))
    text_centered(d, (cx_p, cy_p), cw_p, ch_p, chip_text, cf, WHITE)
    return img


# ─── Mock 2: Import sheet over Home ──────────────────────────────────
def screen_import(w: int, h: int) -> Image.Image:
    img = Image.new("RGB", (w, h), (245, 247, 251))
    d = ImageDraw.Draw(img, "RGBA")
    status_bar(d, w)
    appbar_h = mock_appbar(d, w, status_bar(ImageDraw.Draw(Image.new("RGB",(w,38))), w),
                           APP_NAME)
    # We need the actual y_after_status — recompute simply
    bar_h = max(38, w // 22)
    appbar_h = int(w * 0.13)
    y = bar_h + appbar_h

    # Greeting card (indigo gradient)
    greet_h = int(h * 0.13)
    greet_y = y + int(h * 0.025)
    rounded(d, [int(w * 0.05), greet_y, int(w * 0.95),
                greet_y + greet_h], int(w * 0.04), fill=PRIMARY)
    f1 = F("black", int(w * 0.044))
    d.text((int(w * 0.07), greet_y + int(greet_h * 0.30)),
           "Good morning 👋", font=f1, fill=WHITE, anchor="lm")
    f2 = F("regular", int(w * 0.026))
    d.text((int(w * 0.07), greet_y + int(greet_h * 0.65)),
           "Tap Import to file a new document.",
           font=f2, fill=tint(WHITE, 220), anchor="lm")

    # 3 hero buttons row (Import / Scan / Find)
    hero_y = greet_y + greet_h + int(h * 0.025)
    hero_h = int(h * 0.10)
    btn_pad = int(w * 0.025)
    bx0 = int(w * 0.05)
    bx1 = int(w * 0.95)
    btn_w = (bx1 - bx0 - btn_pad * 2) // 3
    labels = [("Import", True), ("Scan", False), ("Find", False)]
    for i, (label, active) in enumerate(labels):
        bx = bx0 + i * (btn_w + btn_pad)
        bg = tint(PRIMARY, 60 if not active else 140)
        rounded(d, [bx, hero_y, bx + btn_w, hero_y + hero_h],
                int(w * 0.03), fill=bg)
        f = F("black", int(w * 0.026))
        text_centered(d, (bx, hero_y), btn_w, hero_h, label,
                      f, PRIMARY if not active else WHITE)

    # Dim overlay (sheet open)
    dim = Image.new("RGBA", (w, h), (10, 14, 30, 130))
    img.paste(dim, (0, 0), dim)
    d = ImageDraw.Draw(img, "RGBA")

    # Bottom-sheet panel
    sheet_y = int(h * 0.55)
    rounded(d, [0, sheet_y, w, h], int(w * 0.06), fill=WHITE)
    # Drag handle
    d.rounded_rectangle([w // 2 - int(w * 0.06), sheet_y + int(w * 0.020),
                         w // 2 + int(w * 0.06), sheet_y + int(w * 0.030)],
                        radius=8, fill=tint(GRAY_LIGHT, 220))

    # Sheet header
    fhd = F("black", int(w * 0.038))
    d.text((int(w * 0.06), sheet_y + int(w * 0.08)),
           "Import documents", font=fhd, fill=DARK_TEXT, anchor="lt")

    # 3 list items
    items = [
        ("📄", "Import a single file",
         "Pick one PDF, image, doc or note"),
        ("🗂", "Import multiple files",
         "Pick several at once"),
        ("📁", "Import an entire folder",
         "Recursively scan and batch-import"),
    ]
    item_y = sheet_y + int(w * 0.18)
    item_h = int(w * 0.16)
    for i, (icon_letter, title, sub) in enumerate(items):
        iy = item_y + i * (item_h + int(w * 0.020))
        # Tile
        tile_size = int(item_h * 0.82)
        tx = int(w * 0.06)
        ty = iy + (item_h - tile_size) // 2
        rounded(d, [tx, ty, tx + tile_size, ty + tile_size],
                int(tile_size * 0.22), fill=tint(PRIMARY, 60))
        text_centered(d, (tx, ty), tile_size, tile_size,
                      ["1", "N", "F"][i], F("black", int(tile_size * 0.46)),
                      PRIMARY)
        # Title + sub
        d.text((tx + tile_size + int(w * 0.04), iy + int(item_h * 0.22)),
               title, font=F("black", int(w * 0.030)),
               fill=DARK_TEXT, anchor="lt")
        d.text((tx + tile_size + int(w * 0.04), iy + int(item_h * 0.62)),
               sub, font=F("regular", int(w * 0.022)),
               fill=GRAY_DARK, anchor="lt")

    return img


# ─── Mock 3: Categories grid ─────────────────────────────────────────
CATEGORY_GRID = [
    ("Identity",   "🪪", PRIMARY,        12),
    ("Finance",    "💰", PRIMARY_DARK,   28),
    ("Work",       "💼", ACCENT_DARK,    19),
    ("Education",  "🎓", (123, 90, 220), 14),
    ("Health",     "🏥", SUCCESS,         9),
    ("Insurance",  "🛡", (90, 175, 220), 11),
    ("Property",   "🏠", (190, 100, 130),  6),
    ("Vehicle",    "🚗", (40, 140, 180),  4),
]


def screen_categories(w: int, h: int) -> Image.Image:
    img = Image.new("RGB", (w, h), (245, 247, 251))
    d = ImageDraw.Draw(img, "RGBA")
    bar_h = status_bar(d, w)
    appbar_h = mock_appbar(d, w, bar_h, "My Library", primary_bg=False)
    y = bar_h + appbar_h

    # 2-column grid
    margin = int(w * 0.04)
    gap = int(w * 0.025)
    col_w = (w - margin * 2 - gap) // 2
    card_h = int(col_w * 0.85)

    for i, (name, emoji, accent, count) in enumerate(CATEGORY_GRID):
        col = i % 2
        row = i // 2
        cx = margin + col * (col_w + gap)
        cy = y + int(h * 0.025) + row * (card_h + gap)
        # Card with indigo gradient feel — solid tinted
        rounded(d, [cx, cy, cx + col_w, cy + card_h],
                int(col_w * 0.07), fill=accent)
        # Emoji in upper-left — direct paste, no white tile background.
        # (The earlier bug: tint(WHITE, 100) returned solid white, then
        # the letter was also white, so the icon looked like an empty box.)
        emoji_size = int(card_h * 0.32)
        ex = cx + int(col_w * 0.05)
        ey = cy + int(card_h * 0.07)
        paste_emoji(img, emoji, (ex, ey), emoji_size)
        # Name + count
        d.text((cx + int(col_w * 0.07), cy + int(card_h * 0.55)),
               name, font=F("black", int(col_w * 0.10)),
               fill=WHITE, anchor="lt")
        d.text((cx + int(col_w * 0.07), cy + int(card_h * 0.75)),
               f"{count} document{'s' if count != 1 else ''}",
               font=F("regular", int(col_w * 0.062)),
               fill=tint(WHITE, 220), anchor="lt")

    # Bottom nav
    mock_bottom_nav(d, w, h, active_idx=1)
    return img


# ─── Mock 4: Rich note editor ────────────────────────────────────────
def screen_notes(w: int, h: int) -> Image.Image:
    img = Image.new("RGB", (w, h), (255, 251, 235))  # soft amber tint
    d = ImageDraw.Draw(img, "RGBA")
    bar_h = status_bar(d, w, light=True)
    # AppBar (white-ish on amber bg)
    abh = int(w * 0.13)
    f_ab = F("black", int(abh * 0.36))
    pad = int(w * 0.04)
    d.text((pad, bar_h + abh / 2), "Edit note", font=f_ab,
           fill=DARK_TEXT, anchor="lm")
    # Save button
    save_w, save_h = int(w * 0.18), int(abh * 0.55)
    sx = w - pad - save_w
    sy = bar_h + (abh - save_h) // 2
    rounded(d, [sx, sy, sx + save_w, sy + save_h],
            save_h // 2, fill=PRIMARY)
    text_centered(d, (sx, sy), save_w, save_h, "Save",
                  F("black", int(save_h * 0.42)), WHITE)
    y = bar_h + abh

    # Folder chip
    chip_text = "Work / Project Briefs"
    cf = F("bold", int(w * 0.026))
    bbox = cf.getbbox(chip_text)
    cw_p = bbox[2] - bbox[0] + int(w * 0.06)
    ch_p = int(w * 0.06)
    cx_p = pad
    cy_p = y + int(w * 0.03)
    rounded(d, [cx_p, cy_p, cx_p + cw_p, cy_p + ch_p],
            ch_p // 2, fill=tint(PRIMARY, 70))
    text_centered(d, (cx_p, cy_p), cw_p, ch_p, chip_text, cf, PRIMARY)

    # Title
    title_y = cy_p + ch_p + int(w * 0.03)
    d.text((pad, title_y), "Q1 review notes",
           font=F("black", int(w * 0.060)),
           fill=DARK_TEXT, anchor="lt")
    d.line([(pad, title_y + int(w * 0.085)),
            (w - pad, title_y + int(w * 0.085))],
           fill=tint(GRAY_LIGHT, 230), width=2)

    # Body — H1 + bullets, with one highlighted span
    body_y = title_y + int(w * 0.115)
    d.text((pad, body_y), "Action items",
           font=F("black", int(w * 0.044)),
           fill=DARK_TEXT, anchor="lt")
    body_y += int(w * 0.075)

    bullets = [
        ("•", "Ship", "v0.2.0 to Play Internal", " by Friday"),
        ("•", "Update", "privacy policy", " (camera disclosure)"),
        ("•", "Reach out to", "5 beta testers", " for review"),
        ("•", "Polish", "the home screen tips", " carousel"),
    ]
    fb = F("regular", int(w * 0.034))
    fbb = F("black", int(w * 0.034))
    for i, (b, prefix, mid, suffix) in enumerate(bullets):
        by_ = body_y + i * int(w * 0.062)
        d.text((pad, by_), b, font=fb, fill=DARK_TEXT, anchor="lt")
        x_cur = pad + int(w * 0.04)
        # prefix
        d.text((x_cur, by_), prefix + " ", font=fb, fill=DARK_TEXT, anchor="lt")
        x_cur += fb.getbbox(prefix + " ")[2]
        # highlighted (amber)
        bbox_m = fbb.getbbox(mid)
        mid_w, mid_h = bbox_m[2] - bbox_m[0], bbox_m[3] - bbox_m[1]
        rounded(d, [x_cur - 4, by_ + 2,
                    x_cur + mid_w + 4, by_ + mid_h + 8],
                6, fill=ACCENT)
        d.text((x_cur, by_), mid, font=fbb, fill=DARK_TEXT, anchor="lt")
        x_cur += mid_w
        # suffix
        d.text((x_cur, by_), suffix, font=fb, fill=DARK_TEXT, anchor="lt")

    # Toolbar at bottom
    tb_h = int(w * 0.13)
    tb_y = h - tb_h
    d.rectangle([0, tb_y, w, h], fill=WHITE)
    d.line([(0, tb_y), (w, tb_y)], fill=tint(GRAY_LIGHT, 230), width=1)
    icons = ["B", "I", "U", "S", "≡", "•", "1.", "H₁", "↺"]
    iw = w / len(icons)
    for i, label in enumerate(icons):
        cx = int(iw * (i + 0.5))
        d.text((cx, tb_y + tb_h / 2), label,
               font=F("black", int(tb_h * 0.32)),
               fill=DARK_TEXT, anchor="mm")
    return img


# ─── Mock 5: Expiry reminders ────────────────────────────────────────
def screen_reminders(w: int, h: int) -> Image.Image:
    img = Image.new("RGB", (w, h), (245, 247, 251))
    d = ImageDraw.Draw(img, "RGBA")
    bar_h = status_bar(d, w)
    appbar_h = mock_appbar(d, w, bar_h, "Properties")
    y = bar_h + appbar_h

    # Doc card
    card_y = y + int(h * 0.025)
    card_h = int(h * 0.16)
    pad = int(w * 0.05)
    rounded(d, [pad, card_y, w - pad, card_y + card_h],
            int(w * 0.04), fill=WHITE)
    # PDF tile
    tile = int(card_h * 0.62)
    tx = pad + int(w * 0.04)
    ty = card_y + (card_h - tile) // 2
    rounded(d, [tx, ty, tx + tile, ty + tile],
            int(tile * 0.18), fill=DANGER)
    text_centered(d, (tx, ty), tile, tile, "PDF",
                  F("black", int(tile * 0.30)), WHITE)
    # Name + breadcrumb
    d.text((tx + tile + int(w * 0.04), card_y + int(card_h * 0.24)),
           "Passport.pdf", font=F("black", int(w * 0.040)),
           fill=DARK_TEXT, anchor="lt")
    d.text((tx + tile + int(w * 0.04), card_y + int(card_h * 0.60)),
           "Identity / Passport · 2.4 MB",
           font=F("regular", int(w * 0.026)),
           fill=GRAY_DARK, anchor="lt")

    # Expiry section
    sec_y = card_y + card_h + int(h * 0.030)
    rounded(d, [pad, sec_y, w - pad, sec_y + int(h * 0.30)],
            int(w * 0.04), fill=WHITE)
    sx = pad + int(w * 0.04)
    sy = sec_y + int(w * 0.04)
    d.text((sx, sy), "EXPIRY",
           font=F("black", int(w * 0.024)),
           fill=GRAY_DARK, anchor="lt")
    d.text((sx, sy + int(w * 0.05)),
           "15 March 2031",
           font=F("black", int(w * 0.052)),
           fill=DARK_TEXT, anchor="lt")
    # Days-until chip (green)
    chip_text = "in 4 years 10 months"
    cf = F("bold", int(w * 0.026))
    bbox = cf.getbbox(chip_text)
    cw_p = bbox[2] - bbox[0] + int(w * 0.04)
    ch_p = int(w * 0.058)
    cx_p = sx
    cy_p = sy + int(w * 0.13)
    rounded(d, [cx_p, cy_p, cx_p + cw_p, cy_p + ch_p],
            ch_p // 2, fill=tint(SUCCESS, 70))
    text_centered(d, (cx_p, cy_p), cw_p, ch_p, chip_text, cf, SUCCESS)

    # Reminder lead-time row
    rl_y = cy_p + ch_p + int(w * 0.04)
    d.text((sx, rl_y), "Reminder lead-time",
           font=F("regular", int(w * 0.028)),
           fill=GRAY_DARK, anchor="lt")
    d.text((sx, rl_y + int(w * 0.045)), "30 days before",
           font=F("black", int(w * 0.038)),
           fill=DARK_TEXT, anchor="lt")

    # Calendar status row (success bar) — use a drawn check tile
    # instead of the ✓ glyph (which Pillow + sans-serif font drops as a
    # tofu box per trap #9 in the prompt).
    cal_y = rl_y + int(w * 0.130)
    cal_h = int(w * 0.090)
    rounded(d, [sx, cal_y, w - pad - int(w * 0.04),
                cal_y + cal_h],
            int(w * 0.02), fill=tint(SUCCESS, 60))
    # Drawn check mark on the left
    check_size = int(cal_h * 0.55)
    cx = sx + int(cal_h * 0.20)
    cy = cal_y + (cal_h - check_size) // 2
    rounded(d, [cx, cy, cx + check_size, cy + check_size],
            check_size // 4, fill=SUCCESS)
    # Two-line check stroke
    d.line([
        (cx + check_size * 0.22, cy + check_size * 0.55),
        (cx + check_size * 0.42, cy + check_size * 0.74),
        (cx + check_size * 0.78, cy + check_size * 0.32),
    ], fill="white", width=max(3, int(check_size * 0.14)))
    f_cal = F("bold", int(w * 0.030))
    # Centre the text in the remaining space (right of the check tile)
    text_x = cx + check_size + int(w * 0.020)
    text_w = (w - pad - int(w * 0.04)) - text_x
    text_centered(d, (text_x, cal_y), text_w, cal_h,
                  "Reminder added to your phone calendar",
                  f_cal, SUCCESS)
    # Bottom nav
    mock_bottom_nav(d, w, h, active_idx=1)
    return img


# ──────────────────────────────────────────────────────────────────────
# Slide composer (feature slides)
# ──────────────────────────────────────────────────────────────────────
def slide_feature(W: int, H: int, screen_fn,
                  headline: str, subtitle: str) -> Image.Image:
    img = slide_canvas(W, H)
    d = ImageDraw.Draw(img, "RGBA")
    draw_brand_header(d, img, W, H)

    # Headline + subtitle
    h_y = int(H * 0.10)
    fh = fit_font(headline, int(W * 0.88), "black",
                  int(W * 0.060), min_size=32)
    text_centered(d, (0, h_y), W, int(W * 0.085), headline, fh, WHITE)
    fs = fit_font(subtitle, int(W * 0.84), "regular",
                  int(W * 0.028), min_size=16)
    text_centered(d, (0, h_y + int(W * 0.080)),
                  W, int(W * 0.04), subtitle, fs, tint(WHITE, 200))

    # Phone — width 75% of canvas, aspect ~9:18
    frame_w = int(W * 0.75)
    frame_h = int(frame_w * 1.96)
    available_y0 = h_y + int(W * 0.150)
    available_y1 = H - int(H * 0.04)
    if frame_h > (available_y1 - available_y0):
        frame_h = available_y1 - available_y0
        frame_w = int(frame_h / 1.96)

    # Render inner mock at frame inner size for crisp text
    bezel = max(10, int(frame_w * 0.020))
    inner_w = frame_w - bezel * 2
    inner_h = frame_h - bezel * 2
    inner = screen_fn(inner_w, inner_h)
    frame = render_phone_in_frame(inner, frame_w, frame_h)

    # Centered horizontally
    fx = (W - frame_w) // 2
    fy = available_y0 + (available_y1 - available_y0 - frame_h) // 2
    base = img.convert("RGBA")
    shadow_under(base, [fx, fy, fx + frame_w, fy + frame_h],
                 radius=int(frame_w * 0.085), blur=30,
                 alpha=110, dy=18)
    base.alpha_composite(frame, (fx, fy))
    return base.convert("RGB")


# ──────────────────────────────────────────────────────────────────────
# Slide pack emitter
# ──────────────────────────────────────────────────────────────────────
FEATURES = [
    ("phone-3-scan",
     screen_scan,
     "Scan paper documents",
     "Auto-edge detection. Perspective fixed. Multi-page → one PDF."),
    ("phone-4-import",
     screen_import,
     "Import from anywhere",
     "Single file, multiple files, or an entire folder. Or share-to from any app."),
    ("phone-5-categories",
     screen_categories,
     "14 starter folders, fully customisable",
     "Identity, Finance, Work, Education, Health, Insurance, Quotations, Receipts…"),
    ("phone-6-notes",
     screen_notes,
     "Rich-text notes built in",
     "Bold, italic, underline, highlight, lists, headings — all offline."),
    ("phone-7-reminders",
     screen_reminders,
     "Calendar reminders for what expires",
     "DocShelf hands the reminder to your phone calendar — survives reboots & battery savers."),
]


def emit_slide_set(prefix: str, W: int, H: int):
    """Render the 7-slide pack at (W, H) and save with `prefix`."""
    slide_intro(W, H).save(OUT_DIR / f"{prefix}1-intro.png", "PNG", optimize=True)
    slide_problem(W, H).save(OUT_DIR / f"{prefix}2-problem.png", "PNG", optimize=True)
    for i, (name, fn, headline, subtitle) in enumerate(FEATURES, start=3):
        slug = name.split("-", 2)[-1]
        slide = slide_feature(W, H, fn, headline, subtitle)
        slide.save(OUT_DIR / f"{prefix}{i}-{slug}.png", "PNG", optimize=True)


def make_phone_screens():
    emit_slide_set(prefix="phone-", W=1080, H=1920)


def make_tablet_7_screens():
    # 1200×1920 — same composition, slightly wider canvas
    W, H = 1200, 1920
    slide_intro(W, H).save(OUT_DIR / "tablet-7-1.png", "PNG", optimize=True)
    slide_problem(W, H).save(OUT_DIR / "tablet-7-2.png", "PNG", optimize=True)
    for i, (name, fn, headline, subtitle) in enumerate(FEATURES, start=3):
        slide_feature(W, H, fn, headline, subtitle).save(
            OUT_DIR / f"tablet-7-{i}.png", "PNG", optimize=True
        )


def make_tablet_10_screens():
    # 1800×2880 — 10-inch tablet
    W, H = 1800, 2880
    slide_intro(W, H).save(OUT_DIR / "tablet-10-1.png", "PNG", optimize=True)
    slide_problem(W, H).save(OUT_DIR / "tablet-10-2.png", "PNG", optimize=True)
    for i, (name, fn, headline, subtitle) in enumerate(FEATURES, start=3):
        slide_feature(W, H, fn, headline, subtitle).save(
            OUT_DIR / f"tablet-10-{i}.png", "PNG", optimize=True
        )


# ──────────────────────────────────────────────────────────────────────
# Descriptions
# ──────────────────────────────────────────────────────────────────────
SHORT_DESCRIPTION = (
    "Offline document vault — scan, organise & remind for IDs, bills, contracts and more."
)

FULL_DESCRIPTION = """\
DocShelf — every important document of your life, in one offline vault on your phone.

⚡ The chaos: passports in WhatsApp, contracts in Gmail, marksheets in Drive, car quotations on a USB stick somewhere. The fix: one private, offline vault that scans, organises, searches, and reminds — without ever uploading a thing.

▸ ON-DEVICE DOCUMENT SCANNER
Tap Scan, point at any paper document, and the camera auto-detects edges, fixes perspective, and enhances contrast — like Adobe Scan, but fully offline. Multi-page captures stitch into a single PDF automatically.

▸ IMPORT FROM ANYWHERE
Pick a single file, multiple files, or an entire folder. Or share into DocShelf from WhatsApp, Drive, Gmail, Files — anywhere your documents already live. The “Find on device” scanner crawls common folders (WhatsApp, Telegram, Downloads, DCIM, Documents) for files you already own.

▸ 14 STARTER CATEGORIES
Identity, Finance, Work, Education, Health, Insurance & Policies, Property, Vehicle, Bills, Receipts & Warranties, Quotations & Estimates, Travel, Family, and Other. Add your own subfolders or whole new categories anytime.

▸ RICH-TEXT NOTES BUILT IN
Powered by flutter-quill — bold, italic, underline, strike, highlight, bullet & numbered lists, headings, indent, quote, undo / redo. Pick a sticky-note background colour. Notes save alongside your documents.

▸ EXPIRY REMINDERS THROUGH YOUR PHONE CALENDAR
Toggle “This document has an expiry date” on a passport, insurance, lease, license — DocShelf opens your phone’s native calendar pre-filled with the reminder. The OS handles the alert. Survives reboots, battery savers, and OEM kill behaviour that breaks normal in-app reminders.

▸ SEARCH THAT ACTUALLY FINDS
Search across file names, your descriptions, AND folder paths. Filter by file type. Find any document in seconds.

KEY FEATURES
• Fully offline — no account, no cloud, no tracking, no ads
• On-device document scanner (Google ML Kit, no upload)
• Import single, multiple, or entire-folder
• 14 starter folders + unlimited custom subfolders
• Rich-text note editor (lists, highlight, headings)
• Calendar-based expiry reminders
• Bookmarks, descriptions, and metadata on every file
• Material 3 design with light + dark mode
• Dark mode designed intentionally — not a slap-on
• Files visible in your file manager at /storage/emulated/0/DocShelf/
• Files survive uninstall — your data is yours
• No accounts. No tracking. No ads.

▸ WHO IT’S FOR
DocShelf is built for anyone with documents:
• Households juggling Aadhaar, PAN, sale deeds, marksheets, bills
• Professionals tracking contracts, NDAs, payslips, performance reviews
• Students & teachers managing assignments, marksheets, lesson plans
• Anyone comparing car quotations, repair estimates, vendor bids
• Anyone tired of cloud subscription apps reading their data

Examples: passport, driving license, ITR, bank statement, insurance policy, lease agreement, NDA, payslip, car quotation, repair estimate, warranty card, lab report, prescription, marksheet, lesson plan, project report.

▸ PRIVATE BY DESIGN
DocShelf has no server. There is no telemetry, no analytics, no cloud sync, no in-app purchases, no ads, no accounts. Files live on your device only. Privacy policy: https://mulgundsunil1918.github.io/Docshelf/privacy.html — read it, you'll see.

▸ FREE
DocShelf is free. No ads. Optional “Buy me a chai” support tile if you’d like to chip in — keeps it that way for everyone else.

▸ FEEDBACK
Settings → Feedback. Suggest a feature, give feedback, report a bug, or rate the app. Bug reports auto-include version + platform.

USE CASES: paperless office, family document storage, freelance contract archive, student assignment vault, teacher lesson-plan storage, vehicle paperwork, property documentation, insurance renewals, healthcare records, travel document organiser, receipts & warranty tracker, quotation comparison

KEYWORDS: document scanner, offline scanner, document vault, document organiser, file vault, paperless, scan to PDF, expiry reminder, document storage, private storage, offline storage, no account app, document manager, file manager, PDF organiser

DocShelf. Files organized · Offline.
"""


def write_descriptions():
    (OUT_DIR / "short_description.txt").write_text(
        SHORT_DESCRIPTION.strip() + "\n", encoding="utf-8"
    )
    (OUT_DIR / "full_description.txt").write_text(
        FULL_DESCRIPTION.strip() + "\n", encoding="utf-8"
    )


# ──────────────────────────────────────────────────────────────────────
# Zip + main
# ──────────────────────────────────────────────────────────────────────
def make_zip():
    if ZIP_PATH.exists():
        ZIP_PATH.unlink()
    with zipfile.ZipFile(ZIP_PATH, "w", zipfile.ZIP_DEFLATED) as zf:
        for f in sorted(OUT_DIR.iterdir()):
            zf.write(f, f.relative_to(OUT_DIR.parent))


def main():
    if OUT_DIR.exists():
        for f in OUT_DIR.glob("*.png"):
            f.unlink()
        for f in OUT_DIR.glob("*.txt"):
            f.unlink()
    OUT_DIR.mkdir(parents=True, exist_ok=True)

    print("Generating Play Store asset pack for DocShelf …")
    make_icon()
    print("  ✓ icon-512.png")
    make_feature_graphic()
    print("  ✓ feature-graphic-1024x500.png")

    make_phone_screens()
    print("  ✓ phone-1-intro.png … phone-7-reminders.png  (7 × 1080×1920)")

    make_tablet_7_screens()
    print("  ✓ tablet-7-1.png … tablet-7-7.png  (7 × 1200×1920)")

    make_tablet_10_screens()
    print("  ✓ tablet-10-1.png … tablet-10-7.png  (7 × 1800×2880)")

    write_descriptions()
    print("  ✓ short_description.txt + full_description.txt")

    make_zip()
    print(f"\n→ {ZIP_PATH}  ({ZIP_PATH.stat().st_size // 1024} KB)")
    print(f"→ {OUT_DIR}/")


if __name__ == "__main__":
    main()
