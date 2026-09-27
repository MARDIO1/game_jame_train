"""裁切用户提供的电脑图标表，并输出像素对齐的矢量 SVG。"""

from __future__ import annotations

import argparse
from io import BytesIO
from pathlib import Path

import cairosvg
from PIL import Image


WINDOWS_ICONS = {
    "folder": ((28, 64, 148, 169), 48, 48),
    "text": ((176, 60, 275, 168), 48, 48),
    "image": ((299, 62, 410, 169), 48, 48),
    "start": ((32, 197, 140, 301), 24, 24),
    "volume": ((164, 195, 280, 312), 24, 24),
    "cursor": ((439, 190, 549, 312), 24, 32),
}

CHAT_ICONS = {
    "chat_person": ((0, 0, 168, 168), 64, 64),
    "chat_unknown": ((168, 0, 337, 168), 64, 64),
    "chat": ((0, 168, 168, 337), 48, 48),
    "chat_bubbles": ((168, 168, 337, 337), 64, 64),
}


def clean_alpha(image: Image.Image) -> Image.Image:
    """使用原图透明通道去掉抗锯齿薄雾，不猜测黑色背景。"""
    image = image.convert("RGBA")
    pixels = image.load()
    for y in range(image.height):
        for x in range(image.width):
            red, green, blue, alpha = pixels[x, y]
            pixels[x, y] = (red, green, blue, 255) if alpha >= 96 else (0, 0, 0, 0)
    return image


def resize_nearest(image: Image.Image, width: int, height: int) -> Image.Image:
    """裁掉透明空白，并以最近邻采样居中放入带安全边距的画布。"""
    visible_alpha = image.getchannel("A").point(lambda alpha: 255 if alpha >= 96 else 0)
    content_box = visible_alpha.getbbox()
    if content_box is None:
        raise ValueError("裁片中没有可见像素")
    image = image.crop(content_box)
    padding = 2 if width >= 48 else 1
    image.thumbnail((width - padding * 2, height - padding * 2), Image.Resampling.NEAREST)
    canvas = Image.new("RGBA", (width, height), (0, 0, 0, 0))
    x = (width - image.width) // 2
    y = (height - image.height) // 2
    canvas.alpha_composite(image, (x, y))
    return canvas


def svg_from_pixels(image: Image.Image) -> str:
    """将每行相邻的同色像素合并为整数坐标 SVG 矩形。"""
    width, height = image.size
    parts = [
        f'<svg xmlns="http://www.w3.org/2000/svg" width="{width}" '
        f'height="{height}" viewBox="0 0 {width} {height}" '
        'shape-rendering="crispEdges">'
    ]
    pixels = image.load()
    for y in range(height):
        x = 0
        while x < width:
            red, green, blue, alpha = pixels[x, y]
            if alpha == 0:
                x += 1
                continue
            end_x = x + 1
            while end_x < width and pixels[end_x, y] == pixels[x, y]:
                end_x += 1
            color = f"#{red:02x}{green:02x}{blue:02x}"
            parts.append(
                f'<rect x="{x}" y="{y}" width="{end_x - x}" height="1" '
                f'fill="{color}"/>'
            )
            x = end_x
    parts.append("</svg>")
    return "\n".join(parts) + "\n"


def render_svg(svg: str, width: int, height: int) -> Image.Image:
    """以目标像素尺寸回渲染 SVG。"""
    rendered_data = cairosvg.svg2png(
        bytestring=svg.encode("utf-8"),
        output_width=width,
        output_height=height,
    )
    return Image.open(BytesIO(rendered_data)).convert("RGBA")


def pixel_similarity(expected: Image.Image, actual: Image.Image) -> float:
    """返回两张同尺寸图像的逐通道相似度。"""
    difference = 0
    for expected_pixel, actual_pixel in zip(expected.getdata(), actual.getdata()):
        difference += sum(abs(left - right) for left, right in zip(expected_pixel, actual_pixel))
    channel_count = expected.width * expected.height * len(expected.getbands())
    return 1.0 - difference / (channel_count * 255)


def flatten(image: Image.Image) -> Image.Image:
    """合成到电脑桌面灰底，忽略透明像素中不可见的 RGB 数据。"""
    background = Image.new("RGBA", image.size, (184, 189, 194, 255))
    background.alpha_composite(image)
    return background.convert("RGB")


def main() -> None:
    """读取图标表，裁切六个图标并写入目标目录。"""
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("source", nargs="?", type=Path, help="原始图标表 PNG")
    parser.add_argument(
        "--preset",
        choices=("windows", "chat"),
        default="windows",
        help="图标表布局，默认 windows",
    )
    parser.add_argument(
        "--output",
        type=Path,
        default=Path("interactables/computer/os/art"),
        help="SVG 输出目录",
    )
    args = parser.parse_args()
    source_path = args.source or Path(
        "tests/talk_icon.png" if args.preset == "chat" else "tests/image.png"
    )
    if not source_path.is_file():
        raise SystemExit(f"找不到图标原图：{source_path}")

    source = Image.open(source_path).convert("RGBA")
    icons = CHAT_ICONS if args.preset == "chat" else WINDOWS_ICONS
    args.output.mkdir(parents=True, exist_ok=True)

    for name, (box, width, height) in icons.items():
        raw_crop = source.crop(box)
        reference = resize_nearest(raw_crop, width, height)
        crop = clean_alpha(raw_crop)
        icon = resize_nearest(crop, width, height)
        svg = svg_from_pixels(icon)
        rendered = render_svg(svg, width, height)
        svg_similarity = pixel_similarity(icon, rendered)
        source_similarity = pixel_similarity(flatten(reference), flatten(rendered))
        if svg_similarity < 0.9999 or source_similarity < 0.985:
            raise SystemExit(
                f"{name} 相似度不足：svg={svg_similarity:.6f}, source={source_similarity:.6f}"
            )
        output_path = args.output / f"{name}.svg"
        with output_path.open("w", encoding="utf-8", newline="\n") as output_file:
            output_file.write(svg)
        print(
            f"{name}: {width}×{height}, svg={svg_similarity:.6f}, "
            f"source={source_similarity:.6f} -> {output_path}"
        )


if __name__ == "__main__":
    main()
