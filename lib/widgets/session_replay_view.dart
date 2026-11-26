import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';

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
  final _boundaryKey = GlobalKey();
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
      _timer ??= Timer.periodic(const Duration(seconds: 1), (_) => _capture());
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
    final tap = _tap;
    _tap = null;
    unawaited(widget.telemetry.captureReplay(_captureFrame, tap));
  }

  Future<({Size size, Uint8List png})?> _captureFrame() async {
    if (!mounted ||
        !widget.telemetry.replayEnabled ||
        WidgetsBinding.instance.lifecycleState != AppLifecycleState.resumed) {
      return null;
    }
    final boundary = _boundaryKey.currentContext?.findRenderObject();
    if (boundary is! RenderRepaintBoundary ||
        !boundary.hasSize ||
        boundary.size.isEmpty) {
      return null;
    }

    final size = boundary.size;
    final image = await boundary.toImage();
    try {
      final data = await image.toByteData(format: ui.ImageByteFormat.png);
      if (data == null ||
          !mounted ||
          !widget.telemetry.replayEnabled ||
          WidgetsBinding.instance.lifecycleState != AppLifecycleState.resumed) {
        return null;
      }
      return (size: size, png: Uint8List.sublistView(data));
    } finally {
      image.dispose();
    }
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
    child: RepaintBoundary(key: _boundaryKey, child: widget.child),
  );

  @override
  void dispose() {
    _timer?.cancel();
    widget.telemetry.removeListener(_updateRecording);
    super.dispose();
  }
}
