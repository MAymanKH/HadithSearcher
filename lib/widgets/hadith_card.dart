import 'package:flutter/material.dart';
import '../l10n/localization.dart';
import '../core/constants/app_config.dart';
import '../services/telemetry/telemetry_service.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import '../models/hadith.dart';
import '../services/database_service.dart';
import '../services/explanation_service.dart';
import '../viewmodels/similar_hadith_viewmodel.dart';
import 'favourite_undo.dart';
import 'hadith_card_layout.dart';
import 'hadith_source_sheet.dart';
import '../views/similar_hadith/similar_hadith_view.dart';
import 'hadith_additional_info.dart';
import 'hadith_reading_sheet.dart';

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
      grading: citation.grade,
      gradingLabel: context.l10n.gradeLabel(''),
      attribution: citation.compactSource,
      onSourceInfo: () => showHadithSourceSheet(context, hadith),
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
          ? () => showAlternateHadithSheet(context, hadith.id)
          : null,
    );
  }

  Future<void> _showSharh(BuildContext context) async {
    if (!_sharhInFlight.add(hadith.id)) return;
    try {
      await showExplanationSheet(
        context,
        load: () => ExplanationService().getExplanation(
          hadith.id,
          sharhId: hadith.sharhId,
          explanation: hadith.explanation,
        ),
      );
    } finally {
      _sharhInFlight.remove(hadith.id);
    }
  }

  void _showSimilar(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ChangeNotifierProvider(
          create: (_) => SimilarHadithViewModel(),
          child: SimilarHadithView(hadithId: hadith.id),
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
            '${hadith.citation.cardText(hadith.text, context.l10n)}\n\nHadith Searcher:\n$appShareUrl',
      ),
    );
  }
}
