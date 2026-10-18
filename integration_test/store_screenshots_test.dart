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

const _hadith = {
  'hadithId': 'intentions',
  'hadith':
      'إنَّما الأعمالُ بالنِّيَّاتِ، وإنَّما لكُلِّ امرِئٍ ما نَوى، فمَن كانَت هِجرَتُه إلى دُنيا يُصيبُها، أو إلى امرَأةٍ يَنكِحُها، فهِجرَتُه إلى ما هاجَرَ إليه.',
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

    Future<void> capture(String name) async {
      await tester.pumpAndSettle();
      await tester.pump(const Duration(milliseconds: 500));
      await binding.takeScreenshot(name);
      expect(tester.takeException(), isNull);
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
    await tester.tap(find.byType(TextField));
    await tester.enterText(find.byType(TextField), 'إنما الأعمال بالنيات');
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
      findsOneWidget,
      reason:
          'Search error: ${search.errorMessage}; query: ${search.searchQuery}',
    );
    await binding.convertFlutterSurfaceToImage();
    await tester.pumpAndSettle();
    await capture('01-search');
    await tester.tap(find.widgetWithText(TextButton, 'التصفية'));
    await capture('02-filters');
    await tester.tap(find.widgetWithText(TextButton, 'التصفية'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('معلومات إضافية'));
    await tester.tap(find.text('معلومات إضافية'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('أصول الحديث وطرق إخراجه'));
    await capture('03-details');
    await DatabaseService().addFavourite(
      hadithText: _hadith['hadith'] as String,
      hadithInfo: Hadith.fromJson(_hadith).formattedInfo,
      hadithId: 'intentions',
      hadith: Hadith.fromJson(_hadith),
    );
    await tester.tap(find.text('المحفوظات').last);
    await capture('04-saved');
    await tester.tap(find.text('الإعدادات').last);
    await capture('05-appearance');
    await settings.setTheme(ThemePreference.dark);
    await tester.pumpAndSettle();
    await tester.tap(find.text('البحث').last);
    await tester.pumpAndSettle();
    await capture('06-dark');
    await tester.pumpWidget(const SizedBox());
  });
}
