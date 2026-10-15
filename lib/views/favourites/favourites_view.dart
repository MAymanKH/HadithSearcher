import 'package:flutter/material.dart';
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
        title: const Text(
          'المفضلة',
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
      child: const Column(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.star_border, size: 140),
          SizedBox(height: 15),
          Text(
            'لم يتم إضافة أحاديث للمفضلة',
            style: TextStyle(fontSize: 23, fontWeight: FontWeight.bold),
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
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(error),
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
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('جارٍ البحث عن الشرح...'),
        duration: Duration(seconds: 30),
      ),
    );

    final result = await vm.getSharh(hadithId);

    if (!mounted) return;

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
      // Show error as snackbar for all errors
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
      grading: citation?.grading,
      attribution: citation?.attribution ?? favourite.hadithInfo,
      additionalInfo: HadithAdditionalInfo(
        key: ValueKey(favourite.hadithId),
        hadith: Hadith.fromDatabase(favourite.toDatabase()),
        fetchDetails: true,
      ),
      isFavourite: true,
      onExplanation: onGetSharh,
      onSimilar: () => _showSimilar(context),
      onShare: () async {
        TelemetryService.event('share_opened', {
          'hadith_id': favourite.hadithId,
        });
        await SharePlus.instance.share(
          ShareParams(
            text:
                '${favourite.shareText}\n\nHadith Searcher:\nhttps://bit.ly/hadith-searcher',
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
