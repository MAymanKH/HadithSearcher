import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

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
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('تعذر فتح سياسة الخصوصية.')));
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
                      const Text(
                        'الموافقة على مشاركة البيانات',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        'المشاركة اختيارية ويمكن تغيير اختيارك لاحقاً.',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 16, height: 1.5),
                      ),
                      const SizedBox(height: 24),
                      CheckboxListTile(
                        key: const Key('analytics-consent'),
                        contentPadding: EdgeInsets.zero,
                        controlAffinity: ListTileControlAffinity.leading,
                        title: const Text(
                          'أوافق على مشاركة إحصاءات الاستخدام.',
                        ),
                        value: _analytics,
                        onChanged: telemetry.saving
                            ? null
                            : (value) => setState(() => _analytics = value!),
                      ),
                      CheckboxListTile(
                        key: const Key('diagnostics-consent'),
                        contentPadding: EdgeInsets.zero,
                        controlAffinity: ListTileControlAffinity.leading,
                        title: const Text('أوافق على مشاركة تقارير الأعطال.'),
                        value: _diagnostics,
                        onChanged: telemetry.saving
                            ? null
                            : (value) => setState(() => _diagnostics = value!),
                      ),
                      if (telemetry.error != null)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          child: Text(
                            telemetry.error!,
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
                        child: const Text('متابعة'),
                      ),
                      const SizedBox(height: 8),
                      TextButton(
                        onPressed: _openPrivacyPolicy,
                        child: const Text('سياسة الخصوصية'),
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
