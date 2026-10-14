import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/constants/app_config.dart';
import '../../widgets/app_link.dart';
import '../../widgets/app_logo.dart';

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
              const SizedBox(height: 16),
              const Text(
                'Hadith Searcher',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 37, fontWeight: FontWeight.bold),
              ),
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
            WidgetSpan(
              alignment: PlaceholderAlignment.middle,
              child: AppLink(
                label: 'dorar.net',
                onPressed: () => _launchUrl(Uri.parse('https://dorar.net/')),
              ),
            ),
            const TextSpan(text: ' باستخدام '),
            WidgetSpan(
              alignment: PlaceholderAlignment.middle,
              child: AppLink(
                label: 'Dorar Hadith API',
                onPressed: () => _launchUrl(
                  Uri.parse(
                    'https://github.com/AhmedElTabarani/dorar-hadith-api',
                  ),
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
    return Wrap(
      alignment: WrapAlignment.center,
      spacing: 24,
      runSpacing: 16,
      children: [
        AppLink(
          icon: Icons.share_rounded,
          label: 'مشاركة',
          onPressed: () async {
            await SharePlus.instance.share(
              ShareParams(text: 'https://bit.ly/hadith-searcher'),
            );
          },
        ),
        AppLink(
          icon: Icons.code_rounded,
          label: 'الكود',
          onPressed: () => _launchUrl(
            Uri.parse('https://github.com/MAymanKH/HadithSearcher'),
          ),
        ),
        AppLink(
          icon: Icons.attach_money_rounded,
          label: 'دعم',
          onPressed: () => _launchUrl(Uri.parse('https://ko-fi.com/MAymanKH')),
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
        Wrap(
          alignment: WrapAlignment.center,
          spacing: 24,
          runSpacing: 16,
          children: [
            AppLink(
              icon: Icons.language,
              label: 'الموقع',
              onPressed: () =>
                  _launchUrl(Uri.parse('https://mohamedayman.net')),
            ),
            AppLink(
              icon: Icons.email,
              label: 'البريد',
              onPressed: () => _launchUrl(
                Uri.parse('mailto:mohamed.ayman.khodeir@gmail.com'),
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),
        AppLink(
          onPressed: () => showLicensePage(
            context: context,
            applicationName: 'Hadith Searcher',
          ),
          label: 'تراخيص المكتبات والخطوط',
        ),
        AppLink(
          label: 'سياسة الخصوصية',
          onPressed: () => _launchUrl(Uri.parse(privacyPolicyUrl)),
        ),
      ],
    );
  }
}
