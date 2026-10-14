import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:hadithsearcher/models/settings.dart';
import 'package:hadithsearcher/viewmodels/settings_viewmodel.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:hadithsearcher/app.dart';
import 'package:hadithsearcher/views/search/search_view.dart';
import 'package:hadithsearcher/services/telemetry/telemetry_service.dart';
import 'telemetry/fake_backend.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  Future<void> mount(WidgetTester tester, {double width = 320}) async {
    tester.view.physicalSize = Size(width, 850);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final telemetry = TelemetryService(
      preferences: await SharedPreferences.getInstance(),
      backend: FakeBackend(),
    );
    await telemetry.save(diagnostics: false, analytics: false);
    addTearDown(telemetry.dispose);
    await tester.pumpWidget(
      HadithSearcherApp(
        initialThemeMode: ThemeMode.light,
        telemetry: telemetry,
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets(
    'search text survives tab switches but starts blank after reopening',
    (tester) async {
      SharedPreferences.setMockInitialValues({
        'searchQuery': 'old saved query',
      });
      await mount(tester, width: 800);
      expect(
        tester.widget<TextField>(find.byType(TextField)).controller!.text,
        isEmpty,
      );
      await tester.enterText(find.byType(TextField), 'session query');
      await tester.tap(find.text('الإعدادات').last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('البحث').last);
      await tester.pumpAndSettle();
      expect(find.text('session query'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
      await mount(tester, width: 800);
      expect(
        tester.widget<TextField>(find.byType(TextField)).controller!.text,
        isEmpty,
      );
      expect(
        (await SharedPreferences.getInstance()).containsKey('searchQuery'),
        isFalse,
      );
      await tester.pumpWidget(const SizedBox());
    },
  );

  for (final mode in ['light', 'dark']) {
    testWidgets(
      'search scrolling and app bar appearance persist in $mode mode',
      (tester) async {
        await http.runWithClient(
          () async {
            await mount(tester, width: 800);
            await tester
                .element(find.byType(TextField))
                .read<SettingsViewModel>()
                .setTheme(
                  mode == 'dark' ? ThemePreference.dark : ThemePreference.light,
                );
            await tester.pumpAndSettle();
            await tester.enterText(find.byType(TextField), 'first query');
            await tester.tap(find.widgetWithText(ElevatedButton, 'بحث'));
            await tester.pumpAndSettle();
            final list = find.descendant(
              of: find.byType(SearchView),
              matching: find.byType(ListView),
            );
            final firstController = tester.widget<ListView>(list).controller!;
            firstController.jumpTo(1400);
            await tester.pumpAndSettle();
            final savedOffset = firstController.offset;
            final appBarMaterial = find
                .descendant(
                  of: find.byType(AppBar),
                  matching: find.byType(Material),
                )
                .first;
            expect(tester.widget<Material>(appBarMaterial).elevation, 0);
            expect(
              tester.widget<Material>(appBarMaterial).color,
              mode == 'light' ? Colors.white : Colors.black,
            );
            await tester.tap(find.text('الإعدادات').last);
            await tester.pumpAndSettle();
            await tester.tap(find.text('البحث').last);
            await tester.pumpAndSettle();
            expect(
              tester.widget<ListView>(list).controller!.offset,
              closeTo(savedOffset, 1),
            );
            await tester.enterText(find.byType(TextField), 'second query');
            await tester.tap(find.widgetWithText(ElevatedButton, 'بحث'));
            await tester.pumpAndSettle();
            expect(tester.widget<ListView>(list).controller!.offset, 0);
            expect(tester.takeException(), isNull);
            await tester.pumpWidget(const SizedBox());
          },
          () => MockClient(
            (request) async => request.url.path.startsWith('/v1/data/')
                ? http.Response('[]', 200)
                : http.Response(
                    jsonEncode({
                      'metadata': {'hasNextPage': false},
                      'data': List.generate(
                        30,
                        (index) => {
                          'hadithId': 'item$index',
                          'hadith': 'Hadith text for result $index',
                          'rawi': 'narrator',
                          'mohdith': 'scholar',
                          'book': 'source',
                          'numberOrPage': '$index',
                          'grade': 'grading',
                        },
                      ),
                    }),
                    200,
                  ),
          ),
        );
      },
    );
  }

  testWidgets('advanced controls fit a narrow phone', (tester) async {
    await mount(tester);
    await tester.tap(find.byTooltip('البحث المتقدم'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.byType(DropdownButtonFormField<String>), findsNWidgets(3));
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('the search field remains editable during a request', (
    tester,
  ) async {
    final response = Completer<http.Response>();
    await http.runWithClient(
      () async {
        await mount(tester, width: 400);
        await tester.enterText(find.byType(TextField), 'first');
        await tester.tap(find.widgetWithText(ElevatedButton, 'بحث'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));
        expect(find.byType(CircularProgressIndicator), findsOneWidget);
        expect(find.byType(TextField), findsOneWidget);
        await tester.enterText(find.byType(TextField), 'second');
        expect(find.text('second'), findsOneWidget);
        response.complete(
          http.Response(
            '{"metadata":{"length":0,"hasNextPage":false},"data":[]}',
            200,
          ),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
      },
      () => MockClient(
        (request) => request.url.path.startsWith('/v1/data/')
            ? Future.value(http.Response('[]', 200))
            : response.future,
      ),
    );
  });
}
