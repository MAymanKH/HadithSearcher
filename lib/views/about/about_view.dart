import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../l10n/localization.dart';
import '../../core/constants/app_config.dart';
import '../../services/update_service.dart';
import '../../widgets/app_logo.dart';
import '../../widgets/update_prompt.dart';

class AboutView extends StatelessWidget {
  const AboutView({super.key});

  Future<void> _launchUrl(Uri url) async {
    if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
      throw Exception('Could not launch $url');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          context.l10n.about,
          style: TextStyle(fontSize: 25, fontWeight: FontWeight.bold),
        ),
      ),
      body: SingleChildScrollView(
        child: Center(
          child: Column(
            children: [
              const SizedBox(height: 16),
              const AppLogo(size: 128),
              const SizedBox(height: 20),
              _buildInfoCard(context, context.l10n.aboutDescription),
              _buildApiInfoCard(context),
              const SizedBox(height: 15),
              _buildActionButtons(context),
              const SizedBox(height: 30),
              _buildDeveloperSection(context),
              const SizedBox(height: 30),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoCard(BuildContext context, String text) {
    return Container(
      margin: const EdgeInsets.all(10),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainer,
        borderRadius: BorderRadius.circular(30),
      ),
      child: Text(text, style: const TextStyle(fontSize: 18)),
    );
  }

  Widget _buildApiInfoCard(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(10),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainer,
        borderRadius: BorderRadius.circular(30),
      ),
      child: RichText(
        textAlign: TextAlign.center,
        text: TextSpan(
          style: Theme.of(context).textTheme.bodyMedium!.copyWith(
            fontSize: 18,
            color: Theme.of(context).colorScheme.onSurface,
          ),
          children: [
            TextSpan(text: context.l10n.sourceCredit),
            TextSpan(
              text: 'dorar.net',
              style: TextStyle(
                decoration: TextDecoration.underline,
                decorationColor: Theme.of(context).colorScheme.primary,
                color: Theme.of(context).colorScheme.primary,
              ),
              recognizer: TapGestureRecognizer()
                ..onTap = () => _launchUrl(Uri.parse('https://dorar.net/')),
            ),
            TextSpan(text: context.l10n.usingApi),
            TextSpan(
              text: 'Dorar Hadith API',
              style: TextStyle(
                decoration: TextDecoration.underline,
                decorationColor: Theme.of(context).colorScheme.primary,
                color: Theme.of(context).colorScheme.primary,
              ),
              recognizer: TapGestureRecognizer()
                ..onTap = () => _launchUrl(
                  Uri.parse('https://github.com/MAymanKH/dorar-hadith-api'),
                ),
            ),
            const TextSpan(text: '.'),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButtons(BuildContext context) {
    final updateService = context.watch<UpdateService>();
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _ActionIconButton(
          icon: Icons.share_rounded,
          label: context.l10n.share,
          onTap: () async {
            await SharePlus.instance.share(ShareParams(text: appShareUrl));
          },
        ),
        const SizedBox(width: 24),
        _ActionIconButton(
          icon: Icons.code_rounded,
          label: context.l10n.code,
          onTap: () => _launchUrl(
            Uri.parse('https://github.com/MAymanKH/HadithSearcher'),
          ),
        ),
        const SizedBox(width: 24),
        _ActionIconButton(
          icon: Icons.attach_money_rounded,
          label: context.l10n.support,
          onTap: () => _launchUrl(Uri.parse('https://ko-fi.com/MAymanKH')),
        ),
        const SizedBox(width: 24),
        _ActionIconButton(
          icon: Icons.system_update_rounded,
          label: context.l10n.update,
          onTap: updateService.isChecking
              ? null
              : () => checkForUpdates(context),
        ),
      ],
    );
  }

  Widget _buildDeveloperSection(BuildContext context) {
    return Column(
      children: [
        Text(
          context.l10n.contactDeveloper,
          style: TextStyle(fontSize: 25, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 15),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _ActionIconButton(
              icon: Icons.language,
              label: context.l10n.website,
              onTap: () => _launchUrl(Uri.parse('https://mohamedayman.net')),
            ),
            const SizedBox(width: 40),
            _ActionIconButton(
              icon: Icons.email,
              label: context.l10n.email,
              onTap: () => _launchUrl(
                Uri.parse('mailto:mohamed.ayman.khodeir@gmail.com'),
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),
        TextButton(
          onPressed: () => showLicensePage(
            context: context,
            applicationName: 'Hadith Searcher',
          ),
          child: Text(context.l10n.licenses),
        ),
        GestureDetector(
          onTap: () => _launchUrl(Uri.parse(privacyPolicyUrl)),
          child: Text(
            context.l10n.privacyPolicy,
            style: TextStyle(
              decoration: TextDecoration.underline,
              decorationColor: Theme.of(context).colorScheme.primary,
              color: Theme.of(context).colorScheme.primary,
              fontSize: 16,
            ),
          ),
        ),
      ],
    );
  }
}

class _ActionIconButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback? onTap;

  const _ActionIconButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(2),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surfaceContainer,
            borderRadius: BorderRadius.circular(30),
          ),
          child: IconButton(
            onPressed: onTap,
            icon: Icon(icon, semanticLabel: label),
            iconSize: 33,
          ),
        ),
        const SizedBox(height: 5),
        Text(label),
      ],
    );
  }
}
