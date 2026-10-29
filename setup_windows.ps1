#requires -Version 5.1
<#
.SYNOPSIS
  إعداد مشروع Glowara وتشغيل التحقق والبناء على Windows.

.DESCRIPTION
  يثبّت Flutter SDK إن طُلب، ينشئ مجلدَي android وweb دون المساس بكود lib،
  ثم يجلب الحزم ويشغّل التحليل والاختبارات ويبني الويب وAPK.

.PARAMETER InstallFlutter
  ثبّت Flutter SDK (3.24.0) في C:\src\flutter إن لم يكن موجودًا.

.PARAMETER FlutterChannel
  قناة Flutter (stable افتراضيًا). تُستخدم عند تثبيت إصدار غير مثبت مسبقًا.

.PARAMETER FlutterVersion
  إصدار Flutter المطلوب. الافتراضي 3.24.0، وهو الإصدار الذي كُتب الكود ليتوافق معه.
#>
param(
  [Parameter()][switch] $InstallFlutter,
  [Parameter()][string] $FlutterChannel = 'stable',
  [Parameter()][string] $FlutterVersion = '3.24.0'
)

$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'

$projectRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$flutterRoot = 'C:\src\flutter'
$flutterBin = Join-Path $flutterRoot 'bin\flutter.bat'

Write-Host "=== Glowara Windows Setup ===" -ForegroundColor Cyan
Write-Host "Project root: $projectRoot" -ForegroundColor Gray

function Run-Cmd {
  param(
    [Parameter(Mandatory = $true)][string] $Command,
    [string] $WorkingDirectory = $projectRoot,
    [switch] $Critical
  )
  Write-Host "> $Command" -ForegroundColor DarkGray
  $proc = Start-Process -FilePath 'cmd.exe' `
    -ArgumentList "/c $Command" `
    -WorkingDirectory $WorkingDirectory `
    -NoNewWindow -Wait -PassThru
  if ($proc.ExitCode -ne 0) {
    Write-Host "فشل الأمر: $Command (رمز الخروج $($proc.ExitCode))" -ForegroundColor Red
    if ($Critical) { throw "أمر مطلوب فشل: $Command" }
    return $false
  }
  return $true
}

# 1) تثبيت Flutter عند الطلب
if ($InstallFlutter) {
  if (-not (Test-Path $flutterBin)) {
    Write-Host "تثبيت Flutter $FlutterVersion في $flutterRoot ..." -ForegroundColor Yellow
    $zipUrl = "https://storage.googleapis.com/flutter_infra_release/releases/$FlutterChannel/windows/flutter_windows_$FlutterVersion-$FlutterChannel.zip"
    $zipPath = Join-Path $env:TEMP 'flutter_windows.zip'
    Invoke-WebRequest -Uri $zipUrl -OutFile $zipPath
    New-Item -ItemType Directory -Force -Path 'C:\src' | Out-Null
    Expand-Archive -Path $zipPath -DestinationFolder 'C:\src' -Force
    Remove-Item $zipPath -Force
    Write-Host "تم تثبيت Flutter." -ForegroundColor Green
  } else {
    Write-Host "Flutter مثبت مسبقًا في $flutterRoot" -ForegroundColor Green
  }
  $env:PATH = "$flutterRoot\bin;$env:PATH"
} else {
  if (-not (Test-Path $flutterBin)) {
    throw "Flutter غير موجود في $flutterBin. شغّل السكربت مع -InstallFlutter."
  }
  $env:PATH = "$flutterRoot\bin;$env:PATH"
}

Run-Cmd -Command "flutter --version" -Critical

# 2) إنشاء android وweb في مجلد مؤقت، ثم نسخهما فقط.
#    لا نستخدم `flutter create .` مباشرة لأنه قد يستبدل ملفات المشروع الحالية.
$missingAndroid = -not (Test-Path (Join-Path $projectRoot 'android'))
$missingWeb = -not (Test-Path (Join-Path $projectRoot 'web'))
if ($missingAndroid -or $missingWeb) {
  Write-Host "إنشاء scaffolding النظامي (android, web) في مجلد مؤقت ..." -ForegroundColor Yellow
  $scaffold = Join-Path $env:TEMP 'glowara_scaffold'
  if (Test-Path $scaffold) { Remove-Item $scaffold -Recurse -Force }
  New-Item -ItemType Directory -Force -Path $scaffold | Out-Null

  $platforms = @()
  if ($missingAndroid) { $platforms += 'android' }
  if ($missingWeb) { $platforms += 'web' }
  $platformArg = $platforms -join ','

  Run-Cmd -Command "flutter create --no-pub --project-name glowara --org com.glowara --platforms=$platformArg `"$scaffold`"" -Critical

  if ($missingAndroid) {
    Copy-Item -Path (Join-Path $scaffold 'android') -Destination $projectRoot -Recurse -Force
    Write-Host "نُسخ android/ إلى المشروع." -ForegroundColor Green
  }
  if ($missingWeb) {
    Copy-Item -Path (Join-Path $scaffold 'web') -Destination $projectRoot -Recurse -Force
    Write-Host "نُسخ web/ إلى المشروع." -ForegroundColor Green
  }
  if (-not (Test-Path (Join-Path $projectRoot '.metadata'))) {
    Copy-Item -Path (Join-Path $scaffold '.metadata') -Destination $projectRoot -Force
  }
  Remove-Item $scaffold -Recurse -Force
} else {
  Write-Host "android/ وweb/ موجودان مسبقًا." -ForegroundColor Green
}

# 2b) إذن الإنترنت مطلوب لتنزيل القرآن في نسخة release.
#     قالب Flutter يضعه في debug/profile فقط، لذلك نضيفه إلى main.
$manifestPath = Join-Path $projectRoot 'android\app\src\main\AndroidManifest.xml'
if (Test-Path $manifestPath) {
  $manifest = Get-Content $manifestPath -Raw
  if ($manifest -notmatch [regex]::Escape('android.permission.INTERNET')) {
    $manifest = $manifest -replace '(<manifest[^>]*>)', "`$1`r`n    <uses-permission android:name=`"android.permission.INTERNET`" />"
    Set-Content -Path $manifestPath -Value $manifest -Encoding UTF8
    Write-Host "أُضيف إذن INTERNET إلى AndroidManifest.xml." -ForegroundColor Green
  }
} else {
  Write-Host "تحذير: لم يُعثر على AndroidManifest.xml لإضافة إذن الإنترنت." -ForegroundColor Yellow
}

# 3) جلب الحزم
Write-Host "جلب الحزم (flutter pub get) ..." -ForegroundColor Yellow
Run-Cmd -Command "flutter pub get" -Critical

# 4) التحليل الساكن
Write-Host "تشغيل التحليل الساكن (flutter analyze) ..." -ForegroundColor Yellow
$analyzeOk = Run-Cmd -Command "flutter analyze"
if (-not $analyzeOk) {
  Write-Host "تحذير: flutter analyze أبلغ عن تحذيرات أو أخطاء. راجع المخرج أعلاه." -ForegroundColor Yellow
}

# 5) الاختبارات
Write-Host "تشغيل الاختبارات (flutter test) ..." -ForegroundColor Yellow
$testOk = Run-Cmd -Command "flutter test"
if (-not $testOk) {
  Write-Host "تحذير: فشل أحد الاختبارات أو لم تُشغَّل. راجع المخرج أعلاه." -ForegroundColor Yellow
}

# 6) بناء الويب
Write-Host "بناء نسخة الويب (flutter build web --release) ..." -ForegroundColor Yellow
$webOk = Run-Cmd -Command "flutter build web --release"
if ($webOk) { Write-Host "نسخة الويب جاهزة في: build\web\" -ForegroundColor Green }

# 7) بناء APK
Write-Host "بناء نسخة APK (flutter build apk --release) ..." -ForegroundColor Yellow
$apkOk = Run-Cmd -Command "flutter build apk --release"
if ($apkOk) {
  $apkPath = Join-Path $projectRoot 'build\app\outputs\flutter-apk\app-release.apk'
  Write-Host "نسخة APK جاهزة في: $apkPath" -ForegroundColor Green
}

Write-Host "=== اكتمل الإعداد ===" -ForegroundColor Cyan
Write-Host "إن ظهرت تحذيرات analyze/test/build فالمشروع لم يُتحقق منه بالكامل." -ForegroundColor Yellow
