import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:hadithsearcher/app.dart';
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

  testWidgets('advanced controls fit a narrow phone', (tester) async {
    await mount(tester);
    await tester.tap(find.byTooltip('البحث المتقدم'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.byType(DropdownButtonFormField<String>), findsNWidgets(5));
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('the search field remains editable during a request', (
    tester,
  ) async {
    final response = Completer<http.Response>();
    await http.runWithClient(() async {
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
    }, () => MockClient((_) => response.future));
  });
}
