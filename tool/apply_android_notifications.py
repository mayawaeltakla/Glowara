#!/usr/bin/env python3
"""يجهّز مشروع أندرويد المولَّد لإشعارات flutter_local_notifications.

يُستدعى في خطوات البناء بعد توليد android/. آمن عند التكرار (idempotent).
يُنهي بخطأ واضح إن لم يجد ما يعدّله حتى لا يُبنى APK بإشعارات معطّلة بصمت.
"""
import re
import sys
from pathlib import Path

root = Path('android')
manifest = root / 'app/src/main/AndroidManifest.xml'
if not manifest.exists():
    sys.exit('android manifest not found')

text = manifest.read_text(encoding='utf-8')
perms = ['android.permission.POST_NOTIFICATIONS', 'android.permission.RECEIVE_BOOT_COMPLETED',
         'android.permission.VIBRATE']
for perm in perms:
    if perm not in text:
        start = text.index('<manifest')
        end = text.index('>', start) + 1
        text = text[:end] + f'\n    <uses-permission android:name="{perm}" />' + text[end:]
if 'ScheduledNotificationReceiver' not in text:
    receivers = '''
        <receiver android:exported="false" android:name="com.dexterous.flutterlocalnotifications.ScheduledNotificationReceiver" />
        <receiver android:exported="false" android:name="com.dexterous.flutterlocalnotifications.ScheduledNotificationBootReceiver">
            <intent-filter>
                <action android:name="android.intent.action.BOOT_COMPLETED"/>
                <action android:name="android.intent.action.MY_PACKAGE_REPLACED"/>
                <action android:name="android.intent.action.QUICKBOOT_POWERON" />
                <action android:name="com.htc.intent.action.QUICKBOOT_POWERON"/>
            </intent-filter>
        </receiver>
    '''
    if '</application>' not in text:
        sys.exit('no </application> in manifest')
    text = text.replace('</application>', receivers + '</application>', 1)
manifest.write_text(text, encoding='utf-8')
print('manifest ok')

kts = root / 'app/build.gradle.kts'
groovy = root / 'app/build.gradle'
rules = root / 'app/proguard-rules.pro'
rules.write_text('''-keep class com.dexterous.** { *; }
-keepattributes Signature
-keepattributes *Annotation*
-keep class * extends com.google.gson.reflect.TypeToken
-keep,allowobfuscation,allowshrinking class com.google.gson.reflect.TypeToken
''', encoding='utf-8')

if kts.exists():
    g = kts.read_text(encoding='utf-8')
    if 'isCoreLibraryDesugaringEnabled' not in g:
        g, n = re.subn(r'compileOptions\s*\{', 'compileOptions {\n        isCoreLibraryDesugaringEnabled = true', g, count=1)
        if n == 0:
            sys.exit('compileOptions not found in build.gradle.kts')
        g += '\ndependencies {\n    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")\n}\n'
    if 'proguard-rules.pro' not in g:
        g = re.sub(r'(release\s*\{)', r'\1\n            proguardFiles(getDefaultProguardFile("proguard-android-optimize.txt"), "proguard-rules.pro")', g, count=1)
    kts.write_text(g, encoding='utf-8')
    print('gradle kts ok')
elif groovy.exists():
    g = groovy.read_text(encoding='utf-8')
    if 'coreLibraryDesugaringEnabled' not in g:
        g, n = re.subn(r'compileOptions\s*\{', 'compileOptions {\n        coreLibraryDesugaringEnabled true', g, count=1)
        if n == 0:
            sys.exit('compileOptions not found in build.gradle')
        g += "\ndependencies {\n    coreLibraryDesugaring 'com.android.tools:desugar_jdk_libs:2.1.4'\n}\n"
    if 'proguard-rules.pro' not in g:
        g = re.sub(r'(release\s*\{)', r"\1\n            proguardFiles getDefaultProguardFile('proguard-android-optimize.txt'), 'proguard-rules.pro'", g, count=1)
    groovy.write_text(g, encoding='utf-8')
    print('gradle groovy ok')
else:
    sys.exit('no app build.gradle(.kts)')
