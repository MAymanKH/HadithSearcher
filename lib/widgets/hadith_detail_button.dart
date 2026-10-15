import 'package:flutter/material.dart';

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
    return Align(
      alignment: AlignmentDirectional.centerStart,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: OutlinedButton.icon(
          onPressed: onPressed,
          icon: Icon(icon, size: 22),
          label: Text(label),
          style: OutlinedButton.styleFrom(
            foregroundColor: colors.secondaryContainer,
            backgroundColor: Color.lerp(
              colors.primaryContainer,
              colors.surface,
              0.45,
            ),
            side: BorderSide(
              color: colors.secondaryContainer.withValues(alpha: 0.38),
            ),
            minimumSize: const Size(0, 44),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            tapTargetSize: MaterialTapTargetSize.padded,
            textStyle: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
      ),
    );
  }
}
