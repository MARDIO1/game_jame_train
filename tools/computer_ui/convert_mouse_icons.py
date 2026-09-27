"""把三张透明鼠标 PNG 原样裁边并转换为像素对齐 SVG。"""

from __future__ import annotations

from io import BytesIO
from pathlib import Path

import cairosvg
from PIL import Image


SOURCE_DIRECTORY = Path("tests")
OUTPUT_DIRECTORY = Path("ui/world_1/art")
ICON_NAMES = ("mouse_left", "mouse_middle", "mouse_right")


def svg_from_image(image: Image.Image) -> str:
    """把相邻同色像素合并成标准 SVG 矩形，不重采样原图。"""
    image = image.convert("RGBA")
    content_box = image.getchannel("A").getbbox()
    if content_box is None:
        raise ValueError("图标中没有可见像素")
    image = image.crop(content_box)
    width, height = image.size
    pixels = image.load()
    parts = [
        f'<svg xmlns="http://www.w3.org/2000/svg" width="{width}" height="{height}" '
        f'viewBox="0 0 {width} {height}" shape-rendering="crispEdges">'
    ]
    for y in range(height):
        x = 0
        while x < width:
            color = pixels[x, y]
            if color[3] == 0:
                x += 1
                continue
            end_x = x + 1
            while end_x < width and pixels[end_x, y] == color:
                end_x += 1
            red, green, blue, alpha = color
            opacity = f' fill-opacity="{alpha / 255:.4f}"' if alpha < 255 else ""
            parts.append(
                f'<rect x="{x}" y="{y}" width="{end_x - x}" height="1" '
                f'fill="#{red:02x}{green:02x}{blue:02x}"{opacity}/>'
            )
            x = end_x
    parts.append("</svg>")
    return "\n".join(parts) + "\n"


def similarity(expected: Image.Image, svg: str) -> float:
    """回渲染 SVG，并返回合成到黑底后的平均相似度。"""
    expected = expected.convert("RGBA")
    content_box = expected.getchannel("A").getbbox()
    expected = expected.crop(content_box)
    rendered_data = cairosvg.svg2png(bytestring=svg.encode("utf-8"))
    rendered = Image.open(BytesIO(rendered_data)).convert("RGBA")
    background = Image.new("RGBA", expected.size, (0, 0, 0, 255))
    background.alpha_composite(expected)
    expected = background.convert("RGB")
    background = Image.new("RGBA", rendered.size, (0, 0, 0, 255))
    background.alpha_composite(rendered)
    rendered = background.convert("RGB")
    difference = 0
    for left, right in zip(expected.getdata(), rendered.getdata()):
        difference += sum(abs(a - b) for a, b in zip(left, right))
    channel_count = expected.width * expected.height * 3
    return 1.0 - difference / (channel_count * 255)


def main() -> None:
    """转换三个固定命名的鼠标图标。"""
    OUTPUT_DIRECTORY.mkdir(parents=True, exist_ok=True)
    for name in ICON_NAMES:
        source_path = SOURCE_DIRECTORY / f"{name}.png"
        output_path = OUTPUT_DIRECTORY / f"{name}.svg"
        image = Image.open(source_path)
        svg = svg_from_image(image)
        score = similarity(image, svg)
        if score < 0.999:
            raise ValueError(f"{name} 回渲染相似度不足：{score:.6f}")
        output_path.write_text(svg, encoding="utf-8", newline="\n")
        print(f"{source_path} -> {output_path}, similarity={score:.6f}")


if __name__ == "__main__":
    main()
