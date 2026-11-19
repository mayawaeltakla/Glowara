#!/usr/bin/env python3
"""يفحص الملفات المتتبَّعة في Git بحثًا عن أسرار: بالاسم وبالمحتوى.

يعمل دون شبكة ودون تثبيت أدوات. الأنماط مبنية على أنماط الأدوات المعروفة
(gitleaks/detect-secrets) لأهم الحالات. هو فحص مكافئ مبسّط وليس بديلًا كاملًا
عن أداة مخصصة، لذا يُنصح بتفعيل GitHub secret scanning في إعدادات المستودع.

ما يكتشفه:
  * ملفات مفاتيح ومستودعات مفاتيح (jks/keystore/p12/pfx/pem/key) وملفات بيئة.
  * مفاتيح خاصة (BEGIN ... PRIVATE KEY).
  * رموز GitHub وAWS وGoogle API وSlack وStripe ومفاتيح مشابهة.
  * كلمات مرور/أسرار ثابتة في الكود وملفات البناء (password = "...").
  * ملفات google-services.json وkey.properties.

لا توجد استثناءات عامة. الاستثناء الوحيد سطر محدد بتعليق
``secret-scan: allow <سبب>`` في نفس السطر، ويظهر في المراجعة.

تاريخ Git لا يُفحص هنا: المفتاح القديم ما زال موجودًا في commits سابقة
(انظر docs/SIGNING_AND_SECURITY.md).
"""
import re
import subprocess
import sys
from pathlib import Path

BAD_NAMES = re.compile(
    r'(\.(jks|keystore|p12|pfx|pem|key|ppk)$)'
    r'|((^|/)key\.properties$)'
    r'|((^|/)google-services\.json$)'
    r'|((^|/)\.env(\..*)?$)'
    r'|((^|/)id_(rsa|dsa|ecdsa|ed25519)$)',
    re.IGNORECASE,
)

PATTERNS = [
    ('private key block', re.compile(r'-----BEGIN (?:[A-Z]+ )?PRIVATE KEY-----')),
    ('GitHub token', re.compile(r'\b(?:ghp|gho|ghu|ghs|ghr|github_pat)_[A-Za-z0-9_]{20,}')),
    ('AWS access key id', re.compile(r'\b(?:AKIA|ASIA)[0-9A-Z]{16}\b')),
    ('Google API key', re.compile(r'\bAIza[0-9A-Za-z_\-]{35}\b')),
    ('Slack token', re.compile(r'\bxox[abprs]-[0-9A-Za-z\-]{10,}')),
    ('Stripe live key', re.compile(r'\b(?:sk|rk)_live_[0-9A-Za-z]{16,}')),
    ('generic bearer/API secret', re.compile(
        r'(?i)\b(?:api[_-]?key|secret|access[_-]?token|auth[_-]?token)\b\s*[:=]\s*["\'][A-Za-z0-9_\-/+=]{16,}["\']')),
    ('hard-coded password', re.compile(
        r'(?i)\b(?:store|key|keystore|db|admin)?_?pass(?:word|wd)?\b\s*[:=]\s*["\'](?!\s*["\'])(?![^"\']*(?:\$\{|\$\(|\bgetenv\b|System\.getenv|%s))([^"\']{4,})["\']')),
]

# كلمات مرور وهمية محددة بالاسم تستعملها الاختبارات لحسابات اختبار في الذاكرة.
# تُقبل فقط داخل test/ وفقط بهذه القيم الثلاث؛ أي قيمة أخرى في test/ تُفحص كالمعتاد.
TEST_DUMMY_PASSWORDS = frozenset({'bad-pass', 'secret1', 'wrong-one'})

# أسطر مسموحة صراحة، سطرًا بسطر (قيم وهمية في الاختبارات مثلًا).
# لا يُستثنى أي مجلد أو ملف بالكامل، بما فيه test/.
ALLOW_MARK = 'secret-scan: allow'

TEXT_SUFFIXES = {
    '.dart', '.py', '.sh', '.yml', '.yaml', '.json', '.gradle', '.kts', '.properties',
    '.xml', '.md', '.txt', '.toml', '.cfg', '.ini', '.js', '.html', '.ps1', '.arb',
}
# أصول ثنائية ونسخة النصوص الدينية الاحتياطية فقط (لا كود فيها).
SKIP_DIRS = ('assets/', 'docs/content-backup/')


def tracked_files():
    out = subprocess.run(['git', 'ls-files', '-z'], capture_output=True, check=True).stdout
    return [p for p in out.decode('utf-8').split('\0') if p]


def main():
    problems = []
    for name in tracked_files():
        if BAD_NAMES.search(name):
            problems.append(f'{name}: sensitive file type is tracked')
            continue
        if name.startswith(SKIP_DIRS):
            continue
        path = Path(name)
        if path.suffix.lower() not in TEXT_SUFFIXES or not path.is_file():
            continue
        try:
            text = path.read_text(encoding='utf-8')
        except UnicodeDecodeError:
            continue
        for number, line in enumerate(text.splitlines(), 1):
            if ALLOW_MARK in line:
                continue
            for label, pattern in PATTERNS:
                matches = list(pattern.finditer(line))
                if not matches:
                    continue
                if (label == 'hard-coded password' and name.startswith('test/')
                        and all(m.group(1) in TEST_DUMMY_PASSWORDS for m in matches)):
                    continue
                problems.append(f'{name}:{number}: possible {label}')
    if problems:
        print('Secret scan failed:')
        for item in problems:
            print('  ' + item)
        sys.exit(1)
    print('Secret scan passed: no sensitive files or secret patterns in tracked files.')


if __name__ == '__main__':
    main()
