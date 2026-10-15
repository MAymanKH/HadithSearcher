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
        selectedColor: colors.onSurface,
        title: title,
        leading: leading,
        trailing: multiple
            ? Checkbox(
                value: selected,
                tristate: true,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(5),
                ),
                side: WidgetStateBorderSide.resolveWith(
                  (_) => BorderSide(color: colors.onSurface, width: 1.5),
                ),
                fillColor: WidgetStateProperty.resolveWith(
                  (states) => states.contains(WidgetState.selected)
                      ? colors.onSurface
                      : Colors.transparent,
                ),
                checkColor: colors.surface,
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
