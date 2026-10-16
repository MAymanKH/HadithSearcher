import 'package:flutter/material.dart';
import 'app_selection_tile.dart';
import 'selection_sheet.dart';

/// Opens choices in the same bottom sheet layout as the search filters.
class AppDropdown<T> extends StatelessWidget {
  final String title;
  final T value;
  final List<DropdownMenuItem<T>> items;
  final ValueChanged<T?> onChanged;
  final InputDecoration decoration;
  final bool _settingsRow;

  const AppDropdown({
    super.key,
    required this.title,
    required this.value,
    required this.items,
    required this.onChanged,
    this.decoration = const InputDecoration(
      border: InputBorder.none,
      enabledBorder: InputBorder.none,
      focusedBorder: InputBorder.none,
      contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
    ),
  }) : _settingsRow = false;

  const AppDropdown.settings({
    super.key,
    required this.title,
    required this.value,
    required this.items,
    required this.onChanged,
  }) : decoration = const InputDecoration(),
       _settingsRow = true;

  Future<void> _select(BuildContext context) async {
    final selection = await showModalBottomSheet<T>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (context) => SelectionSheet(
        title: title,
        child: ListView.builder(
          shrinkWrap: true,
          itemCount: items.length,
          itemBuilder: (context, index) {
            final item = items[index];
            return AppSelectionTile(
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
    if (_settingsRow) {
      final colors = Theme.of(context).colorScheme;
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
        child: Material(
          color: colors.surfaceContainer,
          borderRadius: BorderRadius.circular(16),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: () => _select(context),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
              child: Row(
                children: [
                  Expanded(
                    child: Text(title, style: const TextStyle(fontSize: 18)),
                  ),
                  const SizedBox(width: 16),
                  Flexible(
                    child: Align(
                      alignment: AlignmentDirectional.centerEnd,
                      child: DefaultTextStyle.merge(
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(color: colors.onSurfaceVariant),
                        child: selected.child,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Icon(
                    Icons.expand_more_rounded,
                    size: 22,
                    color: colors.onSurfaceVariant,
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }
    return Semantics(
      button: true,
      label: title,
      child: InkWell(
        borderRadius: BorderRadius.circular(30),
        onTap: () => _select(context),
        child: InputDecorator(
          decoration: decoration,
          child: Row(
            children: [
              Expanded(
                child: DefaultTextStyle.merge(
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  child: selected.child,
                ),
              ),
              const SizedBox(width: 8),
              Icon(
                Icons.expand_more_rounded,
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
