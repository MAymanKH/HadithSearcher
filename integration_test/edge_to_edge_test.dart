import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:hadithsearcher/app.dart';
import 'package:hadithsearcher/core/constants/routes.dart';
import 'package:hadithsearcher/models/settings.dart';
import 'package:hadithsearcher/services/telemetry/telemetry_service.dart';
import 'package:hadithsearcher/viewmodels/settings_viewmodel.dart';
import 'package:hadithsearcher/views/similar_hadith/similar_hadith_view.dart';

import '../test/telemetry/fake_backend.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'Android insets protect controls, themes, routes, and the keyboard',
    (tester) async {
      await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
      final preferences = await SharedPreferences.getInstance();
      await preferences.clear();
      final telemetry = TelemetryService(
        preferences: preferences,
        backend: FakeBackend(),
      );
      addTearDown(telemetry.dispose);
      addTearDown(() => SystemChrome.setPreferredOrientations([]));

      await tester.pumpWidget(
        HadithSearcherApp(
          initialThemeMode: ThemeMode.light,
          telemetry: telemetry,
        ),
      );
      await tester.pumpAndSettle();
      await tester.ensureVisible(
        find.byKey(const Key('save-telemetry-consent')),
      );
      await tester.tap(find.byKey(const Key('save-telemetry-consent')));
      await tester.pumpAndSettle();

      for (final orientation in [
        DeviceOrientation.portraitUp,
        DeviceOrientation.landscapeLeft,
      ]) {
        await SystemChrome.setPreferredOrientations([orientation]);
        for (var attempt = 0; attempt < 20; attempt++) {
          await tester.pump(const Duration(milliseconds: 100));
          final size = tester.view.physicalSize;
          if ((size.width > size.height) ==
              (orientation == DeviceOrientation.landscapeLeft)) {
            break;
          }
        }
        await tester.pumpAndSettle();
        final size = tester.view.physicalSize / tester.view.devicePixelRatio;
        final padding = EdgeInsets.fromViewPadding(
          tester.view.viewPadding,
          tester.view.devicePixelRatio,
        );
        expect(
          size.width > size.height,
          orientation == DeviceOrientation.landscapeLeft,
        );
        expect(padding, isNot(EdgeInsets.zero));

        for (final theme in [ThemePreference.light, ThemePreference.dark]) {
          final settings = tester
              .element(find.byType(NavigationBar))
              .read<SettingsViewModel>();
          await settings.setTheme(theme);
          await tester.pumpAndSettle();
          final icons = theme == ThemePreference.light
              ? Brightness.dark
              : Brightness.light;
          expect(SystemChrome.latestStyle!.statusBarIconBrightness, icons);
          expect(
            SystemChrome.latestStyle!.systemNavigationBarIconBrightness,
            icons,
          );
          expect(SystemChrome.latestStyle!.statusBarColor, isNull);
          expect(SystemChrome.latestStyle!.systemNavigationBarColor, isNull);

          for (final label in ['البحث', 'المفضلة', 'الإعدادات', 'حول']) {
            await tester.tap(find.text(label).last);
            await tester.pumpAndSettle();
            final navigation = tester.getRect(find.byType(NavigationBar));
            expect(navigation.bottom, closeTo(size.height, 1));
            expect(navigation.left, greaterThanOrEqualTo(padding.left));
            expect(
              navigation.right,
              lessThanOrEqualTo(size.width - padding.right),
            );
            for (final element
                in find.byType(NavigationDestination).evaluate()) {
              final bounds = tester.getRect(find.byWidget(element.widget));
              expect(
                bounds.bottom,
                lessThanOrEqualTo(size.height - padding.bottom + 1),
              );
            }
            expect(
              tester.takeException(),
              isNull,
              reason: '${orientation.name}, ${theme.name}, $label',
            );
          }
        }
        await tester.tap(find.text('البحث').last);
        await tester.pumpAndSettle();
        final context = tester.element(find.byType(TextField));
        Navigator.of(context).pushNamed(similarHadithRoute);
        await tester.pumpAndSettle();
        final content = find
            .descendant(
              of: find.byType(SimilarHadithView),
              matching: find.byType(Center),
            )
            .first;
        final bounds = tester.getRect(content);
        expect(
          bounds.bottom,
          lessThanOrEqualTo(size.height - padding.bottom + 1),
        );
        expect(bounds.left, greaterThanOrEqualTo(padding.left));
        expect(bounds.right, lessThanOrEqualTo(size.width - padding.right));
        Navigator.of(tester.element(content)).pop();
        await tester.pumpAndSettle();
      }

      await SystemChrome.setPreferredOrientations([
        DeviceOrientation.portraitUp,
      ]);
      for (var attempt = 0; attempt < 20; attempt++) {
        await tester.pump(const Duration(milliseconds: 100));
        if (tester.view.physicalSize.height > tester.view.physicalSize.width) {
          break;
        }
      }
      await tester.pumpAndSettle();
      await tester.tap(find.byType(TextField));
      for (var attempt = 0; attempt < 20; attempt++) {
        await tester.pump(const Duration(milliseconds: 100));
        if (tester.view.viewInsets.bottom > 0) break;
      }
      await tester.pumpAndSettle();
      expect(tester.view.viewInsets.bottom, greaterThan(0));
      final keyboardTop =
          (tester.view.physicalSize.height - tester.view.viewInsets.bottom) /
          tester.view.devicePixelRatio;
      expect(
        tester.getRect(find.byType(TextField)).bottom,
        lessThan(keyboardTop),
      );
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );
}
