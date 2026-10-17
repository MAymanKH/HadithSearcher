import 'package:flutter/material.dart';

class SelectionSheet extends StatelessWidget {
  final String title;
  final Widget? trailing;
  final Widget? search;
  final Widget child;

  const SelectionSheet({
    super.key,
    required this.title,
    this.trailing,
    this.search,
    required this.child,
  });

  static ShapeBorder shape(BuildContext context) => RoundedRectangleBorder(
    borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
    side: BorderSide(
      color: Theme.of(context).colorScheme.outlineVariant,
      width: .75,
    ),
  );

  @override
  Widget build(BuildContext context) {
    final keyboard = MediaQuery.viewInsetsOf(context).bottom;
    return SafeArea(
      top: false,
      child: Padding(
        padding: EdgeInsets.only(bottom: keyboard),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: (MediaQuery.sizeOf(context).height - keyboard) * .85,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        title,
                        textAlign: trailing == null ? TextAlign.center : null,
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                    ),
                    if (trailing != null) trailing!,
                  ],
                ),
              ),
              if (search != null)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  child: search,
                ),
              Flexible(
                child: ClipRect(
                  child: Material(
                    type: MaterialType.transparency,
                    child: child,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
