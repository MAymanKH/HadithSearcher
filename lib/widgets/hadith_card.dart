import 'package:flutter/material.dart';
import '../services/telemetry/telemetry_service.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import '../models/hadith.dart';
import '../services/api_service.dart';
import '../services/database_service.dart';
import '../services/explanation_service.dart';
import '../viewmodels/similar_hadith_viewmodel.dart';
import 'favourite_undo.dart';
import 'hadith_card_layout.dart';
import '../views/similar_hadith/similar_hadith_view.dart';
import 'message_dialog.dart';

/// Displays a hadith with actions (sharh, similar, share, favourite).
class HadithCard extends StatelessWidget {
  final Hadith hadith;
  final bool isFavourite;
  final bool showSimilarButton;
  final Future<void> Function() onFavouriteToggle;

  const HadithCard({
    super.key,
    required this.hadith,
    required this.isFavourite,
    required this.onFavouriteToggle,
    this.showSimilarButton = true,
  });

  @override
  Widget build(BuildContext context) {
    final citation = hadith.citation;
    return HadithCardLayout(
      text: hadith.text,
      grading: citation.grading,
      attribution: citation.attribution,
      isFavourite: isFavourite,
      onExplanation: () => _showSharh(context),
      onSimilar: showSimilarButton ? () => _showSimilar(context) : null,
      onShare: _share,
      onFavourite: () => _toggleFavourite(context),
      onAlternate: hadith.hasAlternateHadithSahih
          ? () => _showSimilar(context, alternate: true)
          : null,
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

    final result = await ExplanationService().getExplanation(
      hadith.id,
      sharhId: hadith.sharhId,
    );

    if (!context.mounted) return;

    // Hide the searching snackbar
    ScaffoldMessenger.of(context).hideCurrentSnackBar();

    if (result.isSuccess) {
      showMessageDialog(
        context,
        title: 'الشرح',
        content: result.data!,
        useReadingSettings: true,
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

  void _showSimilar(BuildContext context, {bool alternate = false}) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ChangeNotifierProvider(
          create: (_) => SimilarHadithViewModel(),
          child: SimilarHadithView(hadithId: hadith.id, alternate: alternate),
        ),
      ),
    );
  }

  Future<void> _toggleFavourite(BuildContext context) async {
    FavouriteHadith? removed;
    if (isFavourite) {
      removed = await DatabaseService().getFavourite(hadith.id);
      if (!context.mounted) return;
    }
    await onFavouriteToggle();
    if (removed != null) {
      if (context.mounted && !await DatabaseService().isFavourite(hadith.id)) {
        if (context.mounted) showFavouriteUndo(context, removed);
      }
    }
  }

  Future<void> _share() async {
    TelemetryService.event('share_opened', {'hadith_id': hadith.id});
    await SharePlus.instance.share(
      ShareParams(
        text:
            '${hadith.shareText}\n\nHadith Searcher:\nhttps://bit.ly/hadith-searcher',
      ),
    );
  }
}
