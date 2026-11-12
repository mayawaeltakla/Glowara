#!/usr/bin/env python3
"""يوقّع نسخة release ويعطيها معرّف تطبيق جديدًا (com.glowara.app) كي تُثبَّت
بجانب النسخة القديمة الموقَّعة بمفتاح التجربة دون حذفها، فتنقلين بياناتك بأمان.

يوقّع نسخة release بمفتاح ثابت بدل مفتاح التجربة الذي يتغير مع كل بناء.

بدون مفتاح ثابت يرفض أندرويد تثبيت النسخة الجديدة فوق القديمة. المفتاح هنا
للاستخدام الشخصي خارج المتاجر، وهو في مستودع عام، فلا تعتمدي عليه لنشر تطبيق.
"""
import re
import shutil
import sys
from pathlib import Path

src = Path('tool/signing/glowara-release.jks')
app = Path('android/app')
if not src.exists() or not app.exists():
    sys.exit('keystore or android/app missing')
shutil.copy(src, app / 'glowara-release.jks')

kts = app / 'build.gradle.kts'
groovy = app / 'build.gradle'
if kts.exists():
    g = kts.read_text(encoding='utf-8')
    if 'glowara-release.jks' not in g:
        block = '''
    signingConfigs {
        create("glowara") {
            storeFile = file("glowara-release.jks")
            storePassword = "glowara-local"
            keyAlias = "glowara"
            keyPassword = "glowara-local"
        }
    }
'''
        g, n = re.subn(r'(\nandroid\s*\{)', lambda m: m.group(1) + block, g, count=1)
        if n == 0:
            sys.exit('android block not found')
        g, n = re.subn(r'signingConfigs\.getByName\("debug"\)', 'signingConfigs.getByName("glowara")', g)
        if n == 0:
            sys.exit('debug signing line not found')
    g, n = re.subn(r'applicationId\s*=\s*"[^"]+"', 'applicationId = "com.glowara.app"', g, count=1)
    if n == 0:
        sys.exit('applicationId not found')
    kts.write_text(g, encoding='utf-8')
    print('signing kts ok')
elif groovy.exists():
    g = groovy.read_text(encoding='utf-8')
    if 'glowara-release.jks' not in g:
        block = '''
    signingConfigs {
        glowara {
            storeFile file("glowara-release.jks")
            storePassword "glowara-local"
            keyAlias "glowara"
            keyPassword "glowara-local"
        }
    }
'''
        g, n = re.subn(r'(\nandroid\s*\{)', lambda m: m.group(1) + block, g, count=1)
        if n == 0:
            sys.exit('android block not found')
        g, n = re.subn(r'signingConfigs\.debug', 'signingConfigs.glowara', g)
        if n == 0:
            sys.exit('debug signing line not found')
    g, n = re.subn(r'applicationId\s*=?\s*"[^"]+"', 'applicationId "com.glowara.app"', g, count=1)
    if n == 0:
        sys.exit('applicationId not found')
    groovy.write_text(g, encoding='utf-8')
    print('signing groovy ok')
else:
    sys.exit('no build.gradle(.kts)')
