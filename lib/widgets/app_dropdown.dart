import 'package:flutter/material.dart';

import '../l10n/localization.dart';
import 'app_selection_tile.dart';
import 'app_input_button.dart';
import 'selection_sheet.dart';
import 'app_bottom_sheet.dart';

/// Opens choices in the same bottom sheet layout as the search filters.
class AppDropdown<T> extends StatelessWidget {
  final String title;
  final T value;
  final List<DropdownMenuItem<T>> items;
  final ValueChanged<T?> onChanged;
  final InputDecoration decoration;
  final Widget Function(BuildContext, T)? itemLeadingBuilder;
  final T? defaultValue;
  final bool _settingsRow;

  const AppDropdown({
    super.key,
    required this.title,
    required this.value,
    required this.items,
    required this.onChanged,
    this.itemLeadingBuilder,
    this.decoration = const InputDecoration(),
  }) : defaultValue = null,
       _settingsRow = false;

  const AppDropdown.settings({
    super.key,
    required this.title,
    required this.value,
    this.defaultValue,
    required this.items,
    required this.onChanged,
    this.itemLeadingBuilder,
  }) : decoration = const InputDecoration(),
       _settingsRow = true;

  Future<void> _select(BuildContext context) async {
    final selection = await showAppBottomSheet<T>(
      context: context,
      shape: SelectionSheet.shape,
      builder: (context, scrollController) => SelectionSheet(
        title: title,
        child: ListView.builder(
          controller: scrollController,
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
    final theme = Theme.of(context);
    const arrowIconSize = 24.0;
    final arrowSlotWidth =
        theme.inputDecorationTheme.suffixIconConstraints?.minWidth ??
        kMinInteractiveDimension;
    final arrow = Icon(
      Icons.expand_more_rounded,
      size: arrowIconSize,
      color: theme.colorScheme.onSurface,
    );
    final resetValue = defaultValue;
    final suffix = resetValue == null || value == resetValue
        ? arrow
        : Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                constraints: const BoxConstraints(
                  minWidth: kMinInteractiveDimension,
                  minHeight: kMinInteractiveDimension,
                ),
                padding: EdgeInsets.zero,
                tooltip: context.l10n.resetSetting(title),
                icon: const Icon(Icons.restore_outlined, size: 20),
                onPressed: () => onChanged(resetValue),
              ),
              SizedBox(
                width: (arrowSlotWidth + arrowIconSize) / 2,
                child: Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: arrow,
                ),
              ),
            ],
          );
    final field = Semantics(
      button: true,
      label: title,
      child: AppInputButton(
        onTap: () => _select(context),
        decoration:
            (_settingsRow ? InputDecoration(labelText: title) : decoration)
                .copyWith(suffixIcon: suffix),
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
