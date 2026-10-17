import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/telemetry/telemetry_service.dart';
import '../viewmodels/settings_viewmodel.dart';
import '../widgets/update_prompt.dart';
import '../widgets/app_logo.dart';
import 'main_shell.dart';
import 'privacy/telemetry_consent_view.dart';
import 'welcome/welcome_view.dart';

class StartupFlow extends StatefulWidget {
  final Future<void>? startupReady;

  const StartupFlow({super.key, this.startupReady});

  @override
  State<StartupFlow> createState() => _StartupFlowState();
}

class _StartupFlowState extends State<StartupFlow> {
  bool _firstFrame = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await widget.startupReady;
      if (mounted) setState(() => _firstFrame = false);
    });
  }

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsViewModel>();
    final telemetry = context.watch<TelemetryService>();
    final Widget page;
    if (_firstFrame || settings.isLoading) {
      page = const Scaffold(
        key: ValueKey('startup-splash'),
        body: Center(child: AppLogo()),
      );
    } else if (!settings.welcomeCompleted) {
      page = const WelcomeView(key: ValueKey('welcome'));
    } else if (telemetry.needsConsent) {
      page = const TelemetryConsentView(
        key: ValueKey('consent'),
        firstLaunch: true,
      );
    } else {
      page = const UpdatePrompt(key: ValueKey('main'), child: MainShell());
    }

    return _StartupTransition(
      key: const ValueKey('startup-transition'),
      disableAnimations: MediaQuery.disableAnimationsOf(context),
      child: page,
    );
  }
}

class _StartupTransition extends StatefulWidget {
  final Widget child;
  final bool disableAnimations;

  const _StartupTransition({
    super.key,
    required this.child,
    required this.disableAnimations,
  });

  @override
  State<_StartupTransition> createState() => _StartupTransitionState();
}

class _StartupTransitionState extends State<_StartupTransition>
    with SingleTickerProviderStateMixin {
  late final _controller =
      AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 800),
        value: 1,
      )..addStatusListener((status) {
        if (status == AnimationStatus.completed && _previous != null) {
          setState(() => _previous = null);
        }
      });
  late final _incoming = _controller.drive(
    CurveTween(curve: const Interval(.15, 1, curve: Curves.easeInOutCubic)),
  );
  late final _outgoing = ReverseAnimation(
    _controller.drive(
      CurveTween(curve: const Interval(0, .6, curve: Curves.easeInOutCubic)),
    ),
  );
  Widget? _previous;
  int _revision = 0;

  @override
  void didUpdateWidget(_StartupTransition oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.disableAnimations) {
      _revision++;
      _previous = null;
      _controller.value = 1;
      return;
    }
    if (oldWidget.child.key == widget.child.key) return;
    _previous = oldWidget.child;
    _controller.value = 0;
    final revision = ++_revision;
    // Mount the destination first. Start on a fresh frame so its initial
    // layout does not consume the animation's elapsed time.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      WidgetsBinding.instance.scheduleFrameCallback((_) {
        if (mounted && revision == _revision) _controller.forward();
      });
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Widget _page(
    Widget child,
    Animation<double> opacity, {
    bool outgoing = false,
  }) {
    final scale = outgoing
        ? Tween(
            begin: child.key == const ValueKey('startup-splash') ? 1.12 : 1.04,
            end: 1.0,
          )
        : Tween(begin: .94, end: 1.0);
    return KeyedSubtree(
      key: ValueKey(child.key),
      child: ExcludeFocus(
        excluding: outgoing,
        child: IgnorePointer(
          ignoring: outgoing,
          child: ExcludeSemantics(
            excluding: outgoing,
            child: FadeTransition(
              opacity: opacity,
              child: ScaleTransition(scale: opacity.drive(scale), child: child),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => Stack(
    fit: StackFit.expand,
    children: [
      if (_previous != null) _page(_previous!, _outgoing, outgoing: true),
      _page(widget.child, _incoming),
    ],
  );
}
