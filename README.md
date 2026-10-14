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
- **تصفية متقدمة** - تصفية نتائج البحث حسب درجة الصحة والمحدث والكتاب وخيارات أخرى
- **المفضلة** - حفظ الأحاديث للوصول السريع إليها بدون اتصال بالإنترنت
- **تخصيص المظهر** - التحكم في حجم ونوع وثقل الخط المستخدم في عرض الأحاديث
- **الوضع الليلي** - دعم الوضع الفاتح والداكن

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

جميع الأحاديث والمعلومات مأخوذة من موقع [الدرر السنية](https://dorar.net/) باستخدام [Dorar Hadith API](https://github.com/AhmedElTabarani/dorar-hadith-api) للمطور Ahmed ElTabarani.

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

رابط API الافتراضي موجود في `lib/core/constants/app_config.dart`، ومفاتيح إرسال Sentry وPostHog العامة موجودة في `lib/core/constants/telemetry_config.dart`. لا يحتاج البناء إلى ملف `.env`. تستخدم نسخة Google Play خدمة Shorebird، وتستخدم نسخة F-Droid مكتبة Flutter القياسية. لا تضع رموز إدارة الحسابات أو مفاتيح التوقيع الخاصة في ملفات المصدر.

في نسخة F-Droid تتوقف تقارير الأعطال وإحصاءات الاستخدام افتراضياً، ويسأل التطبيق عند أول تشغيل، ويمكن تغيير كل اختيار من الإعدادات. في نسخة Google Play تعمل الخدمتان تلقائياً ولا تظهر شاشة الموافقة أو خيارات إيقاف القياس. تشمل الإحصاءات كلمات البحث والمرشحات ومعرّفات الأحاديث المتفاعل معها. يستخدم المتجران رابط سياسة الخصوصية نفسه.

استخدم Flutter **3.47.2** لنسخة F-Droid. يحدد سكربت الإصدار Flutter **3.47.7** لنسخة Shorebird. يعتمد بناء Android على Gradle 8.14.3 وAndroid Gradle Plugin 8.11.1 وKotlin 2.2.20، مع الاعتماديات المحددة في `pubspec.lock`.

### 3. تثبيت الاعتماديات

```bash
flutter pub get
```

### 4. تشغيل التطبيق

```bash
flutter run --flavor fdroid
# لتجربة واجهة نسخة Google Play:
flutter run --flavor play
```

### 5. بناء التطبيق

**لبناء نسختي Android:**
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
| `./scripts/release.py play` | ملف AAB موقع مع Shorebird، وتسجيل الإصدار في حساب Shorebird الحالي |
| `./scripts/release.py fdroid` | ملف APK غير موقع، دون Shorebird، مع شاشة الموافقة وإعدادات القياس |
| `./scripts/release.py all` | بناء نسختي المتجرين بالتتابع |
| `./scripts/release.py play --dry-run` | بناء ملف Play دون تسجيل إصدار على الخادم |
| `./scripts/release.py patch-play` | إرسال تحديث Dart لإصدار Play المحدد حالياً في `pubspec.yaml` |

يحفظ السكربت ملفات المتجرين في `build/releases/play/` و`build/releases/fdroid/` بأسماء تتضمن رقم الإصدار. لا يرفع الملفات إلى Google Play أو F-Droid. يتطلب Play ملف `android/key.properties` ومفتاح التوقيع المحلي، بينما تبقى نسخة F-Droid غير موقعة حتى عند وجودهما. لا تُضمّن بيانات التوقيع الخاصة في المصدر.

يبني السكربت نسخة Play في مجلد مؤقت لتوافق فحص أصول Shorebird مع أصل خاص بالنكهة. لا يغير ملف `pubspec.yaml` الأصلي، ولا ينشئ تطبيق Shorebird لنسخة F-Droid. يتحقق من نوع محرك Flutter ووجود إعداد Shorebird أو غيابه داخل الناتج قبل حفظه.

للبناء المباشر في F-Droid استخدم `flutter build apk --release --flavor fdroid`، والناتج هو `build/app/outputs/flutter-apk/app-fdroid-release.apk`. النكهة الافتراضية هي `fdroid` إذا لم تحدد نكهة. يستخدم المتجران معرّف Android نفسه، لكن مفتاح توقيع F-Droid قد يختلف عن مفتاح Play.

المكتبتان Sentry وPostHog مرخصتان بـ MIT. في F-Droid تتوقف المكتبتان قبل الموافقة، ولا تُضمّن إعدادات Shorebird أو محركه. لا تستخدم أي نسخة تسجيل الشاشة. أهلية المستودع الرسمي تخضع أيضاً لفحص F-Droid للبناء والتراخيص والخدمات والأصول.

للتحقق من اختيار المستخدم والبيانات المرسلة:

```bash
flutter analyze
flutter test test
flutter test integration_test/telemetry_test.dart --flavor fdroid -d emulator-5554
flutter test integration_test/distribution_test.dart --flavor fdroid -d emulator-5554
flutter test integration_test/distribution_test.dart --flavor play -d emulator-5554
./scripts/release.py all --dry-run
```

اختبار `integration_test/cloud_telemetry_test.dart` متوقف افتراضياً. تشغيله مع `--dart-define=VERIFY_TELEMETRY_CLOUD=true` يرسل حدثاً اصطناعياً إلى الحسابين المهيأين في المصدر، تحت بيئة `verification`.

تفاصيل معالجة عرض الحواف وتحذيرات Google Play وخطوات التحقق موجودة في [دليل Android edge-to-edge](docs/android-edge-to-edge.md).

## الترخيص

هذا المشروع مرخص بموجب [رخصة GNU العمومية الإصدار 3](LICENSE) - برنامج حر ومفتوح المصدر.

</div>
