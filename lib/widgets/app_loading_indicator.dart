import 'package:flutter/material.dart';

/// Single app-wide loading indicator.
///
/// All loading states use this centered circular spinner so sheets,
/// inline expansions, pickers, and full screens look consistent.
/// It fades (and slightly scales) in on appearance so the switch
/// from content to loading does not pop.
class AppLoadingIndicator extends StatelessWidget {
  final EdgeInsetsGeometry padding;

  const AppLoadingIndicator({
    super.key,
    this.padding = const EdgeInsets.all(24),
  });

  @override
  Widget build(BuildContext context) {
    final child = Padding(
      padding: padding,
      child: const Center(child: CircularProgressIndicator()),
    );
    if (MediaQuery.disableAnimationsOf(context)) return child;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 350),
      curve: Curves.easeOutCubic,
      builder: (context, value, child) => Opacity(
        opacity: value,
        child: Transform.scale(
          scale: 0.92 + 0.08 * value,
          child: child,
        ),
      ),
      child: child,
    );
  }
}

/// Eases the transition between a loading state and its content.
///
/// Wraps [child] and [loadingWidget] in an [AnimatedSwitcher] with a
/// fade so neither the spinner appearing nor the content arriving pops
/// in abruptly. The two sides are distinguished by key, so callers only
/// pass the current [loading] flag.
class AppLoadingSwitcher extends StatelessWidget {
  final bool loading;
  final Widget child;
  final Widget loadingWidget;
  final Duration duration;

  const AppLoadingSwitcher({
    super.key,
    required this.loading,
    required this.child,
    this.loadingWidget = const AppLoadingIndicator(),
    this.duration = const Duration(milliseconds: 350),
  });

  @override
  Widget build(BuildContext context) {
    final effectiveDuration = MediaQuery.disableAnimationsOf(context)
        ? Duration.zero
        : duration;
    return AnimatedSwitcher(
      duration: effectiveDuration,
      switchInCurve: Curves.easeOutCubic,
      switchOutCurve: Curves.easeInCubic,
      layoutBuilder: (current, previous) => Stack(
        alignment: Alignment.topCenter,
        children: [...previous, if (current != null) current],
      ),
      transitionBuilder: (child, animation) => SizeTransition(
        sizeFactor: animation,
        alignment: Alignment.topCenter,
        child: FadeTransition(opacity: animation, child: child),
      ),
      child: loading
          ? KeyedSubtree(
              key: const ValueKey('loading'),
              child: loadingWidget,
            )
          : KeyedSubtree(key: const ValueKey('content'), child: child),
    );
  }
}
