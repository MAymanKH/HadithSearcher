import 'package:flutter/material.dart';

class AppSelectionTile extends StatelessWidget {
  final Widget title;
  final bool? selected;
  final bool multiple;
  final Widget? leading;
  final VoidCallback? onTap;

  const AppSelectionTile({
    super.key,
    required this.title,
    required this.selected,
    required this.onTap,
    this.multiple = false,
    this.leading,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
      child: ListTile(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        selected: selected == true,
        selectedTileColor: colors.primaryContainer,
        selectedColor: colors.onPrimaryContainer,
        title: title,
        leading: leading,
        trailing: multiple
            ? Checkbox(
                value: selected,
                tristate: true,
                onChanged: onTap == null ? null : (_) => onTap!(),
              )
            : selected == true
            ? const Icon(Icons.check)
            : null,
        enabled: onTap != null,
        onTap: onTap,
      ),
    );
  }
}
