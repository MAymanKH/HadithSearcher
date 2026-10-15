import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:hadithsearcher/viewmodels/settings_viewmodel.dart';
import 'package:hadithsearcher/viewmodels/search_viewmodel.dart';
import 'package:hadithsearcher/widgets/selection_sheet.dart';
import 'package:hadithsearcher/models/search_option.dart';
import 'package:hadithsearcher/services/api_service.dart';
import 'package:hadithsearcher/widgets/search_option_picker.dart';

void main() {
  List<SearchOption> latestSelection = [];

  Future<void> openPicker(
    WidgetTester tester, {
    required Future<ApiResult<List<SearchOption>>> Function() load,
    List<SearchOption> selected = const [],
    SearchFilter filter = SearchFilter.narrator,
    Size size = const Size(320, 850),
    ValueChanged<List<SearchOption>>? onChanged,
  }) async {
    latestSelection = List.of(selected);
    SharedPreferences.setMockInitialValues({});
    final settings = SettingsViewModel();
    addTearDown(settings.dispose);
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: settings,
        child: MaterialApp(
          builder: (_, child) =>
              Directionality(textDirection: TextDirection.rtl, child: child!),
          home: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () => showSearchOptionPicker(
                  context,
                  filter: filter,
                  loadOptions: load,
                  selected: selected,
                  onChanged: (values) {
                    latestSelection = List.of(values);
                    onChanged?.call(values);
                  },
                ),
                child: const Text('فتح'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('فتح'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
  }

  Future<void> settle(WidgetTester tester) async {
    await tester.runAsync(() async {
      // compute uses a real isolate, so let it finish outside the fake clock.
      for (var i = 0; i < 200; i++) {
        await tester.pump();
        if (find.byType(LinearProgressIndicator).evaluate().isEmpty) break;
        await Future<void>.delayed(const Duration(milliseconds: 10));
      }
    });
    await tester.pumpAndSettle();
  }

  int optionCount(WidgetTester tester) =>
      (tester.widget<SliverList>(find.byType(SliverList)).delegate
              as SliverChildBuilderDelegate)
          .childCount!;

  ScrollController controller(WidgetTester tester) => tester
      .widget<CustomScrollView>(find.byType(CustomScrollView))
      .controller!;

  testWidgets('scrolling appends options lazily and search resets the batch', (
    tester,
  ) async {
    final options = [
      SearchOption.allNarrators,
      ...List.generate(11434, (i) => SearchOption('${i + 1}', 'راوي $i')),
      const SearchOption('20000', 'أَسْمَاء بنت أبى بكر'),
    ];
    await openPicker(tester, load: () async => ApiResult.success(options));
    await settle(tester);
    await tester.tap(find.text('جميع الرواة'));
    await tester.pumpAndSettle();
    expect(optionCount(tester), 40);
    expect(find.text('السابق'), findsNothing);
    expect(find.text('التالي'), findsNothing);
    expect(find.text('أَسْمَاء بنت أبى بكر'), findsNothing);
    expect(find.byType(ListTile).evaluate().length, lessThan(25));
    for (var i = 0; i < 10 && optionCount(tester) == 40; i++) {
      await tester.drag(find.byType(CustomScrollView), const Offset(0, -400));
      await tester.pumpAndSettle();
    }
    expect(optionCount(tester), 80);
    expect(controller(tester).offset, greaterThan(0));
    expect(find.byType(ListTile).evaluate().length, lessThan(25));
    controller(tester).jumpTo(0);
    await tester.pumpAndSettle();
    expect(optionCount(tester), 80);
    expect(find.text('راوي 0'), findsOneWidget);
    controller(tester).jumpTo(500);
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'اسماء بنت ابي');
    await tester.pump(const Duration(milliseconds: 250));
    await tester.pumpAndSettle();
    expect(optionCount(tester), 1);
    expect(controller(tester).offset, 0);
    expect(find.text('أَسْمَاء بنت أبى بكر'), findsOneWidget);
    expect(find.text('جميع الرواة'), findsOneWidget);
    await tester.enterText(find.byType(TextField), '');
    await tester.pump(const Duration(milliseconds: 250));
    await tester.pumpAndSettle();
    expect(optionCount(tester), 40);
    await tester.enterText(find.byType(TextField), 'اسماء بنت ابي');
    await tester.pump(const Duration(milliseconds: 250));
    await tester.pumpAndSettle();
    await tester.tap(find.text('أَسْمَاء بنت أبى بكر'));
    await tester.pumpAndSettle();
    expect(latestSelection.single.apiCode, '20000');
    expect(tester.takeException(), isNull);
  });

  testWidgets('scrolling reaches the final partial batch without duplicates', (
    tester,
  ) async {
    await openPicker(
      tester,
      load: () async => ApiResult.success([
        ...List.generate(85, (i) => SearchOption('${i + 1}', 'راوي $i')),
      ]),
    );
    await settle(tester);
    final scroll = controller(tester);
    expect(optionCount(tester), 40);
    for (final expectedCount in [80, 85]) {
      final offset = scroll.position.maxScrollExtent - 100;
      scroll.jumpTo(offset);
      await tester.pumpAndSettle();
      expect(optionCount(tester), expectedCount);
      expect(scroll.offset, offset);
    }
    scroll.jumpTo(scroll.position.maxScrollExtent);
    await tester.pumpAndSettle();
    expect(optionCount(tester), 85);
    expect(find.text('راوي 84'), findsOneWidget);
    scroll.jumpTo(0);
    await tester.pumpAndSettle();
    expect(optionCount(tester), 85);
    expect(find.text('راوي 0'), findsOneWidget);
    scroll.jumpTo(scroll.position.maxScrollExtent);
    await tester.pumpAndSettle();
    expect(optionCount(tester), 85);
    await tester.tap(find.text('راوي 84'));
    await tester.pumpAndSettle();
    expect(latestSelection, hasLength(84));
    expect(latestSelection.any((option) => option.apiCode == '85'), isFalse);
    expect(tester.takeException(), isNull);
  });

  testWidgets('scrolling a filtered list only appends matching names', (
    tester,
  ) async {
    await openPicker(
      tester,
      load: () async => ApiResult.success(
        List.generate(
          120,
          (i) => SearchOption('${i + 1}', i.isEven ? 'أسماء $i' : 'راوي $i'),
        ),
      ),
    );
    await settle(tester);
    await tester.enterText(find.byType(TextField), 'اسماء');
    await tester.pump(const Duration(milliseconds: 250));
    await tester.pumpAndSettle();
    expect(optionCount(tester), 40);
    final scroll = controller(tester);
    scroll.jumpTo(scroll.position.maxScrollExtent - 100);
    await tester.pumpAndSettle();
    expect(optionCount(tester), 60);
    scroll.jumpTo(scroll.position.maxScrollExtent);
    await tester.pumpAndSettle();
    expect(find.text('أسماء 118'), findsOneWidget);
    expect(
      find.descendant(
        of: find.byType(SliverList),
        matching: find.textContaining('راوي'),
      ),
      findsNothing,
    );
    await tester.tap(find.text('أسماء 118'));
    await tester.pumpAndSettle();
    expect(latestSelection, hasLength(119));
    expect(latestSelection.any((option) => option.apiCode == '119'), isFalse);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'failed loading offers retry and keeps a saved selection usable',
    (tester) async {
      var calls = 0;
      await openPicker(
        tester,
        selected: const [SearchOption('999', 'راوٍ محفوظ')],
        load: () async => ++calls == 1
            ? ApiResult.error(ApiError.noConnection)
            : ApiResult.success([const SearchOption('2', 'راوٍ جديد')]),
      );
      await settle(tester);
      expect(find.text('راوٍ محفوظ'), findsOneWidget);
      expect(
        tester
            .widgetList<Checkbox>(find.byType(Checkbox))
            .where((box) => box.value == true),
        hasLength(2),
      );
      expect(find.text('أعد المحاولة'), findsOneWidget);
      await tester.tap(find.text('أعد المحاولة'));
      await settle(tester);
      expect(calls, 2);
      expect(find.text('راوٍ جديد'), findsOneWidget);
      expect(find.text('أعد المحاولة'), findsNothing);
      await tester.enterText(find.byType(TextField), 'لا يوجد');
      await tester.pump(const Duration(milliseconds: 250));
      await tester.pumpAndSettle();
      expect(find.text('لا توجد خيارات مطابقة'), findsOneWidget);
      await tester.tap(find.text('جميع الرواة'));
      await tester.pumpAndSettle();
      expect(latestSelection.single.apiCode, '0');
      await tester.tap(find.text('جميع الرواة'));
      await tester.pumpAndSettle();
      expect(latestSelection, isEmpty);
    },
  );

  testWidgets('closing during loading ignores the late response', (
    tester,
  ) async {
    final response = Completer<ApiResult<List<SearchOption>>>();
    await openPicker(tester, load: () => response.future);
    expect(find.byType(LinearProgressIndicator), findsOneWidget);
    tester.state<NavigatorState>(find.byType(Navigator)).pop();
    await tester.pumpAndSettle();
    response.complete(ApiResult.success([const SearchOption('2', 'راوٍ آخر')]));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'search keeps keyboard focus as the sheet adjusts to keyboard height',
    (tester) async {
      await openPicker(
        tester,
        load: () async => ApiResult.error(ApiError.noConnection),
      );
      await settle(tester);
      final field = find.byType(TextField);
      expect(tester.testTextInput.isVisible, isFalse);
      await tester.tap(field);
      await tester.pump();
      expect(tester.testTextInput.isVisible, isTrue);
      tester.view.viewInsets = const FakeViewPadding(bottom: 300);
      await tester.pumpAndSettle();
      expect(tester.testTextInput.isVisible, isTrue);
      expect(tester.getBottomRight(field).dy, lessThan(550));
      tester.testTextInput.hide();
      tester.view.viewInsets = FakeViewPadding.zero;
      await tester.pumpAndSettle();
      expect(tester.testTextInput.isVisible, isFalse);
      await tester.tap(field);
      await tester.pump();
      expect(tester.testTextInput.isVisible, isTrue);
      await tester.enterText(field, 'راوٍ');
      await tester.pump(const Duration(milliseconds: 250));
      await tester.tap(find.text('جميع الرواة'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('picker fits a narrow phone above the keyboard', (tester) async {
    await openPicker(
      tester,
      size: const Size(320, 640),
      load: () async => ApiResult.error(ApiError.noConnection),
    );
    await settle(tester);
    tester.view.viewInsets = const FakeViewPadding(bottom: 300);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
  testWidgets(
    'four grades have no search, apply immediately, and all selects or clears every checkbox',
    (tester) async {
      await openPicker(
        tester,
        filter: SearchFilter.grade,
        load: () async => fail('Grades must use their four local options'),
      );
      await tester.pumpAndSettle();
      expect(find.byType(TextField), findsNothing);
      expect(find.byType(Checkbox), findsNWidgets(5));
      expect(find.textContaining('تطبيق'), findsNothing);
      expect(find.text('المحدد: 4'), findsOneWidget);
      expect(
        tester
            .widgetList<Checkbox>(find.byType(Checkbox))
            .every((box) => box.value == true),
        isTrue,
      );
      expect(tester.getSize(find.byType(SelectionSheet)).height, lessThan(500));
      await tester.tap(find.text('جميع الدرجات'));
      await tester.pumpAndSettle();
      expect(latestSelection, isEmpty);
      expect(find.text('المحدد: 0'), findsOneWidget);
      await tester.tap(find.text('جميع الدرجات'));
      await tester.pumpAndSettle();
      expect(latestSelection.single.apiCode, '0');
      expect(
        tester
            .widgetList<Checkbox>(find.byType(Checkbox))
            .every((box) => box.value == true),
        isTrue,
      );
      expect(find.text('المحدد: 4'), findsOneWidget);
      await tester.tap(find.text('أحاديث صحيحة'));
      await tester.pumpAndSettle();
      expect(latestSelection.map((option) => option.apiCode), ['2', '3', '4']);
      expect(
        tester.widget<Checkbox>(find.byType(Checkbox).first).value,
        isNull,
      );
      expect(find.text('المحدد: 3'), findsOneWidget);
      await tester.tap(find.text('جميع الدرجات'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('جميع الدرجات'));
      await tester.pumpAndSettle();
      expect(latestSelection, isEmpty);
      expect(
        tester
            .widgetList<Checkbox>(find.byType(Checkbox))
            .every((box) => box.value == false),
        isTrue,
      );
      expect(find.text('المحدد: 0'), findsOneWidget);
    },
  );

  for (final filter in [SearchFilter.book, SearchFilter.scholar]) {
    testWidgets(
      '${filter.name} info opens independently on the right with checkboxes on the left',
      (tester) async {
        final option = filter == SearchFilter.book
            ? const SearchOption('6216', 'صحيح البخاري')
            : const SearchOption('256', 'البخاري');
        var calls = 0;
        await http.runWithClient(
          () async {
            await openPicker(
              tester,
              filter: filter,
              load: () async => ApiResult.success([
                option,
                const SearchOption('other', 'خيار آخر'),
              ]),
            );
            await settle(tester);
            await tester.tap(find.text(filter.all.arabicName));
            await tester.pumpAndSettle();
            final row = find.widgetWithText(ListTile, option.arabicName);
            final info = find.byTooltip('معلومات عن ${option.arabicName}');
            final checkbox = find.descendant(
              of: row,
              matching: find.byType(Checkbox),
            );
            expect(
              tester.getCenter(info).dx,
              greaterThan(tester.getCenter(checkbox).dx),
            );
            await tester.tap(info);
            await tester.pumpAndSettle();
            if (filter == SearchFilter.book) {
              expect(find.text('أعد المحاولة'), findsOneWidget);
              await tester.tap(find.text('أعد المحاولة'));
              await tester.pumpAndSettle();
            }
            expect(
              find.textContaining(
                filter == SearchFilter.book
                    ? 'المؤلف: الإمام البخاري'
                    : 'ترجمة المحدث',
              ),
              findsOneWidget,
            );
            expect(latestSelection, isEmpty);
            await tester.tap(find.text('إغلاق'));
            await tester.pumpAndSettle();
            expect(tester.widget<Checkbox>(checkbox).value, isFalse);
            await tester.tap(checkbox);
            await tester.pumpAndSettle();
            expect(latestSelection.single.apiCode, option.apiCode);
            expect(find.text('المحدد: 1'), findsOneWidget);
            expect(tester.takeException(), isNull);
          },
          () => MockClient((request) async {
            calls++;
            expect(
              request.url.path,
              filter == SearchFilter.book
                  ? '/v1/site/book/6216'
                  : '/v1/site/mohdith/256',
            );
            if (filter == SearchFilter.book && calls == 1) {
              return http.Response('', 503);
            }
            return http.Response(
              jsonEncode({
                'data': filter == SearchFilter.book
                    ? {
                        'name': option.arabicName,
                        'author': 'الإمام البخاري',
                        'publisher': 'دار النشر',
                      }
                    : {'name': option.arabicName, 'info': 'ترجمة المحدث'},
              }),
              200,
              headers: {'content-type': 'application/json; charset=utf-8'},
            );
          }),
        );
      },
    );
  }

  testWidgets(
    'all remains selected as a catalog finishes loading and clears in one tap',
    (tester) async {
      final response = Completer<ApiResult<List<SearchOption>>>();
      await openPicker(tester, load: () => response.future);
      response.complete(
        ApiResult.success(
          List.generate(100, (i) => SearchOption('$i-id', 'راوٍ $i')),
        ),
      );
      await settle(tester);
      expect(find.text('المحدد: 100'), findsOneWidget);
      expect(
        tester
            .widgetList<Checkbox>(find.byType(Checkbox))
            .every((box) => box.value == true),
        isTrue,
      );
      await tester.tap(find.text('جميع الرواة'));
      await tester.pumpAndSettle();
      expect(latestSelection, isEmpty);
      expect(find.text('المحدد: 0'), findsOneWidget);
      expect(
        tester
            .widgetList<Checkbox>(find.byType(Checkbox))
            .every((box) => box.value == false),
        isTrue,
      );
    },
  );
  testWidgets('manually selecting every grade clears the active filter count', (
    tester,
  ) async {
    final vm = SearchViewModel();
    addTearDown(vm.dispose);
    await openPicker(
      tester,
      filter: SearchFilter.grade,
      load: () async => fail('Grades use local options'),
      onChanged: (values) => vm.setSelectedOptions(SearchFilter.grade, values),
    );
    await tester.pumpAndSettle();
    expect(vm.activeFilters, isEmpty);
    await tester.tap(find.text('جميع الدرجات'));
    await tester.pumpAndSettle();
    for (final option in SearchOption.grades.skip(1)) {
      await tester.tap(find.text(option.arabicName));
      await tester.pumpAndSettle();
      if (option.apiCode != '4') expect(vm.activeFilters, hasLength(1));
    }
    expect(latestSelection.single.apiCode, '0');
    expect(vm.activeFilters, isEmpty);
    expect(find.text('المحدد: 4'), findsOneWidget);
    expect(
      tester
          .widgetList<Checkbox>(find.byType(Checkbox))
          .every((box) => box.value == true),
      isTrue,
    );
  });
}
