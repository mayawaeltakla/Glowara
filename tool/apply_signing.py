#!/usr/bin/env python3
"""يهيّئ مشروع Android المولَّد في CI: معرّف التطبيق والتوقيع.

الوضعان:

* ``--test``: يضبط ``applicationId`` فقط ويُبقي توقيع التجربة (debug) الذي يضعه
  Flutter. يُستعمل في بناء PR والاختبار. النتيجة **ليست إصدارًا رسميًا**.
* بدون ``--test`` (وضع الإصدار): يتطلب كل بيانات الاعتماد من متغيرات البيئة
  (أسرار GitHub Actions) ويفشل بوضوح إن نقص أي منها. لا توجد قيم افتراضية ولا
  رجوع إلى أي مفتاح قديم.

متغيرات وضع الإصدار (كلها إلزامية):

* ``GLOWARA_KEYSTORE_B64``: ملف keystore مشفّر Base64.
* ``GLOWARA_STORE_PASSWORD`` و``GLOWARA_KEY_PASSWORD`` و``GLOWARA_KEY_ALIAS``.
* ``GLOWARA_KEYSTORE_PATH``: مسار ملف مؤقت خارج المستودع (مثل ``$RUNNER_TEMP``)
  يُكتب إليه المفتاح بصلاحيات 600. يحذفه الـworkflow في خطوة ``if: always()``.

اختياري: ``GLOWARA_EXPECTED_SHA256`` للتحقق من بصمة الشهادة.

لا تُكتب كلمات المرور في أي ملف ولا تُطبع في السجلات: يقرأها Gradle من البيئة.
"""
import base64
import binascii
import os
import re
import subprocess
import sys
from pathlib import Path

# بصمة المفتاح الذي نُشر في المستودع العام. مرفوضة دائمًا في وضع الإصدار.
EXPOSED_SHA256 = (
    '75:ED:C7:BF:2B:8F:41:84:4F:82:AF:CF:BE:B9:80:09:09:E3:20:A7:8F:A0:C6:FF:5C:52:70:FF:E1:A3:0F:05'
)
APPLICATION_ID = 'com.glowara.app'
REQUIRED = (
    'GLOWARA_KEYSTORE_B64',
    'GLOWARA_STORE_PASSWORD',
    'GLOWARA_KEY_PASSWORD',
    'GLOWARA_KEY_ALIAS',
    'GLOWARA_KEYSTORE_PATH',
)

app = Path('android/app')
test_mode = '--test' in sys.argv[1:]


def fail(message):
    print(f'::error::{message}', file=sys.stderr)
    sys.exit(1)


def prepare_keystore():
    """يتحقق من الأسرار ويكتب الـkeystore لملف مؤقت ويتحقق من بصمته."""
    missing = [name for name in REQUIRED if not os.environ.get(name)]
    if missing:
        fail('Release signing credentials are missing: ' + ', '.join(missing))
    path = Path(os.environ['GLOWARA_KEYSTORE_PATH']).resolve()
    if Path.cwd().resolve() in path.parents:
        fail('GLOWARA_KEYSTORE_PATH must be outside the repository checkout')
    try:
        data = base64.b64decode(os.environ['GLOWARA_KEYSTORE_B64'], validate=False)
    except (binascii.Error, ValueError):
        fail('GLOWARA_KEYSTORE_B64 is not valid Base64')
    if not data:
        fail('GLOWARA_KEYSTORE_B64 decoded to an empty file')
    fd = os.open(path, os.O_WRONLY | os.O_CREAT | os.O_TRUNC, 0o600)
    with os.fdopen(fd, 'wb') as handle:
        handle.write(data)
    os.chmod(path, 0o600)

    result = subprocess.run(
        ['keytool', '-list', '-v', '-keystore', str(path),
         '-storepass:env', 'GLOWARA_STORE_PASSWORD',
         '-alias', os.environ['GLOWARA_KEY_ALIAS']],
        capture_output=True, text=True,
    )
    if result.returncode != 0:
        fail('keystore could not be opened with the given password and alias')
    match = re.search(r'SHA256:\s*([0-9A-F:]{95})', result.stdout)
    if not match:
        fail('could not read the certificate fingerprint')
    fingerprint = match.group(1)
    if fingerprint == EXPOSED_SHA256:
        fail('this keystore is the publicly exposed Glowara key and must not be used')
    expected = os.environ.get('GLOWARA_EXPECTED_SHA256', '').strip().upper()
    if expected and expected != fingerprint:
        fail('keystore fingerprint does not match GLOWARA_EXPECTED_SHA256')
    print(f'Release certificate SHA-256: {fingerprint}')


def patch_gradle():
    kts = app / 'build.gradle.kts'
    groovy = app / 'build.gradle'
    if kts.exists():
        text = kts.read_text(encoding='utf-8')
        if not test_mode and 'GLOWARA_KEYSTORE_PATH' not in text:
            block = '''
    signingConfigs {
        create("glowara") {
            storeFile = file(System.getenv("GLOWARA_KEYSTORE_PATH"))
            storePassword = System.getenv("GLOWARA_STORE_PASSWORD")
            keyAlias = System.getenv("GLOWARA_KEY_ALIAS")
            keyPassword = System.getenv("GLOWARA_KEY_PASSWORD")
        }
    }
'''
            text, n = re.subn(r'(\nandroid\s*\{)', lambda m: m.group(1) + block, text, count=1)
            if n == 0:
                fail('android block not found')
            text, n = re.subn(r'signingConfigs\.getByName\("debug"\)',
                              'signingConfigs.getByName("glowara")', text)
            if n == 0:
                fail('debug signing line not found')
        text, n = re.subn(r'applicationId\s*=\s*"[^"]+"',
                          f'applicationId = "{APPLICATION_ID}"', text, count=1)
        if n == 0:
            fail('applicationId not found')
        kts.write_text(text, encoding='utf-8')
    elif groovy.exists():
        text = groovy.read_text(encoding='utf-8')
        if not test_mode and 'GLOWARA_KEYSTORE_PATH' not in text:
            block = '''
    signingConfigs {
        glowara {
            storeFile file(System.getenv("GLOWARA_KEYSTORE_PATH"))
            storePassword System.getenv("GLOWARA_STORE_PASSWORD")
            keyAlias System.getenv("GLOWARA_KEY_ALIAS")
            keyPassword System.getenv("GLOWARA_KEY_PASSWORD")
        }
    }
'''
            text, n = re.subn(r'(\nandroid\s*\{)', lambda m: m.group(1) + block, text, count=1)
            if n == 0:
                fail('android block not found')
            text, n = re.subn(r'signingConfigs\.debug', 'signingConfigs.glowara', text)
            if n == 0:
                fail('debug signing line not found')
        text, n = re.subn(r'applicationId\s*=?\s*"[^"]+"',
                          f'applicationId "{APPLICATION_ID}"', text, count=1)
        if n == 0:
            fail('applicationId not found')
        groovy.write_text(text, encoding='utf-8')
    else:
        fail('no build.gradle(.kts) found')


if not app.exists():
    fail('android/app is missing')
if not test_mode:
    prepare_keystore()
patch_gradle()
print('test build (debug-signed, NOT an official release)' if test_mode else 'release signing configured')
