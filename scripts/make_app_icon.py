#!/usr/bin/env python3
"""Vẽ biểu tượng app DuoSocial (1024x1024, không trong suốt).

Cần Pillow và numpy:  pip install pillow numpy
Chạy:                 python3 scripts/make_app_icon.py
"""
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw

SIZE = 1024
SCALE = 4  # vẽ ở 4x rồi thu nhỏ để có khử răng cưa
S = SIZE * SCALE

FACEBOOK_BLUE = np.array([24, 119, 242], dtype=float)
MESSENGER_PURPLE = np.array([160, 51, 255], dtype=float)
MESSENGER_PINK = np.array([255, 82, 128], dtype=float)

OUTPUT = Path(__file__).resolve().parent.parent / "DuoSocial/Assets.xcassets/AppIcon.appiconset/AppIcon.png"


def gradient_background() -> Image.Image:
    # Chéo từ trên-trái (xanh Facebook) xuống dưới-phải (tím → hồng Messenger).
    ys, xs = np.mgrid[0:SIZE, 0:SIZE].astype(float)
    t = (xs + ys) / (2 * (SIZE - 1))
    first = np.clip(t / 0.7, 0, 1)[..., None]
    second = np.clip((t - 0.7) / 0.3, 0, 1)[..., None]
    rgb = FACEBOOK_BLUE * (1 - first) + MESSENGER_PURPLE * first
    rgb = rgb * (1 - second) + MESSENGER_PINK * second
    image = Image.fromarray(rgb.astype(np.uint8), "RGB")
    return image.resize((S, S), Image.BICUBIC)


def person_mask(cx: float, cy: float, r: float) -> Image.Image:
    """Hình người (đầu + vai) nằm gọn trong vòng tròn tâm (cx, cy) bán kính r."""
    mask = Image.new("L", (S, S), 0)
    draw = ImageDraw.Draw(mask)
    head_r = r * 0.34
    head_cy = cy - r * 0.2
    draw.ellipse((cx - head_r, head_cy - head_r, cx + head_r, head_cy + head_r), fill=255)
    body_rx, body_ry = r * 0.66, r * 0.5
    body_cy = cy + r * 0.72
    body = Image.new("L", (S, S), 0)
    ImageDraw.Draw(body).ellipse((cx - body_rx, body_cy - body_ry, cx + body_rx, body_cy + body_ry), fill=255)
    clip = Image.new("L", (S, S), 0)
    ImageDraw.Draw(clip).ellipse((cx - r, cy - r, cx + r, cy + r), fill=255)
    body = Image.fromarray(np.minimum(np.array(body), np.array(clip)))
    return Image.fromarray(np.maximum(np.array(mask), np.array(body)))


def circle_mask(cx: float, cy: float, r: float) -> Image.Image:
    mask = Image.new("L", (S, S), 0)
    ImageDraw.Draw(mask).ellipse((cx - r, cy - r, cx + r, cy + r), fill=255)
    return mask


def main() -> None:
    background = gradient_background()
    icon = background.copy()
    white = Image.new("RGB", (S, S), (255, 255, 255))
    blue = Image.new("RGB", (S, S), tuple(int(c) for c in FACEBOOK_BLUE))
    purple = Image.new("RGB", (S, S), tuple(int(c) for c in MESSENGER_PURPLE))

    # Tài khoản phía sau (trên-phải): vòng tròn trắng mờ + hình người tím.
    back_cx, back_cy, back_r = 0.64 * S, 0.38 * S, 0.25 * S
    back_circle = circle_mask(back_cx, back_cy, back_r)
    icon.paste(white, mask=back_circle.point(lambda v: int(v * 0.85)))
    icon.paste(purple, mask=person_mask(back_cx, back_cy, back_r))

    # Khoảng hở giữa hai tài khoản: vẽ lại nền trong vòng tròn lớn hơn tài khoản phía trước.
    front_cx, front_cy, front_r = 0.4 * S, 0.62 * S, 0.29 * S
    icon.paste(background, mask=circle_mask(front_cx, front_cy, front_r + 0.035 * S))

    # Tài khoản phía trước (dưới-trái): vòng tròn trắng + hình người xanh.
    icon.paste(white, mask=circle_mask(front_cx, front_cy, front_r))
    icon.paste(blue, mask=person_mask(front_cx, front_cy, front_r))

    icon = icon.resize((SIZE, SIZE), Image.LANCZOS)
    OUTPUT.parent.mkdir(parents=True, exist_ok=True)
    icon.save(OUTPUT, "PNG", optimize=True)
    print(f"Đã lưu {OUTPUT}")


if __name__ == "__main__":
    main()
