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
                const Padding(
                  padding: EdgeInsets.fromLTRB(20, 4, 20, 12),
                  child: Align(
                    alignment: AlignmentDirectional.centerStart,
                    child: Text(
                      'إعدادات نص الأحاديث والشرح',
                      style: TextStyle(
                        fontSize: 23,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
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
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 30),
                  child: Material(
                    color: Theme.of(context).colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(20),
                    clipBehavior: Clip.antiAlias,
                    child: ListTile(
                      title: const Text(
                        'الخصوصية والقياس الاختياري',
                        style: TextStyle(fontSize: 18),
                      ),
                      trailing: const Icon(Icons.chevron_right),
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
    return AppDropdown<ThemePreference>.settings(
      title: 'المظهر العام',
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
    );
  }

  Widget _buildFontFamilySection(BuildContext context, SettingsViewModel vm) {
    return AppDropdown<String>.settings(
      title: 'نوع الخط',
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
    );
  }

  Widget _buildFontWeightSection(BuildContext context, SettingsViewModel vm) {
    return AppDropdown<FontWeightPreference>.settings(
      title: 'ثقل الخط',
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
    );
  }

  Widget _buildFontSizeSection(BuildContext context, SettingsViewModel vm) {
    return AppDropdown<int>.settings(
      title: 'حجم الخط',
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
    );
  }

  Widget _buildPaddingSection(BuildContext context, SettingsViewModel vm) {
    return AppDropdown<int>.settings(
      title: 'الحشو',
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
