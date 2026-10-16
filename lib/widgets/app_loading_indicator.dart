import 'package:flutter/material.dart';

/// Single app-wide loading indicator.
///
/// All loading states use this centered circular spinner so sheets,
/// inline expansions, pickers, and full screens look consistent.
class AppLoadingIndicator extends StatelessWidget {
  final EdgeInsetsGeometry padding;

  const AppLoadingIndicator({
    super.key,
    this.padding = const EdgeInsets.all(24),
  });

  @override
  Widget build(BuildContext context) =>
      Padding(padding: padding, child: const Center(child: CircularProgressIndicator()));
}
