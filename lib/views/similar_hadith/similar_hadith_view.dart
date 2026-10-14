import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';
import '../../viewmodels/similar_hadith_viewmodel.dart';
import '../../widgets/back_to_top_button.dart';
import '../../widgets/hadith_card.dart';

class SimilarHadithView extends StatefulWidget {
  final String? hadithId;

  const SimilarHadithView({super.key, this.hadithId});

  @override
  State<SimilarHadithView> createState() => _SimilarHadithViewState();
}

class _SimilarHadithViewState extends State<SimilarHadithView>
    with ScrollToTopMixin {
  @override
  void initState() {
    super.initState();
    initScrollController();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (widget.hadithId != null) {
        context
            .read<SimilarHadithViewModel>()
            .loadSimilarHadith(widget.hadithId!);
      }
    });
  }

  @override
  void dispose() {
    disposeScrollController();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<SimilarHadithViewModel>();

    return Scaffold(
      appBar: AppBar(title: const Text('أحاديث مشابهة')),
      body: Center(
        child: vm.isLoading
            ? const CircularProgressIndicator()
            : vm.isEmpty
                ? _buildEmptyState(vm)
                : _buildResults(vm),
      ),
      floatingActionButton: buildBackToTopButton(),
    );
  }

  Widget _buildEmptyState(SimilarHadithViewModel vm) {
    if (vm.errorMessage == 'noSimilar') {
      return const Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.content_paste_off, size: 100, color: Colors.grey),
          SizedBox(height: 20),
          Text(
            'لا توجد أحاديث مشابهة',
            style: TextStyle(fontSize: 20, color: Colors.grey),
          ),
        ],
      );
    }

    if (vm.errorMessage != null) {
      IconData icon;
      String title;
      String description;

      if (vm.errorMessage!.contains('خطأ بالإتصال')) {
        icon = Icons.wifi_off;
        title = 'خطأ بالإتصال بالإنترنت';
        description = 'تأكد من إتصالك بالإنترنت وأعد المحاولة';
      } else if (vm.errorMessage!.contains('نفذ الوقت')) {
        icon = Icons.timer_off;
        title = 'نفذ الوقت';
        description = 'تأكد من إتصالك بإنترنت مستقر وأعد المحاولة';
      } else {
        icon = Icons.error_outline;
        title = vm.errorMessage!;
        description = 'حاول مرة أخرى';
      }

      return Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 100, color: Colors.grey),
            const SizedBox(height: 20),
            Text(
              title,
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.grey,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 10),
            Text(
              description,
              style: const TextStyle(fontSize: 16, color: Colors.grey),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: () {
                if (widget.hadithId != null) {
                  vm.loadSimilarHadith(widget.hadithId!);
                }
              },
              icon: const Icon(Icons.refresh),
              label: const Text('أعد المحاولة'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(
                  horizontal: 30,
                  vertical: 15,
                ),
              ),
            ),
          ],
        ),
      );
    }

    return const SizedBox.shrink();
  }

  Widget _buildResults(SimilarHadithViewModel vm) {
    return ListView.builder(
      controller: scrollController,
      itemCount: vm.results.length,
      itemBuilder: (context, index) {
        final hadith = vm.results[index];
        return HadithCard(
          hadith: hadith,
          isFavourite: vm.isFavourite(hadith.id),
          showSimilarButton: false, // Don't show similar button in similar view
          onFavouriteToggle: () async {
            final error = await vm.toggleFavourite(hadith);
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
        );
      },
    ).animate().fade(duration: 200.ms);
  }
}
