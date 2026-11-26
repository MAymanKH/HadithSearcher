import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../l10n/localization.dart';
import '../../widgets/app_dropdown.dart';
import '../../widgets/appearance_preferences.dart';
import '../../models/settings.dart';
import '../../viewmodels/settings_viewmodel.dart';
import '../../services/telemetry/telemetry_service.dart';
import '../../services/update_service.dart';
import '../privacy/telemetry_consent_view.dart';

class SettingsView extends StatelessWidget {
  const SettingsView({super.key});

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<SettingsViewModel>();

    final l10n = context.l10n;
    final showPrivacy = context.watch<TelemetryService>().canChangeConsent;
    const sectionTitlePadding = EdgeInsets.fromLTRB(20, 4, 20, 12);
    const sectionTitleStyle = TextStyle(
      fontSize: 23,
      fontWeight: FontWeight.bold,
    );

    return Scaffold(
      appBar: AppBar(
        title: Text(
          l10n.settings,
          style: const TextStyle(fontSize: 25, fontWeight: FontWeight.bold),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.only(top: 15, bottom: 16),
        children: [
          Padding(
            padding: sectionTitlePadding,
            child: Text(l10n.appearanceSettings, style: sectionTitleStyle),
          ),
          const AppearancePreferences(),
          const SizedBox(height: 20),
          Padding(
            padding: sectionTitlePadding,
            child: Text(l10n.readingSettings, style: sectionTitleStyle),
          ),
          _buildFontFamilySection(context, vm),
          _buildFontWeightSection(context, vm),
          _buildFontSizeSection(context, vm),
          _buildPaddingSection(context, vm),
          const Divider(height: 24, indent: 24, endIndent: 24),
          _settingsTile(
            context,
            SwitchListTile(
              title: Text(l10n.automaticUpdateChecks),
              subtitle: Text(
                buildUpdateChannel == UpdateChannel.foss
                    ? l10n.fossUpdateChecksDescription
                    : l10n.playUpdateChecksDescription,
              ),
              value: vm.settings.automaticUpdateChecks,
              onChanged: vm.setAutomaticUpdateChecks,
            ),
          ),
          if (showPrivacy) ...[
            const SizedBox(height: 12),
            _settingsTile(
              context,
              ListTile(
                title: Text(l10n.privacySettings),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const TelemetryConsentView(),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _settingsTile(BuildContext context, Widget child) {
    final decoration = Theme.of(context).inputDecorationTheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Material(
        color: decoration.fillColor,
        shape: decoration.enabledBorder,
        clipBehavior: Clip.antiAlias,
        child: ListTileTheme(
          data: ListTileTheme.of(context).copyWith(
            titleTextStyle: Theme.of(context).textTheme.titleMedium
                ?.copyWith(fontSize: 18),
          ),
          child: child,
        ),
      ),
    );
  }

  Widget _buildFontFamilySection(BuildContext context, SettingsViewModel vm) {
    final isArabic = vm.locale.languageCode == 'ar';
    return AppDropdown<String>.settings(
      title: context.l10n.fontFamily,
      value: vm.fontFamily,
      defaultValue: AppSettings.defaults.fontFamily,
      onChanged: (value) {
        if (value != null) vm.setFontFamily(value);
      },
      items: SettingsViewModel.fontFamilies
          .map(
            (f) => DropdownMenuItem(
              value: f,
              child: Text(
                _localizedFontName(f, isArabic),
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 18),
              ),
            ),
          )
          .toList(),
    );
  }

  String _localizedFontName(String family, bool isArabic) {
    if (!isArabic) return family;
    return switch (family) {
      'Roboto' => 'روبوتو',
      'Cairo' => 'القاهرة',
      'Tajawal' => 'تجوال',
      'Noto Naskh Arabic' => 'نوتو نسخ عربي',
      'Amiri' => 'أميري',
      'Lateef' => 'لطيف',
      'Gulzar' => 'غلزار',
      'Aref Ruqaa' => 'عارف رقعة',
      'Reem Kufi' => 'ريم كوفي',
      _ => family,
    };
  }

  Widget _buildFontWeightSection(BuildContext context, SettingsViewModel vm) {
    return AppDropdown<FontWeightPreference>.settings(
      title: context.l10n.fontWeight,
      value: vm.settings.fontWeight,
      defaultValue: AppSettings.defaults.fontWeight,
      onChanged: (value) {
        if (value != null) vm.setFontWeight(value);
      },
      items: FontWeightPreference.values
          .map(
            (w) => DropdownMenuItem(
              value: w,
              child: Text(
                w.label(context.l10n),
                style: const TextStyle(fontSize: 18),
              ),
            ),
          )
          .toList(),
    );
  }

  Widget _buildFontSizeSection(BuildContext context, SettingsViewModel vm) {
    return AppDropdown<int>.settings(
      title: context.l10n.fontSize,
      value: vm.settings.fontSize,
      defaultValue: AppSettings.defaults.fontSize,
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
      title: context.l10n.padding,
      value: vm.settings.padding,
      defaultValue: AppSettings.defaults.padding,
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
}
