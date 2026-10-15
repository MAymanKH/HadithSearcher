import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:path/path.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite/sqflite.dart';
import 'package:hadithsearcher/app.dart';
import 'package:hadithsearcher/core/constants/app_config.dart';
import 'package:hadithsearcher/models/settings.dart';
import 'package:hadithsearcher/services/telemetry/telemetry_service.dart';
import 'package:hadithsearcher/viewmodels/settings_viewmodel.dart';
import 'package:hadithsearcher/widgets/hadith_card.dart';
import '../test/telemetry/fake_backend.dart';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('approved card layout and authentic alternative navigation', (
    tester,
  ) async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.clear();
    final telemetry = TelemetryService(
      preferences: preferences,
      backend: FakeBackend(),
    );
    await telemetry.save(diagnostics: false, analytics: false);
    addTearDown(telemetry.dispose);
    var alternateRequests = 0;
    expect(
      hadithApiBaseUrl,
      'http://127.0.0.1:8716',
      reason:
          'Run with --dart-define=HADITH_API_BASE_URL=http://127.0.0.1:8716',
    );
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 8716);
    addTearDown(() => server.close(force: true));
    server.listen((request) async {
      Object response;
      if (request.uri.path.startsWith('/v1/data/')) {
        response = [];
      } else if (request.uri.path.endsWith('/alternate/card')) {
        alternateRequests++;
        response = {
          'data': {
            'hadithId': 'alternative',
            'hadith': 'Alternative returned by the source',
            'grade': 'Exact source grading',
          },
        };
      } else {
        response = {
          'metadata': {'hasNextPage': false},
          'data': [
            {
              'hadithId': 'card',
              'hadith':
                  'إنَّما الأعمالُ بالنِّيَّاتِ، وإنَّما لكُلِّ امرِئٍ ما نَوى، فمَن كانَت هِجرَتُه إلى دُنيا يُصيبُها، أو إلى امرَأةٍ يَنكِحُها، فهِجرَتُه إلى ما هاجَرَ إليه.',
              'rawi': 'عمر بن الخطاب',
              'mohdith': 'البخاري',
              'book': 'صحيح البخاري',
              'numberOrPage': '1',
              'grade': '[صحيح]',
              'hasAlternateHadithSahih': true,
            },
          ],
        };
      }
      request.response.headers.contentType = ContentType.json;
      request.response.write(jsonEncode(response));
      await request.response.close();
    });
    await tester.pumpWidget(
      HadithSearcherApp(
        initialThemeMode: ThemeMode.light,
        telemetry: telemetry,
      ),
    );
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'إنما الأعمال بالنيات');
    await tester.tap(find.widgetWithText(ElevatedButton, 'بحث'));
    await tester.pumpAndSettle();
    expect(find.byType(HadithCard), findsOneWidget);
    final settings = tester
        .element(find.byType(HadithCard))
        .read<SettingsViewModel>();
    for (final mode in [ThemePreference.light, ThemePreference.dark]) {
      await settings.setTheme(mode);
      await tester.pumpAndSettle();
      final body = find.byType(SelectableText).first;
      final grading = find.byWidgetPredicate(
        (widget) =>
            widget is SelectableText && widget.data == 'حكم البخاري: [صحيح]',
      );
      final alternate = find.widgetWithText(ElevatedButton, 'البديل الصحيح');
      final attribution = find.byWidgetPredicate(
        (widget) =>
            widget is SelectableText &&
            widget.data ==
                'الراوي: عمر بن الخطاب\nالمصدر: صحيح البخاري، الصفحة أو الرقم: 1',
      );
      expect(tester.widget<SelectableText>(body).style!.fontSize, 20);
      expect(tester.widget<SelectableText>(grading).style!.fontSize, 20);
      expect(tester.widget<SelectableText>(attribution).style!.fontSize, 20);
      expect(
        tester.getRect(alternate).top,
        greaterThan(tester.getRect(grading).bottom),
      );
      expect(
        tester.getRect(alternate).bottom,
        lessThan(tester.getRect(attribution).top),
      );
      expect(tester.takeException(), isNull);
      if (const bool.fromEnvironment('CARD_SCREENSHOTS')) {
        if (mode == ThemePreference.light) {
          await binding.convertFlutterSurfaceToImage();
          await tester.pumpAndSettle();
        }
        final bytes = await binding.takeScreenshot('hadith-card-${mode.name}');
        final cache = join(
          Directory(await getDatabasesPath()).parent.path,
          'cache',
        );
        await File(
          join(cache, 'hadith-card-${mode.name}.png'),
        ).writeAsBytes(bytes);
      }
    }
    await tester.tap(find.widgetWithText(ElevatedButton, 'البديل الصحيح'));
    await tester.pumpAndSettle();
    expect(find.widgetWithText(AppBar, 'البديل الصحيح'), findsOneWidget);
    await tester.runAsync(() async {
      for (var attempt = 0; attempt < 30 && alternateRequests == 0; attempt++) {
        await Future<void>.delayed(const Duration(milliseconds: 100));
      }
    });
    await tester.pumpAndSettle();
    expect(alternateRequests, 1);
    expect(find.text('Alternative returned by the source'), findsOneWidget);
    expect(find.widgetWithText(TextButton, 'مشابهة'), findsNothing);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });
}
