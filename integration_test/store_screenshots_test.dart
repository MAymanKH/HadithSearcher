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
import 'package:hadithsearcher/models/hadith.dart';
import 'package:hadithsearcher/viewmodels/search_viewmodel.dart';
import 'package:hadithsearcher/services/telemetry/telemetry_service.dart';
import 'package:hadithsearcher/viewmodels/settings_viewmodel.dart';
import 'package:hadithsearcher/services/database_service.dart';
import 'package:hadithsearcher/widgets/hadith_card.dart';
import '../test/telemetry/fake_backend.dart';

import 'fixtures/store_hadiths.dart';
import 'fixtures/store_collections.dart';
import 'fixtures/store_sources.dart';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('capture current Arabic store screens', (tester) async {
    expect(hadithApiBaseUrl, 'http://127.0.0.1:8717');
    final preferences = await SharedPreferences.getInstance();
    await preferences.clear();
    await preferences.setBool('welcomeCompleted', true);
    await deleteDatabase('${await getDatabasesPath()}/hadithsearcher.db');
    final telemetry = TelemetryService(
      preferences: preferences,
      backend: FakeBackend(),
    );
    await telemetry.save(diagnostics: false, analytics: false);
    addTearDown(telemetry.dispose);
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 8717);
    addTearDown(() => server.close(force: true));
    server.listen((request) async {
      final path = request.uri.path;
      Object result;
      if (path == '/v1/data/methodSearch') {
        result = {
          'data': [
            {'key': 'a', 'value': 'أي كلمة'},
          ],
        };
      } else if (path == '/v1/data/zoneSearch') {
        result = {
          'data': [
            {'key': '*', 'value': 'جميع الأحاديث'},
          ],
        };
      } else if (path == '/v1/data/degree') {
        result = {
          'data': [
            {'key': '0', 'value': 'جميع الدرجات'},
            {'key': '1', 'value': 'أحاديث صحيحة'},
            {'key': '2', 'value': 'أحاديث أسانيدها صحيحة'},
            {'key': '3', 'value': 'أحاديث ضعيفة'},
            {'key': '4', 'value': 'أحاديث أسانيدها ضعيفة'},
          ],
        };
      } else if (path == '/v1/data/book') {
        result = {
          'data': [
            {'key': '6216', 'value': 'صحيح البخاري'},
            {'key': '3088', 'value': 'صحيح مسلم'},
            {'key': '96', 'value': 'الصحيح المسند'},
          ],
        };
      } else if (path == '/v1/data/rawi') {
        result = {
          'data': [
            {'key': '1', 'value': 'عمر بن الخطاب'},
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
        result = {
          'metadata': {'hasNextPage': false, 'exclusionsApplied': true},
          'data': storeHadiths,
        };
      } else if (path == '/v1/site/hadith/usul/JIDbtVSz') {
        result = {'data': storeOrigins};
      } else if (path == '/v1/site/book/3664') {
        result = {'data': storeBook};
      } else if (path == '/v1/site/mohdith/1122') {
        result = {'data': storeScholar};
      } else {
        request.response.statusCode = 404;
        result = {};
      }
      request.response.headers.contentType = ContentType.json;
      request.response.write(jsonEncode(result));
      await request.response.close();
    });

    Future<void> capture(String name) async {
      await tester.pumpAndSettle();
      await tester.pump(const Duration(milliseconds: 500));
      await Future<void>.delayed(const Duration(milliseconds: 400));
      await tester.pumpAndSettle();
      await binding.takeScreenshot(name);
      expect(tester.takeException(), isNull);
    }

    await tester.pumpWidget(
      HadithSearcherApp(initialThemeMode: ThemeMode.dark, telemetry: telemetry),
    );
    await tester.pumpAndSettle();
    final settings = tester
        .element(find.byType(TextField))
        .read<SettingsViewModel>();
    await settings.setTheme(ThemePreference.dark);
    await tester.tap(find.byType(TextField));
    await tester.enterText(find.byType(TextField), 'الأعمال بالنيات');
    await tester.tap(find.widgetWithText(ElevatedButton, 'بحث'));
    await tester.pumpAndSettle();
    await tester.runAsync(() async {
      for (
        var i = 0;
        i < 100 && find.byType(HadithCard).evaluate().isEmpty;
        i++
      ) {
        await Future<void>.delayed(const Duration(milliseconds: 100));
      }
    });
    await tester.pumpAndSettle();
    final search = tester
        .element(find.byType(TextField))
        .read<SearchViewModel>();
    expect(
      find.byType(HadithCard),
      findsWidgets,
      reason:
          'Search error: ${search.errorMessage}; query: ${search.searchQuery}',
    );
    expect(search.results, hasLength(storeHadiths.length));
    await binding.convertFlutterSurfaceToImage();
    await tester.pumpAndSettle();
    await capture('01-search');
    await tester.tap(find.widgetWithText(TextButton, 'التصفية'));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(TextField).first);
    await tester.enterText(find.byType(TextField).first, '');
    FocusManager.instance.primaryFocus?.unfocus();
    await tester.pumpAndSettle();
    expect(
      tester.widget<TextField>(find.byType(TextField).first).controller!.text,
      isEmpty,
    );
    await capture('02-filters');
    await tester.tap(find.byType(TextField).first);
    await tester.enterText(find.byType(TextField).first, 'الأعمال بالنيات');
    FocusManager.instance.primaryFocus?.unfocus();
    await tester.tap(find.widgetWithText(TextButton, 'التصفية'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('معلومات إضافية').first);
    await tester.pumpAndSettle();
    final originsButton = find.text('أصول الحديث وطرق إخراجه').first;
    await tester.ensureVisible(originsButton);
    await tester.tap(originsButton);
    for (
      var i = 0;
      i < 100 && find.textContaining('[صحيح البخاري]').evaluate().isEmpty;
      i++
    ) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(find.text('أصول الحديث'), findsOneWidget);
    expect(find.textContaining('[صحيح البخاري]'), findsOneWidget);
    await capture('03-origins');
    tester.state<NavigatorState>(find.byType(Navigator)).pop();
    await tester.pumpAndSettle();
    for (final item in storeSavedHadiths.reversed) {
      final hadith = Hadith.fromJson(item);
      await DatabaseService().addFavourite(
        hadithText: hadith.text,
        hadithInfo: hadith.formattedInfo,
        hadithId: hadith.id,
        hadith: hadith,
      );
    }
    await tester.tap(find.text('المحفوظات').last);
    await capture('04-saved');
    await tester.tap(find.text('الإعدادات').last);
    await settings.setColorScheme(ColorSchemePreference.sepia);
    await capture('05-appearance');
    await settings.setColorScheme(ColorSchemePreference.forest);
    await capture('05-appearance-forest');
    await settings.setColorScheme(ColorSchemePreference.ocean);
    await capture('05-appearance-ocean');
    await settings.setColorScheme(ColorSchemePreference.lavender);
    await capture('05-appearance-lavender');
    await settings.setColorScheme(ColorSchemePreference.rose);
    await capture('05-appearance-rose');
    await settings.setColorScheme(ColorSchemePreference.amber);
    await capture('05-appearance-amber');
    await settings.setColorScheme(ColorSchemePreference.classic);
    await settings.setTheme(ThemePreference.dark);
    await tester.pumpAndSettle();
    await tester.tap(find.text('البحث').last);
    await tester.pumpAndSettle();
    tester.widget<ListView>(find.byType(ListView)).controller!.jumpTo(0);
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('معلومات المحدث والكتاب').first);
    for (
      var i = 0;
      i < 100 && find.textContaining('المكتب الإسلامي').evaluate().isEmpty;
      i++
    ) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(find.text('معلومات المحدث والكتاب'), findsOneWidget);
    expect(find.textContaining('المكتب الإسلامي'), findsOneWidget);
    expect(find.text(storeScholar['info'] as String), findsOneWidget);
    await capture('06-sources');
    await tester.pumpWidget(const SizedBox());
  });
}
