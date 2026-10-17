<div dir="rtl">
<div align="center">
<img src="https://i.imgur.com/uwZTeVL.png" width="200">

# Hadith Searcher

تطبيق للبحث في الأحاديث النبوية والاطّلاع على شروحها وأحكام المحدثين عليها

<a href='https://play.google.com/store/apps/details?id=com.moaymandev.hadithsearcher'><img alt='Get it on Google Play' src='https://play.google.com/intl/en_us/badges/static/images/badges/en_badge_web_generic.png' height="80"/></a>

</div>

## حول التطبيق

تطبيق Hadith Searcher هو تطبيق مجاني ومفتوح المصدر للبحث في الأحاديث النبوية والاطّلاع على شروحها ومصادرها وأحكام المحدثين عليها. يعتمد على محتوى موقع الدرر السنية، ويجمع معلومات الحديث في مكان واحد لتيسير قراءته ودراسته.

## المميزات

- **البحث** - البحث بأي كلمة أو بجميع الكلمات أو بعبارة مطابقة، مع اختيار نطاق البحث واستبعاد كلمات أو جملة
- **بيانات الحديث** - عرض الراوي والمصدر والمحدث وخلاصة حكم المحدث والتخريج وأصول الحديث
- **الشروحات** - الاطلاع على شروحات وتفاسير الأحاديث
- **الأحاديث المشابهة** - البحث عن أحاديث مشابهة للحديث المعروض
- **تصفية متقدمة** - اختيار درجات أو محدثين أو كتب أو رواة في البحث من ضمن آلاف الاختيارات
- **المحفوظات** - حفظ الأحاديث للقراءة بدون اتصال بالإنترنت
- **تخصيص المظهر** - التحكم في حجم ونوع خط الأحاديث ودعم العديد من الألوان للتطبيق

## صور من التطبيق

<div align="center">

| البحث | البحث المتقدم |
|:---:|:---:|
| <img src="https://i.imgur.com/wo6bGGc.png" width="250"> | <img src="https://i.imgur.com/KFjDb4B.png" width="250"> |

| المحفوظات | الإعدادات |
|:---:|:---:|
| <img src="https://i.imgur.com/bS4FQF8.png" width="250"> | <img src="https://i.imgur.com/77MRNM4.png" width="250"> |

</div>

## مصادر البيانات

جميع الأحاديث والمعلومات مأخوذة من موقع [الدرر السنية](https://dorar.net/) باستخدام [Dorar Hadith API](https://github.com/MAymanKH/dorar-hadith-api).

## المتطلبات

- Flutter بإصدار `3.47.0` أو أحدث، مع Dart بإصدار `3.12.0` أو أحدث وأقل من `4.0.0`، وفقاً لـ `pubspec.yaml`
- Android SDK مع المنصة `37` وNDK بإصدار `29.0.13113456`، وفقاً لـ `android/app/build.gradle.kts`
- JDK متوافق مع Gradle، ويمكن استخدام JDK المرفق مع Android Studio
- محاكي Android أو جهاز حقيقي للتجربة
- Python 3 لتشغيل سكربتات الإصدار وتوليد الألوان

## التثبيت والتشغيل

### 1. استنساخ المشروع

```bash
git clone https://github.com/MAymanKH/HadithSearcher.git
cd HadithSearcher
```

### 2. إعداد الخدمات

رابط API الافتراضي موجود في `lib/core/constants/app_config.dart`، ومفاتيح إرسال Sentry وPostHog العامة موجودة في `lib/core/constants/telemetry_config.dart`. لا يحتاج البناء إلى ملف `.env`. لا تضع رموز إدارة الحسابات أو مفاتيح التوقيع الخاصة في ملفات المصدر.

لتجربة خادم آخر، مرّر `--dart-define=HADITH_API_BASE_URL=https://your-api.example` إلى أمر التشغيل أو البناء.

تفعّل نسخة Play تقارير الأعطال وتحليلات الاستخدام تلقائياً. تطلب نسختا F-Droid وGitHub موافقة منفصلة لكل خدمة. تفاصيل القياس والخصوصية: [Telemetry](docs/telemetry.md). خطوات الاختبار المحلي والتحقق من وصول الأحداث: [Verify telemetry](docs/verify-telemetry.md).

### 3. تثبيت الاعتماديات

```bash
flutter doctor
flutter pub get
```

### 4. تشغيل التطبيق

```bash
flutter run --flavor fdroid
# لتشغيل نسخة Google Play:
flutter run --flavor play
```

### 5. بناء التطبيق

لبناء نسخ Android الثلاث، جهّز متطلبات التوقيع وShorebird الموضحة أدناه، ثم شغّل:

```bash
./scripts/release.py all
```

## بناء Android والتوزيع

غيّر `version` في `pubspec.yaml` مرة واحدة لكل إصدار جديد، ثم شغّل `./scripts/release.py all`. تعرض صفحة حول التطبيق رقم الإصدار الفعلي. يتطلب السكربت Python 3، وFlutter، وShorebird عند بناء نسخة Play، مع تسجيل الدخول مسبقاً عبر `shorebird login`. يستخدم سكربت إصدار Play إصدار Flutter `3.47.7` عبر Shorebird.

| الأمر | الناتج |
| --- | --- |
| `./scripts/release.py play` | ملف AAB لنسخة Google Play، وتسجيل الإصدار في Shorebird |
| `./scripts/release.py fdroid` | ملف APK غير موقّع لنسخة F-Droid |
| `./scripts/release.py github` | بناء ملف APK لنسخة GitHub وتوقيعه للتثبيت المباشر |
| `./scripts/release.py all` | بناء نسخ F-Droid وGitHub وGoogle Play بالتتابع |
| `./scripts/release.py play --dry-run` | بناء ملف Play دون تسجيل إصدار على الخادم |
| `./scripts/release.py patch-play` | إرسال تحديث Dart لإصدار Play المحدد حالياً في `pubspec.yaml` |

يحفظ السكربت ملفات الإصدارات في `build/releases/play/` و`build/releases/fdroid/` و`build/releases/github/` بأسماء تتضمن رقم الإصدار. لا يرفع الملفات إلى Google Play أو F-Droid أو GitHub. لبناء نسختي Play وGitHub، جهّز ملف `android/key.properties` ومفتاح التوقيع المحلي. لا تُضمّن بيانات التوقيع الخاصة في المصدر.

لا تحتوي نسخة F-Droid على محدّث Shorebird أو مكتبة تحديث Google Play. للبناء المباشر استخدم `flutter build apk --release --flavor fdroid`، والناتج هو `build/app/outputs/flutter-apk/app-fdroid-release.apk`.

ملف F-Droid غير موقّع، ولا يمكن تثبيته مباشرة على الهاتف. لإنشاء نسخة GitHub للتثبيت المباشر، جهّز `android/key.properties` ومفتاح التوقيع المحلي، ثم شغّل `./scripts/release.py github`. يبني الأمر ملف APK من المصدر باستخدام إعدادات F-Droid ثم يوقّعه، دون الحاجة إلى بناء نسخة F-Droid مسبقاً. يحفظ الناتج باسم `HadithSearcher-<version>-github.apk` في `build/releases/github/` ويتحقق من توقيعه. تظل نسخة F-Droid غير موقّعة لكي يوقّعها F-Droid عند النشر. تتطلب تحديثات التطبيق استخدام مفتاح التوقيع نفسه؛ قد تختلف مفاتيح نسخ Google Play وF-Droid المنشورة عن المفتاح المحلي.

## التحقق من المشروع

لتشغيل التحليل واختبارات الوحدة والواجهات واختبارات سكربت الإصدار:

```bash
flutter analyze
flutter test test
python3 -m unittest discover -s test -p release_update_channel_test.py
```

لاختبار البحث وتفاصيل المصادر عبر API الفعلي:

```bash
flutter test test/hadith_details_live_test.dart --dart-define=VERIFY_LIVE_DETAILS=true
flutter test test/filter_catalog_live_test.dart --dart-define=VERIFY_LIVE_FILTERS=true
```

لاختبار الواجهات على محاكي Android وحفظ صورها في `build/api-capabilities`، استبدل `emulator-5554` بمعرّف المحاكي:

```bash
flutter drive --driver=test_driver/api_capabilities.dart \
  --target=integration_test/api_capabilities_test.dart \
  -d emulator-5554 --flavor fdroid \
  --dart-define=HADITH_API_BASE_URL=http://127.0.0.1:8717 \
  --dart-define=API_SCREENSHOTS=true
```

يستخدم اختبار الواجهات خادم بيانات محلياً ويمسح إعدادات التطبيق داخل المحاكي عند البدء.

## التحقق من تحديثات التطبيق

يتحقق التطبيق من التحديثات عند فتحه أو العودة إليه، بحد أقصى محاولة تلقائية واحدة يومياً. يظهر تنبيه يمكن تأجيله، ويمكن التحقق يدوياً في أي وقت من صفحة «حول». لا يمنع فشل الاتصال استخدام التطبيق.

- تستخدم نسخة Play واجهة Google Play للتحقق من توفر تحديث لهذا الجهاز والحساب، وتفتح صفحة التطبيق في المتجر عند اختيار التحديث. مكتبة Google الخاصة بالتحديثات موجودة في نسخة Play فقط.
- تستخدم نسخة F-Droid الإصدار الموصى به في `https://f-droid.org/api/v1/packages/com.moaymandev.hadithsearcher`، وتفتح صفحة الحزمة في F-Droid. يجب نشر الحزمة في مستودع F-Droid الرسمي لكي يعمل التحقق.
- تستخدم نسخة GitHub آخر إصدار مستقر منشور في GitHub Releases، وتشترط وجود ملف APK مرفوع للتثبيت. ارفع الملف `HadithSearcher-<version>+<build>-github.apk` الناتج من `./scripts/release.py github` مع الإصدار. يُقرأ رقم البناء من اسم الملف، وتظل ملفات الإصدارات القديمة المسماة `app-release.apk` مدعومة عند استخدام وسم مثل `v2.1.2` أو `v2.1.2+14`. يفتح زر التحديث صفحة الإصدار لتنزيل APK وتثبيته.

يضيف سكربت إصدار GitHub الخيار `--dart-define=UPDATE_CHANNEL=github` تلقائياً. عند البناء يدوياً استخدم `flutter build apk --release --flavor fdroid --dart-define=UPDATE_CHANNEL=github` ثم وقّع الملف بالمفتاح نفسه المستخدم للإصدارات السابقة. تبقى نسخة F-Droid الافتراضية موجهة إلى F-Droid.

لتشغيل اختبارات التحديثات:

```bash
flutter test test/update_service_test.dart test/update_prompt_test.dart
# لاختبار واجهات التحديثات وقنوات Android على محاكي:
flutter test integration_test/update_test.dart -d emulator-5554 --flavor fdroid --dart-define=UPDATE_CHANNEL=github
flutter test integration_test/update_test.dart -d emulator-5554 --flavor play
```

## أدلة التطوير

- [ترجمة الواجهة وإضافة النصوص](lib/l10n/README.md)
- [تنظيم لوحات الألوان](docs/color-schemes.md)
- [تعديل الألوان وتوليد الملفات](docs/change-colors.md)
- [استبعاد عوامل التصفية ومتطلبات API](docs/filter-exclusions.md)
- [القياس والخصوصية](docs/telemetry.md)
- [التحقق من القياس](docs/verify-telemetry.md)

## الترخيص

هذا المشروع مرخص بموجب [رخصة GNU العمومية الإصدار 3](LICENSE) - برنامج حر ومفتوح المصدر.

</div>
