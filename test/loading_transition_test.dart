import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hadithsearcher/widgets/app_loading_indicator.dart';

void main() {
  testWidgets('indicator renders the single circular style', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: AppLoadingIndicator())),
    );
    // The spinner itself animates forever, so advance fixed frames
    // instead of settling.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });

  testWidgets('switcher cross-fades between spinner and content', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: AppLoadingSwitcher(loading: true, child: Text('done')),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.byType(AppLoadingIndicator), findsOneWidget);
    expect(find.text('done'), findsNothing);

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: AppLoadingSwitcher(loading: false, child: Text('done')),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 50));
    // Incoming content arrives while the outgoing spinner fades out.
    expect(find.text('done'), findsOneWidget);

    await tester.pumpAndSettle();
    expect(find.text('done'), findsOneWidget);
    expect(find.byType(AppLoadingIndicator), findsNothing);
  });
}
