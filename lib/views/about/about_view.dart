import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
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
        title: const Text(
          'حول',
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
              _buildInfoCard(
                context,
                'تطبيق Hadith Searcher هو تطبيق مجاني ومفتوح المصدر للبحث في آلاف الأحاديث النبوية الشريفة. يوفر التطبيق إمكانيات بحث وتصفية متقدمة، مع عرض تفصيلي لمعلومات سند الحديث ودرجة صحته.',
              ),
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
        color: Theme.of(context).colorScheme.primaryContainer,
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
        color: Theme.of(context).colorScheme.primaryContainer,
        borderRadius: BorderRadius.circular(30),
      ),
      child: RichText(
        textAlign: TextAlign.center,
        text: TextSpan(
          style: TextStyle(
            fontSize: 18,
            color: Theme.of(context).colorScheme.onSurface,
          ),
          children: [
            const TextSpan(text: 'جميع الأحاديث والمعلومات مأخوذة من موقع '),
            TextSpan(
              text: 'dorar.net',
              style: const TextStyle(
                decoration: TextDecoration.none,
                decorationColor: Colors.blue,
                color: Colors.blue,
              ),
              recognizer: TapGestureRecognizer()
                ..onTap = () => _launchUrl(Uri.parse('https://dorar.net/')),
            ),
            const TextSpan(text: ' باستخدام '),
            TextSpan(
              text: 'Dorar Hadith API',
              style: const TextStyle(
                decoration: TextDecoration.none,
                decorationColor: Colors.blue,
                color: Colors.blue,
              ),
              recognizer: TapGestureRecognizer()
                ..onTap = () => _launchUrl(
                  Uri.parse(
                    'https://github.com/MAymanKH/dorar-hadith-api',
                  ),
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
          label: 'مشاركة',
          onTap: () async {
            await SharePlus.instance.share(
              ShareParams(text: 'https://bit.ly/hadith-searcher'),
            );
          },
        ),
        const SizedBox(width: 24),
        _ActionIconButton(
          icon: Icons.code_rounded,
          label: 'الكود',
          onTap: () => _launchUrl(
            Uri.parse('https://github.com/MAymanKH/HadithSearcher'),
          ),
        ),
        const SizedBox(width: 24),
        _ActionIconButton(
          icon: Icons.attach_money_rounded,
          label: 'دعم',
          onTap: () => _launchUrl(Uri.parse('https://ko-fi.com/MAymanKH')),
        ),
        const SizedBox(width: 24),
        _ActionIconButton(
          icon: Icons.system_update_rounded,
          label: 'تحديث',
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
        const Text(
          'تواصل مع المطور',
          style: TextStyle(fontSize: 25, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 15),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _ActionIconButton(
              icon: Icons.language,
              label: 'الموقع',
              onTap: () => _launchUrl(Uri.parse('https://mohamedayman.net')),
            ),
            const SizedBox(width: 40),
            _ActionIconButton(
              icon: Icons.email,
              label: 'البريد',
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
          child: const Text('تراخيص المكتبات والخطوط'),
        ),
        GestureDetector(
          onTap: () => _launchUrl(Uri.parse(privacyPolicyUrl)),
          child: const Text(
            'سياسة الخصوصية',
            style: TextStyle(
              decoration: TextDecoration.none,
              decorationColor: Colors.blue,
              color: Colors.blue,
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
            color: Theme.of(context).colorScheme.primaryContainer,
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
