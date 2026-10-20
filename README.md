<div dir="rtl">
<div align="center">
<img src="assets/icons/logo_readme.svg" width="200" alt="Hadith Searcher">

# Hadith Searcher

[English](README.en.md) | العربية

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
| <img src="store/screenshots/ar/phone/01-search.png" width="250" alt="البحث في الأحاديث"> | <img src="store/screenshots/ar/phone/02-filters.png" width="250" alt="البحث المتقدم"> |

| أصول الحديث | المحفوظات |
|:---:|:---:|
| <img src="store/screenshots/ar/phone/03-origins.png" width="250" alt="أصول الحديث"> | <img src="store/screenshots/ar/phone/04-saved.png" width="250" alt="المحفوظات"> |

| تخصيص المظهر | معلومات المحدث والكتاب |
|:---:|:---:|
| <img src="store/screenshots/ar/phone/05-appearance.png" width="250" alt="تخصيص مظهر التطبيق"> | <img src="store/screenshots/ar/phone/06-sources.png" width="250" alt="معلومات المحدث والكتاب"> |

</div>

[تصاميم صور المتجر وطريقة تحديثها](store/screenshots/README.md)

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

تفعّل نسخة Play تقارير الأعطال وتحليلات الاستخدام تلقائياً. تطبّق نسخة FOSS اختيارات شاشة البدء بعد المتابعة، ويمكن إلغاء أي خيار. تفاصيل القياس والخصوصية واختبار وصول الأحداث: [Telemetry](docs/telemetry.md).

### 3. تثبيت الاعتماديات

```bash
flutter doctor
flutter pub get
```

### 4. تشغيل التطبيق

```bash
flutter run --flavor foss
# لتشغيل نسخة Google Play:
flutter run --flavor play
```

### 5. بناء التطبيق

لبناء نسختَي Android، جهّز متطلبات التوقيع وShorebird الموضحة أدناه، ثم شغّل:

```bash
./scripts/release.py all
```

## بناء Android والتوزيع

يوجد نوعان من البناء: `play` و`foss`. توزّع GitHub وF-Droid ملفات FOSS نفسها، ويتيح مربع التحديث اختيار المصدر مع عرض الإصدار المتاح لدى كل منهما. تختار تنزيلات GitHub المعمارية المناسبة للجهاز. لا تحتوي نسخة FOSS على Shorebird أو مكتبة تحديث Google Play، وتتطلب موافقة مستقلة للقياس الاختياري.

غيّر `version` في `pubspec.yaml` لكل إصدار. يجب أن يقبل رقم البناء القسمة على 10، مثل `3.0.3+220` ثم `3.0.4+230`. تستخدم Play الرقم الأساسي، وتضيف FOSS الرقم 1 لمعمارية `arm64-v8a`، و2 لمعمارية `armeabi-v7a`، و3 لمعمارية `x86_64`. لذلك تكون أرقام ملفات FOSS في المثال الأول 221 و222 و223. يتجاهل فحص التحديث خانة المعمارية عند مقارنة الإصدارات.

يتطلب السكربت Python 3 وFlutter، وShorebird لنسخة Play مع تسجيل الدخول عبر `shorebird login`. جهّز `android/key.properties` ومفتاح التوقيع المحلي، ولا تضمّن بيانات التوقيع الخاصة في المصدر. تتطلب FOSS أيضاً ملف `android/local.properties` مع `sdk.dir` وأداتي `apksigner` و`zipalign` من Android SDK Build Tools بإصدار 35 أو أحدث.

| الأمر | الناتج |
| --- | --- |
| `./scripts/release.py play` | ملف AAB لنسخة Google Play وتسجيل الإصدار في Shorebird |
| `./scripts/release.py foss` | ثلاثة ملفات APK موقعة حسب المعمارية لتوزيعها على GitHub وF-Droid |
| `./scripts/release.py all` | بناء FOSS وGoogle Play بالتتابع |
| `./scripts/release.py play --dry-run` | بناء ملف Play دون تسجيل الإصدار على الخادم |
| `./scripts/release.py patch-play` | إرسال تحديث Dart لإصدار Play المحدد في `pubspec.yaml` |

يحفظ السكربت الملفات في `build/releases/play/` و`build/releases/foss/` ولا يرفعها تلقائياً. مثال لاسم ملف FOSS: `HadithSearcher-3.0.3+221-foss-arm64-v8a.apk`. ارفع الملفات الثلاثة إلى إصدار GitHub ذي الوسم `3.0.3`. تستخدم F-Droid الملفات نفسها للتحقق من إعادة البناء ثم تنشرها بتوقيع المطوّر.

للبناء غير الموقّع شغّل `python3 scripts/build_foss_unsigned.py`. يمكن بناء معمارية واحدة بإضافة `--abi arm64-v8a`. الناتج هو `build/app/outputs/flutter-apk/app-<abi>-foss-release.apk`. يستخدم البناء المسار الثابت `/var/tmp/hadithsearcher-foss` ثم يحذفه لضمان تطابق مسارات Dart المضمّنة. وفّر عدة غيغابايت وشغّل بناء FOSS واحداً في كل مرة.

يجلب F-Droid نسخة Flutter المحددة في الوصفة دون وحدة فرعية في مستودع التطبيق. يستخدم البناء المحلي `flutter` من PATH، ويمكن اختيار SDK آخر عبر `FLUTTER_BIN=/path/to/flutter`. راجع [خطوات التحقق من إعادة البناء](README.en.md#build-android-releases) لكل معمارية.

يتطلب الانتقال بين Play وFOSS شهادة توقيع واحدة و`versionCode` مساوياً أو أعلى من النسخة المثبّتة. يجب أن يطابق مفتاح توقيع التطبيق في Play المفتاح المحلي. داخل الإصدار نفسه يكون رقم FOSS أعلى من رقم Play الأساسي، لذا تتطلب العودة إلى Play إصداراً أحدث. ملفات GitHub وF-Droid متطابقة لكل معمارية.

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
  -d emulator-5554 --flavor foss \
  --dart-define=HADITH_API_BASE_URL=http://127.0.0.1:8717 \
  --dart-define=API_SCREENSHOTS=true
```

يستخدم اختبار الواجهات خادم بيانات محلياً ويمسح إعدادات التطبيق داخل المحاكي عند البدء.

## أدلة التطوير

- [ترجمة الواجهة وإضافة النصوص](lib/l10n/README.md)
- [تعديل الألوان وتوليد الملفات](docs/change-colors.md)
- [القياس والخصوصية](docs/telemetry.md)

## الترخيص

هذا المشروع مرخص بموجب [رخصة GNU العمومية الإصدار 3](LICENSE) - برنامج حر ومفتوح المصدر.

</div>
