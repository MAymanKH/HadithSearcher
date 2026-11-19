import 'dart:async';

import 'package:flutter/material.dart';

import '../services/telemetry/telemetry_service.dart';

class SessionReplayView extends StatefulWidget {
  const SessionReplayView({
    required this.telemetry,
    required this.child,
    super.key,
  });

  final TelemetryService telemetry;
  final Widget child;

  @override
  State<SessionReplayView> createState() => _SessionReplayViewState();
}

class _SessionReplayViewState extends State<SessionReplayView> {
  Timer? _timer;
  Offset? _tap;
  int? _pointer;
  Offset? _pointerDown;

  @override
  void initState() {
    super.initState();
    widget.telemetry.addListener(_updateRecording);
    _updateRecording();
  }

  @override
  void didUpdateWidget(SessionReplayView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.telemetry == widget.telemetry) return;
    oldWidget.telemetry.removeListener(_updateRecording);
    widget.telemetry.addListener(_updateRecording);
    _updateRecording();
  }

  void _updateRecording() {
    if (widget.telemetry.replayEnabled) {
      _timer ??= Timer.periodic(const Duration(seconds: 2), (_) => _capture());
    } else {
      _timer?.cancel();
      _timer = null;
      _tap = _pointerDown = null;
      _pointer = null;
    }
  }

  void _capture() {
    if (WidgetsBinding.instance.lifecycleState != AppLifecycleState.resumed) {
      return;
    }
    final root = context.findRenderObject();
    if (root is! RenderBox || !root.hasSize || root.size.isEmpty) return;
    final controls = <Rect>[];
    final viewport = Offset.zero & root.size;
    var tap = _tap;
    _tap = null;

    var remaining = 1500;
    void visit(Element element) {
      if (remaining-- <= 0 ||
          controls.length >= 60 ||
          (element.widget is Offstage &&
              (element.widget as Offstage).offstage)) {
        return;
      }
      switch (element.widget) {
        case TextField():
          final box = element.findRenderObject();
          if (tap != null && box is RenderBox && box.hasSize) {
            final bounds =
                box.localToGlobal(Offset.zero, ancestor: root) & box.size;
            if (bounds.contains(tap!)) tap = null;
          }
          return;
        case ButtonStyleButton() ||
            IconButton() ||
            CheckboxListTile() ||
            SwitchListTile() ||
            ListTile() ||
            NavigationBar() ||
            Chip():
          final box = element.findRenderObject();
          if (box is RenderBox && box.hasSize) {
            final bounds =
                (box.localToGlobal(Offset.zero, ancestor: root) & box.size)
                    .intersect(viewport);
            if (bounds.width >= 16 && bounds.height >= 16) controls.add(bounds);
          }
          return;
        default:
          element.visitChildElements(visit);
      }
    }

    context.visitChildElements(visit);
    if (tap != null && !controls.any((bounds) => bounds.contains(tap!))) {
      tap = null;
    }
    unawaited(widget.telemetry.captureReplay(root.size, controls, tap));
  }

  @override
  Widget build(BuildContext context) => Listener(
    onPointerDown: (event) {
      if (!widget.telemetry.replayEnabled) return;
      _pointer = event.pointer;
      _pointerDown = event.localPosition;
    },
    onPointerUp: (event) {
      final down = _pointerDown;
      if (event.pointer != _pointer || down == null) return;
      _pointerDown = null;
      _pointer = null;
      if ((event.localPosition - down).distance <= 12) {
        _tap = event.localPosition;
      }
    },
    onPointerCancel: (_) {
      _pointerDown = null;
      _pointer = null;
    },
    child: widget.child,
  );

  @override
  void dispose() {
    _timer?.cancel();
    widget.telemetry.removeListener(_updateRecording);
    super.dispose();
  }
}
