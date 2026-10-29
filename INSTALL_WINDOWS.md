# تشغيل Glowara على Windows

هذا الدليل يشرح تجهيز Flutter، وإنشاء مجلدَي Android والويب، وتشغيل التطبيق، والتحقق منه، وبناء نسختي APK والويب.

> **تنبيه مهم عن بيئة الإعداد الحالية:** لم يكن Flutter/Dart SDK مثبتًا، وكانت أداة الطرفية غير متاحة. لذلك **لم يُشغَّل** `flutter pub get` ولا `flutter analyze` ولا `flutter test` ولا `flutter build`، ولا توجد نسخة APK أو web مبنية. كل الأوامر أدناه يجب تنفيذها على جهازك للتحقق الفعلي.

## المتطلبات

- Windows 10/11 (64 بت).
- اتصال إنترنت للتحميل الأولي فقط؛ التطبيق نفسه يعمل دون إنترنت بعد تحميل النصوص.
- Flutter **3.24.0** أو أحدث متوافق مع Dart 3.4 (الكود مكتوب لـ Flutter 3.22+).
- Android SDK لإنتاج APK. المسار الشائع: `C:\Users\<اسمك>\AppData\Local\Android\Sdk`.
- Java 17 (يأتي مع Android Studio أو يمكن تثبيته منفصلًا).
- متصفح Edge أو Chrome لتشغيل نسخة الويب.

## الخطوة 1: تثبيت Flutter والتحقق منه

### الطريقة الموصى بها: سكربت المشروع

افتح PowerShell في مجلد المشروع:

```powershell
cd C:\path\to\glowara
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser
.\tool\setup_windows.ps1 -InstallFlutter
```

السكربت:

1. يثبّت Flutter 3.24.0 في `C:\src\flutter` إن لم يكن موجودًا.
2. يضيف Flutter إلى `PATH` للجلسة الحالية.
3. ينشئ `android/` و`web/` في **مجلد مؤقت** ثم ينسخهما فقط، حتى لا يستبدل `lib/main.dart` أو بقية الكود.
4. ينفّذ `flutter pub get`.
5. ينفّذ `flutter analyze` و`flutter test` (يسجّل الفشل ولا يخفيه).
6. ينفّذ `flutter build web --release` و`flutter build apk --release`.

### الطريقة اليدوية

بعد تثبيت Flutter وإضافته إلى `PATH`:

```powershell
flutter --version
flutter doctor -v
```

عالج ما يظهره `flutter doctor`، خصوصًا ترخيص Android:

```powershell
flutter doctor --android-licenses
```

> **تحذير:** لا تشغّل `flutter create .` مباشرة في مشروع موجود إلا بعد أخذ نسخة احتياطية أو استخدام Git. قد يعيد توليد ملفات المشروع. استخدم سكربت الإعداد، أو أنشئ المشروع في مجلد مؤقت وانسخ `android/` و`web/` فقط.

## الخطوة 2: إنشاء مجلدات المنصات

إذا لم تستخدم السكربت:

```powershell
$tmp = Join-Path $env:TEMP 'glowara_scaffold'
Remove-Item $tmp -Recurse -Force -ErrorAction SilentlyContinue
flutter create --no-pub --project-name glowara --org com.glowara --platforms=android,web $tmp
Copy-Item "$tmp\android" . -Recurse
Copy-Item "$tmp\web" . -Recurse
Copy-Item "$tmp\.metadata" . -ErrorAction SilentlyContinue
Remove-Item $tmp -Recurse -Force
```

ثم:

```powershell
flutter pub get
```

> **إذن الإنترنت على Android:** قالب Flutter يضع `INTERNET` في manifest الخاص بـ debug/profile فقط. لكي يعمل جلب القرآن في نسخة release، أضف داخل `android/app/src/main/AndroidManifest.xml` السطر التالي ضمن `<manifest>`:
>
> ```xml
> <uses-permission android:name="android.permission.INTERNET" />
> ```
>
> سكربت `tool/setup_windows.ps1` يضيفه تلقائيًا بعد إنشاء السقالات. إذا أنشأت المجلدات يدويًا، أضفه بنفسك.

> المجلدات `android/` و`web/` غير موجودة في التسليم الحالي لأن إنشاءها يحتاج Flutter SDK. هذا متوقع.

## الخطوة 3: التحقق قبل التشغيل

```powershell
flutter analyze
flutter test
```

- `flutter analyze`: يكشف أخطاء الأنواع وواجهات الحزم التي لم تُتحقق منها البيئة الحالية.
- `flutter test`: يشغّل `test/core_test.dart` (اختبارات وحدات أساسية). أضف اختبارات للمستودعات والواجهة لاحقًا.

**لا تعتبر المشروع متحققًا منه حتى ينجح الأمران.** أي خطأ يظهر هنا يجب إصلاحه قبل البناء.

## الخطوة 4: التشغيل في وضع التطوير

### الويب

```powershell
flutter run -d web-server --web-port 8080
```

افتح `http://localhost:8080`.

ملاحظات:

- استخدم خادم HTTP وليس فتح `build/web/index.html` مباشرة، لأن IndexedDB ومسارات التطبيق تحتاج أصلًا (origin) صحيحًا.
- بيانات الويب محفوظة في IndexedDB للمتصفح. مسح بيانات الموقع يمسح البيانات.
- لا تفتح نسخة الويب على `file://`.

### Android

```powershell
flutter devices
flutter run
```

أو اختر جهازًا صريحًا:

```powershell
flutter run -d <device-id>
```

إذا لم يظهر جهاز، فعّل تصحيح USB أو شغّل محاكيًا من Android Studio.

## الخطوة 5: بناء نسخ النشر

### APK

```powershell
flutter build apk --release
```

المخرج:

```text
build\app\outputs\flutter-apk\app-release.apk
```

للتوزيع على Google Play تحتاج حساب مطوّر (رسم لمرة واحدة) وتوقيعًا بمفتاح إصدار عبر `android/key.properties`. لا تضع كلمة مرور المفتاح في المستودع.

### الويب

```powershell
flutter build web --release
```

المخرج: `build\web\`. ارفع محتوياته إلى استضافة ثابتة (Firebase Hosting أو Netlify أو GitHub Pages). إن نشرت على مسار فرعي، اضبط `--base-href` حسب الاستضافة.

## الخطوة 6: فحص سريع للوظائف

بعد التشغيل، تحقق يدويًا من:

1. إنشاء حساب محلي، ثم إغلاق التطبيق وإعادة فتحه: يجب أن يبقى الحساب مسجلًا.
2. إضافة مهمة وعادة ومذكرة ومزاج، ثم إعادة التشغيل: يجب أن تبقى البيانات.
3. فتح سورة من المصحف مع الإنترنت، ثم إغلاق التطبيق وفتحها دون إنترنت: يجب أن تُعرض النسخة المخزنة.
4. تغيير اللغة والثيم وإعادة التشغيل: يجب أن يبقى الاختيار.
5. أنشئ حسابًا محليًا أولًا، ثم استورد ملف JSON مُصدَّرًا من حساب آخر/نسخة أخرى: يجب أن تظهر السجلات منسوبة للحساب الحالي، وأن تبقى الحسابات وكلمات المرور غير مستوردة، وأن تظهر رسالة خطأ واضحة إذا كان الملف ليس نسخة Glowara.
6. فعّل PIN للمذكرات: يجب أن يُطلب عند فتح القسم. تذكّر أن PIN قفل وصول محلي وليس تشفيرًا.
7. اختبر مهمة يومية وأخرى أسبوعية: يجب أن تظهر في الأيام المطابقة، وأن يكون إتمامها مشتركًا على مستوى السلسلة (هذا سلوك هذه النسخة).

## التكلفة والخدمات

| الخدمة | التكلفة | ملاحظة |
|---|---|---|
| Flutter/Dart | مجانية | لا رسوم ترخيص |
| Git ومستودع خاص | مجاني عادةً | تحقق من حدود الخطة |
| استضافة ويب ثابتة | مجانية ضمن حدود | تحقق من النطاق الترددي |
| Google Play | رسم لمرة واحدة | مطلوب للنشر على المتجر |
| مزامنة سحابية | **غير منفذة** | تحتاج خادمًا ومصادقة ومفاتيح خارجية |
| إشعارات خلفية | **غير منفذة** | تحتاج إعدادًا خاصًا بكل منصة |

## ما لم يُنفَّذ في هذه البيئة

- `flutter pub get`
- `flutter analyze`
- `flutter test`
- `flutter build web`
- `flutter build apk`
- إنشاء APK أو نسخة ويب فعلية

هذه ليست ادعاءات نجاح؛ هي خطوات متبقية يجب تنفيذها والتحقق من نتائجها. لا توجد في التسليم الحالي نسخة APK ولا مجلد `build/web`، ومجلدا `android/` و`web/` نفسيهما غير موجودين بعد.

التعريب لا يُولَّد من ARB في هذه النسخة؛ النصوص في `lib/core/localization/`. ملفات `l10n.yaml` و`lib/l10n/*.arb` مرجعية وغير مستخدمة.

## استكشاف الأخطاء

- **`flutter` غير معروف:** أعد فتح PowerShell بعد تعديل `PATH` أو استخدم `C:\src\flutter\bin\flutter.bat`.
- **فشل بناء Android بسبب Java:** ثبّت JDK 17 وحدّد `JAVA_HOME`.
- **فشل `flutter doctor` في تراخيص Android:** نفّذ `flutter doctor --android-licenses`.
- **فشل `flutter create`:** تأكد أن مجلد الهدف فارغ إن استخدمت الطريقة اليدوية.
- **الويب لا يحفظ البيانات:** تأكد من فتحه عبر HTTP وليس `file://`، ومن عدم استخدام وضع التصفح الخاص.
- **تعارض إصدارات الحزم:** استخدم `flutter pub get` أولًا، ثم `flutter pub upgrade --major-versions` بحذر، وأعد التحليل والاختبار.
