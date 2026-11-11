#!/usr/bin/env bash
# يجلب خط Tajawal إلى assets/google_fonts ليُضمَّن داخل التطبيق (يعمل دون إنترنت).
# يتعرّف عليه حزمة google_fonts تلقائيًا من هذا المجلد. أي فشل لا يوقف البناء:
# يعود التطبيق وقتها إلى الجلب عند أول تشغيل أو خط النظام.
set -u
dir="assets/google_fonts"
mkdir -p "$dir"
base="https://raw.githubusercontent.com/google/fonts/main/ofl/tajawal"
for w in Regular Medium Bold; do
  f="Tajawal-$w.ttf"
  if [ ! -s "$dir/$f" ]; then
    curl -fsSL --retry 3 "$base/$f" -o "$dir/$f" || { echo "could not fetch $f"; rm -f "$dir/$f"; }
  fi
done
ls -l "$dir"
