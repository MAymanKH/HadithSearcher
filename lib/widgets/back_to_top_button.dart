import 'package:flutter/material.dart';
import '../l10n/localization.dart';
import 'package:flutter/rendering.dart';

const _directionScrollThreshold = 100.0;

/// A floating action button that appears when user scrolls up.
class BackToTopButton extends StatefulWidget {
  final ScrollController scrollController;
  final Widget child;

  const BackToTopButton({
    super.key,
    required this.scrollController,
    required this.child,
  });

  @override
  State<BackToTopButton> createState() => _BackToTopButtonState();
}

class _BackToTopButtonState extends State<BackToTopButton> {
  bool _showButton = false;
  double _previousOffset = 0;
  double _upwardScrollDistance = 0;
  double _downwardScrollDistance = 0;

  @override
  void initState() {
    super.initState();
    widget.scrollController.addListener(_scrollListener);
  }

  @override
  void dispose() {
    widget.scrollController.removeListener(_scrollListener);
    super.dispose();
  }

  void _scrollListener() {
    final offset = widget.scrollController.offset;
    final direction = widget.scrollController.position.userScrollDirection;

    setState(() {
      if (offset >= 800) {
        if (direction == ScrollDirection.reverse) {
          _upwardScrollDistance = 0;
          _downwardScrollDistance += offset - _previousOffset;
          if (_downwardScrollDistance >= _directionScrollThreshold) {
            _showButton = false;
          }
        } else if (direction == ScrollDirection.forward) {
          _downwardScrollDistance = 0;
          final scrollDelta = _previousOffset - offset;
          _upwardScrollDistance += scrollDelta;

          if (_upwardScrollDistance >= _directionScrollThreshold) {
            _showButton = true;
          }
        }
      } else {
        _showButton = false;
        _upwardScrollDistance = 0;
        _downwardScrollDistance = 0;
      }

      _previousOffset = offset;
    });
  }

  void _scrollToTop() {
    widget.scrollController.animateTo(
      0,
      duration: const Duration(milliseconds: 500),
      curve: Curves.linear,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: widget.child,
      floatingActionButton: _showButton
          ? FloatingActionButton(
              onPressed: _scrollToTop,
              tooltip: context.l10n.backToTop,
              child: const Icon(Icons.arrow_upward),
            )
          : null,
    );
  }
}

/// Mixin to add scroll-to-top functionality to StatefulWidgets.
mixin ScrollToTopMixin<T extends StatefulWidget> on State<T> {
  late ScrollController scrollController;
  bool showBackToTopButton = false;
  double _previousOffset = 0;
  double _upwardScrollDistance = 0;
  double _downwardScrollDistance = 0;

  void initScrollController() {
    scrollController = ScrollController()..addListener(_scrollListener);
  }

  void disposeScrollController() {
    scrollController.removeListener(_scrollListener);
    scrollController.dispose();
  }

  void _scrollListener() {
    final offset = scrollController.offset;
    final direction = scrollController.position.userScrollDirection;

    setState(() {
      if (offset >= 800) {
        if (direction == ScrollDirection.reverse) {
          _upwardScrollDistance = 0;
          _downwardScrollDistance += offset - _previousOffset;
          if (_downwardScrollDistance >= _directionScrollThreshold) {
            showBackToTopButton = false;
          }
        } else if (direction == ScrollDirection.forward) {
          _downwardScrollDistance = 0;
          final scrollDelta = _previousOffset - offset;
          _upwardScrollDistance += scrollDelta;

          if (_upwardScrollDistance >= _directionScrollThreshold) {
            showBackToTopButton = true;
          }
        }
      } else {
        showBackToTopButton = false;
        _upwardScrollDistance = 0;
        _downwardScrollDistance = 0;
      }

      _previousOffset = offset;
    });
  }

  void scrollToTop() {
    scrollController.animateTo(
      0,
      duration: const Duration(milliseconds: 500),
      curve: Curves.linear,
    );
  }

  void hideBackToTopButton() {
    setState(() {
      showBackToTopButton = false;
    });
  }

  Widget? buildBackToTopButton() {
    if (!showBackToTopButton) return null;
    return FloatingActionButton(
      onPressed: scrollToTop,
      tooltip: context.l10n.backToTop,
      child: const Icon(Icons.arrow_upward),
    );
  }
}
