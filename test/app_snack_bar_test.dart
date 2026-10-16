import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hadithsearcher/widgets/app_snack_bar.dart';

void main() {
  for (final accessible in [false, true]) {
    for (final material3 in [false, true]) {
      for (final behavior in SnackBarBehavior.values) {
        testWidgets(
          'slides up and down for $behavior with M3=$material3 and accessibility=$accessible',
          (tester) async {
            late BuildContext context;
            var visible = 0;
            await tester.pumpWidget(
              MaterialApp(
                theme: ThemeData(useMaterial3: material3),
                builder: (context, child) => MediaQuery(
                  data: MediaQuery.of(
                    context,
                  ).copyWith(accessibleNavigation: accessible),
                  child: AppScaffoldMessenger(child: child!),
                ),
                home: Scaffold(
                  body: Builder(
                    builder: (value) {
                      context = value;
                      return const SizedBox();
                    },
                  ),
                ),
              ),
            );
            expect(MediaQuery.accessibleNavigationOf(context), accessible);
            final controller = showAppSnackBar(
              context,
              SnackBar(
                behavior: behavior,
                content: const Text('Notice'),
                duration: const Duration(seconds: 1),
                onVisible: () => visible++,
              ),
            );
            final message = find.text('Notice');
            final slide = find.byKey(const ValueKey('app-snack-bar-slide'));
            double offset() =>
                tester.widget<SlideTransition>(slide).position.value.dy;
            await tester.pump();
            await tester.pump(const Duration(milliseconds: 75));
            final earlyOffset = offset();
            await tester.pump(const Duration(milliseconds: 75));
            final middleOffset = offset();
            await tester.pump(const Duration(milliseconds: 75));
            final lateOffset = offset();
            expect(earlyOffset, inInclusiveRange(0.7, 0.95));
            expect(middleOffset, closeTo(0.5, 0.01));
            expect(lateOffset, inInclusiveRange(0.05, 0.3));
            await tester.pump(const Duration(milliseconds: 75));
            expect(offset(), 0);
            await tester.pumpAndSettle();
            expect(visible, 1);
            final restingY = tester.getTopLeft(message).dy;
            await tester.pump(const Duration(seconds: 1));
            await tester.pump(const Duration(milliseconds: 75));
            expect(offset(), closeTo(lateOffset, 0.01));
            expect(tester.getTopLeft(message).dy, greaterThan(restingY));
            await tester.pump(const Duration(milliseconds: 75));
            expect(offset(), closeTo(middleOffset, 0.01));
            await tester.pump(const Duration(milliseconds: 75));
            expect(offset(), closeTo(earlyOffset, 0.01));
            expect(find.byType(SnackBar), findsOneWidget);
            await tester.pump(const Duration(milliseconds: 75));
            await tester.pumpAndSettle();
            expect(message, findsNothing);
            expect(await controller.closed, SnackBarClosedReason.timeout);
          },
        );
      }
    }
  }

  testWidgets('reduced motion skips the slide', (tester) async {
    late BuildContext context;
    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(disableAnimations: true),
          child: Scaffold(
            body: Builder(
              builder: (value) {
                context = value;
                return const SizedBox();
              },
            ),
          ),
        ),
      ),
    );
    final controller = showAppSnackBar(
      context,
      const SnackBar(content: Text('Notice')),
    );
    await tester.pump();
    expect(find.byKey(const ValueKey('app-snack-bar-slide')), findsNothing);
    controller.close();
    await tester.pumpAndSettle();
    expect(find.text('Notice'), findsNothing);
  });
}
