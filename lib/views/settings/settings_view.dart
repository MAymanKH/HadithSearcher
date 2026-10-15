import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../widgets/app_dropdown.dart';
import '../../models/settings.dart';
import '../../viewmodels/settings_viewmodel.dart';
import '../../services/telemetry/telemetry_service.dart';
import '../privacy/telemetry_consent_view.dart';

class SettingsView extends StatelessWidget {
  const SettingsView({super.key});

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<SettingsViewModel>();

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'الإعدادات',
          style: TextStyle(fontSize: 25, fontWeight: FontWeight.bold),
        ),
      ),
      body: ListView(
        children: [
          SingleChildScrollView(
            child: Column(
              children: [
                const SizedBox(height: 15),
                _buildThemeSection(context, vm),
                const SizedBox(height: 20),
                const Text(
                  'إعدادات نص الأحاديث والشرح',
                  style: TextStyle(fontSize: 30, fontWeight: FontWeight.bold),
                ),
                _buildFontFamilySection(context, vm),
                _buildFontWeightSection(context, vm),
                _buildFontSizeSection(context, vm),
                _buildPaddingSection(context, vm),
              ],
            ),
          ),
          Column(
            children: [
              const SizedBox(height: 30),
              _buildResetButton(context, vm),
              const SizedBox(height: 30),
              if (context.watch<TelemetryService>().canChangeConsent)
                Padding(
                  padding: const EdgeInsets.fromLTRB(10, 0, 10, 30),
                  child: Material(
                    color: Theme.of(context).colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(20),
                    clipBehavior: Clip.antiAlias,
                    child: ListTile(
                      leading: const Icon(Icons.privacy_tip_outlined),
                      title: const Text(
                        'الخصوصية والقياس الاختياري',
                        style: TextStyle(fontSize: 18),
                      ),
                      trailing: const Icon(Icons.chevron_left),
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const TelemetryConsentView(),
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildThemeSection(BuildContext context, SettingsViewModel vm) {
    return _SettingsRow(
      label: 'المظهر العام',
      child: AppDropdown<ThemePreference>(
        value: vm.settings.theme,
        onChanged: (value) {
          if (value != null) {
            vm.setTheme(value);
          }
        },
        items: ThemePreference.values
            .map(
              (t) => DropdownMenuItem(
                value: t,
                child: Text(t.arabicName, style: const TextStyle(fontSize: 18)),
              ),
            )
            .toList(),
      ),
    );
  }

  Widget _buildFontFamilySection(BuildContext context, SettingsViewModel vm) {
    return _SettingsRow(
      label: 'نوع الخط',
      child: AppDropdown<String>(
        value: vm.fontFamily,
        onChanged: (value) {
          if (value != null) vm.setFontFamily(value);
        },
        items: SettingsViewModel.fontFamilies
            .map(
              (f) => DropdownMenuItem(
                value: f,
                child: Text(
                  f,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 18, fontFamily: f),
                ),
              ),
            )
            .toList(),
      ),
    );
  }

  Widget _buildFontWeightSection(BuildContext context, SettingsViewModel vm) {
    return _SettingsRow(
      label: 'ثقل الخط',
      child: AppDropdown<FontWeightPreference>(
        value: vm.settings.fontWeight,
        onChanged: (value) {
          if (value != null) vm.setFontWeight(value);
        },
        items: FontWeightPreference.values
            .map(
              (w) => DropdownMenuItem(
                value: w,
                child: Text(w.arabicName, style: const TextStyle(fontSize: 18)),
              ),
            )
            .toList(),
      ),
    );
  }

  Widget _buildFontSizeSection(BuildContext context, SettingsViewModel vm) {
    return _SettingsRow(
      label: 'حجم الخط',
      child: AppDropdown<int>(
        value: vm.settings.fontSize,
        onChanged: (value) {
          if (value != null) vm.setFontSize(value);
        },
        items: SettingsViewModel.fontSizes
            .map(
              (s) => DropdownMenuItem(
                value: s,
                child: Text('$s', style: const TextStyle(fontSize: 18)),
              ),
            )
            .toList(),
      ),
    );
  }

  Widget _buildPaddingSection(BuildContext context, SettingsViewModel vm) {
    return _SettingsRow(
      label: 'الحشو',
      child: AppDropdown<int>(
        value: vm.settings.padding,
        onChanged: (value) {
          if (value != null) vm.setPadding(value);
        },
        items: SettingsViewModel.paddingValues
            .map(
              (p) => DropdownMenuItem(
                value: p,
                child: Text('$p', style: const TextStyle(fontSize: 18)),
              ),
            )
            .toList(),
      ),
    );
  }

  Widget _buildResetButton(BuildContext context, SettingsViewModel vm) {
    return SizedBox(
      height: 45,
      child: ElevatedButton.icon(
        onPressed: () => vm.resetToDefaults(),
        icon: const Icon(Icons.restore_outlined, size: 25),
        label: const Text(
          'العودة للإعدادات الافتراضية',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        style: ElevatedButton.styleFrom(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(30),
          ),
        ),
      ),
    );
  }
}

class _SettingsRow extends StatelessWidget {
  final String label;
  final Widget child;

  const _SettingsRow({required this.label, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(10),
      child: Row(
        children: [
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primaryContainer,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  Text(label, style: const TextStyle(fontSize: 18)),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: Theme.of(context).scaffoldBackgroundColor,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: child,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
