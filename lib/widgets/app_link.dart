import 'package:flutter/material.dart';

class AppLink extends StatelessWidget {
  final String label;
  final VoidCallback onPressed;
  final IconData? icon;

  const AppLink({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final style = TextButton.styleFrom(
      foregroundColor: Theme.of(context).colorScheme.primary,
      textStyle: Theme.of(
        context,
      ).textTheme.bodyLarge?.copyWith(decoration: TextDecoration.none),
    );
    return TextButton(
      style: style,
      onPressed: onPressed,
      child: icon == null
          ? Text(label)
          : Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 33),
                const SizedBox(height: 5),
                Text(label),
              ],
            ),
    );
  }
}
