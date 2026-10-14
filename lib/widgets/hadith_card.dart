import 'package:flutter/material.dart';
import '../services/telemetry/telemetry_service.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import '../models/hadith.dart';
import '../services/api_service.dart';
import '../viewmodels/settings_viewmodel.dart';
import '../views/similar_hadith/similar_hadith_view.dart';
import 'message_dialog.dart';

/// Displays a hadith with actions (sharh, similar, share, favourite).
class HadithCard extends StatelessWidget {
  final Hadith hadith;
  final bool isFavourite;
  final bool showSimilarButton;
  final VoidCallback onFavouriteToggle;

  const HadithCard({
    super.key,
    required this.hadith,
    required this.isFavourite,
    required this.onFavouriteToggle,
    this.showSimilarButton = true,
  });

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsViewModel>();

    return Container(
      margin: const EdgeInsets.all(10),
      padding: settings.padding,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primaryContainer,
        borderRadius: BorderRadius.circular(30),
      ),
      child: Column(
        children: [
          SelectableText(
            '${hadith.text}\n\n${hadith.formattedInfo}',
            style: TextStyle(
              color: Theme.of(context).colorScheme.secondaryContainer,
              fontSize: settings.fontSize,
              fontWeight: settings.fontWeight,
              fontFamily: settings.fontFamily,
            ),
          ),
          const SizedBox(height: 15),
          _buildActionRow1(context),
          const SizedBox(height: 10),
          _buildActionRow2(context),
        ],
      ),
    );
  }

  Widget _buildActionRow1(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _ActionButton(
          icon: Icons.manage_search,
          label: 'الشرح',
          onPressed: () => _showSharh(context),
        ),
        if (showSimilarButton) ...[
          const SizedBox(width: 15),
          _ActionButton(
            icon: Icons.content_paste_go,
            label: 'أحاديث مشابهة',
            onPressed: () => _showSimilar(context),
          ),
        ],
      ],
    );
  }

  Widget _buildActionRow2(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _ActionButton(
          icon: Icons.share_rounded,
          label: 'مشاركة',
          onPressed: () => _share(),
        ),
        const SizedBox(width: 15),
        _ActionButton(
          icon: isFavourite ? Icons.star : Icons.star_border,
          label: isFavourite ? 'أزل من المفضلة' : 'أضف إلى المفضلة',
          onPressed: onFavouriteToggle,
        ),
      ],
    );
  }

  Future<void> _showSharh(BuildContext context) async {
    if (!hadith.hasSharhMetadata || hadith.sharhId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('لا يوجد شرح لهذا الحديث'),
          duration: Duration(seconds: 2),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    // Show searching snackbar
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('جارٍ البحث عن الشرح...'),
        duration: Duration(seconds: 30),
      ),
    );

    final result = await ApiService().getSharh(hadith.sharhId!);

    if (!context.mounted) return;

    // Hide the searching snackbar
    ScaffoldMessenger.of(context).hideCurrentSnackBar();

    if (result.isSuccess) {
      showMessageDialog(
        context,
        title: 'الشرح',
        content: result.data!,
      );
    } else {
      // Show error as snackbar
      String errorMessage;
      if (result.error == ApiError.notFound) {
        errorMessage = 'لا يوجد شرح لهذا الحديث';
      } else if (result.error == ApiError.noConnection) {
        errorMessage = 'تأكد من إتصالك بالإنترنت وأعد المحاولة';
      } else if (result.error == ApiError.timeout) {
        errorMessage = 'نفذ الوقت - تأكد من إتصالك بإنترنت مستقر';
      } else {
        errorMessage = 'حدث خطأ غير متوقع، حاول مرة أخرى';
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(errorMessage),
          duration: const Duration(seconds: 3),
          behavior: SnackBarBehavior.floating,
          action: result.error != ApiError.notFound
              ? SnackBarAction(
                  label: 'أعد المحاولة',
                  onPressed: () => _showSharh(context),
                )
              : null,
        ),
      );
    }
  }

  void _showSimilar(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => SimilarHadithView(hadithId: hadith.id),
      ),
    );
  }

  Future<void> _share() async {
    TelemetryService.event('share_opened', {'hadith_id': hadith.id});
    await SharePlus.instance.share(
      ShareParams(
          text:
              '${hadith.shareText}\n\nHadith Searcher:\nhttps://bit.ly/hadith-searcher'),
    );
  }
}

/// Reusable action button for hadith card.
class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onPressed;

  const _ActionButton({
    required this.icon,
    required this.label,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 45,
      child: ElevatedButton.icon(
        onPressed: onPressed,
        icon: Icon(icon, size: 25),
        label: Text(
          label,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        style: ElevatedButton.styleFrom(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(30.0),
          ),
        ),
      ),
    );
  }
}
