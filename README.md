<div dir="rtl">
<div align="center">
<img src="https://i.imgur.com/uwZTeVL.png" width="200">

# **Hadith Searcher**

### تطبيق شامل للبحث في الأحاديث النبوية والتحقق من صحتها

<a href='https://play.google.com/store/apps/details?id=com.moaymandev.hadithsearcher'><img alt='Get it on Google Play' src='https://play.google.com/intl/en_us/badges/static/images/badges/en_badge_web_generic.png' height="80"/></a>

</div>

## حول التطبيق

تطبيق Hadith Searcher هو تطبيق مجاني ومفتوح المصدر للبحث في آلاف الأحاديث النبوية الشريفة. يوفر التطبيق إمكانيات بحث وتصفية متقدمة، مع عرض تفصيلي للمعلومات المتعلقة بسند الحديث ودرجة صحته.

## المميزات

- **البحث السريع والدقيق** - البحث في آلاف الأحاديث بسرعة عالية
- **التحقق من الأحاديث** - عرض الراوي والمصدر والمحدث وحكم المحدث على الحديث
- **شروحات الأحاديث** - الاطلاع على شروحات وتفاسير الأحاديث
- **الأحاديث المشابهة** - البحث عن أحاديث مشابهة للحديث المعروض
- **تصفية متقدمة** - اختيار عدة درجات أو محدثين أو كتب أو رواة في البحث الواحد، مع حفظ عوامل التصفية
- **البحث للمتخصصين** - البحث في الموسوعة الكاملة بما يشمل اختلاف أحكام المحدثين وتفاصيل الأسانيد
- **معلومات إضافية** - إظهار توضيح الحكم والتخريج والتصنيف الموضوعي داخل بطاقة الحديث وإخفاؤها عند الحاجة
- **أصول الحديث** - الاطلاع على مصادر الروايات وأسانيدها ومتونها عند توفرها
- **معلومات المصادر** - فتح معلومات الكتاب وترجمة المحدث من زر المعلومات في قوائم عوامل التصفية
- **المفضلة** - حفظ الأحاديث للوصول السريع إليها بدون اتصال بالإنترنت
- **تخصيص المظهر** - التحكم في حجم ونوع وثقل الخط المستخدم في عرض الأحاديث
- **لوحات الألوان** - عشر لوحات ألوان، تشمل البني الدافئ والأزرق الرمادي والأخضر الهادئ والتباين العالي واللافندر والوردي والأزرق المخضر والكهرماني والرمادي المحايد، مع دعم الوضع الفاتح والداكن واتباع النظام

## صور من التطبيق

<div align="center">

| البحث | البحث المتقدم |
|:---:|:---:|
| <img src="https://i.imgur.com/wo6bGGc.png" width="250"> | <img src="https://i.imgur.com/KFjDb4B.png" width="250"> |

| المفضلة | الإعدادات |
|:---:|:---:|
| <img src="https://i.imgur.com/bS4FQF8.png" width="250"> | <img src="https://i.imgur.com/77MRNM4.png" width="250"> |

</div>

## مصادر البيانات

جميع الأحاديث والمعلومات مأخوذة من موقع [الدرر السنية](https://dorar.net/) باستخدام [Dorar Hadith API](https://github.com/MAymanKH/dorar-hadith-api) للمطور Ahmed ElTabarani.

## عوامل التصفية

درجات الحديث أربعة خيارات محلية بدون حقل بحث. تتوفر قوائم الكتب والمحدثين والرواة من API. تُحمّل كل قائمة عند فتحها فقط، وتُحفظ محلياً لمدة سبعة أيام. عند تعذر التحديث، تبقى القائمة المحفوظة متاحة. يعرض منتقي عوامل التصفية أول 40 خياراً، ثم يضيف المزيد تلقائياً عند التمرير، مع البحث بالاسم في القائمة كاملة وبناء العناصر الظاهرة فقط. لا تُضمّن القوائم الكبيرة في ملفات التطبيق.

تُطبّق الاختيارات فوراً عند تغيير مربعات التحديد، ويظهر عدد الخيارات المحددة أعلى القائمة. يحدد خيار «الجميع» القائمة كاملة أو يلغي تحديدها. تظهر معلومات الكتب والمحدثين من زر منفصل بجانب كل اسم. تُحفظ حالة إظهار صف عوامل التصفية النشطة أو إخفائه عند إعادة تشغيل التطبيق.

يظهر خيار «تذكّر عوامل التصفية» في أعلى القائمة. يتيح خيار «البحث للمتخصصين» البحث في الموسوعة الكاملة. يبقى البحث الميسّر هو الوضع الافتراضي.

## التحقق من البحث وتفاصيل الحديث

تظهر أزرار الشرح والأحاديث المشابهة معطّلة عندما لا يتيحها المصدر. تحفظ المفضلة حالة توفرها ونص الشرح المتاح مع نتائج البحث، وتستخدم النص المحفوظ قبل طلبه من API.

مرجع تنظيم الألوان: [لوحات الألوان](docs/color-schemes.md). لتعديل لوحة أو إضافة أخرى، اتبع [تغيير الألوان](docs/change-colors.md).

لتشغيل اختبارات الوحدة والواجهات:

```bash
flutter test
```

لاختبار البحث وتفاصيل المصادر عبر API الفعلي:

```bash
flutter test test/hadith_details_live_test.dart --dart-define=VERIFY_LIVE_DETAILS=true
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

## المتطلبات

- Flutter SDK
- Android Studio أو VS Code
- محاكي Android أو جهاز حقيقي للتجربة

## التثبيت والتشغيل

### 1. استنساخ المشروع

```bash
git clone https://github.com/MAymanKH/HadithSearcher.git
cd HadithSearcher
```

### 2. إعداد الخدمات

رابط API الافتراضي موجود في `lib/core/constants/app_config.dart`، ومفاتيح إرسال Sentry وPostHog العامة موجودة في `lib/core/constants/telemetry_config.dart`. لا يحتاج البناء إلى ملف `.env`. لا تضع رموز إدارة الحسابات أو مفاتيح التوقيع الخاصة في ملفات المصدر.

تفاصيل القياس والخصوصية: [Telemetry](docs/telemetry.md). خطوات الاختبار المحلي والتحقق من وصول الأحداث: [Verify telemetry](docs/verify-telemetry.md).

### 3. تثبيت الاعتماديات

```bash
flutter pub get
```

### 4. تشغيل التطبيق

```bash
flutter run --flavor fdroid
# لتشغيل نسخة Google Play:
flutter run --flavor play
```

### 5. بناء التطبيق

**لبناء نسخ Android الثلاث:**
```bash
./scripts/release.py all
```

**لنظام iOS:**
```bash
flutter build ios --release
```

## بناء Android والتوزيع

غيّر `version` في `pubspec.yaml` مرة واحدة لكل إصدار جديد، ثم شغّل `./scripts/release.py all`. تعرض صفحة حول التطبيق رقم الإصدار الفعلي. يتطلب السكربت Python 3، وFlutter، وShorebird عند بناء نسخة Play، مع تسجيل الدخول مسبقاً عبر `shorebird login`.

| الأمر | الناتج |
| --- | --- |
| `./scripts/release.py play` | ملف AAB لنسخة Google Play، وتسجيل الإصدار في Shorebird |
| `./scripts/release.py fdroid` | ملف APK غير موقّع لنسخة F-Droid |
| `./scripts/release.py github` | بناء ملف APK لنسخة GitHub وتوقيعه للتثبيت المباشر |
| `./scripts/release.py all` | بناء نسخ F-Droid وGitHub وGoogle Play بالتتابع |
| `./scripts/release.py play --dry-run` | بناء ملف Play دون تسجيل إصدار على الخادم |
| `./scripts/release.py patch-play` | إرسال تحديث Dart لإصدار Play المحدد حالياً في `pubspec.yaml` |

يحفظ السكربت ملفات الإصدارات في `build/releases/play/` و`build/releases/fdroid/` و`build/releases/github/` بأسماء تتضمن رقم الإصدار. لا يرفع الملفات إلى Google Play أو F-Droid أو GitHub. لبناء نسختي Play وGitHub، جهّز ملف `android/key.properties` ومفتاح التوقيع المحلي. لا تُضمّن بيانات التوقيع الخاصة في المصدر.

نسخة F-Droid متوافقة مع سياسات F-Droid. للبناء المباشر استخدم `flutter build apk --release --flavor fdroid`، والناتج هو `build/app/outputs/flutter-apk/app-fdroid-release.apk`.

ملف F-Droid غير موقّع، ولا يمكن تثبيته مباشرة على الهاتف. لإنشاء نسخة GitHub للتثبيت المباشر، جهّز `android/key.properties` ومفتاح التوقيع المحلي، ثم شغّل `./scripts/release.py github`. يبني الأمر ملف APK من المصدر باستخدام إعدادات F-Droid ثم يوقّعه، دون الحاجة إلى بناء نسخة F-Droid مسبقاً. يحفظ الناتج باسم `HadithSearcher-<version>-github.apk` في `build/releases/github/` ويتحقق من توقيعه. تظل نسخة F-Droid غير موقّعة لكي يوقّعها F-Droid عند النشر. تتطلب تحديثات التطبيق استخدام مفتاح التوقيع نفسه؛ قد تختلف مفاتيح نسخ Google Play وF-Droid المنشورة عن المفتاح المحلي.

للتحقق من المشروع:

```bash
flutter analyze
flutter test test
# تحقق اختياري من القوائم وعامل تصفية الراوي عبر API الفعلي:
flutter test --dart-define=VERIFY_LIVE_FILTERS=true test/filter_catalog_live_test.dart
```

## التحقق من تحديثات التطبيق

يتحقق التطبيق من التحديثات عند فتحه أو العودة إليه، بحد أقصى محاولة تلقائية واحدة يومياً. يظهر تنبيه يمكن تأجيله، ويمكن التحقق يدوياً في أي وقت من صفحة «حول». لا يمنع فشل الاتصال استخدام التطبيق.

- تستخدم نسخة Play واجهة Google Play للتحقق من توفر تحديث لهذا الجهاز والحساب، وتفتح صفحة التطبيق في المتجر عند اختيار التحديث. مكتبة Google الخاصة بالتحديثات موجودة في نسخة Play فقط.
- تستخدم نسخة F-Droid الإصدار الموصى به في `https://f-droid.org/api/v1/packages/com.moaymandev.hadithsearcher`، وتفتح صفحة الحزمة في F-Droid. يجب نشر الحزمة في مستودع F-Droid الرسمي لكي يعمل التحقق.
- تستخدم نسخة GitHub آخر إصدار مستقر منشور في GitHub Releases، وتشترط وجود ملف APK مرفوع للتثبيت. ارفع الملف `HadithSearcher-<version>+<build>-github.apk` الناتج من `./scripts/release.py github` مع الإصدار. يُقرأ رقم البناء من اسم الملف، وتظل ملفات الإصدارات القديمة المسماة `app-release.apk` مدعومة عند استخدام وسم مثل `v2.1.2` أو `v2.1.2+14`. يفتح زر التحديث صفحة الإصدار لتنزيل APK وتثبيته.

يضيف سكربت إصدار GitHub الخيار `--dart-define=UPDATE_CHANNEL=github` تلقائياً. عند البناء يدوياً استخدم `flutter build apk --release --flavor fdroid --dart-define=UPDATE_CHANNEL=github` ثم وقّع الملف بالمفتاح نفسه المستخدم للإصدارات السابقة. تبقى نسخة F-Droid الافتراضية موجهة إلى F-Droid.

لتشغيل اختبارات التحديثات وسكربت الإصدار:

```bash
flutter test test/update_service_test.dart test/update_prompt_test.dart
python3 -m unittest discover -s test -p release_update_channel_test.py
# لاختبار واجهات التحديثات وقنوات Android على محاكي:
flutter test integration_test/update_test.dart -d emulator-5554 --flavor fdroid --dart-define=UPDATE_CHANNEL=github
flutter test integration_test/update_test.dart -d emulator-5554 --flavor play
```

## الترخيص

هذا المشروع مرخص بموجب [رخصة GNU العمومية الإصدار 3](LICENSE) - برنامج حر ومفتوح المصدر.

</div>
