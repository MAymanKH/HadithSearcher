import 'package:flutter/material.dart';
import '../../l10n/localization.dart';
import '../../widgets/app_snack_bar.dart';
import '../../services/telemetry/telemetry_service.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import '../../services/api_service.dart';
import '../../services/database_service.dart';
import '../../viewmodels/favourites_viewmodel.dart';
import '../../models/hadith_citation.dart';
import '../../models/hadith.dart';
import '../../widgets/hadith_additional_info.dart';
import '../../widgets/hadith_card_layout.dart';
import '../../widgets/back_to_top_button.dart';
import '../../widgets/message_dialog.dart';
import '../../widgets/favourite_undo.dart';
import '../../viewmodels/similar_hadith_viewmodel.dart';
import '../similar_hadith/similar_hadith_view.dart';

class FavouritesView extends StatefulWidget {
  const FavouritesView({super.key});

  @override
  State<FavouritesView> createState() => _FavouritesViewState();
}

class _FavouritesViewState extends State<FavouritesView> with ScrollToTopMixin {
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
        child: vm.isLoading
            ? const CircularProgressIndicator()
            : vm.isEmpty
            ? _buildEmptyState()
            : _buildFavouritesList(vm),
      ),
      floatingActionButton: buildBackToTopButton(),
    );
  }

  Widget _buildEmptyState() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.star_border, size: 100, color: Colors.grey),
          Text(
            context.l10n.emptyFavourites,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 20, color: Colors.grey),
          ),
        ],
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
    // Show searching snackbar
    showAppSnackBar(
      context,
      SnackBar(
        content: Text(context.l10n.loadingExplanation),
        duration: ApiService.requestTimeout * 2 + const Duration(seconds: 5),
      ),
    );

    final result = await vm.getSharh(hadithId);

    if (!mounted) return;

    // Hide the searching snackbar
    ScaffoldMessenger.of(context).hideCurrentSnackBar();

    if (result.isSuccess) {
      showMessageDialog(
        context,
        title: context.l10n.explanation,
        content: result.data!,
        useReadingSettings: true,
      );
    } else {
      // Show error as snackbar for all errors
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
                  onPressed: () => _getSharh(vm, hadithId),
                )
              : null,
        ),
      );
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
      grading: citation == null
          ? null
          : context.l10n.gradeLabel(citation.grade),
      scholar: citation == null || citation.mohdith.trim().isEmpty
          ? null
          : '${context.l10n.scholar}: ${citation.mohdith}',
      attribution:
          citation?.localizedAttribution(context.l10n) ?? favourite.hadithInfo,
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
        await SharePlus.instance.share(
          ShareParams(
            text:
                '${favourite.hadithText}\n\n${citation?.localizedInfo(context.l10n) ?? favourite.hadithInfo}\n\nHadith Searcher:\nhttps://bit.ly/hadith-searcher',
          ),
        );
      },
      onFavourite: onRemove,
      onAlternate: favourite.hasAlternate
          ? () => _showSimilar(context, alternate: true)
          : null,
    );
  }

  void _showSimilar(BuildContext context, {bool alternate = false}) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ChangeNotifierProvider(
          create: (_) => SimilarHadithViewModel(),
          child: SimilarHadithView(
            hadithId: favourite.hadithId,
            alternate: alternate,
          ),
        ),
      ),
    );
  }
}
