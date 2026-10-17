import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hadithsearcher/core/theme/app_theme.dart';
import 'package:hadithsearcher/widgets/app_dropdown.dart';
import 'package:hadithsearcher/widgets/app_selection_tile.dart';
import 'package:hadithsearcher/widgets/selection_sheet.dart';

void main() {
  testWidgets('option sheet outline paints only its rounded top edge', (
    tester,
  ) async {
    late BuildContext sheetContext;
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.darkTheme,
        home: Builder(
          builder: (context) {
            sheetContext = context;
            return const SizedBox();
          },
        ),
      ),
    );
    await tester.runAsync(() async {
      final recorder = ui.PictureRecorder();
      SelectionSheet.shape(
        sheetContext,
      ).paint(Canvas(recorder), const Rect.fromLTWH(0, 0, 120, 200));
      final picture = recorder.endRecording();
      final image = await picture.toImage(120, 200);
      final pixels = (await image.toByteData(
        format: ui.ImageByteFormat.rawRgba,
      ))!;
      int alpha(int x, int y) => pixels.getUint8((y * 120 + x) * 4 + 3);
      expect(alpha(60, 0), greaterThan(0));
      for (var y = 24; y < 200; y++) {
        expect(alpha(0, y), 0);
        expect(alpha(119, y), 0);
      }
      expect(alpha(60, 199), 0);
      image.dispose();
      picture.dispose();
    });
  });

  testWidgets('scrolled selected backgrounds stay below the search field', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final boundary = GlobalKey();
    final search = GlobalKey();
    final theme = AppTheme.darkTheme;
    await tester.pumpWidget(
      MaterialApp(
        theme: theme.copyWith(
          colorScheme: theme.colorScheme.copyWith(primaryContainer: Colors.red),
        ),
        home: Scaffold(
          body: RepaintBoundary(
            key: boundary,
            child: Material(
              color: Colors.black,
              child: SelectionSheet(
                title: 'المحدث',
                search: SizedBox(key: search, height: 60),
                child: ListView.builder(
                  itemCount: 50,
                  itemBuilder: (_, index) => AppSelectionTile(
                    title: Text('محدث $index'),
                    selected: true,
                    multiple: true,
                    onTap: () {},
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.drag(find.byType(ListView), const Offset(0, -123));
    await tester.pumpAndSettle();
    final position = tester.getCenter(find.byKey(search));
    await tester.runAsync(() async {
      final image =
          await (boundary.currentContext!.findRenderObject()
                  as RenderRepaintBoundary)
              .toImage();
      final pixels = (await image.toByteData(
        format: ui.ImageByteFormat.rawRgba,
      ))!;
      final offset =
          (position.dy.floor() * image.width + position.dx.floor()) * 4;
      expect(pixels.buffer.asUint8List(offset, 3), [
        0,
        0,
        0,
      ], reason: 'Selected row ink must not paint over the search area');
      image.dispose();
    });
  });

  for (final count in [3, 5]) {
    testWidgets(
      '$count single choices use a compact sheet with no empty footer',
      (tester) async {
        tester.view.physicalSize = const Size(360, 850);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        String? selection;
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: AppDropdown<String>(
                title: 'الاختيارات',
                value: '0',
                items: List.generate(
                  count,
                  (i) => DropdownMenuItem(value: '$i', child: Text('خيار $i')),
                ),
                onChanged: (value) => selection = value,
              ),
            ),
          ),
        );
        await tester.tap(find.byType(AppDropdown<String>));
        await tester.pumpAndSettle();
        final sheet = tester.getRect(find.byType(SelectionSheet));
        final last = tester.getRect(
          find.widgetWithText(ListTile, 'خيار ${count - 1}'),
        );
        expect(sheet.height, lessThan(450));
        expect(sheet.bottom - last.bottom, lessThan(30));
        await tester.tap(find.text('خيار ${count - 1}'));
        await tester.pumpAndSettle();
        expect(selection, '${count - 1}');
        expect(tester.takeException(), isNull);
      },
    );
  }
}
