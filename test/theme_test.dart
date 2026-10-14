import 'package:flutter_test/flutter_test.dart';
import 'package:hadithsearcher/core/theme/app_theme.dart';

void main() {
  for (final entry in {
    'light': AppTheme.lightTheme,
    'dark': AppTheme.darkTheme,
  }.entries) {
    test('selected checkbox mark is visible in ${entry.key} theme', () {
      final colors = entry.value.colorScheme;
      final luminance = [
        colors.primary.computeLuminance(),
        colors.onPrimary.computeLuminance(),
      ]..sort();
      final contrast = (luminance.last + 0.05) / (luminance.first + 0.05);
      expect(contrast, greaterThanOrEqualTo(3));
    });
  }
}
