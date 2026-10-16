import 'fixtures/search_catalogs.dart';
import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:hadithsearcher/app.dart';
import 'package:hadithsearcher/l10n/localization.dart';
import 'package:hadithsearcher/l10n/app_localizations_ar.dart';
import 'package:hadithsearcher/l10n/app_localizations_en.dart';
import 'package:hadithsearcher/models/hadith.dart';
import 'package:hadithsearcher/models/search_option.dart';
import 'package:hadithsearcher/models/settings.dart';
import 'package:hadithsearcher/models/search_params.dart';
import 'package:hadithsearcher/services/telemetry/telemetry_service.dart';
import 'package:hadithsearcher/services/api_service.dart';
import 'package:hadithsearcher/viewmodels/search_viewmodel.dart';
import 'package:hadithsearcher/viewmodels/settings_viewmodel.dart';
import 'package:hadithsearcher/views/main_shell.dart';
import 'package:hadithsearcher/views/privacy/telemetry_consent_view.dart';
import 'package:hadithsearcher/views/welcome/welcome_view.dart';
import 'package:hadithsearcher/widgets/hadith_card.dart';

import 'telemetry/fake_backend.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));
  const capture = bool.fromEnvironment('CAPTURE_SCREENSHOTS');
  setUpAll(() async {
    if (!capture) return;
    for (final entry in {
      'Roboto': 'Roboto-Regular.ttf',
      'Cairo': 'Cairo-Variable.ttf',
    }.entries) {
      await (FontLoader(
        entry.key,
      )..addFont(rootBundle.load('assets/fonts/${entry.value}'))).load();
    }
    await (FontLoader(
      'MaterialIcons',
    )..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'))).load();
  });

  Future<TelemetryService> mount(
    WidgetTester tester, {
    TelemetryPolicy policy = TelemetryPolicy.optIn,
  }) async {
    await seedCatalogCache();
    final telemetry = TelemetryService(
      preferences: await SharedPreferences.getInstance(),
      backend: FakeBackend(),
      policy: policy,
    );
    addTearDown(telemetry.dispose);
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      RepaintBoundary(
        key: const Key('screenshot'),
        child: HadithSearcherApp(
          initialThemeMode: ThemeMode.system,
          telemetry: telemetry,
        ),
      ),
    );
    await finishCatalogPreload(
      tester,
      tester
          .element(find.byType(MaterialApp))
          .read<SearchViewModel>()
          .preloadCatalogs(),
    );
    await tester.pumpAndSettle();
    return telemetry;
  }

  Future<void> chooseEnglish(WidgetTester tester) async {
    await tester.tap(find.byKey(const Key('language-selector')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('English').last);
    await tester.pumpAndSettle();
  }

  test('catalogs have matching keys and placeholders', () {
    final ar =
        jsonDecode(File('lib/l10n/app_ar.arb').readAsStringSync()) as Map;
    final en =
        jsonDecode(File('lib/l10n/app_en.arb').readAsStringSync()) as Map;
    final keys = en.keys.where((key) => !key.startsWith('@')).toSet();
    expect(ar.keys.where((key) => !key.startsWith('@')).toSet(), keys);
    final placeholder = RegExp(r'\{(\w+)\}');
    for (final key in keys) {
      expect((ar[key] as String).trim(), isNotEmpty, reason: key);
      expect((en[key] as String).trim(), isNotEmpty, reason: key);
      expect(
        placeholder.allMatches(ar[key]).map((m) => m[1]).toSet(),
        placeholder.allMatches(en[key]).map((m) => m[1]).toSet(),
        reason: key,
      );
    }
  });

  test('every service API error has an English presentation', () {
    final l = AppLocalizationsEn();
    for (final error in ApiError.values) {
      expect(localizedError(error.arabicTitle, l), error.title(l));
    }
  });

  for (final policy in TelemetryPolicy.values) {
    testWidgets('welcome previews and saves choices before $policy routing', (
      tester,
    ) async {
      final telemetry = await mount(tester, policy: policy);
      expect(find.byType(WelcomeView), findsOneWidget);
      expect(find.byType(TelemetryConsentView), findsNothing);
      expect(find.byType(MainShell), findsNothing);
      expect(
        Directionality.of(tester.element(find.byType(WelcomeView))),
        TextDirection.rtl,
      );
      await chooseEnglish(tester);
      expect(find.text('Welcome to Hadith Searcher'), findsOneWidget);
      expect(
        Directionality.of(tester.element(find.byType(WelcomeView))),
        TextDirection.ltr,
      );
      await tester.tap(find.byKey(const Key('theme-selector')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Dark').last);
      await tester.pumpAndSettle();
      expect(
        Theme.of(tester.element(find.byType(WelcomeView))).brightness,
        Brightness.dark,
      );
      await tester.ensureVisible(find.byKey(const Key('complete-welcome')));
      await tester.tap(find.byKey(const Key('complete-welcome')));
      await tester.pumpAndSettle();
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getBool('welcomeCompleted'), isTrue);
      expect(prefs.getString('language'), 'en');
      expect(prefs.getString('theme'), 'dark');
      if (policy == TelemetryPolicy.optIn) {
        expect(find.byType(TelemetryConsentView), findsOneWidget);
        expect(find.text('Data sharing'), findsOneWidget);
        expect(telemetry.consent.decided, isFalse);
        await tester.ensureVisible(
          find.byKey(const Key('save-telemetry-consent')),
        );
        await tester.tap(find.byKey(const Key('save-telemetry-consent')));
        await tester.pumpAndSettle();
      }
      expect(find.byType(MainShell), findsOneWidget);
      expect(find.text('Search'), findsWidgets);
      await tester.tap(find.widgetWithText(TextButton, 'Filters'));
      await tester.pumpAndSettle();
      expect(find.text('Any word'), findsOneWidget);
      expect(find.text('All grades'), findsOneWidget);
      await tester.ensureVisible(find.text('Any word'));
      await tester.tap(find.text('Any word'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Exact match').last);
      await tester.pumpAndSettle();
      final searchVm = tester
          .element(find.byType(MainShell))
          .read<SearchViewModel>();
      expect(searchVm.searchWay, SearchWay.exactMatch);
      expect(find.text('Exact match'), findsWidgets);
      await tester.pumpWidget(const SizedBox());
      // A fresh app instance must keep the locale and skip welcome.
      await tester.pumpWidget(
        HadithSearcherApp(
          initialThemeMode: ThemeMode.light,
          telemetry: telemetry,
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(WelcomeView), findsNothing);
      expect(find.text('Search'), findsWidgets);
      await tester.tap(find.text('Settings').last);
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('language-selector')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('العربية').last);
      await tester.pumpAndSettle();
      expect(find.text('الإعدادات'), findsWidgets);
      expect(prefs.getString('language'), 'ar');
      expect(
        Directionality.of(tester.element(find.byType(MainShell))),
        TextDirection.rtl,
      );
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    });
  }

  testWidgets('interrupted welcome resumes; consent never bypasses it', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({'language': 'en', 'theme': 'dark'});
    final telemetry = await mount(tester);
    expect(find.byType(WelcomeView), findsOneWidget);
    expect(find.text('Welcome to Hadith Searcher'), findsOneWidget);
    await telemetry.save(diagnostics: false, analytics: false);
    await tester.pumpAndSettle();
    expect(find.byType(WelcomeView), findsOneWidget);
    await tester.tap(find.byKey(const Key('complete-welcome')));
    await tester.pumpAndSettle();
    expect(find.byType(MainShell), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });

  test(
    'English filter summaries preserve source labels and query parameters',
    () {
      final vm = SearchViewModel();
      addTearDown(vm.dispose);
      final en = AppLocalizationsEn();
      vm.setSelectedOptions(SearchFilter.grade, [grades[1]]);
      vm.setSelectedOptions(
        SearchFilter.book,
        [],
        excluded: [const SearchOption('6216', 'صحيح البخاري')],
      );
      vm.setExcludedWords('كلمات عربية');
      expect(vm.selectionLabel(SearchFilter.grade, en), 'Authentic hadiths');
      expect(
        vm.selectionLabel(SearchFilter.book, en),
        'All except صحيح البخاري',
      );
      expect(vm.localizedActiveFilters(en), contains('Exclude: كلمات عربية'));
      expect(
        vm.localizedActiveFilters(en),
        contains('Hadith grade: Authentic hadiths'),
      );
      expect(vm.selectedOptions(SearchFilter.grade).single.apiCode, '1');
      expect(
        vm.selectionLabel(SearchFilter.grade, AppLocalizationsAr()),
        'أحاديث صحيحة',
      );
    },
  );

  testWidgets('English hadith controls keep API text and grades in Arabic', (
    tester,
  ) async {
    const hadith = Hadith(
      id: '',
      text: 'نص الحديث من المصدر',
      rawi: 'راوٍ',
      mohdith: 'محدث',
      book: 'كتاب المصدر',
      numberOrPage: '١٢',
      grade: 'صحيح من المصدر',
    );
    final vm = SettingsViewModel();
    addTearDown(vm.dispose);
    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: vm,
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: const Locale('en'),
          home: Scaffold(
            body: HadithCard(
              hadith: hadith,
              isFavourite: false,
              onFavouriteToggle: () async {},
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text(hadith.text), findsOneWidget);
    expect(find.text('Grading: صحيح من المصدر'), findsOneWidget);
    expect(find.text('Scholar: محدث'), findsOneWidget);
    expect(find.text('Explanation'), findsOneWidget);
    expect(find.text('Share'), findsOneWidget);
    expect(
      tester
          .widget<SelectableText>(
            find.byWidgetPredicate(
              (widget) =>
                  widget is SelectableText && widget.data == hadith.text,
            ),
          )
          .textDirection,
      TextDirection.rtl,
    );
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });

  for (final language in ['ar', 'en']) {
    for (final theme in ['light', 'dark']) {
      testWidgets(
        'welcome fits $language $theme at narrow and landscape sizes',
        (tester) async {
          SharedPreferences.setMockInitialValues({
            'language': language,
            'theme': theme,
          });
          await mount(tester);
          final vm = tester
              .element(find.byType(WelcomeView))
              .read<SettingsViewModel>();
          expect(vm.settings.theme, ThemePreference.fromString(theme));
          if (capture) {
            final boundary = tester.renderObject<RenderRepaintBoundary>(
              find.byKey(const Key('screenshot')),
            );
            await tester.runAsync(() async {
              final image = await boundary.toImage();
              final data = await image.toByteData(
                format: ui.ImageByteFormat.png,
              );
              final file = File(
                'build/localization/welcome-$language-$theme.png',
              );
              await file.parent.create(recursive: true);
              await file.writeAsBytes(data!.buffer.asUint8List());
              image.dispose();
            });
          }
          for (final size in [const Size(320, 568), const Size(844, 390)]) {
            tester.view.physicalSize = size;
            await tester.pumpAndSettle();
            await tester.ensureVisible(
              find.byKey(const Key('complete-welcome')),
            );
            await tester.pumpAndSettle();
            expect(tester.takeException(), isNull);
            expect(
              tester.getRect(find.byKey(const Key('complete-welcome'))).right,
              lessThanOrEqualTo(size.width),
            );
          }
          await tester.pumpWidget(const SizedBox());
        },
      );
    }
  }
}
