import 'dart:convert';
import 'dart:ui' show SemanticsAction;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:hadithsearcher/core/theme/app_theme.dart';
import 'package:hadithsearcher/models/settings.dart';
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

  testWidgets('reading settings reset individually on a narrow RTL phone', (
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
    final restoreIcons = find.byIcon(Icons.restore_outlined);
    expect(find.byType(FloatingActionButton), findsNothing);
    expect(restoreIcons, findsNothing);
    final arrows = find.byIcon(Icons.expand_more_rounded);
    expect(arrows, findsNWidgets(7));
    final arrowPositions = tester.getCenter(arrows.first).dx;
    for (final arrow in arrows.evaluate()) {
      expect(tester.getCenter(find.byWidget(arrow.widget)).dx, arrowPositions);
    }
    final familyField = find.ancestor(
      of: find.text('نوع الخط'),
      matching: find.byType(AppDropdown<String>),
    );
    final familyDecoration = find.descendant(
      of: familyField,
      matching: find.byType(InputDecorator),
    );
    final familyWidth = tester.getSize(familyDecoration).width;
    final familyArrow = find.descendant(of: familyField, matching: arrows);
    await tester.tap(familyField);
    await tester.pumpAndSettle();
    await tester.tap(find.text('نوتو نسخ عربي').last);
    await tester.pumpAndSettle();
    expect(settings.fontFamily, 'Noto Naskh Arabic');
    expect(restoreIcons, findsOneWidget);
    expect(tester.getSize(familyDecoration).width, familyWidth);
    final familyReset = find.byTooltip('استعادة القيمة الافتراضية لـنوع الخط');
    expect(
      tester.getRect(familyDecoration).contains(tester.getCenter(familyReset)),
      isTrue,
    );
    expect(tester.getCenter(familyArrow).dx, arrowPositions);
    expect(tester.getCenter(restoreIcons), tester.getCenter(familyReset));
    expect(
      (tester.getCenter(restoreIcons).dx - tester.getCenter(familyArrow).dx)
          .abs(),
      lessThanOrEqualTo(42),
    );
    expect(tester.getSize(familyReset).shortestSide, greaterThanOrEqualTo(48));
    final semantics = tester.ensureSemantics();
    final resetSemantics = tester.getSemantics(familyReset).getSemanticsData();
    semantics.dispose();
    expect(resetSemantics.tooltip, 'استعادة القيمة الافتراضية لـنوع الخط');
    expect(resetSemantics.hasAction(SemanticsAction.tap), isTrue);
    await settings.setFontWeight(FontWeightPreference.normal);
    await settings.setFontSize(30);
    await settings.setPadding(15);
    await tester.pumpAndSettle();
    expect(restoreIcons, findsNWidgets(4));
    final updateSwitch = find.byType(SwitchListTile);
    await tester.scrollUntilVisible(
      updateSwitch,
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(updateSwitch);
    await tester.pumpAndSettle();
    expect(settings.settings.automaticUpdateChecks, isFalse);
    final restored = SettingsViewModel();
    await restored.loadSettings();
    expect(restored.settings.automaticUpdateChecks, isFalse);
    restored.dispose();
    final privacy = find.text('الخصوصية والقياس الاختياري');
    await tester.scrollUntilVisible(
      privacy,
      250,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    final divider = find.byType(Divider);
    expect(divider, findsOneWidget);
    expect(
      tester.getCenter(divider).dy,
      lessThan(tester.getTopLeft(updateSwitch).dy),
    );
    await tester.ensureVisible(familyReset);
    await tester.tap(familyReset);
    await tester.pumpAndSettle();
    expect(find.byType(BottomSheet), findsNothing);
    expect(settings.fontFamily, AppSettings.defaults.fontFamily);
    expect(settings.settings.fontWeight, FontWeightPreference.normal);
    expect(settings.settings.fontSize, 30);
    expect(settings.settings.padding, 15);

    for (final label in ['ثقل الخط', 'حجم الخط', 'الحشو']) {
      final reset = find.byTooltip('استعادة القيمة الافتراضية لـ$label');
      await tester.ensureVisible(reset);
      await tester.tap(reset);
      await tester.pumpAndSettle();
      expect(reset, findsNothing);
    }
    expect(restoreIcons, findsNothing);
    final saved = SettingsViewModel();
    addTearDown(saved.dispose);
    await saved.loadSettings();
    expect(saved.settings.fontFamily, AppSettings.defaults.fontFamily);
    expect(saved.settings.fontWeight, AppSettings.defaults.fontWeight);
    expect(saved.settings.fontSize, AppSettings.defaults.fontSize);
    expect(saved.settings.padding, AppSettings.defaults.padding);
    expect(saved.settings.automaticUpdateChecks, isFalse);
    await tester.ensureVisible(privacy);
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
