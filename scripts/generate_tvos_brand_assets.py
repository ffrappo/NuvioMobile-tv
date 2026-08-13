#!/usr/bin/env python3
"""Generate tvOS layered icons and Top Shelf fallbacks from the original logo."""

from pathlib import Path
import json

import numpy as np
from PIL import Image


ROOT = Path(__file__).resolve().parents[1]
SOURCE = (
    ROOT
    / "tvosApp/Resources/Assets.xcassets/NuvioLogo.imageset/app-icon-1024.png"
)
BRAND = (
    ROOT
    / "tvosApp/Resources/Assets.xcassets"
    / "App Icon & Top Shelf Image.brandassets"
)


def write_json(path: Path, value: dict) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(value, indent=2) + "\n", encoding="utf-8")


def transparent_mark(source: Image.Image) -> Image.Image:
    rgb = np.asarray(source.convert("RGB"), dtype=np.float32)
    alpha = rgb.max(axis=2)
    safe_alpha = np.where(alpha > 0, alpha, 1)
    straight = np.clip(rgb * 255 / safe_alpha[..., None], 0, 255)
    rgba = np.dstack((straight, alpha)).astype(np.uint8)
    return Image.fromarray(rgba, "RGBA")


def centered_mark(mark: Image.Image, size: tuple[int, int], height_ratio: float) -> Image.Image:
    alpha = mark.getchannel("A")
    bounds = alpha.getbbox()
    if bounds is None:
        raise ValueError("The source logo contains no visible pixels")
    cropped = mark.crop(bounds)
    target_height = round(size[1] * height_ratio)
    scale = target_height / cropped.height
    resized = cropped.resize(
        (round(cropped.width * scale), target_height),
        Image.Resampling.LANCZOS,
    )
    canvas = Image.new("RGBA", size, (0, 0, 0, 0))
    position = ((size[0] - resized.width) // 2, (size[1] - resized.height) // 2)
    canvas.alpha_composite(resized, position)
    return canvas


def black_canvas(size: tuple[int, int]) -> Image.Image:
    return Image.new("RGB", size, (0, 0, 0))


def save_icon_stack(name: str, size: tuple[int, int], mark: Image.Image, two_x: bool) -> None:
    stack = BRAND / f"{name}.imagestack"
    write_json(
        stack / "Contents.json",
        {
            "layers": [
                {"filename": "Front.imagestacklayer"},
                {"filename": "Back.imagestacklayer"},
            ],
            "info": {"author": "xcode", "version": 1},
        },
    )
    scales = [("1x", size, "content.png")]
    if two_x:
        scales.append(("2x", (size[0] * 2, size[1] * 2), "content@2x.png"))
    for layer in ("Front", "Back"):
        layer_dir = stack / f"{layer}.imagestacklayer"
        write_json(
            layer_dir / "Contents.json",
            {
                "content": {"filename": "Content.imageset"},
                "info": {"author": "xcode", "version": 1},
            },
        )
        images = []
        content = layer_dir / "Content.imageset"
        content.mkdir(parents=True, exist_ok=True)
        for scale, dimensions, filename in scales:
            image = (
                centered_mark(mark, dimensions, 0.66)
                if layer == "Front"
                else black_canvas(dimensions)
            )
            image.save(content / filename, "PNG", optimize=True)
            images.append(
                {"idiom": "tv", "filename": filename, "scale": scale}
            )
        write_json(
            content / "Contents.json",
            {"images": images, "info": {"author": "xcode", "version": 1}},
        )


def save_top_shelf(name: str, size: tuple[int, int], mark: Image.Image) -> None:
    image_set = BRAND / f"{name}.imageset"
    image_set.mkdir(parents=True, exist_ok=True)
    images = []
    for scale, dimensions, filename in (
        ("1x", size, "content.png"),
        ("2x", (size[0] * 2, size[1] * 2), "content@2x.png"),
    ):
        canvas = black_canvas(dimensions).convert("RGBA")
        canvas.alpha_composite(centered_mark(mark, dimensions, 0.64))
        canvas.convert("RGB").save(image_set / filename, "PNG", optimize=True)
        images.append({"idiom": "tv", "filename": filename, "scale": scale})
    write_json(
        image_set / "Contents.json",
        {"images": images, "info": {"author": "xcode", "version": 1}},
    )


def generate() -> None:
    for stale in BRAND.rglob("icon-*.png"):
        stale.unlink()
    mark = transparent_mark(Image.open(SOURCE))
    save_icon_stack("App Icon", (400, 240), mark, two_x=True)
    save_icon_stack("App Icon - App Store", (1280, 768), mark, two_x=False)
    save_top_shelf("Top Shelf Image", (1920, 720), mark)
    save_top_shelf("Top Shelf Image Wide", (2320, 720), mark)
    write_json(
        BRAND / "Contents.json",
        {
            "assets": [
                {
                    "filename": "App Icon - App Store.imagestack",
                    "idiom": "tv",
                    "role": "primary-app-icon",
                    "size": "1280x768",
                },
                {
                    "filename": "App Icon.imagestack",
                    "idiom": "tv",
                    "role": "primary-app-icon",
                    "size": "400x240",
                },
                {
                    "filename": "Top Shelf Image Wide.imageset",
                    "idiom": "tv",
                    "role": "top-shelf-image-wide",
                    "size": "2320x720",
                },
                {
                    "filename": "Top Shelf Image.imageset",
                    "idiom": "tv",
                    "role": "top-shelf-image",
                    "size": "1920x720",
                },
            ],
            "info": {"author": "xcode", "version": 1},
        },
    )


if __name__ == "__main__":
    generate()
