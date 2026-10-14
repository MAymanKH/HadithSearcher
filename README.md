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

رابط API الافتراضي موجود في `lib/core/constants/app_config.dart`، ومفاتيح إرسال Sentry وPostHog العامة موجودة في `lib/core/constants/telemetry_config.dart`. لا يحتاج البناء إلى ملف `.env`. لا تضع رموز إدارة الحسابات أو مفاتيح التوقيع الخاصة في ملفات المصدر.

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
| `./scripts/release.py play` | ملف AAB لنسخة Google Play، وتسجيل الإصدار في Shorebird |
| `./scripts/release.py fdroid` | ملف APK لنسخة F-Droid |
| `./scripts/release.py all` | بناء نسختي المتجرين بالتتابع |
| `./scripts/release.py play --dry-run` | بناء ملف Play دون تسجيل إصدار على الخادم |
| `./scripts/release.py patch-play` | إرسال تحديث Dart لإصدار Play المحدد حالياً في `pubspec.yaml` |

يحفظ السكربت ملفات المتجرين في `build/releases/play/` و`build/releases/fdroid/` بأسماء تتضمن رقم الإصدار. لا يرفع الملفات إلى Google Play أو F-Droid. لبناء نسخة Play، جهّز ملف `android/key.properties` ومفتاح التوقيع المحلي. لا تُضمّن بيانات التوقيع الخاصة في المصدر.

نسخة F-Droid متوافقة مع سياسات F-Droid. للبناء المباشر استخدم `flutter build apk --release --flavor fdroid`، والناتج هو `build/app/outputs/flutter-apk/app-fdroid-release.apk`.

للتحقق من المشروع:

```bash
flutter analyze
flutter test test
```

## الترخيص

هذا المشروع مرخص بموجب [رخصة GNU العمومية الإصدار 3](LICENSE) - برنامج حر ومفتوح المصدر.

</div>
