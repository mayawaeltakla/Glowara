#!/usr/bin/env python3
"""يطبّق هوية Glowara على مجلدي android/ وweb/ المولَّدين بـ `flutter create`.

- ينسخ الأيقونات الجاهزة من tool/icons (انظر tool/generate_icons.py).
- يضبط اسم التطبيق وألوانه في AndroidManifest.xml وweb/manifest.json وweb/index.html.

آمن للتشغيل أكثر من مرة (idempotent)، ويتجاوز بصمت ما لا يجده. لا يحتاج حزمًا
خارجية.

    python3 tool/apply_branding.py
"""
import json
import re
import shutil
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
ICONS = ROOT / 'tool' / 'icons'

APP_NAME = 'Glowara'
DESCRIPTION = 'Glowara — a calm space for worship, planning, study and self-care.'
THEME_COLOR = '#8A4F6E'  # الخوخي البرقوقي (primary في Serene Glow)
BACKGROUND_COLOR = '#FAF6F0'  # كريمي دافئ (canvas في Serene Glow)


def copy_android_icons() -> None:
    res = ROOT / 'android' / 'app' / 'src' / 'main' / 'res'
    if not res.is_dir():
        print('android/ غير موجود: تخطّي أيقونات Android.')
        return
    for source_dir in sorted((ICONS / 'android').glob('mipmap-*')):
        target = res / source_dir.name
        target.mkdir(parents=True, exist_ok=True)
        shutil.copyfile(source_dir / 'ic_launcher.png', target / 'ic_launcher.png')
        print(f'android: {target.relative_to(ROOT)}/ic_launcher.png')
    # أي أيقونة تكيفية (adaptive) من القالب تتغلّب على PNG في Android 8+؛ نحذفها
    # ليظهر الشعار كما صُمّم بدل أيقونة Flutter الافتراضية.
    for adaptive in res.glob('mipmap-anydpi*/ic_launcher*.xml'):
        adaptive.unlink()
        print(f'android: حُذفت الأيقونة التكيفية الافتراضية {adaptive.relative_to(ROOT)}')


def patch_android_manifest() -> None:
    manifest = ROOT / 'android' / 'app' / 'src' / 'main' / 'AndroidManifest.xml'
    if not manifest.is_file():
        return
    text = manifest.read_text(encoding='utf-8')
    patched = re.sub(r'android:label="[^"]*"', f'android:label="{APP_NAME}"', text, count=1)
    if patched != text:
        manifest.write_text(patched, encoding='utf-8')
        print(f'android: اسم التطبيق = {APP_NAME}')


def copy_web_icons() -> None:
    web = ROOT / 'web'
    if not web.is_dir():
        print('web/ غير موجود: تخطّي أيقونات الويب.')
        return
    shutil.copyfile(ICONS / 'web' / 'favicon.png', web / 'favicon.png')
    icons_dir = web / 'icons'
    icons_dir.mkdir(exist_ok=True)
    for icon in sorted((ICONS / 'web' / 'icons').glob('*.png')):
        shutil.copyfile(icon, icons_dir / icon.name)
    print('web: favicon.png و icons/*.png')


def patch_web_manifest() -> None:
    path = ROOT / 'web' / 'manifest.json'
    if not path.is_file():
        return
    data = json.loads(path.read_text(encoding='utf-8'))
    data.update(
        name=APP_NAME,
        short_name=APP_NAME,
        description=DESCRIPTION,
        theme_color=THEME_COLOR,
        background_color=BACKGROUND_COLOR,
    )
    path.write_text(json.dumps(data, indent=2, ensure_ascii=False) + '\n', encoding='utf-8')
    print('web: manifest.json')


def patch_web_index() -> None:
    path = ROOT / 'web' / 'index.html'
    if not path.is_file():
        return
    text = path.read_text(encoding='utf-8')
    original = text
    text = re.sub(r'<title>[^<]*</title>', f'<title>{APP_NAME}</title>', text, count=1)
    text = re.sub(
        r'(<meta name="description" content=")[^"]*(")',
        rf'\g<1>{DESCRIPTION}\g<2>',
        text,
        count=1,
    )
    text = re.sub(
        r'(<meta name="apple-mobile-web-app-title" content=")[^"]*(")',
        rf'\g<1>{APP_NAME}\g<2>',
        text,
        count=1,
    )
    if 'name="theme-color"' not in text:
        text = text.replace(
            '<meta charset="UTF-8">',
            f'<meta charset="UTF-8">\n  <meta name="theme-color" content="{THEME_COLOR}">',
            1,
        )
    if text != original:
        path.write_text(text, encoding='utf-8')
        print('web: index.html')


def main() -> None:
    copy_android_icons()
    patch_android_manifest()
    copy_web_icons()
    patch_web_manifest()
    patch_web_index()


if __name__ == '__main__':
    main()
