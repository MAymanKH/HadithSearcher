import 'package:flutter/material.dart';
import '../../services/telemetry/telemetry_service.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import '../../services/api_service.dart';
import '../../services/database_service.dart';
import '../../viewmodels/favourites_viewmodel.dart';
import '../../viewmodels/settings_viewmodel.dart';
import '../../widgets/back_to_top_button.dart';
import '../../widgets/message_dialog.dart';
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
    final settings = context.watch<SettingsViewModel>();

    return Scaffold(
      appBar: AppBar(
          title: const Text(
        'المفضلة',
        style: TextStyle(fontSize: 25, fontWeight: FontWeight.bold),
      )),
      body: Center(
        child: vm.isLoading
            ? const CircularProgressIndicator()
            : vm.isEmpty
                ? _buildEmptyState()
                : _buildFavouritesList(vm, settings),
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

  Widget _buildFavouritesList(
      FavouritesViewModel vm, SettingsViewModel settings) {
    return ListView.builder(
      controller: scrollController,
      itemCount: vm.favourites.length,
      itemBuilder: (context, index) {
        final favourite = vm.favourites[index];
        return _FavouriteHadithCard(
          favourite: favourite,
          settings: settings,
          onRemove: () async {
            final error = await vm.removeFavourite(favourite.hadithId);
            if (error != null && context.mounted) {
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
      showMessageDialog(context, title: 'الشرح', content: result.data!);
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
  final SettingsViewModel settings;
  final VoidCallback onRemove;
  final VoidCallback onGetSharh;

  const _FavouriteHadithCard({
    required this.favourite,
    required this.settings,
    required this.onRemove,
    required this.onGetSharh,
  });

  @override
  Widget build(BuildContext context) {
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
            favourite.displayText,
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
          onPressed: onGetSharh,
        ),
        const SizedBox(width: 15),
        _ActionButton(
          icon: Icons.content_paste_go,
          label: 'أحاديث مشابهة',
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) =>
                    SimilarHadithView(hadithId: favourite.hadithId),
              ),
            );
          },
        ),
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
          onPressed: () async {
            TelemetryService.event(
                'share_opened', {'hadith_id': favourite.hadithId});
            await SharePlus.instance.share(
              ShareParams(
                  text:
                      '${favourite.shareText}\n\nHadith Searcher:\nhttps://bit.ly/hadith-searcher'),
            );
          },
        ),
        const SizedBox(width: 15),
        _ActionButton(
          icon: Icons.star,
          label: 'أزل من المفضلة',
          onPressed: onRemove,
        ),
      ],
    );
  }
}

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
        label: Text(label, style: const TextStyle(fontWeight: FontWeight.bold)),
        style: ElevatedButton.styleFrom(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(30),
          ),
        ),
      ),
    );
  }
}
