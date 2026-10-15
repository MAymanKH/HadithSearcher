import 'package:flutter/material.dart';
import 'app_selection_tile.dart';

/// Opens choices in the same bottom sheet layout as the search filters.
class AppDropdown<T> extends StatelessWidget {
  final String title;
  final T value;
  final List<DropdownMenuItem<T>> items;
  final ValueChanged<T?> onChanged;
  final InputDecoration decoration;

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
  });

  Future<void> _select(BuildContext context) async {
    final selection = await showModalBottomSheet<T>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (context) => SizedBox(
        height: MediaQuery.sizeOf(context).height * .8,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(20),
              child: Text(title, style: Theme.of(context).textTheme.titleLarge),
            ),
            Expanded(
              child: ListView.builder(
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
          ],
        ),
      ),
    );
    if (context.mounted && selection != null) onChanged(selection);
  }

  @override
  Widget build(BuildContext context) {
    final selected = items.firstWhere((item) => item.value == value);
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
