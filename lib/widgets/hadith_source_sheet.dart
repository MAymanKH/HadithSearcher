import 'package:flutter/material.dart';
import '../l10n/localization.dart';
import '../models/hadith.dart';
import '../services/api_service.dart';
import '../services/favourite_details_service.dart';
import 'source_details_sheet.dart';
import 'app_loading_indicator.dart';
import 'details_sheet.dart';

Future<void> showHadithSourceSheet(BuildContext context, Hadith hadith) =>
    showDetailsSheet(
      context,
      title: context.l10n.sourceDetails,
      child: _HadithSourceSheet(hadith: hadith),
    );

class _HadithSourceSheet extends StatefulWidget {
  final Hadith hadith;

  const _HadithSourceSheet({required this.hadith});

  @override
  State<_HadithSourceSheet> createState() => _HadithSourceSheetState();
}

class _HadithSourceSheetState extends State<_HadithSourceSheet> {
  late Future<ApiResult<Hadith>> _hadith;

  Future<ApiResult<Hadith>> _load() async {
    final hadith = widget.hadith;
    if ((hasSourceId(hadith.bookId) && hasSourceId(hadith.mohdithId)) ||
        hadith.id.isEmpty) {
      return ApiResult.success(hadith);
    }
    final result = await FavouriteDetailsService().getSavedDetails(hadith.id);
    if (result.error == ApiError.notFound ||
        (result.isError &&
            (hasSourceId(hadith.bookId) || hasSourceId(hadith.mohdithId)))) {
      return ApiResult.success(hadith);
    }
    return result;
  }

  @override
  void initState() {
    super.initState();
    _hadith = _load();
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<ApiResult<Hadith>>(
    future: _hadith,
    builder: (context, snapshot) {
      final loading = snapshot.connectionState != ConnectionState.done;
      final result = snapshot.data;
      final hadith = result?.data;
      final Widget content;
      if (hadith == null) {
        content = loading
            ? const SizedBox.shrink()
            : SourceDetailsMessage(
                error: result?.error,
                onRetry: () => setState(() {
                  _hadith = _load();
                }),
              );
      } else {
        content = Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ScholarSourceDetails(
              name: hadith.mohdith,
              id: hadith.mohdithId,
            ),
            const SizedBox(height: 16),
            BookSourceDetails(name: hadith.book, id: hadith.bookId),
          ],
        );
      }
      return AppLoadingSwitcher(loading: loading, child: content);
    },
  );
}
