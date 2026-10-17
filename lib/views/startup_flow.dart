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
  const StartupFlow({super.key});

  @override
  State<StartupFlow> createState() => _StartupFlowState();
}

class _StartupFlowState extends State<StartupFlow> {
  bool _firstFrame = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
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

    return AnimatedSwitcher(
      key: const ValueKey('startup-transition'),
      duration: MediaQuery.disableAnimationsOf(context)
          ? Duration.zero
          : const Duration(milliseconds: 550),
      switchInCurve: Curves.easeOutCubic,
      switchOutCurve: Curves.easeInOutCubic,
      layoutBuilder: (current, previous) => Stack(
        fit: StackFit.expand,
        children: [
          for (final child in previous)
            ExcludeFocus(
              child: IgnorePointer(child: ExcludeSemantics(child: child)),
            ),
          ?current,
        ],
      ),
      transitionBuilder: (child, animation) => FadeTransition(
        opacity: animation,
        child: ScaleTransition(
          scale: animation.drive(
            Tween(
              begin: child.key == const ValueKey('startup-splash') ? 1.08 : .98,
              end: 1.0,
            ),
          ),
          child: SlideTransition(
            position: animation.drive(
              Tween(begin: const Offset(0, .025), end: Offset.zero),
            ),
            child: child,
          ),
        ),
      ),
      child: page,
    );
  }
}
