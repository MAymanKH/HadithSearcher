import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hadithsearcher/models/search_option.dart';
import 'package:hadithsearcher/services/api_service.dart';
import 'package:hadithsearcher/widgets/search_option_picker.dart';

void main() {
  Future<void> openPicker(
    WidgetTester tester, {
    required Future<ApiResult<List<SearchOption>>> Function() load,
    SearchOption selected = SearchOption.allNarrators,
    Size size = const Size(320, 850),
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        home: Directionality(
          textDirection: TextDirection.rtl,
          child: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () async {
                  final option = await showSearchOptionPicker(
                    context,
                    filter: SearchFilter.narrator,
                    loadOptions: load,
                    selected: selected,
                  );
                  if (context.mounted && option != null) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('اختيار: ${option.apiCode}')),
                    );
                  }
                },
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
    expect(find.text('اختيار: 20000'), findsOneWidget);
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
    expect(find.text('اختيار: 85'), findsOneWidget);
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
    expect(find.text('اختيار: 119'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'failed loading offers retry and keeps a saved selection usable',
    (tester) async {
      var calls = 0;
      await openPicker(
        tester,
        selected: const SearchOption('999', 'راوٍ محفوظ'),
        load: () async => ++calls == 1
            ? ApiResult.error(ApiError.noConnection)
            : ApiResult.success([const SearchOption('2', 'راوٍ جديد')]),
      );
      await settle(tester);
      expect(find.text('راوٍ محفوظ'), findsOneWidget);
      expect(find.byIcon(Icons.check), findsOneWidget);
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
      expect(find.text('اختيار: 0'), findsOneWidget);
    },
  );

  testWidgets('closing during loading ignores the late response', (
    tester,
  ) async {
    final response = Completer<ApiResult<List<SearchOption>>>();
    await openPicker(tester, load: () => response.future);
    expect(find.byType(LinearProgressIndicator), findsOneWidget);
    await tester.tap(find.text('جميع الرواة'));
    await tester.pumpAndSettle();
    response.complete(ApiResult.success([const SearchOption('2', 'راوٍ آخر')]));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

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
}
