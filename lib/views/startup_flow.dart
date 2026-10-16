import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/telemetry/telemetry_service.dart';
import '../viewmodels/settings_viewmodel.dart';
import '../widgets/update_prompt.dart';
import '../widgets/app_loading_indicator.dart';
import 'main_shell.dart';
import 'privacy/telemetry_consent_view.dart';
import 'welcome/welcome_view.dart';

class StartupFlow extends StatelessWidget {
  const StartupFlow({super.key});

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsViewModel>();
    final telemetry = context.watch<TelemetryService>();
    if (settings.isLoading) {
      return const Scaffold(body: AppLoadingIndicator());
    }

    final Widget page;
    if (!settings.welcomeCompleted) {
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
          : const Duration(milliseconds: 400),
      switchInCurve: Curves.easeInOutCubic,
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
        child: SlideTransition(
          position: animation.drive(
            Tween(begin: const Offset(0, .025), end: Offset.zero),
          ),
          child: child,
        ),
      ),
      child: page,
    );
  }
}
