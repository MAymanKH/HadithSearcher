import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:hadithsearcher/core/theme/app_theme.dart';
import 'package:hadithsearcher/viewmodels/settings_viewmodel.dart';
import 'package:hadithsearcher/widgets/app_dropdown.dart';
import 'package:hadithsearcher/widgets/message_dialog.dart';
import 'package:hadithsearcher/views/settings/settings_view.dart';
import 'package:hadithsearcher/services/telemetry/telemetry_service.dart';
import 'telemetry/fake_backend.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test(
    'every offered font is bundled, including Arabic reading fonts',
    () async {
      final manifest =
          jsonDecode(await rootBundle.loadString('FontManifest.json')) as List;
      final families = manifest.map((entry) => entry['family']);
      expect(families, containsAll(SettingsViewModel.fontFamilies));
      for (final family in ['Cairo', 'Tajawal', 'Noto Naskh Arabic']) {
        expect(SettingsViewModel.fontFamilies, contains(family));
        final entry = manifest.firstWhere((entry) => entry['family'] == family);
        for (final font in entry['fonts']) {
          expect(
            (await rootBundle.load(font['asset'])).lengthInBytes,
            greaterThan(1000),
          );
        }
      }
    },
  );

  testWidgets('settings fit a narrow RTL phone and privacy follows reset', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 850);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final settings = SettingsViewModel();
    final telemetry = TelemetryService(
      preferences: await SharedPreferences.getInstance(),
      backend: FakeBackend(),
    );
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider.value(value: settings),
          ChangeNotifierProvider.value(value: telemetry),
        ],
        child: MaterialApp(
          theme: AppTheme.lightTheme,
          home: const Directionality(
            textDirection: TextDirection.rtl,
            child: SettingsView(),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final arrows = find.byIcon(Icons.expand_more_rounded);
    expect(arrows, findsNWidgets(7));
    final arrowPositions = tester.getTopLeft(arrows.first).dx;
    for (final arrow in arrows.evaluate()) {
      expect(tester.getTopLeft(find.byWidget(arrow.widget)).dx, arrowPositions);
    }
    await tester.tap(find.text('نوع الخط'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('نوتو نسخ عربي').last);
    await tester.pumpAndSettle();
    expect(settings.fontFamily, 'Noto Naskh Arabic');
    final privacy = find.text('الخصوصية والقياس الاختياري');
    await tester.scrollUntilVisible(
      privacy,
      250,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    expect(
      tester.getTopLeft(privacy).dy,
      greaterThan(
        tester.getTopLeft(find.text('العودة للإعدادات الافتراضية')).dy,
      ),
    );
    expect(tester.takeException(), isNull);
    await tester.tap(privacy);
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('save-telemetry-consent')), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    settings.dispose();
    telemetry.dispose();
  });

  for (final theme in [AppTheme.lightTheme, AppTheme.darkTheme]) {
    testWidgets(
      'explanation follows reading settings and reverses actions in ${theme.brightness}',
      (tester) async {
        final settings = SettingsViewModel();
        await settings.setFontFamily('Tajawal');
        await settings.setFontSize(30);
        await settings.setPadding(25);
        await tester.pumpWidget(
          ChangeNotifierProvider.value(
            value: settings,
            child: MaterialApp(
              theme: theme,
              home: Builder(
                builder: (context) => Scaffold(
                  body: TextButton(
                    onPressed: () => showMessageDialog(
                      context,
                      title: 'الشرح',
                      content: 'نص الشرح',
                      useReadingSettings: true,
                    ),
                    child: const Text('open'),
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.tap(find.text('open'));
        await tester.pumpAndSettle();
        final text = tester.widget<SelectableText>(find.byType(SelectableText));
        expect(text.style!.fontFamily, 'Tajawal');
        expect(text.style!.fontSize, 30);
        expect(text.style!.fontWeight, settings.fontWeight);
        expect(
          tester.widget<AlertDialog>(find.byType(AlertDialog)).contentPadding,
          const EdgeInsets.all(25),
        );
        expect(
          tester.getTopLeft(find.text('إغلاق')).dx,
          lessThan(tester.getTopLeft(find.text('نسخ')).dx),
        );
        await tester.tap(find.text('نسخ'));
        await tester.tap(find.text('إغلاق'));
        await tester.pumpAndSettle();
        expect(find.byType(AlertDialog), findsNothing);
        await tester.pumpWidget(const SizedBox());
        settings.dispose();
      },
    );

    testWidgets('dropdown menu opens and selects in ${theme.brightness}', (
      tester,
    ) async {
      var selected = 'أ';
      await tester.pumpWidget(
        MaterialApp(
          theme: theme,
          home: Scaffold(
            body: StatefulBuilder(
              builder: (context, setState) => AppDropdown<String>(
                title: 'الاختيارات',
                value: selected,
                items: const [
                  DropdownMenuItem(value: 'أ', child: Text('أ')),
                  DropdownMenuItem(value: 'ب', child: Text('ب')),
                ],
                onChanged: (value) => setState(() => selected = value!),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.byType(AppDropdown<String>));
      await tester.pumpAndSettle();
      expect(find.byIcon(Icons.check_rounded), findsOneWidget);
      expect(find.byType(BottomSheet), findsOneWidget);
      expect(find.text('الاختيارات'), findsOneWidget);
      await tester.tap(find.text('ب').last);
      await tester.pumpAndSettle();
      expect(selected, 'ب');
      expect(find.byType(BottomSheet), findsNothing);
      await tester.tap(find.byType(AppDropdown<String>));
      await tester.pumpAndSettle();
      await tester.tapAt(const Offset(5, 5));
      await tester.pumpAndSettle();
      expect(selected, 'ب');
      expect(find.byType(BottomSheet), findsNothing);
      expect(tester.takeException(), isNull);
    });
  }
}
