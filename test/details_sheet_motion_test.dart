import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hadithsearcher/core/theme/app_theme.dart';
import 'package:hadithsearcher/widgets/details_sheet.dart';

void main() {
  testWidgets('sheet height eases when asynchronous content arrives', (
    tester,
  ) async {
    final loaded = Completer<void>();
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.darkTheme,
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () => showDetailsSheet(
                context,
                title: 'details',
                child: FutureBuilder<void>(
                  future: loaded.future,
                  builder: (_, snapshot) => SizedBox(
                    height: snapshot.connectionState == ConnectionState.done
                        ? 400
                        : 50,
                  ),
                ),
              ),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    final before = tester.getSize(find.byType(BottomSheet)).height;
    loaded.complete();
    await tester.pump();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    final midway = tester.getSize(find.byType(BottomSheet)).height;
    await tester.pumpAndSettle();
    final after = tester.getSize(find.byType(BottomSheet)).height;
    expect(midway, inExclusiveRange(before, after));
    expect(tester.takeException(), isNull);
  });
}
