import 'package:flutter/material.dart';
import 'app_selection_tile.dart';
import 'app_input_button.dart';
import 'selection_sheet.dart';

/// Opens choices in the same bottom sheet layout as the search filters.
class AppDropdown<T> extends StatelessWidget {
  final String title;
  final T value;
  final List<DropdownMenuItem<T>> items;
  final ValueChanged<T?> onChanged;
  final InputDecoration decoration;
  final Widget Function(BuildContext, T)? itemLeadingBuilder;
  final bool _settingsRow;

  const AppDropdown({
    super.key,
    required this.title,
    required this.value,
    required this.items,
    required this.onChanged,
    this.itemLeadingBuilder,
    this.decoration = const InputDecoration(),
  }) : _settingsRow = false;

  const AppDropdown.settings({
    super.key,
    required this.title,
    required this.value,
    required this.items,
    required this.onChanged,
    this.itemLeadingBuilder,
  }) : decoration = const InputDecoration(),
       _settingsRow = true;

  Future<void> _select(BuildContext context) async {
    final selection = await showModalBottomSheet<T>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      shape: SelectionSheet.shape,
      showDragHandle: true,
      builder: (context) => SelectionSheet(
        title: title,
        child: ListView.builder(
          shrinkWrap: true,
          itemCount: items.length,
          itemBuilder: (context, index) {
            final item = items[index];
            final itemValue = item.value;
            return AppSelectionTile(
              leading: itemValue == null
                  ? null
                  : itemLeadingBuilder?.call(context, itemValue),
              title: item.child,
              selected: item.value == value,
              onTap: item.enabled
                  ? () => Navigator.pop(context, item.value)
                  : null,
            );
          },
        ),
      ),
    );
    if (context.mounted && selection != null) onChanged(selection);
  }

  @override
  Widget build(BuildContext context) {
    final selected = items.firstWhere((item) => item.value == value);
    final field = Semantics(
      button: true,
      label: title,
      child: AppInputButton(
        onTap: () => _select(context),
        decoration:
            (_settingsRow ? InputDecoration(labelText: title) : decoration)
                .copyWith(
                  suffixIcon: Icon(
                    Icons.expand_more_rounded,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
        child: DefaultTextStyle.merge(
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          child: selected.child,
        ),
      ),
    );
    return _settingsRow
        ? Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
            child: field,
          )
        : field;
  }
}
