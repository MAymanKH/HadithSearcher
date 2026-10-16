import 'package:flutter/material.dart';
import '../l10n/localization.dart';
import 'app_snack_bar.dart';
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
import 'hadith_additional_info.dart';
import 'message_dialog.dart';

/// Displays a hadith with actions (sharh, similar, share, favourite).
class HadithCard extends StatelessWidget {
  static final _sharhInFlight = <String>{};
  final EdgeInsetsGeometry margin;
  final Hadith hadith;
  final bool isFavourite;
  final bool showSimilarButton;
  final Future<void> Function() onFavouriteToggle;

  const HadithCard({
    super.key,
    this.margin = const EdgeInsets.all(10),
    required this.hadith,
    required this.isFavourite,
    required this.onFavouriteToggle,
    this.showSimilarButton = true,
  });

  @override
  Widget build(BuildContext context) {
    final citation = hadith.citation;
    return HadithCardLayout(
      margin: margin,
      text: hadith.text,
      narrator: citation.rawi,
      grading: context.l10n.gradeLabel(citation.grade),
      attribution: citation.compactSource,
      additionalInfo: HadithAdditionalInfo(
        key: ValueKey(hadith.id),
        hadith: hadith,
        fetchDetails: hadith.bookId == null && hadith.mohdithId == null,
      ),
      isFavourite: isFavourite,
      onExplanation: hadith.hasExplanation ? () => _showSharh(context) : null,
      showSimilarButton: showSimilarButton,
      onSimilar: hadith.hasSimilarHadith ? () => _showSimilar(context) : null,
      onShare: () => _share(context),
      onFavourite: () => _toggleFavourite(context),
      onAlternate: hadith.hasAlternateHadithSahih
          ? () => _showSimilar(context, alternate: true)
          : null,
    );
  }

  Future<void> _showSharh(BuildContext context) async {
    // Ignore repeated taps while an explanation is loading.
    if (!_sharhInFlight.add(hadith.id)) return;
    final messenger = ScaffoldMessenger.of(context);
    late final ApiResult<String> result;
    try {
      // Show searching snackbar
      showAppSnackBar(
        context,
        SnackBar(
          content: Text(context.l10n.loadingExplanation),
          duration: ApiService.requestTimeout + const Duration(seconds: 5),
        ),
      );

      result = await ExplanationService().getExplanation(
        hadith.id,
        sharhId: hadith.sharhId,
        explanation: hadith.explanation,
      );

      if (messenger.mounted) {
        messenger.clearSnackBars();
        messenger.removeCurrentSnackBar();
      }
    } finally {
      _sharhInFlight.remove(hadith.id);
    }
    if (!context.mounted) return;

    if (result.isSuccess) {
      await showMessageDialog(
        context,
        title: context.l10n.explanation,
        content: result.data!,
        useReadingSettings: true,
      );
    } else {
      // Show error as snackbar
      String errorMessage;
      if (result.error == ApiError.notFound) {
        errorMessage = context.l10n.noExplanation;
      } else if (result.error == ApiError.noConnection) {
        errorMessage = context.l10n.connectionHelp;
      } else if (result.error == ApiError.timeout) {
        errorMessage = context.l10n.explanationTimeout;
      } else {
        errorMessage = context.l10n.unexpectedHelp;
      }

      showAppSnackBar(
        context,
        SnackBar(
          content: Text(errorMessage),
          duration: const Duration(seconds: 3),
          behavior: SnackBarBehavior.floating,
          action: result.error != ApiError.notFound
              ? SnackBarAction(
                  label: context.l10n.retry,
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
    if (!context.mounted) return;
    final isNowFavourite = await DatabaseService().isFavourite(hadith.id);
    if (!context.mounted) return;
    if (!isFavourite && isNowFavourite) {
      showFavouriteAdded(context);
    } else if (removed != null && !isNowFavourite) {
      showFavouriteUndo(context, removed);
    }
  }

  Future<void> _share(BuildContext context) async {
    TelemetryService.event('share_opened', {'hadith_id': hadith.id});
    await SharePlus.instance.share(
      ShareParams(
        text:
            '${hadith.text}\n\n${hadith.citation.localizedInfo(context.l10n)}\n\nHadith Searcher:\nhttps://bit.ly/hadith-searcher',
      ),
    );
  }
}
