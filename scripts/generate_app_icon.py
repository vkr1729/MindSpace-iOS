#!/usr/bin/env python3
"""Generate MindSpace's image-free Quiet Native app icon."""

from pathlib import Path
import math

from PIL import Image, ImageDraw, ImageFilter


ROOT = Path(__file__).resolve().parent.parent
OUTPUT = ROOT / "Resources" / "Assets.xcassets" / "AppIcon.appiconset" / "AppIcon-1024.png"
SCALE = 4
SIZE = 1024


def hex_rgb(value: str) -> tuple[int, int, int]:
    value = value.lstrip("#")
    return tuple(int(value[index : index + 2], 16) for index in (0, 2, 4))


def breathing_path(width: int, center_y: int, amplitude: int) -> list[tuple[int, int]]:
    points: list[tuple[int, int]] = []
    start_x = 238 * SCALE
    end_x = 786 * SCALE
    for x in range(start_x, end_x + 1, 4):
        progress = (x - start_x) / (end_x - start_x)
        envelope = math.sin(math.pi * progress) ** 1.7
        wave = math.sin((progress * 2.0 - 0.5) * math.pi)
        y = center_y - int(amplitude * envelope * wave)
        points.append((x, y))
    return points


def main() -> None:
    canvas_size = SIZE * SCALE
    background = Image.new("RGB", (canvas_size, canvas_size), hex_rgb("#090D0C"))
    pixels = background.load()

    top = hex_rgb("#15211D")
    bottom = hex_rgb("#090D0C")
    for y in range(canvas_size):
        progress = y / (canvas_size - 1)
        color = tuple(round(top[channel] * (1 - progress) + bottom[channel] * progress) for channel in range(3))
        for x in range(canvas_size):
            pixels[x, y] = color

    glow = Image.new("RGBA", background.size, (0, 0, 0, 0))
    glow_draw = ImageDraw.Draw(glow)
    glow_draw.rounded_rectangle(
        (180 * SCALE, 270 * SCALE, 844 * SCALE, 754 * SCALE),
        radius=240 * SCALE,
        fill=(*hex_rgb("#8BCAB7"), 34),
    )
    glow = glow.filter(ImageFilter.GaussianBlur(100 * SCALE))
    background = Image.alpha_composite(background.convert("RGBA"), glow)

    mark = Image.new("RGBA", background.size, (0, 0, 0, 0))
    draw = ImageDraw.Draw(mark)
    path = breathing_path(canvas_size, 512 * SCALE, 126 * SCALE)
    draw.line(path, fill=(*hex_rgb("#8BCAB7"), 255), width=52 * SCALE, joint="curve")

    secondary = breathing_path(canvas_size, 512 * SCALE, 72 * SCALE)
    draw.line(secondary, fill=(*hex_rgb("#B7D6C8"), 92), width=20 * SCALE, joint="curve")

    background = Image.alpha_composite(background, mark)
    background.convert("RGB").resize((SIZE, SIZE), Image.Resampling.LANCZOS).save(
        OUTPUT,
        format="PNG",
        optimize=True,
    )


if __name__ == "__main__":
    main()
