import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hadithsearcher/widgets/app_dropdown.dart';
import 'package:hadithsearcher/widgets/selection_sheet.dart';

void main() {
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
