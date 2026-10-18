import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../l10n/localization.dart';
import '../../widgets/app_snack_bar.dart';
import '../../core/constants/app_config.dart';
import '../../widgets/app_logo.dart';
import '../../services/telemetry/telemetry_service.dart';

class TelemetryConsentView extends StatefulWidget {
  final bool firstLaunch;

  const TelemetryConsentView({super.key, this.firstLaunch = false});

  @override
  State<TelemetryConsentView> createState() => _TelemetryConsentViewState();
}

class _TelemetryConsentViewState extends State<TelemetryConsentView> {
  late bool _diagnostics;
  late bool _analytics;

  @override
  void initState() {
    super.initState();
    TelemetryService.event('screen_viewed', {'screen': 'privacy'});
    final consent = context.read<TelemetryService>().consent;
    _diagnostics = consent.diagnostics;
    _analytics = consent.analytics;
  }

  Future<void> _save(bool diagnostics, bool analytics) async {
    final saved = await context.read<TelemetryService>().save(
      diagnostics: diagnostics,
      analytics: analytics,
    );
    if (saved && mounted && !widget.firstLaunch) Navigator.pop(context);
  }

  Future<void> _openPrivacyPolicy() async {
    final opened = await launchUrl(
      Uri.parse(privacyPolicyUrl),
      mode: LaunchMode.externalApplication,
    );
    if (!opened && mounted) {
      showAppSnackBar(
        context,
        SnackBar(content: Text(context.l10n.privacyOpenFailed)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final telemetry = context.watch<TelemetryService>();
    return Scaffold(
      appBar: widget.firstLaunch ? null : AppBar(),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) => SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: BoxConstraints(
                minHeight: (constraints.maxHeight - 48).clamp(
                  0,
                  double.infinity,
                ),
              ),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 360),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const AppLogo(),
                      const SizedBox(height: 20),
                      Text(
                        context.l10n.consentTitle,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        context.l10n.consentDescription,
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontSize: 14, height: 1.5),
                      ),
                      const SizedBox(height: 24),
                      CheckboxListTile(
                        key: const Key('analytics-consent'),
                        contentPadding: EdgeInsets.zero,
                        controlAffinity: ListTileControlAffinity.leading,
                        title: Text(context.l10n.analyticsConsent),
                        value: _analytics,
                        onChanged: telemetry.saving
                            ? null
                            : (value) => setState(() => _analytics = value!),
                      ),
                      CheckboxListTile(
                        key: const Key('diagnostics-consent'),
                        contentPadding: EdgeInsets.zero,
                        controlAffinity: ListTileControlAffinity.leading,
                        title: Text(context.l10n.diagnosticsConsent),
                        value: _diagnostics,
                        onChanged: telemetry.saving
                            ? null
                            : (value) => setState(() => _diagnostics = value!),
                      ),
                      if (telemetry.error != null)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          child: Text(
                            localizedError(telemetry.error!, context.l10n),
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.error,
                            ),
                          ),
                        ),
                      const SizedBox(height: 12),
                      ElevatedButton(
                        key: const Key('save-telemetry-consent'),
                        style: ElevatedButton.styleFrom(
                          minimumSize: const Size.fromHeight(48),
                        ),
                        onPressed: telemetry.saving
                            ? null
                            : () => _save(_diagnostics, _analytics),
                        child: Text(context.l10n.continueAction),
                      ),
                      const SizedBox(height: 8),
                      TextButton(
                        onPressed: _openPrivacyPolicy,
                        child: Text(context.l10n.privacyPolicy),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
