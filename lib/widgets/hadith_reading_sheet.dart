import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../l10n/localization.dart';
import '../services/api_service.dart';
import '../viewmodels/similar_hadith_viewmodel.dart';
import 'api_details_sheet.dart';
import 'app_loading_indicator.dart';
import 'app_snack_bar.dart';
import 'details_sheet.dart';
import 'hadith_card.dart';

Future<void> showExplanationSheet(
  BuildContext context, {
  required Future<ApiResult<String>> Function() load,
}) {
  final messenger = ScaffoldMessenger.of(context);
  messenger.clearSnackBars();
  messenger.removeCurrentSnackBar();
  return showApiDetailsSheet<String>(
    context,
    title: context.l10n.explanation,
    load: load,
    format: (text) => text,
    emptyMessage: context.l10n.noExplanation,
  );
}

Future<void> showAlternateHadithSheet(BuildContext context, String hadithId) =>
    showDetailsSheet(
      context,
      title: context.l10n.alternate,
      child: ChangeNotifierProvider(
        create: (_) =>
            SimilarHadithViewModel()
              ..loadSimilarHadith(hadithId, alternate: true),
        child: _AlternateHadithContent(hadithId: hadithId),
      ),
    );

class _AlternateHadithContent extends StatelessWidget {
  final String hadithId;
  const _AlternateHadithContent({required this.hadithId});

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<SimilarHadithViewModel>();
    return AppLoadingSwitcher(
      loading: vm.isLoading,
      child: _AlternateHadithBody(hadithId: hadithId),
    );
  }
}

class _AlternateHadithBody extends StatelessWidget {
  final String hadithId;
  const _AlternateHadithBody({required this.hadithId});

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<SimilarHadithViewModel>();
    if (vm.isEmpty) {
      final missing = vm.errorMessage == 'noSimilar';
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            missing
                ? context.l10n.noAlternate
                : localizedError(
                    vm.errorMessage ?? context.l10n.unexpectedHelp,
                    context.l10n,
                  ),
          ),
          if (!missing)
            TextButton.icon(
              onPressed: () => vm.loadSimilarHadith(hadithId, alternate: true),
              icon: const Icon(Icons.refresh),
              label: Text(context.l10n.retry),
            ),
        ],
      );
    }
    if (vm.results.isEmpty) return const SizedBox.shrink();
    final hadith = vm.results.single;
    return HadithCard(
      margin: EdgeInsets.zero,
      hadith: hadith,
      isFavourite: vm.isFavourite(hadith.id),
      onFavouriteToggle: () async {
        final error = await vm.toggleFavourite(hadith);
        if (error != null && context.mounted) {
          showAppSnackBar(
            context,
            SnackBar(content: Text(localizedError(error, context.l10n))),
          );
        }
      },
    );
  }
}
