#!/usr/bin/env python3
"""يضيف ودجت الشاشة الرئيسية (سطر واحد: عدد مهام اليوم) إلى مشروع أندرويد المولَّد.

يُستدعى في بناء الاختبار (build.yml) فقط، مع تمرير `--dart-define=GLOWARA_WIDGET=true`.
لا يُستدعى في release.yml: الإصدار الرسمي لا يحمل الودجت حتى تقرّر المالكة ذلك.
الودجت يقرأ مفتاحين من shared_preferences ولا يتصل بالشبكة ولا يطلب أي إذن.
آمن عند التكرار، ويفشل بوضوح إن لم يجد ما يعدّله.
"""
import re
import sys
from pathlib import Path

root = Path(sys.argv[1]) if len(sys.argv) > 1 else Path('android')
main = root / 'app/src/main'
manifest = main / 'AndroidManifest.xml'
if not manifest.exists():
    sys.exit('android manifest not found')

kotlin_files = list((main / 'kotlin').rglob('MainActivity.kt')) + list((main / 'java').rglob('MainActivity.kt'))
if not kotlin_files:
    sys.exit('MainActivity.kt not found')
pkg_match = re.search(r'^package\s+([\w.]+)', kotlin_files[0].read_text(encoding='utf-8'), re.M)
if not pkg_match:
    sys.exit('package line not found in MainActivity.kt')
pkg = pkg_match.group(1)
cls = f'{pkg}.GlowaraWidgetProvider'

(kotlin_files[0].parent / 'GlowaraWidgetProvider.kt').write_text(f'''package {pkg}

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.Context
import android.view.View
import android.widget.RemoteViews

/** يعرض اسم التطبيق وسطرًا واحدًا يكتبه التطبيق في shared_preferences. بلا شبكة. */
class GlowaraWidgetProvider : AppWidgetProvider() {{
    override fun onUpdate(context: Context, manager: AppWidgetManager, ids: IntArray) {{
        val prefs = context.getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
        val title = prefs.getString("flutter.glowara_widget_title", null) ?: "Glowara"
        val line = prefs.getString("flutter.glowara_widget_line", null)
        val launch = context.packageManager.getLaunchIntentForPackage(context.packageName)
        for (id in ids) {{
            val views = RemoteViews(context.packageName, R.layout.glowara_widget)
            views.setTextViewText(R.id.glowara_widget_title, title)
            if (line.isNullOrEmpty()) {{
                views.setViewVisibility(R.id.glowara_widget_line, View.GONE)
            }} else {{
                views.setViewVisibility(R.id.glowara_widget_line, View.VISIBLE)
                views.setTextViewText(R.id.glowara_widget_line, line)
            }}
            if (launch != null) {{
                val pending = PendingIntent.getActivity(context, 0, launch, PendingIntent.FLAG_IMMUTABLE)
                views.setOnClickPendingIntent(R.id.glowara_widget_root, pending)
            }}
            manager.updateAppWidget(id, views)
        }}
    }}
}}
''', encoding='utf-8')

res = main / 'res'
for d in ('layout', 'xml', 'drawable', 'values'):
    (res / d).mkdir(parents=True, exist_ok=True)

(res / 'drawable/glowara_widget_bg.xml').write_text('''<?xml version="1.0" encoding="utf-8"?>
<shape xmlns:android="http://schemas.android.com/apk/res/android" android:shape="rectangle">
    <solid android:color="#FFF6EFF2" />
    <corners android:radius="22dp" />
</shape>
''', encoding='utf-8')

(res / 'layout/glowara_widget.xml').write_text('''<?xml version="1.0" encoding="utf-8"?>
<LinearLayout xmlns:android="http://schemas.android.com/apk/res/android"
    android:id="@+id/glowara_widget_root"
    android:layout_width="match_parent"
    android:layout_height="match_parent"
    android:orientation="vertical"
    android:gravity="center_vertical"
    android:padding="14dp"
    android:background="@drawable/glowara_widget_bg">
    <TextView
        android:id="@+id/glowara_widget_title"
        android:layout_width="wrap_content"
        android:layout_height="wrap_content"
        android:textColor="#FF5B2A45"
        android:textSize="16sp"
        android:textStyle="bold" />
    <TextView
        android:id="@+id/glowara_widget_line"
        android:layout_width="wrap_content"
        android:layout_height="wrap_content"
        android:layout_marginTop="4dp"
        android:textColor="#FF3F3A3D"
        android:textSize="13sp" />
</LinearLayout>
''', encoding='utf-8')

(res / 'xml/glowara_widget_info.xml').write_text('''<?xml version="1.0" encoding="utf-8"?>
<appwidget-provider xmlns:android="http://schemas.android.com/apk/res/android"
    android:minWidth="180dp"
    android:minHeight="70dp"
    android:updatePeriodMillis="1800000"
    android:initialLayout="@layout/glowara_widget"
    android:resizeMode="horizontal"
    android:widgetCategory="home_screen" />
''', encoding='utf-8')

text = manifest.read_text(encoding='utf-8')
if 'GlowaraWidgetProvider' not in text:
    receiver = f'''
        <receiver android:name="{cls}" android:exported="true">
            <intent-filter>
                <action android:name="android.appwidget.action.APPWIDGET_UPDATE" />
            </intent-filter>
            <meta-data android:name="android.appwidget.provider" android:resource="@xml/glowara_widget_info" />
        </receiver>
    '''
    if '</application>' not in text:
        sys.exit('no </application> in manifest')
    text = text.replace('</application>', receiver + '</application>', 1)
    manifest.write_text(text, encoding='utf-8')
print('widget ok:', cls)
