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

رابط API الافتراضي موجود في `lib/core/constants/app_config.dart`، ومفاتيح إرسال Sentry وPostHog العامة موجودة في `lib/core/constants/telemetry_config.dart`. لا يحتاج البناء إلى ملف `.env` أو Shorebird. لا تضع رموز إدارة الحسابات أو مفاتيح التوقيع الخاصة في هذين الملفين.

تقارير الأعطال وإحصاءات الاستخدام متوقفتان افتراضياً. يسأل التطبيق عند أول تشغيل، ويمكن تغيير كل اختيار من الإعدادات. تشمل إحصاءات الاستخدام الاختيارية كلمات البحث والمرشحات ومعرّفات الأحاديث المتفاعل معها. رابط سياسة الخصوصية متاح قبل الموافقة.

استخدم Flutter **3.47.2** لإعادة بناء النسخة التي تم التحقق منها. يعتمد بناء Android على Gradle 8.14.3 وAndroid Gradle Plugin 8.11.1 وKotlin 2.2.20، مع الاعتماديات المحددة في `pubspec.lock`.

### 3. تثبيت الاعتماديات

```bash
flutter pub get
```

### 4. تشغيل التطبيق

```bash
flutter run
```

### 5. بناء التطبيق

**لنظام Android:**
```bash
flutter build apk --release
```

**لنظام iOS:**
```bash
flutter build ios --release
```

## بناء Android والتوزيع

يستخدم Google Play وF-Droid الكود نفسه وإعدادات القياس نفسها. إذا وُجد ملف `android/key.properties` يُستخدم مفتاح التوقيع المحلي. إذا لم يوجد الملف يُنتج Gradle نسخة غير موقعة يستطيع F-Droid توقيعها. لا تُضمّن بيانات التوقيع الخاصة في المصدر.

المكتبتان Sentry وPostHog مرخصتان بـ MIT. يُعطّل التطبيق التهيئة التلقائية وجمع البيانات قبل الموافقة، ولا يستخدم تحديثات تنفيذية أو تسجيل الشاشة. أهلية المستودع الرسمي تخضع أيضاً لفحص F-Droid للبناء والتراخيص والخدمات والأصول.

للتحقق من اختيار المستخدم والبيانات المرسلة:

```bash
flutter analyze
flutter test test
flutter test integration_test/telemetry_test.dart -d emulator-5554
flutter build apk --release
```

اختبار `integration_test/cloud_telemetry_test.dart` متوقف افتراضياً. تشغيله مع `--dart-define=VERIFY_TELEMETRY_CLOUD=true` يرسل حدثاً اصطناعياً إلى الحسابين المهيأين في المصدر، تحت بيئة `verification`.

## الترخيص

هذا المشروع مرخص بموجب [رخصة GNU العمومية الإصدار 3](LICENSE) - برنامج حر ومفتوح المصدر.

</div>
