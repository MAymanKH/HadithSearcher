import 'package:flutter/material.dart';
import '../../widgets/hadith_source_sheet.dart';
import '../../l10n/localization.dart';
import '../../core/constants/app_config.dart';
import '../../widgets/app_snack_bar.dart';
import '../../services/telemetry/telemetry_service.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import '../../services/database_service.dart';
import '../../viewmodels/favourites_viewmodel.dart';
import '../../models/hadith_citation.dart';
import '../../models/hadith.dart';
import '../../widgets/hadith_additional_info.dart';
import '../../widgets/hadith_card_layout.dart';
import '../../widgets/back_to_top_button.dart';
import '../../widgets/hadith_reading_sheet.dart';
import '../../widgets/app_loading_indicator.dart';
import '../../widgets/favourite_undo.dart';
import '../../viewmodels/similar_hadith_viewmodel.dart';
import '../similar_hadith/similar_hadith_view.dart';

class FavouritesView extends StatefulWidget {
  const FavouritesView({super.key});

  @override
  State<FavouritesView> createState() => _FavouritesViewState();
}

class _FavouritesViewState extends State<FavouritesView> with ScrollToTopMixin {
  final _sharhInFlight = <String>{};
  @override
  void initState() {
    super.initState();
    initScrollController();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<FavouritesViewModel>().loadFavourites();
    });
  }

  @override
  void dispose() {
    disposeScrollController();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<FavouritesViewModel>();

    return Scaffold(
      appBar: AppBar(
        title: Text(
          context.l10n.favourites,
          style: TextStyle(fontSize: 25, fontWeight: FontWeight.bold),
        ),
      ),
      body: Center(
        child: AppLoadingSwitcher(
          loading: vm.isLoading,
          child: vm.isEmpty ? _buildEmptyState() : _buildFavouritesList(vm),
        ),
      ),
      floatingActionButton: buildBackToTopButton(),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.bookmark_border,
              size: 100,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
            Text(
              context.l10n.emptyFavourites,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 20,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFavouritesList(FavouritesViewModel vm) {
    return ListView.builder(
      controller: scrollController,
      itemCount: vm.favourites.length,
      itemBuilder: (context, index) {
        final favourite = vm.favourites[index];
        return _FavouriteHadithCard(
          favourite: favourite,
          onRemove: () async {
            final error = await vm.removeFavourite(favourite.hadithId);
            if (error == null && context.mounted) {
              showFavouriteUndo(context, favourite);
            } else if (error != null && context.mounted) {
              showAppSnackBar(
                context,
                SnackBar(
                  content: Text(localizedError(error, context.l10n)),
                  duration: const Duration(seconds: 2),
                  behavior: SnackBarBehavior.floating,
                ),
              );
            }
          },
          onGetSharh: () => _getSharh(vm, favourite.hadithId),
        );
      },
    ).animate().fade(duration: 200.ms);
  }

  Future<void> _getSharh(FavouritesViewModel vm, String hadithId) async {
    if (!_sharhInFlight.add(hadithId)) return;
    try {
      await showExplanationSheet(context, load: () => vm.getSharh(hadithId));
    } finally {
      _sharhInFlight.remove(hadithId);
    }
  }
}

class _FavouriteHadithCard extends StatelessWidget {
  final FavouriteHadith favourite;
  final VoidCallback onRemove;
  final VoidCallback onGetSharh;

  const _FavouriteHadithCard({
    required this.favourite,
    required this.onRemove,
    required this.onGetSharh,
  });

  @override
  Widget build(BuildContext context) {
    final citation = HadithCitation.tryParse(favourite.hadithInfo);
    return HadithCardLayout(
      text: favourite.hadithText,
      narrator: citation?.rawi,
      grading: citation == null
          ? null
          : context.l10n.gradeLabel(citation.grade),
      attribution: citation?.compactSource ?? favourite.hadithInfo,
      onSourceInfo: citation == null && favourite.details == null
          ? null
          : () => showHadithSourceSheet(
              context,
              favourite.details ?? Hadith.fromDatabase(favourite.toDatabase()),
            ),
      additionalInfo: HadithAdditionalInfo(
        key: ValueKey(favourite.hadithId),
        hadith:
            favourite.details ?? Hadith.fromDatabase(favourite.toDatabase()),
        fetchDetails: favourite.details == null,
      ),
      isFavourite: true,
      onExplanation: favourite.hasExplanation ? onGetSharh : null,
      onSimilar: favourite.hasSimilarHadith
          ? () => _showSimilar(context)
          : null,
      onShare: () async {
        TelemetryService.event('share_opened', {
          'hadith_id': favourite.hadithId,
        });
        final text =
            citation?.cardText(favourite.hadithText, context.l10n) ??
            '${favourite.hadithText}\n\n${favourite.hadithInfo}';
        await SharePlus.instance.share(
          ShareParams(text: '$text\n\nHadith Searcher:\n$appShareUrl'),
        );
      },
      onFavourite: onRemove,
      onAlternate: favourite.hasAlternate
          ? () => showAlternateHadithSheet(context, favourite.hadithId)
          : null,
    );
  }

  void _showSimilar(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ChangeNotifierProvider(
          create: (_) => SimilarHadithViewModel(),
          child: SimilarHadithView(hadithId: favourite.hadithId),
        ),
      ),
    );
  }
}
