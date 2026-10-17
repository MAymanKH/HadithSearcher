import 'package:flutter/material.dart';

/// A button styled as an input, with focus forwarded to its decoration.
class AppInputButton extends StatefulWidget {
  final InputDecoration decoration;
  final Widget child;
  final VoidCallback onTap;

  const AppInputButton({
    super.key,
    required this.decoration,
    required this.child,
    required this.onTap,
  });

  @override
  State<AppInputButton> createState() => _AppInputButtonState();
}

class _AppInputButtonState extends State<AppInputButton> {
  bool _focused = false;

  @override
  Widget build(BuildContext context) => InkWell(
    borderRadius: BorderRadius.circular(16),
    onFocusChange: (focused) => setState(() => _focused = focused),
    onTap: widget.onTap,
    child: InputDecorator(
      isFocused: _focused,
      decoration: widget.decoration,
      child: widget.child,
    ),
  );
}
