import 'fixtures/search_catalogs.dart';
import 'package:hadithsearcher/widgets/app_dropdown.dart';
import 'package:hadithsearcher/widgets/api_details_sheet.dart';
import 'package:hadithsearcher/widgets/hadith_reading_sheet.dart';
import 'package:hadithsearcher/services/api_service.dart';
import 'package:hadithsearcher/widgets/hadith_card_layout.dart';
import 'dart:async';
import 'dart:convert';
import 'dart:ui' as ui;
import 'package:flutter/rendering.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:hadithsearcher/models/settings.dart';
import 'package:hadithsearcher/models/search_option.dart';
import 'package:hadithsearcher/viewmodels/search_viewmodel.dart';
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

  Future<void> mount(
    WidgetTester tester, {
    double width = 320,
    bool includeNarrators = true,
    NavigationMode navigationMode = NavigationMode.traditional,
  }) async {
    await seedCatalogCache(includeNarrators: includeNarrators);
    tester.view.physicalSize = Size(width, 850);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await (await SharedPreferences.getInstance()).setBool(
      'welcomeCompleted',
      true,
    );
    final telemetry = TelemetryService(
      preferences: await SharedPreferences.getInstance(),
      backend: FakeBackend(),
    );
    await telemetry.save(diagnostics: false, analytics: false);
    addTearDown(telemetry.dispose);
    await tester.pumpWidget(
      MediaQuery(
        data: MediaQueryData.fromView(
          tester.view,
        ).copyWith(navigationMode: navigationMode),
        child: HadithSearcherApp(
          initialThemeMode: ThemeMode.light,
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
  }

  testWidgets(
    'search text survives tab switches but starts blank after reopening',
    (tester) async {
      SharedPreferences.setMockInitialValues({
        'searchQuery': 'old saved query',
        'recentSearches': ['old saved query'],
      });
      await mount(tester, width: 800);
      expect(
        tester.widget<TextField>(find.byType(TextField)).controller!.text,
        isEmpty,
      );
      expect(find.text('عمليات البحث الأخيرة'), findsNothing);
      expect(find.text('old saved query'), findsNothing);
      expect(
        (await SharedPreferences.getInstance()).containsKey('recentSearches'),
        isFalse,
      );
      await tester.tap(find.byType(TextField));
      await tester.enterText(find.byType(TextField), 'session query');
      await tester.tap(find.text('الإعدادات').last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('البحث').last);
      await tester.pumpAndSettle();
      expect(find.text('session query'), findsOneWidget);
      expect(
        tester
            .widget<EditableText>(find.byType(EditableText))
            .focusNode
            .hasFocus,
        isFalse,
      );
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

  testWidgets('search focus requires a tap every time it is regained', (
    tester,
  ) async {
    await mount(tester, width: 800);
    final field = find.byType(TextField).first;
    final focus = tester
        .widget<EditableText>(find.byType(EditableText).first)
        .focusNode;
    expect(focus.hasFocus, isFalse);
    focus.requestFocus();
    await tester.pump();
    expect(focus.hasFocus, isFalse);
    for (var i = 0; i < 12; i++) {
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();
      expect(focus.hasFocus, isFalse);
    }
    await tester.tap(field);
    await tester.pump();
    expect(focus.hasFocus, isTrue);
    expect(tester.testTextInput.isVisible, isTrue);
    await tester.enterText(field, 'query');
    final dialog = showDialog<void>(
      context: tester.element(field),
      builder: (_) => const AlertDialog(content: Text('Focus test')),
    );
    await tester.pumpAndSettle();
    tester.state<NavigatorState>(find.byType(Navigator)).pop();
    await dialog;
    await tester.pumpAndSettle();
    expect(focus.hasFocus, isFalse);
    expect(tester.testTextInput.isVisible, isFalse);
    focus.requestFocus();
    await tester.pump();
    expect(focus.hasFocus, isFalse);
    await tester.tap(field);
    await tester.pump();
    expect(focus.hasFocus, isTrue);
    focus.unfocus();
    await tester.pump();
    focus.requestFocus();
    await tester.pump();
    expect(focus.hasFocus, isFalse);
    await tester.tap(field);
    await tester.pump();
    expect(focus.hasFocus, isTrue);
    await tester.pumpWidget(const SizedBox());
  });

  for (final navigation in NavigationMode.values) {
    for (final sources in [false, true]) {
      for (final dismissal in ['close', 'barrier', 'back']) {
        testWidgets(
          '${sources ? 'sources' : 'explanation'} cancellation by $dismissal does not restore search focus in ${navigation.name} navigation',
          (tester) async {
            await mount(tester, width: 800, navigationMode: navigation);
            final field = find.byType(TextField).first;
            final focus = tester.widget<TextField>(field).focusNode!;
            await tester.tap(field);
            await tester.pump();
            expect(focus.hasFocus, isTrue);
            final pending = Completer<ApiResult<String>>();
            final context = tester.element(field);
            final dialog = sources
                ? showApiDetailsSheet<String>(
                    context,
                    title: 'أصول الحديث',
                    load: () => pending.future,
                    format: (value) => value,
                  )
                : showExplanationSheet(
                    context,
                    load: () async => ApiResult.success('نص الشرح'),
                  );
            await tester.pump();
            await tester.pump(const Duration(milliseconds: 300));
            expect(find.byType(BottomSheet), findsOneWidget);
            if (dismissal == 'close') {
              await tester.tap(find.byTooltip('إغلاق'));
            } else if (dismissal == 'barrier') {
              await tester.tapAt(const Offset(5, 5));
            } else {
              await tester.binding.handlePopRoute();
            }
            await dialog;
            pending.complete(ApiResult.success('Late source details'));
            await tester.pumpAndSettle();
            expect(find.byType(BottomSheet), findsNothing);
            expect(focus.hasFocus, isFalse);
            expect(tester.testTextInput.isVisible, isFalse);
            focus.requestFocus();
            await tester.pump();
            expect(focus.hasFocus, isFalse);
            await tester.tap(field);
            await tester.pump();
            expect(focus.hasFocus, isTrue);
            expect(tester.testTextInput.isVisible, isTrue);
            await tester.pumpWidget(const SizedBox());
          },
        );
      }
    }
  }

  for (final mode in [ThemeMode.light, ThemeMode.dark]) {
    testWidgets(
      'switch backgrounds stay inside the scrolling panel in ${mode.name} mode',
      (tester) async {
        await mount(tester);
        await tester
            .element(find.byType(SearchView))
            .read<SettingsViewModel>()
            .setTheme(
              mode == ThemeMode.dark
                  ? ThemePreference.dark
                  : ThemePreference.light,
            );
        await tester.pumpAndSettle();
        expect(
          Theme.of(tester.element(find.byType(SearchView))).brightness,
          mode == ThemeMode.dark ? Brightness.dark : Brightness.light,
        );
        final field = find.byType(TextField).first;
        final fieldRect = tester.getRect(field);
        final capture = find
            .ancestor(
              of: find.byType(SearchView),
              matching: find.byType(RepaintBoundary),
            )
            .first;
        Future<List<int>> fieldPixel() async {
          final boundary = tester.renderObject<RenderRepaintBoundary>(capture);
          final origin = tester.getTopLeft(capture);
          return (await tester.runAsync(() async {
            final picture = await boundary.toImage();
            final bytes = await picture.toByteData(
              format: ui.ImageByteFormat.rawRgba,
            );
            final x = (fieldRect.left + 24 - origin.dx).round();
            final y = (fieldRect.center.dy - origin.dy).round();
            final offset = (y * picture.width + x) * 4;
            final pixel = bytes!.buffer.asUint8List().sublist(
              offset,
              offset + 4,
            );
            picture.dispose();
            return pixel;
          }))!;
        }

        final original = await fieldPixel();
        await tester.tap(find.widgetWithText(TextButton, 'التصفية'));
        await tester.pumpAndSettle();
        final row = find.widgetWithText(SwitchListTile, 'تذكّر عوامل التصفية');
        final scroll = tester.state<ScrollableState>(
          find
              .descendant(
                of: find.byType(SingleChildScrollView),
                matching: find.byType(Scrollable),
              )
              .first,
        );
        scroll.position.jumpTo(tester.getCenter(row).dy - fieldRect.center.dy);
        await tester.pumpAndSettle();
        expect(tester.getRect(row).overlaps(fieldRect), isTrue);
        expect(await fieldPixel(), original);
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets('remember filters uses a switch and saves its value', (
    tester,
  ) async {
    await mount(tester);
    await tester.tap(find.widgetWithText(TextButton, 'التصفية'));
    await tester.pumpAndSettle();
    final toggle = find.widgetWithText(SwitchListTile, 'تذكّر عوامل التصفية');
    expect(
      tester.getTopLeft(toggle).dy,
      lessThan(
        tester
            .getTopLeft(find.widgetWithText(SwitchListTile, 'البحث للمتخصصين'))
            .dy,
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.widget<SwitchListTile>(toggle).value, isTrue);
    expect(find.byType(CheckboxListTile), findsNothing);
    await tester.tap(toggle);
    await tester.pumpAndSettle();
    expect(tester.widget<SwitchListTile>(toggle).value, isFalse);
    expect(
      (await SharedPreferences.getInstance()).getBool('advancedSaveCheckbox'),
      isFalse,
    );
    await tester.pumpWidget(const SizedBox());
  });

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
            await tester.tap(find.byType(TextField));
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
            await tester.tap(find.byType(TextField));
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

  testWidgets('narrator picker reuses startup catalog', (tester) async {
    final requests = <Uri>[];
    await http.runWithClient(
      () async {
        await mount(tester, includeNarrators: false);
        expect(requests.map((url) => url.path), ['/v1/data/rawi']);
        await tester.tap(find.byType(TextField));
        await tester.enterText(find.byType(TextField), 'query');
        final searchFocus = tester
            .widget<EditableText>(find.byType(EditableText))
            .focusNode;
        await tester.tap(find.widgetWithText(TextButton, 'التصفية'));
        await tester.pumpAndSettle();
        expect(requests.map((url) => url.path), ['/v1/data/rawi']);
        await tester.ensureVisible(find.text('جميع الرواة'));
        await tester.tap(find.text('جميع الرواة'));
        await tester.pump();
        await tester.runAsync(() async {
          for (var i = 0; i < 200; i++) {
            await tester.pump();
            if (find.byType(LinearProgressIndicator).evaluate().isEmpty) {
              break;
            }
            await Future<void>.delayed(const Duration(milliseconds: 10));
          }
        });
        await tester.pumpAndSettle();
        expect(requests.map((url) => url.path), ['/v1/data/rawi']);
        await tester.tap(find.text('راوٍ آخر'));
        await tester.pumpAndSettle();
        tester.state<NavigatorState>(find.byType(Navigator)).pop();
        await tester.pumpAndSettle();
        expect(searchFocus.hasFocus, isFalse);
        expect(tester.testTextInput.isVisible, isFalse);
        await tester.tap(find.widgetWithText(TextButton, 'التصفية'));
        await tester.pumpAndSettle();
        expect(requests.last.queryParameters['rawi[]'], '8918');
        expect(
          find.widgetWithText(Chip, 'الراوي: عمر بن الخطاب'),
          findsOneWidget,
        );
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
      },
      () => MockClient((request) async {
        requests.add(request.url);
        return http.Response(
          jsonEncode(
            request.url.path == '/v1/data/rawi'
                ? {
                    'data': [
                      {'key': '8918', 'value': 'عمر بن الخطاب'},
                      {'key': '42', 'value': 'راوٍ آخر'},
                    ],
                  }
                : {
                    'metadata': {'hasNextPage': false},
                    'data': [],
                  },
          ),
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      }),
    );
  });

  testWidgets('advanced controls fit a narrow phone', (tester) async {
    await mount(tester);
    await tester.tap(find.widgetWithText(TextButton, 'التصفية'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(
      find.byWidgetPredicate((widget) => widget is AppDropdown),
      findsNWidgets(2),
    );
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('active filter row can be hidden without clearing filters', (
    tester,
  ) async {
    await mount(tester);
    expect(find.byType(Badge), findsNothing);
    final vm = tester.element(find.byType(SearchView)).read<SearchViewModel>();
    vm.setSelectedOptions(SearchFilter.grade, [grades[1]]);
    await tester.pumpAndSettle();
    final activeFilters = List<String>.of(vm.activeFilters);
    expect(find.byType(Chip), findsWidgets);
    final actions = tester.widget<AppBar>(find.byType(AppBar)).actions!;
    expect((actions.first as IconButton).tooltip, 'إخفاء عوامل التصفية النشطة');
    expect(actions.last, isA<TextButton>());
    expect(find.byTooltip('البحث المتقدم'), findsNothing);
    final filtersButton = tester.getRect(
      find.widgetWithText(TextButton, 'التصفية'),
    );
    final filtersLabel = tester.getRect(find.text('التصفية'));
    expect(filtersButton.left, greaterThanOrEqualTo(10));
    expect(filtersLabel.left, greaterThanOrEqualTo(filtersButton.left + 10));
    expect(filtersLabel.right, lessThanOrEqualTo(filtersButton.right - 10));
    expect(
      find.descendant(
        of: find.byType(Badge),
        matching: find.text('${activeFilters.length}'),
      ),
      findsOneWidget,
    );
    final transition = find.byKey(const ValueKey('active-filters-transition'));
    await tester.tap(find.byTooltip('إخفاء عوامل التصفية النشطة'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(tester.getSize(transition).height, inExclusiveRange(0, 58));
    await tester.pumpAndSettle();
    expect(tester.getSize(transition).height, 0);
    expect(find.byType(Chip), findsNothing);
    expect(find.text('مسح عوامل التصفية'), findsNothing);
    expect(vm.activeFilters, activeFilters);
    await tester.tap(find.widgetWithText(TextButton, 'التصفية'));
    await tester.pumpAndSettle();
    expect(
      find.byWidgetPredicate((widget) => widget is AppDropdown),
      findsNWidgets(2),
    );
    await tester.tap(find.widgetWithText(TextButton, 'التصفية'));
    await tester.pumpAndSettle();
    expect(find.byType(Chip), findsNothing);
    await tester.tap(find.byTooltip('إظهار عوامل التصفية النشطة'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(tester.getSize(transition).height, inExclusiveRange(0, 58));
    await tester.pumpAndSettle();
    expect(tester.getSize(transition).height, 58);
    expect(find.byType(Chip), findsWidgets);
    expect(vm.activeFilters, activeFilters);
    await tester.tap(find.text('مسح عوامل التصفية'));
    await tester.pumpAndSettle();
    expect(vm.activeFilters, isEmpty);
    expect(find.byType(Badge), findsNothing);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets(
    'filter row has equal gaps above and below, including while results scroll',
    (tester) async {
      await http.runWithClient(
        () async {
          await mount(tester);
          final vm = tester
              .element(find.byType(SearchView))
              .read<SearchViewModel>();
          vm.setSelectedOptions(SearchFilter.grade, [grades[1]]);
          await vm.search('الصلاة');
          await tester.pumpAndSettle();
          final row = find.byKey(const ValueKey('active-filters-row'));
          final field = find.byType(TextField).first;
          final results = find.byWidgetPredicate(
            (widget) =>
                widget is ListView && widget.scrollDirection == Axis.vertical,
          );
          final firstCard = find.byType(HadithCardLayout).first;
          final surface = find
              .descendant(of: firstCard, matching: find.byType(DecoratedBox))
              .first;
          final above =
              tester.getTopLeft(row).dy - tester.getBottomLeft(field).dy;
          final below =
              tester.getTopLeft(results).dy - tester.getBottomLeft(row).dy;
          expect(above, 10);
          expect(below, above);
          expect(tester.getTopLeft(surface).dy, tester.getTopLeft(results).dy);
          await tester.drag(results, const Offset(0, -400));
          await tester.pumpAndSettle();
          expect(
            tester.getTopLeft(results).dy - tester.getBottomLeft(row).dy,
            above,
          );
          expect(tester.takeException(), isNull);
        },
        () => MockClient(
          (_) async => http.Response(
            jsonEncode({
              'metadata': {'hasNextPage': false},
              'data': List.generate(
                20,
                (index) => {
                  'hadithId': 'spacing-$index',
                  'hadith': List.filled(30, 'نص الحديث').join(' '),
                  'grade': 'صحيح',
                  'rawi': 'راو',
                  'mohdith': 'محدث',
                  'book': 'كتاب',
                  'bookId': '1',
                  'mohdithId': '1',
                },
              ),
            }),
            200,
            headers: {'content-type': 'application/json; charset=utf-8'},
          ),
        ),
      );
    },
  );

  testWidgets('the search field remains editable during a request', (
    tester,
  ) async {
    final response = Completer<http.Response>();
    await http.runWithClient(
      () async {
        await mount(tester, width: 400);
        await tester.tap(find.byType(TextField));
        await tester.enterText(find.byType(TextField), 'first');
        expect(tester.testTextInput.isVisible, isTrue);
        await tester.tap(find.widgetWithText(ElevatedButton, 'بحث'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));
        expect(tester.testTextInput.isVisible, isFalse);
        expect(find.byType(CircularProgressIndicator), findsOneWidget);
        expect(find.byType(TextField), findsOneWidget);
        await tester.tap(find.byType(TextField));
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
