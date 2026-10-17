import 'dart:math' as math;
import 'package:flutter/material.dart';

Future<T?> showAppBottomSheet<T>({
  required BuildContext context,
  required Widget Function(BuildContext, ScrollController) builder,
  ShapeBorder? shape,
  AnimationStyle? sheetAnimationStyle,
}) => showModalBottomSheet<T>(
  context: context,
  isScrollControlled: true,
  useSafeArea: true,
  showDragHandle: true,
  shape: shape,
  sheetAnimationStyle: sheetAnimationStyle,
  builder: (_) => _SheetContent(builder: builder),
);

class _SheetContent extends StatefulWidget {
  final Widget Function(BuildContext, ScrollController) builder;

  const _SheetContent({required this.builder});

  @override
  State<_SheetContent> createState() => _SheetContentState();
}

class _SheetContentState extends State<_SheetContent> {
  final _controller = _SheetScrollController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.builder(context, _controller);
}

class _SheetScrollController extends ScrollController {
  @override
  ScrollPosition createScrollPosition(
    ScrollPhysics physics,
    ScrollContext context,
    ScrollPosition? oldPosition,
  ) => _SheetScrollPosition(
    physics: AlwaysScrollableScrollPhysics(parent: physics),
    context: context,
    oldPosition: oldPosition,
  );
}

class _SheetScrollPosition extends ScrollPositionWithSingleContext {
  _SheetScrollPosition({
    required super.physics,
    required super.context,
    super.oldPosition,
  });

  BottomSheet? _draggedSheet;
  double _sheetHeight = 0;

  bool _startSheetDrag() {
    context.storageContext.visitAncestorElements((element) {
      final widget = element.widget;
      if (widget is! BottomSheet) return true;
      final controller = widget.animationController;
      final render = element.renderObject;
      if (widget.enableDrag &&
          controller != null &&
          controller.status != AnimationStatus.reverse &&
          render is RenderBox &&
          render.hasSize &&
          render.size.height > 0) {
        _draggedSheet = widget;
        _sheetHeight = render.size.height;
        widget.onDragStart?.call(DragStartDetails());
      }
      return false;
    });
    return _draggedSheet != null;
  }

  @override
  void applyUserOffset(double delta) {
    final controller = _draggedSheet?.animationController;
    if (controller != null && controller.value < 1) {
      final restoring = math.max(delta, -(1 - controller.value) * _sheetHeight);
      controller.value -= restoring / _sheetHeight;
      delta -= restoring;
      if (delta == 0) return;
    }
    if (delta > 0) {
      final listDistance = math.max(0.0, pixels - minScrollExtent);
      final listDelta = math.min(delta, listDistance);
      if (listDelta > 0) super.applyUserOffset(listDelta);
      delta -= listDelta;
      if (delta == 0) return;
      if (_draggedSheet != null || _startSheetDrag()) {
        _draggedSheet!.animationController!.value -= delta / _sheetHeight;
        return;
      }
    }
    super.applyUserOffset(delta);
  }

  @override
  void goBallistic(double velocity) {
    final sheet = _draggedSheet;
    if (sheet == null) {
      super.goBallistic(velocity);
      return;
    }
    _draggedSheet = null;
    final controller = sheet.animationController!;
    final restored = controller.value == 1;
    final closing = !restored && (velocity < -700 || controller.value < .5);
    super.goBallistic(restored ? velocity : 0);
    sheet.onDragEnd?.call(
      DragEndDetails(
        primaryVelocity: -velocity,
        velocity: Velocity(pixelsPerSecond: Offset(0, -velocity)),
      ),
      isClosing: closing,
    );
    if (closing) {
      sheet.onClosing();
    } else {
      controller.forward();
    }
  }
}
