#!/usr/bin/env python3

from pathlib import Path

from PIL import Image, ImageDraw, ImageFilter


ROOT = Path(__file__).resolve().parents[1]
ICONSET_DIR = ROOT / "App" / "AppIcon.iconset"
MASTER_PATH = ROOT / "App" / "AppIcon-1024.png"
ICNS_PATH = ROOT / "App" / "PapersApp.icns"

SPECS = [
    ("icon_16x16.png", 16),
    ("icon_16x16@2x.png", 32),
    ("icon_32x32.png", 32),
    ("icon_32x32@2x.png", 64),
    ("icon_128x128.png", 128),
    ("icon_128x128@2x.png", 256),
    ("icon_256x256.png", 256),
    ("icon_256x256@2x.png", 512),
    ("icon_512x512.png", 512),
    ("icon_512x512@2x.png", 1024),
]


def rounded_rectangle(draw: ImageDraw.ImageDraw, box, radius, fill, outline=None, width=1):
    draw.rounded_rectangle(box, radius=radius, fill=fill, outline=outline, width=width)


def create_master_icon(size: int = 1024) -> Image.Image:
    image = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    draw = ImageDraw.Draw(image)

    for y in range(size):
        t = y / max(size - 1, 1)
        r = int(34 + (16 * t))
        g = int(86 + (52 * t))
        b = int(102 + (74 * t))
        draw.line((0, y, size, y), fill=(r, g, b, 255))

    vignette = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    vignette_draw = ImageDraw.Draw(vignette)
    vignette_draw.ellipse(
        (-size * 0.18, -size * 0.12, size * 1.05, size * 0.9),
        fill=(255, 255, 255, 34),
    )
    vignette_draw.ellipse(
        (size * 0.2, size * 0.48, size * 1.15, size * 1.2),
        fill=(7, 25, 39, 58),
    )
    image = Image.alpha_composite(image, vignette)

    shadow = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    shadow_draw = ImageDraw.Draw(shadow)
    shadow_box = (
        int(size * 0.24),
        int(size * 0.18),
        int(size * 0.78),
        int(size * 0.84),
    )
    rounded_rectangle(shadow_draw, shadow_box, radius=int(size * 0.075), fill=(6, 17, 24, 170))
    shadow = shadow.filter(ImageFilter.GaussianBlur(radius=size * 0.03))
    image = Image.alpha_composite(image, shadow)

    paper = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    paper_draw = ImageDraw.Draw(paper)
    paper_box = (
        int(size * 0.2),
        int(size * 0.12),
        int(size * 0.74),
        int(size * 0.8),
    )
    rounded_rectangle(
        paper_draw,
        paper_box,
        radius=int(size * 0.075),
        fill=(250, 248, 242, 255),
        outline=(232, 228, 219, 255),
        width=max(2, size // 256),
    )

    fold = [
        (int(size * 0.635), int(size * 0.12)),
        (int(size * 0.74), int(size * 0.22)),
        (int(size * 0.74), int(size * 0.12)),
    ]
    paper_draw.polygon(fold, fill=(231, 227, 218, 255))
    paper_draw.line(
        (int(size * 0.635), int(size * 0.12), int(size * 0.74), int(size * 0.22)),
        fill=(214, 210, 201, 255),
        width=max(2, size // 256),
    )
    image = Image.alpha_composite(image, paper)

    overlay = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    overlay_draw = ImageDraw.Draw(overlay)

    lines_y = [0.25, 0.33, 0.41, 0.49, 0.57]
    for index, y_ratio in enumerate(lines_y):
        y = int(size * y_ratio)
        x0 = int(size * 0.27)
        x1 = int(size * (0.63 if index != 2 else 0.56))
        overlay_draw.rounded_rectangle(
            (x0, y, x1, y + int(size * 0.022)),
            radius=int(size * 0.011),
            fill=(171, 181, 194, 210),
        )

    highlight_color = (255, 211, 74, 188)
    overlay_draw.rounded_rectangle(
        (
            int(size * 0.255),
            int(size * 0.39),
            int(size * 0.61),
            int(size * 0.455),
        ),
        radius=int(size * 0.02),
        fill=highlight_color,
    )
    overlay_draw.rounded_rectangle(
        (
            int(size * 0.28),
            int(size * 0.55),
            int(size * 0.58),
            int(size * 0.615),
        ),
        radius=int(size * 0.02),
        fill=(255, 236, 168, 150),
    )

    note_box = (
        int(size * 0.49),
        int(size * 0.53),
        int(size * 0.82),
        int(size * 0.76),
    )
    rounded_rectangle(
        overlay_draw,
        note_box,
        radius=int(size * 0.05),
        fill=(250, 239, 191, 250),
        outline=(230, 196, 98, 255),
        width=max(2, size // 256),
    )
    pointer = [
        (int(size * 0.54), int(size * 0.76)),
        (int(size * 0.6), int(size * 0.71)),
        (int(size * 0.64), int(size * 0.76)),
    ]
    overlay_draw.polygon(pointer, fill=(250, 239, 191, 250), outline=(230, 196, 98, 255))

    note_lines = [0.585, 0.635, 0.685]
    for ratio in note_lines:
        y = int(size * ratio)
        overlay_draw.rounded_rectangle(
            (int(size * 0.54), y, int(size * 0.77), y + int(size * 0.018)),
            radius=int(size * 0.009),
            fill=(124, 106, 55, 215),
        )

    ribbon = [
        (int(size * 0.585), int(size * 0.12)),
        (int(size * 0.66), int(size * 0.12)),
        (int(size * 0.66), int(size * 0.255)),
        (int(size * 0.622), int(size * 0.228)),
        (int(size * 0.585), int(size * 0.255)),
    ]
    overlay_draw.polygon(ribbon, fill=(217, 91, 79, 255))

    image = Image.alpha_composite(image, overlay)
    return image


def main() -> None:
    ICONSET_DIR.mkdir(parents=True, exist_ok=True)
    master = create_master_icon()
    master.save(MASTER_PATH)
    master.save(ICNS_PATH)

    for filename, size in SPECS:
        resized = master.resize((size, size), Image.Resampling.LANCZOS)
        resized.save(ICONSET_DIR / filename)


if __name__ == "__main__":
    main()
