import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../l10n/localization.dart';
import '../../viewmodels/settings_viewmodel.dart';
import '../../services/telemetry/telemetry_service.dart';
import '../../widgets/app_logo.dart';
import '../../widgets/appearance_preferences.dart';

class WelcomeView extends StatefulWidget {
  const WelcomeView({super.key});

  @override
  State<WelcomeView> createState() => _WelcomeViewState();
}

class _WelcomeViewState extends State<WelcomeView> {
  bool _saving = false;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    TelemetryService.event('screen_viewed', {'screen': 'welcome'});
  }

  Future<void> _continue() async {
    setState(() {
      _saving = true;
      _failed = false;
    });
    try {
      final saved = await context.read<SettingsViewModel>().completeWelcome();
      if (mounted) setState(() => _failed = !saved);
    } catch (_) {
      if (mounted) setState(() => _failed = true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return Scaffold(
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) => SingleChildScrollView(
            padding: const EdgeInsets.symmetric(vertical: 32),
            child: ConstrainedBox(
              constraints: BoxConstraints(
                minHeight: (constraints.maxHeight - 64).clamp(
                  0,
                  double.infinity,
                ),
              ),
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _content(
                      Column(
                        children: [
                          const Center(child: AppLogo(size: 100)),
                          const SizedBox(height: 24),
                          FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text(
                              l.welcomeTitle,
                              maxLines: 1,
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                          FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text(
                              l.welcomeDescription,
                              maxLines: 1,
                              textAlign: TextAlign.center,
                              style: const TextStyle(fontSize: 14, height: 1.5),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                    AbsorbPointer(
                      absorbing: _saving,
                      child: const AppearancePreferences(),
                    ),
                    const SizedBox(height: 16),
                    _content(
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(
                            l.apiLanguageNotice,
                            textAlign: TextAlign.center,
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                          const SizedBox(height: 24),
                          if (_failed) ...[
                            Text(
                              l.preferencesSaveFailed,
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: Theme.of(context).colorScheme.error,
                              ),
                            ),
                            const SizedBox(height: 12),
                          ],
                          ElevatedButton(
                            key: const Key('complete-welcome'),
                            style: ElevatedButton.styleFrom(
                              minimumSize: const Size.fromHeight(52),
                            ),
                            onPressed: _saving ? null : _continue,
                            child: Text(l.continueAction),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _content(Widget child) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 24),
    child: Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 440),
        child: child,
      ),
    ),
  );
}
