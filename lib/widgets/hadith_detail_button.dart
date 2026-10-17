import 'package:flutter/material.dart';
import '../core/theme/app_theme.dart';
import 'package:provider/provider.dart';
import '../viewmodels/settings_viewmodel.dart';

class HadithDetailButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback? onPressed;

  const HadithDetailButton({
    super.key,
    required this.icon,
    required this.label,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final settings = context.watch<SettingsViewModel?>();
    final textStyle =
        settings?.readingTextStyle ?? const TextStyle(fontSize: 20);
    return Align(
      alignment: AlignmentDirectional.centerStart,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: OutlinedButton.icon(
          onPressed: onPressed,
          icon: Icon(icon, size: 22),
          label: Text(label),
          style: OutlinedButton.styleFrom(
            foregroundColor: colors.onSurface,
            backgroundColor: colors.surfaceContainerHigh,
            disabledForegroundColor: AppTheme.disabledForeground(colors),
            disabledBackgroundColor: AppTheme.disabledBackground(colors),
            side: BorderSide(color: colors.outline),
            minimumSize: const Size(0, 44),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            tapTargetSize: MaterialTapTargetSize.padded,
            textStyle: textStyle.copyWith(fontSize: textStyle.fontSize! * .8),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
      ),
    );
  }
}
