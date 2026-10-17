import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hadithsearcher/core/theme/app_theme.dart';
import 'package:hadithsearcher/models/settings.dart';
import 'package:hadithsearcher/widgets/app_dropdown.dart';

double contrast(Color foreground, Color background) {
  final values = [foreground.computeLuminance(), background.computeLuminance()]
    ..sort();
  return (values.last + .05) / (values.first + .05);
}

void main() {
  for (final palette in ColorSchemePreference.values) {
    for (final brightness in Brightness.values) {
      final theme = AppTheme.build(palette, brightness);
      final colors = theme.colorScheme;
      test(
        '${palette.name}-${brightness.name} inactive controls and actions',
        () {
          final minimum = palette == ColorSchemePreference.highContrast
              ? 7.0
              : 4.5;
          expect(
            contrast(
              AppTheme.unavailableActionForeground(colors),
              colors.inverseSurface,
            ),
            greaterThanOrEqualTo(minimum),
            reason: 'Tappable action labels are normal text',
          );
          final side = WidgetStateProperty.resolveAs<BorderSide?>(
            theme.checkboxTheme.side,
            {},
          );
          expect(side, isNotNull);
          expect(side!.width, greaterThanOrEqualTo(2));
          final track = theme.switchTheme.trackColor!.resolve({})!;
          final thumb = theme.switchTheme.thumbColor!.resolve({})!;
          expect(
            contrast(thumb, track),
            greaterThanOrEqualTo(3),
            reason: 'Off thumb remains visible',
          );
          final trackOutline = theme.switchTheme.trackOutlineColor!.resolve(
            {},
          )!;
          for (final background in [
            colors.surface,
            colors.surfaceContainer,
            colors.surfaceContainerHigh,
          ]) {
            expect(contrast(side.color, background), greaterThanOrEqualTo(3));
            expect(contrast(trackOutline, background), greaterThanOrEqualTo(3));
          }
          expect(
            theme.switchTheme.trackOutlineWidth!.resolve({}),
            greaterThanOrEqualTo(2),
          );
          for (final pair in [
            (theme.textButtonTheme.style!, colors.surface),
            (theme.outlinedButtonTheme.style!, colors.surface),
            (theme.iconButtonTheme.style!, colors.surface),
            (theme.elevatedButtonTheme.style!, colors.secondary),
            (theme.filledButtonTheme.style!, colors.primary),
          ]) {
            final border = pair.$1.side?.resolve({WidgetState.focused});
            expect(
              border,
              isNotNull,
              reason: 'Keyboard focus needs a visible border',
            );
            expect(border!.width, greaterThanOrEqualTo(2));
            expect(contrast(border.color, pair.$2), greaterThanOrEqualTo(3));
          }
        },
      );

      testWidgets(
        '${palette.name}-${brightness.name} keyboard focus reaches dropdown decoration',
        (tester) async {
          var selection = 'one';
          await tester.pumpWidget(
            MaterialApp(
              theme: theme,
              home: Scaffold(
                body: AppDropdown<String>.settings(
                  title: 'Choose',
                  value: selection,
                  items: const [
                    DropdownMenuItem(value: 'one', child: Text('One')),
                  ],
                  onChanged: (value) => selection = value!,
                ),
              ),
            ),
          );
          await tester.sendKeyEvent(LogicalKeyboardKey.tab);
          await tester.pumpAndSettle();
          final decorator = tester.widget<InputDecorator>(
            find.byType(InputDecorator),
          );
          expect(decorator.isFocused, isTrue);
          final border = theme.inputDecorationTheme.focusedBorder!;
          expect(border.borderSide.width, greaterThanOrEqualTo(2));
          expect(
            contrast(border.borderSide.color, colors.surfaceContainerHigh),
            greaterThanOrEqualTo(3),
          );
          await tester.sendKeyEvent(LogicalKeyboardKey.enter);
          await tester.pumpAndSettle();
          expect(find.byType(BottomSheet), findsOneWidget);
          await tester.pumpWidget(const SizedBox());
        },
      );
    }
  }
}
