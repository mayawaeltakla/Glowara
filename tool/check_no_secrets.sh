#!/usr/bin/env bash
# يفشل إن وُجد ملف مفتاح أو سر جديد داخل المستودع.
# المفتاح التاريخي الوحيد المسموح مؤقتًا: tool/signing/glowara-release.jks
# (انظر docs/SIGNING_AND_SECURITY.md لخطة إزالته).
set -euo pipefail
allowed='^tool/signing/glowara-release\.jks$'
bad=$(git ls-files | grep -E '\.(jks|keystore|p12|pfx|pem|key)$|(^|/)key\.properties$|(^|/)google-services\.json$|(^|/)\.env' | grep -vE "$allowed" || true)
if [ -n "$bad" ]; then
  echo "Sensitive files are tracked in git:"
  echo "$bad"
  exit 1
fi
echo "No new sensitive files tracked."
