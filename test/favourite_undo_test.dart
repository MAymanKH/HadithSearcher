import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hadithsearcher/core/theme/app_theme.dart';
import 'package:hadithsearcher/services/database_service.dart';
import 'package:hadithsearcher/widgets/favourite_undo.dart';

double opacity(WidgetTester tester, String message) => tester
    .widget<FadeTransition>(
      find
          .ancestor(
            of: find.text(message),
            matching: find.byType(FadeTransition),
          )
          .first,
    )
    .opacity
    .value;

void main() {
  testWidgets('adding replaces a stale undo notice with animated dismissal', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => Column(
              children: [
                TextButton(
                  onPressed: () => showFavouriteUndo(
                    context,
                    const FavouriteHadith(
                      id: 1,
                      hadithId: 'example',
                      hadithText: 'text',
                      hadithInfo: 'info',
                    ),
                  ),
                  child: const Text('Remove'),
                ),
                TextButton(
                  onPressed: () => showFavouriteAdded(context),
                  child: const Text('Add'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Remove'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Add'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250));
    expect(
      opacity(tester, 'تمت إزالة الحديث من المفضلة'),
      inExclusiveRange(0, 1),
    );
    await tester.pumpAndSettle();
    expect(find.text('تراجع'), findsNothing);
    expect(find.text('تمت إضافة الحديث إلى المفضلة'), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 1500));
    await tester.pumpAndSettle();
    expect(find.byType(SnackBar), findsNothing);
  });

  for (final mode in ['light', 'dark']) {
    testWidgets('undo is readable and expires in $mode mode', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: mode == 'dark' ? AppTheme.darkTheme : AppTheme.lightTheme,
          home: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () => showFavouriteUndo(
                  context,
                  const FavouriteHadith(
                    id: 1,
                    hadithId: 'example',
                    hadithText: 'text',
                    hadithInfo: 'info',
                  ),
                ),
                child: const Text('Remove'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Remove'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 250));
      expect(
        opacity(tester, 'تمت إزالة الحديث من المفضلة'),
        inExclusiveRange(0, 1),
      );
      await tester.pumpAndSettle();
      final actionText = tester.widget<RichText>(
        find.descendant(
          of: find.byType(SnackBarAction),
          matching: find.byType(RichText),
        ),
      );
      expect(
        actionText.text.style!.color,
        mode == 'dark' ? Colors.black : Colors.white,
      );
      await tester.pump(const Duration(seconds: 3));
      expect(find.text('تراجع'), findsOneWidget);
      await tester.pump(const Duration(seconds: 1));
      await tester.pump(const Duration(milliseconds: 250));
      expect(
        opacity(tester, 'تمت إزالة الحديث من المفضلة'),
        inExclusiveRange(0, 1),
      );
      await tester.pumpAndSettle();
      expect(find.byType(SnackBar), findsNothing);
      expect(tester.takeException(), isNull);
    });
    testWidgets(
      'added confirmation animates and expires quickly in $mode mode',
      (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            theme: mode == 'dark' ? AppTheme.darkTheme : AppTheme.lightTheme,
            home: Scaffold(
              body: Builder(
                builder: (context) => TextButton(
                  onPressed: () => showFavouriteAdded(context),
                  child: const Text('Add'),
                ),
              ),
            ),
          ),
        );
        await tester.tap(find.text('Add'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 250));
        const message = 'تمت إضافة الحديث إلى المفضلة';
        expect(opacity(tester, message), inExclusiveRange(0, 1));
        await tester.pumpAndSettle();
        expect(find.text(message), findsOneWidget);
        expect(find.text('تراجع'), findsNothing);
        await tester.pump(const Duration(milliseconds: 1500));
        await tester.pump(const Duration(milliseconds: 250));
        expect(opacity(tester, message), inExclusiveRange(0, 1));
        await tester.pumpAndSettle();
        expect(find.byType(SnackBar), findsNothing);
        expect(tester.takeException(), isNull);
      },
    );
  }
}
