import 'package:flutter/material.dart';

class AppSelectionTile extends StatelessWidget {
  final Widget title;
  final bool selected;
  final VoidCallback? onTap;

  const AppSelectionTile({
    super.key,
    required this.title,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
      child: ListTile(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        selected: selected,
        selectedTileColor: colors.primaryContainer,
        selectedColor: colors.onSurface,
        title: title,
        trailing: selected ? const Icon(Icons.check) : null,
        enabled: onTap != null,
        onTap: onTap,
      ),
    );
  }
}
