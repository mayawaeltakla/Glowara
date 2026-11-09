#!/usr/bin/env python3
"""يولّد أيقونات Glowara (Android + الويب) من assets/icon/glowara_icon_source.png.

أداة تطوير فقط: الملفات الناتجة تُرفع إلى المستودع، ولا يحتاج CI إلى تشغيل هذا
السكربت. يتطلب Pillow وnumpy.

    python3 tool/generate_icons.py
"""
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw, ImageFilter

ROOT = Path(__file__).resolve().parent.parent
SOURCE = ROOT / 'assets' / 'icon' / 'glowara_icon_source.png'
MASTER = ROOT / 'assets' / 'icon' / 'glowara_icon.png'
OUT = ROOT / 'tool' / 'icons'

MASTER_SIZE = 1024
ANDROID_SIZES = {
    'mipmap-mdpi': 48,
    'mipmap-hdpi': 72,
    'mipmap-xhdpi': 96,
    'mipmap-xxhdpi': 144,
    'mipmap-xxxhdpi': 192,
}


def extract_squircle(source: Image.Image) -> Image.Image:
    """يقصّ الأيقونة المستديرة ويحوّل الخلفية البيضاء حولها إلى شفافية."""
    rgb = source.convert('RGB')
    width, height = rgb.size
    marker = (255, 0, 255)
    work = rgb.copy()
    for xy in ((0, 0), (width - 1, 0), (0, height - 1), (width - 1, height - 1)):
        ImageDraw.floodfill(work, xy, marker, thresh=12)
    outside = np.all(np.asarray(work) == marker, axis=2)

    alpha = Image.fromarray(np.where(outside, 0, 255).astype('uint8'), 'L')
    # تآكل بكسل واحد لإزالة الهالة البيضاء، ثم تنعيم الحافة.
    alpha = alpha.filter(ImageFilter.MinFilter(3)).filter(ImageFilter.GaussianBlur(0.8))

    rgba = rgb.convert('RGBA')
    rgba.putalpha(alpha)

    ys, xs = np.where(~outside)
    cx = (xs.min() + xs.max() + 1) / 2
    cy = (ys.min() + ys.max() + 1) / 2
    side = max(xs.max() - xs.min(), ys.max() - ys.min()) + 3
    left = int(round(cx - side / 2))
    top = int(round(cy - side / 2))
    cropped = rgba.crop((left, top, left + side, top + side))
    return cropped.resize((MASTER_SIZE, MASTER_SIZE), Image.LANCZOS)


def _gaussian_blur(channel: np.ndarray, sigma: float) -> np.ndarray:
    h, w = channel.shape
    fy = np.fft.fftfreq(h)[:, None]
    fx = np.fft.rfftfreq(w)[None, :]
    kernel = np.exp(-2 * (np.pi ** 2) * (sigma ** 2) * (fx ** 2 + fy ** 2))
    return np.fft.irfft2(np.fft.rfft2(channel) * kernel, s=channel.shape)


def extend(rgba: Image.Image, sigma: float) -> Image.Image:
    """يملأ المناطق الشفافة بلون مستمر من الأطراف المعتمة المجاورة (RGB معتم)."""
    arr = np.asarray(rgba, dtype=np.float64)
    alpha = arr[..., 3] / 255.0
    den = np.maximum(_gaussian_blur(alpha, sigma), 1e-6)
    out = np.empty(arr.shape[:2] + (3,))
    for i in range(3):
        num = _gaussian_blur(arr[..., i] * alpha, sigma)
        filled = num / den
        out[..., i] = arr[..., i] * alpha + filled * (1 - alpha)
    return Image.fromarray(np.clip(out, 0, 255).astype('uint8'), 'RGB')


def make_maskable(master: Image.Image, size: int = MASTER_SIZE, scale: float = 0.72) -> Image.Image:
    """أيقونة maskable: ملء كامل بلون الأيقونة، والتصميم داخل المنطقة الآمنة."""
    full = extend(master, sigma=40)
    inner = int(size * scale)
    inner_img = full.resize((inner, inner), Image.LANCZOS).convert('RGBA')
    canvas = Image.new('RGBA', (size, size), (0, 0, 0, 0))
    offset = (size - inner) // 2
    canvas.paste(inner_img, (offset, offset))
    return extend(canvas, sigma=120)


def save(image: Image.Image, path: Path, size: int) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    image.resize((size, size), Image.LANCZOS).save(path, optimize=True)
    print(f'{path.relative_to(ROOT)}  {size}x{size}')


def main() -> None:
    master = extract_squircle(Image.open(SOURCE))
    MASTER.parent.mkdir(parents=True, exist_ok=True)
    master.save(MASTER, optimize=True)
    print(f'{MASTER.relative_to(ROOT)}  {MASTER_SIZE}x{MASTER_SIZE}')

    for folder, size in ANDROID_SIZES.items():
        save(master, OUT / 'android' / folder / 'ic_launcher.png', size)

    maskable = make_maskable(master).convert('RGBA')
    save(master, OUT / 'web' / 'favicon.png', 64)
    for size in (192, 512):
        save(master, OUT / 'web' / 'icons' / f'Icon-{size}.png', size)
        save(maskable, OUT / 'web' / 'icons' / f'Icon-maskable-{size}.png', size)


if __name__ == '__main__':
    main()
