import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hadithsearcher/models/search_option.dart';
import 'package:hadithsearcher/services/api_service.dart';
import 'package:hadithsearcher/widgets/app_dropdown.dart';
import 'package:hadithsearcher/widgets/app_loading_indicator.dart';
import 'package:hadithsearcher/widgets/details_sheet.dart';
import 'package:hadithsearcher/widgets/search_option_picker.dart';

enum _SheetKind { dropdown, filters, details }

void main() {
  testWidgets('a downward fling dismisses only the top nested sheet', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () => showDetailsSheet(
                context,
                title: 'Parent',
                child: Builder(
                  builder: (context) => TextButton(
                    onPressed: () => showDetailsSheet(
                      context,
                      title: 'Child',
                      child: Column(
                        children: List.generate(
                          80,
                          (i) => SizedBox(height: 48, child: Text('Detail $i')),
                        ),
                      ),
                    ),
                    child: const Text('Open child'),
                  ),
                ),
              ),
              child: const Text('Open parent'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open parent'));
    await tester.pumpAndSettle();
    final parentTop = tester.getTopLeft(find.byType(BottomSheet)).dy;
    await tester.tap(find.text('Open child'));
    await tester.pumpAndSettle();
    expect(find.byType(BottomSheet, skipOffstage: false), findsNWidgets(2));
    final list = find.descendant(
      of: find.byType(BottomSheet).last,
      matching: find.byType(SingleChildScrollView),
    );
    await tester.fling(list, const Offset(0, 100), 1500);
    await tester.pumpAndSettle();
    expect(find.byType(BottomSheet), findsOneWidget);
    expect(find.text('Parent'), findsOneWidget);
    expect(
      tester.getTopLeft(find.byType(BottomSheet)).dy,
      closeTo(parentTop, 1),
    );
    expect(tester.takeException(), isNull);
  });

  for (final platform in [TargetPlatform.android, TargetPlatform.iOS]) {
    for (final kind in _SheetKind.values) {
      for (final long in [false, true]) {
        testWidgets(
          '${platform.name} ${kind.name} ${long ? 'long' : 'short'} list hands downward drag to sheet',
          (tester) async {
            tester.view.physicalSize = const Size(390, 850);
            tester.view.devicePixelRatio = 1;
            addTearDown(tester.view.reset);
            final count = long ? 80 : 3;
            await tester.pumpWidget(
              MaterialApp(
                theme: ThemeData(platform: platform),
                home: Scaffold(
                  body: Builder(
                    builder: (context) {
                      if (kind == _SheetKind.dropdown) {
                        return AppDropdown<int>(
                          title: 'Choices',
                          value: 0,
                          items: List.generate(
                            count,
                            (i) => DropdownMenuItem(
                              value: i,
                              child: Text('Choice $i'),
                            ),
                          ),
                          onChanged: (_) {},
                        );
                      }
                      return TextButton(
                        onPressed: () {
                          if (kind == _SheetKind.filters) {
                            showSearchOptionPicker(
                              context,
                              filter: SearchFilter.narrator,
                              loadOptions: () async => ApiResult.success(
                                List.generate(
                                  count,
                                  (i) => SearchOption('${i + 1}', 'Choice $i'),
                                ),
                              ),
                              selected: [],
                              onChanged: (_, _) {},
                            );
                          } else {
                            showDetailsSheet(
                              context,
                              title: 'Details',
                              child: Column(
                                children: List.generate(
                                  count,
                                  (i) => SizedBox(
                                    height: 48,
                                    child: Text('Detail $i'),
                                  ),
                                ),
                              ),
                            );
                          }
                        },
                        child: const Text('Open'),
                      );
                    },
                  ),
                ),
              ),
            );
            await tester.tap(
              kind == _SheetKind.dropdown
                  ? find.byType(AppDropdown<int>)
                  : find.text('Open'),
            );
            await tester.pump();
            if (kind == _SheetKind.filters) {
              await tester.runAsync(() async {
                for (var i = 0; i < 200; i++) {
                  await tester.pump();
                    if (find.byType(AppLoadingIndicator).evaluate().isEmpty) {
                    break;
                    }
                  await Future<void>.delayed(const Duration(milliseconds: 10));
                }
              });
            }
            await tester.pumpAndSettle();
            final sheet = find.byType(BottomSheet);
            final list = find
                .descendant(
                  of: sheet,
                  matching: find.byWidgetPredicate(
                    (widget) =>
                        widget is Scrollable &&
                        widget.axisDirection == AxisDirection.down,
                  ),
                )
                .first;
            final position = tester.state<ScrollableState>(list).position;
            final initial = tester.getRect(sheet);
            if (long) {
              await tester.drag(list, const Offset(0, -180));
              await tester.pumpAndSettle();
              expect(position.pixels, greaterThan(0));
              expect(tester.getRect(sheet).top, closeTo(initial.top, 1));
              position.jumpTo(60);
              await tester.pump();
            }
            final start = tester.getRect(list).topCenter + const Offset(0, 40);
            final gesture = await tester.startGesture(start);
            await gesture.moveBy(
              const Offset(0, 20),
              timeStamp: const Duration(milliseconds: 100),
            );
            final distance = long ? 140.0 : 50.0;
            await gesture.moveBy(
              Offset(0, distance),
              timeStamp: const Duration(milliseconds: 500),
            );
            await tester.pump();
            expect(position.pixels, closeTo(position.minScrollExtent, 1));
            expect(tester.getRect(sheet).top, greaterThan(initial.top + 10));
            await gesture.up(timeStamp: const Duration(milliseconds: 1000));
            await tester.pumpAndSettle();
            expect(sheet, findsOneWidget);
            expect(tester.getRect(sheet).top, closeTo(initial.top, 1));

            if (long) {
              final reverse = await tester.startGesture(start);
              await reverse.moveBy(
                const Offset(0, 20),
                timeStamp: const Duration(milliseconds: 100),
              );
              await reverse.moveBy(
                const Offset(0, 90),
                timeStamp: const Duration(milliseconds: 500),
              );
              await tester.pump();
              expect(tester.getRect(sheet).top, greaterThan(initial.top + 10));
              await reverse.moveBy(
                const Offset(0, -160),
                timeStamp: const Duration(milliseconds: 1000),
              );
              await tester.pump();
              expect(tester.getRect(sheet).top, closeTo(initial.top, 1));
              expect(position.pixels, greaterThan(0));
              await reverse.up(timeStamp: const Duration(milliseconds: 1500));
              await tester.pumpAndSettle();
              position.jumpTo(0);
              await tester.pump();
            }

            final dismiss = await tester.startGesture(start);
            await dismiss.moveBy(
              const Offset(0, 20),
              timeStamp: const Duration(milliseconds: 100),
            );
            await dismiss.moveBy(
              Offset(0, initial.height * .7),
              timeStamp: const Duration(milliseconds: 1000),
            );
            await tester.pump();
            expect(
              tester.getRect(sheet).top,
              greaterThan(initial.top + initial.height * .5),
            );
            await dismiss.up(timeStamp: const Duration(milliseconds: 1500));
            await tester.pumpAndSettle();
            expect(sheet, findsNothing);
            expect(tester.takeException(), isNull);
          },
        );
      }
    }
  }
}
