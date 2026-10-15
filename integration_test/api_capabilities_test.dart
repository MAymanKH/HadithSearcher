import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite/sqflite.dart';
import 'package:hadithsearcher/app.dart';
import 'package:hadithsearcher/core/constants/app_config.dart';
import 'package:hadithsearcher/models/settings.dart';
import 'package:hadithsearcher/services/telemetry/telemetry_service.dart';
import 'package:hadithsearcher/viewmodels/settings_viewmodel.dart';
import 'package:hadithsearcher/widgets/selection_sheet.dart';
import 'package:hadithsearcher/widgets/hadith_card.dart';
import '../test/telemetry/fake_backend.dart';

const _hadith = {
  'hadithId': 'intentions',
  'hadith':
      'إنما الأعمال بالنيات، وإنما لكل امرئ ما نوى، فمن كانت هجرته إلى الله ورسوله فهجرته إلى الله ورسوله.',
  'rawi': 'عمر بن الخطاب',
  'mohdith': 'البخاري',
  'mohdithId': '256',
  'book': 'صحيح البخاري',
  'bookId': '6216',
  'numberOrPage': '1',
  'grade': '[صحيح]',
  'explainGrade': 'حكم المحدث على الحديث بالصحة.',
  'takhrij': 'أخرجه البخاري (1)، ومسلم (1907).',
  'categories': [
    {'id': 'intention', 'name': 'رقائق وزهد - النية'},
    {'id': 'worship', 'name': 'نية - النية في العبادات'},
  ],
  'hasUsulHadith': true,
};

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('specialist filters and hadith source details work together', (
    tester,
  ) async {
    expect(
      hadithApiBaseUrl,
      'http://127.0.0.1:8717',
      reason: 'Use --dart-define=HADITH_API_BASE_URL=http://127.0.0.1:8717',
    );
    final preferences = await SharedPreferences.getInstance();
    await preferences.clear();
    final telemetry = TelemetryService(
      preferences: preferences,
      backend: FakeBackend(),
    );
    await telemetry.save(diagnostics: false, analytics: false);
    addTearDown(telemetry.dispose);
    final searches = <Uri>[];
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 8717);
    addTearDown(() => server.close(force: true));
    server.listen((request) async {
      final path = request.uri.path;
      Object result;
      if (path == '/v1/data/book') {
        result = {
          'data': [
            {'key': '6216', 'value': 'صحيح البخاري'},
            {'key': '3088', 'value': 'صحيح مسلم'},
            {'key': '96', 'value': 'الصحيح المسند'},
          ],
        };
      } else if (path == '/v1/data/mohdith') {
        result = {
          'data': [
            {'key': '256', 'value': 'البخاري'},
            {'key': '261', 'value': 'مسلم'},
          ],
        };
      } else if (path == '/v1/site/hadith/search') {
        searches.add(request.uri);
        result = {
          'metadata': {'hasNextPage': false},
          'data': [_hadith],
        };
      } else if (path == '/v1/site/book/6216') {
        result = {
          'data': {
            'name': 'صحيح البخاري',
            'author': 'محمد بن إسماعيل البخاري',
            'publisher': 'دار طوق النجاة',
            'edition': 'الأولى',
            'editionYear': '1422',
          },
        };
      } else if (path == '/v1/site/mohdith/256') {
        result = {
          'data': {
            'name': 'البخاري',
            'info': 'محمد بن إسماعيل البخاري، صاحب الجامع الصحيح.',
          },
        };
      } else if (path == '/v1/site/hadith/usul/intentions') {
        result = {
          'data': {
            'usulHadith': {
              'sources': [
                {
                  'source': 'صحيح البخاري (1)',
                  'chain':
                      'الحميدي، عن سفيان، عن يحيى بن سعيد، عن محمد بن إبراهيم، عن علقمة بن وقاص، عن عمر بن الخطاب.',
                  'hadithText': 'إنما الأعمال بالنيات، وإنما لكل امرئ ما نوى.',
                },
              ],
            },
          },
        };
      } else {
        request.response.statusCode = 404;
        result = {};
      }
      request.response.headers.contentType = ContentType.json;
      request.response.write(jsonEncode(result));
      await request.response.close();
    });

    Future<void> waitFor(Finder finder) async {
      for (var i = 0; i < 60; i++) {
        await tester.pump(const Duration(milliseconds: 100));
        if (finder.evaluate().isNotEmpty) {
          await tester.pumpAndSettle();
          return;
        }
      }
      expect(finder, findsWidgets);
    }

    var converted = false;
    Future<void> capture(String name) async {
      if (!const bool.fromEnvironment('API_SCREENSHOTS')) return;
      await tester.pump(const Duration(milliseconds: 300));
      await Future<void>.delayed(const Duration(milliseconds: 300));
      if (!converted) {
        await binding.convertFlutterSurfaceToImage();
        converted = true;
        await tester.pumpAndSettle();
      }
      final bytes = await binding.takeScreenshot('api-$name');
      final cache = Directory(await getDatabasesPath()).parent.path;
      await File('$cache/cache/api-$name.png').writeAsBytes(bytes);
    }

    await tester.pumpWidget(
      HadithSearcherApp(
        initialThemeMode: ThemeMode.light,
        telemetry: telemetry,
      ),
    );
    await tester.pumpAndSettle();
    final settings = tester
        .element(find.byType(TextField))
        .read<SettingsViewModel>();
    await settings.setTheme(ThemePreference.light);
    await tester.enterText(find.byType(TextField), 'إنما الأعمال بالنيات');
    await tester.tap(find.byTooltip('البحث المتقدم'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('جميع الدرجات'));
    await tester.tap(find.text('جميع الدرجات'));
    await tester.pumpAndSettle();
    expect(
      find.descendant(
        of: find.byType(SelectionSheet),
        matching: find.byType(TextField),
      ),
      findsNothing,
    );
    expect(
      find.descendant(
        of: find.byType(SelectionSheet),
        matching: find.byType(Checkbox),
      ),
      findsNWidgets(5),
    );
    expect(tester.getSize(find.byType(SelectionSheet)).height, lessThan(500));
    final allGrades = find.descendant(
      of: find.byType(SelectionSheet),
      matching: find.text('جميع الدرجات'),
    );
    await tester.tap(allGrades);
    await tester.pumpAndSettle();
    expect(find.text('المحدد: 4'), findsOneWidget);
    await tester.tap(allGrades);
    await tester.pumpAndSettle();
    await capture('grades');
    tester.state<NavigatorState>(find.byType(Navigator)).pop();
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('جميع الكتب'));
    await tester.tap(find.text('جميع الكتب'));
    await waitFor(find.text('صحيح مسلم'));
    await tester.tap(find.text('صحيح البخاري'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('صحيح مسلم'));
    await tester.pumpAndSettle();
    expect(find.text('المحدد: 2'), findsOneWidget);
    expect(find.textContaining('تطبيق'), findsNothing);
    await capture('picker');
    await tester.tap(find.byTooltip('معلومات عن صحيح البخاري'));
    await waitFor(find.textContaining('المؤلف: محمد بن إسماعيل البخاري'));
    await capture('book');
    await tester.tap(find.text('إغلاق'));
    await tester.pumpAndSettle();
    expect(find.text('المحدد: 2'), findsOneWidget);
    tester.state<NavigatorState>(find.byType(Navigator)).pop();
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('جميع المحدثين'));
    await tester.tap(find.text('جميع المحدثين'));
    await waitFor(find.text('البخاري'));
    await tester.tap(find.byTooltip('معلومات عن البخاري'));
    await waitFor(
      find.textContaining('محمد بن إسماعيل البخاري، صاحب الجامع الصحيح.'),
    );
    await tester.tap(find.text('إغلاق'));
    await tester.pumpAndSettle();
    expect(find.text('المحدد: 0'), findsOneWidget);
    tester.state<NavigatorState>(find.byType(Navigator)).pop();
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('البحث للمتخصصين'));
    await tester.tap(find.text('البحث للمتخصصين'));
    await tester.pumpAndSettle();
    await capture('advanced');
    await tester.tap(find.widgetWithText(ElevatedButton, 'بحث'));
    await waitFor(find.byType(HadithCard));
    expect(searches.single.queryParametersAll['s[]'], ['3088', '6216']);
    expect(searches.single.queryParameters['specialist'], 'true');
    expect(preferences.getBool('searchSpecialist'), isTrue);
    expect(find.byTooltip('تفاصيل الحديث'), findsNothing);
    await capture('card');
    await tester.ensureVisible(find.text('معلومات إضافية'));
    await tester.tap(find.text('معلومات إضافية'));
    await tester.pumpAndSettle();
    expect(find.widgetWithText(AppBar, 'البحث'), findsOneWidget);
    await tester.ensureVisible(find.text('أصول الحديث وطرق إخراجه'));
    await capture('inline-light');
    await tester.tap(find.text('أصول الحديث وطرق إخراجه'));
    await waitFor(find.textContaining('الإسناد: الحميدي'));
    await capture('origins');
    await tester.tap(find.text('إغلاق'));
    await tester.pumpAndSettle();
    await settings.setTheme(ThemePreference.dark);
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('أصول الحديث وطرق إخراجه'));
    await tester.pumpAndSettle();
    expect(find.text('أصول الحديث وطرق إخراجه').hitTestable(), findsOneWidget);
    await capture('inline-dark');
    await Scrollable.ensureVisible(
      tester.element(find.text('إخفاء المعلومات الإضافية')),
      alignment: .5,
    );
    await tester.pumpAndSettle();
    expect(find.text('إخفاء المعلومات الإضافية').hitTestable(), findsOneWidget);
    await tester.tap(find.text('إخفاء المعلومات الإضافية'));
    await tester.pumpAndSettle();
    expect(find.text('التصنيف الموضوعي'), findsNothing);
    await tester.tap(find.byTooltip('إخفاء الفلاتر النشطة'));
    await tester.pumpAndSettle();
    expect(preferences.getBool('showActiveFilters'), isFalse);
    await tester.pumpWidget(const SizedBox());
    await tester.pumpWidget(
      HadithSearcherApp(initialThemeMode: ThemeMode.dark, telemetry: telemetry),
    );
    await tester.pumpAndSettle();
    expect(find.byTooltip('إظهار الفلاتر النشطة'), findsOneWidget);
    expect(find.byKey(const ValueKey('active-filters-row')), findsNothing);
    await tester.tap(find.text('الإعدادات').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('حجم الخط'));
    await tester.pumpAndSettle();
    expect(tester.getSize(find.byType(SelectionSheet)).height, lessThan(500));
    await capture('font-size');
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });
}
