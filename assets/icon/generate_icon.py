"""
Generates the DocShelf launcher PNGs from the same shapes as
logo_mark.svg using PIL — no SVG converter needed.

Run with:    python assets/icon/generate_icon.py
Outputs:     assets/icon/app_icon.png             (1024x1024 full icon)
             assets/icon/app_icon_foreground.png  (foreground-only, for
                                                    Android adaptive icon)
"""
from PIL import Image, ImageDraw

# ─── Brand tokens ──────────────────────────────────────────────────────
INDIGO = (61, 90, 254, 255)        # #3D5AFE
INDIGO_DARK = (45, 63, 184, 255)   # #2D3FB8
AMBER = (255, 179, 0, 255)         # #FFB300
WHITE = (255, 255, 255, 255)
WHITE_FAINT = (255, 255, 255, int(255 * 0.65))
TRANSPARENT = (0, 0, 0, 0)

SIZE = 1024
RADIUS = 220


def gradient_bg(width, height, top, bottom):
    img = Image.new("RGBA", (width, height), top)
    draw = ImageDraw.Draw(img)
    for y in range(height):
        t = y / max(1, height - 1)
        r = int(top[0] * (1 - t) + bottom[0] * t)
        g = int(top[1] * (1 - t) + bottom[1] * t)
        b = int(top[2] * (1 - t) + bottom[2] * t)
        draw.line([(0, y), (width, y)], fill=(r, g, b, 255))
    return img


def rounded_mask(width, height, radius):
    mask = Image.new("L", (width, height), 0)
    ImageDraw.Draw(mask).rounded_rectangle(
        [(0, 0), (width, height)], radius=radius, fill=255
    )
    return mask


def draw_stacked_bars(canvas):
    """Three stacked document bars + shelf line.

    All bars are centered on x=512 so the stack reads as a deliberate
    pyramid, not a random offset. Coordinates mirror logo_mark.svg.
    """
    d = ImageDraw.Draw(canvas, "RGBA")

    # Helper: draw a rounded bar centered horizontally on the canvas.
    def centered_bar(y, width, height, fill):
        x = (SIZE - width) // 2
        d.rounded_rectangle(
            [(x, y), (x + width, y + height)],
            radius=height // 2,
            fill=fill,
        )

    # Top bar — white, narrowest
    centered_bar(y=320, width=380, height=80, fill=WHITE)

    # Middle bar — translucent white, medium
    centered_bar(y=436, width=500, height=80, fill=WHITE_FAINT)

    # Bottom bar — amber, widest (signature accent)
    centered_bar(y=552, width=620, height=80, fill=AMBER)

    # White shelf line beneath — centered, length 480
    shelf_y = 712
    shelf_half = 240
    d.line(
        [(SIZE // 2 - shelf_half, shelf_y),
         (SIZE // 2 + shelf_half, shelf_y)],
        fill=WHITE,
        width=22,
    )
    # Round caps emulated with circles at each end
    d.ellipse(
        [(SIZE // 2 - shelf_half - 11, shelf_y - 11),
         (SIZE // 2 - shelf_half + 11, shelf_y + 11)],
        fill=WHITE,
    )
    d.ellipse(
        [(SIZE // 2 + shelf_half - 11, shelf_y - 11),
         (SIZE // 2 + shelf_half + 11, shelf_y + 11)],
        fill=WHITE,
    )


def make_full_icon():
    bg = gradient_bg(SIZE, SIZE, INDIGO, INDIGO_DARK)
    mask = rounded_mask(SIZE, SIZE, RADIUS)
    rounded_bg = Image.new("RGBA", (SIZE, SIZE), TRANSPARENT)
    rounded_bg.paste(bg, mask=mask)
    draw_stacked_bars(rounded_bg)
    return rounded_bg


def make_foreground_only():
    """Adaptive-icon foreground over transparent — Android tints the bg
    using adaptive_icon_background from pubspec.yaml.
    """
    fg = Image.new("RGBA", (SIZE, SIZE), TRANSPARENT)
    draw_stacked_bars(fg)
    return fg


if __name__ == "__main__":
    make_full_icon().save("assets/icon/app_icon.png", "PNG")
    print("wrote assets/icon/app_icon.png 1024x1024")

    make_foreground_only().save(
        "assets/icon/app_icon_foreground.png", "PNG"
    )
    print("wrote assets/icon/app_icon_foreground.png 1024x1024")
