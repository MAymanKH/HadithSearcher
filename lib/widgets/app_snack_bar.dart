import 'package:flutter/material.dart';

class AppScaffoldMessenger extends StatelessWidget {
  const AppScaffoldMessenger({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    // ScaffoldMessenger otherwise removes snackbars immediately when an
    // accessibility service is active, even when reduced motion is off.
    return MediaQuery(
      data: media.copyWith(accessibleNavigation: false),
      child: ScaffoldMessenger(
        child: MediaQuery(data: media, child: child),
      ),
    );
  }
}

ScaffoldFeatureController<SnackBar, SnackBarClosedReason> showAppSnackBar(
  BuildContext context,
  SnackBar snackBar,
) {
  return ScaffoldMessenger.of(context).showSnackBar(
    _SlidingSnackBar(snackBar: snackBar),
    snackBarAnimationStyle: MediaQuery.disableAnimationsOf(context)
        ? AnimationStyle.noAnimation
        : const AnimationStyle(
            duration: Duration(milliseconds: 800),
            reverseDuration: Duration(milliseconds: 800),
          ),
  );
}

class _SlidingSnackBar extends SnackBar {
  _SlidingSnackBar({required this.snackBar, super.animation, Key? key})
    : super(
        key: key ?? snackBar.key,
        content: snackBar.content,
        behavior: snackBar.behavior,
        width: snackBar.width,
        margin: snackBar.margin,
        duration: snackBar.duration,
        persist: snackBar.persist,
        action: snackBar.action,
      );

  final SnackBar snackBar;

  @override
  SnackBar withAnimation(Animation<double> newAnimation, {Key? fallbackKey}) {
    return _SlidingSnackBar(
      snackBar: snackBar,
      animation: newAnimation,
      key: key ?? fallbackKey,
    );
  }

  @override
  State<SnackBar> createState() => _SlidingSnackBarState();
}

class _SlidingSnackBarState extends State<_SlidingSnackBar> {
  @override
  Widget build(BuildContext context) {
    // Keep Material's content, actions and semantics without its varying
    // fixed/floating transitions. The messenger drives the shared slide instead.
    final content = widget.snackBar.withAnimation(
      _FullyVisibleAnimation(widget.animation!),
    );
    if (MediaQuery.disableAnimationsOf(context)) {
      return content;
    }
    return ClipRect(
      child: SlideTransition(
        key: const ValueKey('app-snack-bar-slide'),
        position: widget.animation!
            .drive(CurveTween(curve: Curves.easeInOutSine))
            .drive(Tween<Offset>(begin: const Offset(0, 1), end: Offset.zero)),
        child: content,
      ),
    );
  }
}

// Forward status notifications so Material still delivers onVisible.
class _FullyVisibleAnimation extends ProxyAnimation {
  _FullyVisibleAnimation(super.animation);

  @override
  double get value => 1;
}
