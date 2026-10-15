import 'package:flutter/material.dart';

/// Rounded menus with the same neutral colors as the app's cards.
class AppDropdown<T> extends StatelessWidget {
  final T value;
  final List<DropdownMenuItem<T>> items;
  final ValueChanged<T?> onChanged;
  final InputDecoration decoration;

  const AppDropdown({
    super.key,
    required this.value,
    required this.items,
    required this.onChanged,
    this.decoration = const InputDecoration(
      border: InputBorder.none,
      enabledBorder: InputBorder.none,
      focusedBorder: InputBorder.none,
      contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
    ),
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return DropdownButtonFormField<T>(
      key: ValueKey(value),
      initialValue: value,
      isExpanded: true,
      decoration: decoration,
      dropdownColor: colors.surface,
      borderRadius: BorderRadius.circular(20),
      elevation: 4,
      menuMaxHeight: 360,
      icon: Icon(Icons.expand_more_rounded, color: colors.onSurface),
      style: TextStyle(color: colors.onSurface, fontSize: 18),
      selectedItemBuilder: (_) => items.map((item) => item.child).toList(),
      items: items.map((item) {
        final selected = item.value == value;
        return DropdownMenuItem<T>(
          value: item.value,
          enabled: item.enabled,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: selected ? colors.primaryContainer : Colors.transparent,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Expanded(child: item.child),
                if (selected) ...[
                  const SizedBox(width: 8),
                  Icon(Icons.check_rounded, color: colors.onSurface, size: 20),
                ],
              ],
            ),
          ),
        );
      }).toList(),
      onChanged: onChanged,
    );
  }
}
