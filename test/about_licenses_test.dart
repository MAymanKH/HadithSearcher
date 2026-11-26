import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hadithsearcher/l10n/localization.dart';
import 'package:hadithsearcher/services/update_service.dart';
import 'package:hadithsearcher/views/about/about_view.dart';
import 'package:provider/provider.dart';

void main() {
  testWidgets('license list and details have no back tooltip', (tester) async {
    tester.view.physicalSize = const Size(390, 850);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    LicenseRegistry.reset();
    addTearDown(LicenseRegistry.reset);
    LicenseRegistry.addLicense(
      () => Stream.value(
        const LicenseEntryWithLineBreaks([
          'Example package',
        ], 'Example license'),
      ),
    );
    final updates = UpdateService();
    addTearDown(updates.dispose);
    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: updates,
        child: const MaterialApp(
          locale: Locale('ar'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: AboutView(),
        ),
      ),
    );
    final link = find.text('تراخيص المكتبات والخطوط');
    await tester.ensureVisible(link);
    await tester.tap(link);
    await tester.pumpAndSettle();

    final back = find.byType(BackButton);
    Future<void> verifyBackTooltipHidden() async {
      expect(back, findsOneWidget);
      expect(TooltipVisibility.of(tester.element(back)), isFalse);
      final label = MaterialLocalizations.of(tester.element(back))
          .backButtonTooltip;
      final hold = await tester.startGesture(tester.getCenter(back));
      await tester.pump(const Duration(seconds: 1));
      expect(find.text(label), findsNothing);
      await hold.cancel();
      await tester.pumpAndSettle();
    }

    final package = find.text('Example package');
    await verifyBackTooltipHidden();
    await tester.tap(package);
    await tester.pumpAndSettle();
    await verifyBackTooltipHidden();
    await tester.tap(back);
    await tester.pumpAndSettle();
    expect(package, findsOneWidget);
    await tester.tap(back);
    await tester.pumpAndSettle();
    expect(find.byType(AboutView), findsOneWidget);
  });
}
