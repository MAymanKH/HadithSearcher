import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../l10n/localization.dart';
import '../models/hadith.dart';
import '../models/hadith_details.dart';
import '../services/api_service.dart';
import '../services/favourite_details_service.dart';
import '../viewmodels/settings_viewmodel.dart';

bool _hasId(String? id) => id != null && id.trim().isNotEmpty && id != '0';

Future<void> showHadithSourceSheet(BuildContext context, Hadith hadith) =>
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
      ),
      builder: (_) => _HadithSourceSheet(hadith: hadith),
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
    if ((_hasId(hadith.bookId) && _hasId(hadith.mohdithId)) ||
        hadith.id.isEmpty) {
      return ApiResult.success(hadith);
    }
    final result = await FavouriteDetailsService().getSavedDetails(hadith.id);
    if (result.isError && (_hasId(hadith.bookId) || _hasId(hadith.mohdithId))) {
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
  Widget build(BuildContext context) => SafeArea(
    top: false,
    child: ConstrainedBox(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * 0.85,
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    context.l10n.sourceDetails,
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
                IconButton(
                  tooltip: context.l10n.close,
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
            const SizedBox(height: 12),
            FutureBuilder<ApiResult<Hadith>>(
              future: _hadith,
              builder: (context, snapshot) {
                if (snapshot.connectionState != ConnectionState.done) {
                  return const Padding(
                    padding: EdgeInsets.all(24),
                    child: Center(child: CircularProgressIndicator()),
                  );
                }
                final result = snapshot.data;
                final hadith = result?.data;
                if (hadith == null) {
                  return _LoadMessage(
                    error: result?.error,
                    onRetry: () => setState(() {
                      _hadith = _load();
                    }),
                  );
                }
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _SourceSection<ScholarDetails>(
                      title: context.l10n.scholar,
                      name: hadith.mohdith,
                      icon: Icons.person_outline,
                      load: () => _hasId(hadith.mohdithId)
                          ? ApiService().getScholarDetails(hadith.mohdithId!)
                          : Future.value(ApiResult.error(ApiError.notFound)),
                      format: (scholar) => [
                        if (scholar.name.trim() != hadith.mohdith.trim())
                          scholar.name,
                        scholar.info,
                      ].where((text) => text.trim().isNotEmpty).join('\n\n'),
                    ),
                    const SizedBox(height: 16),
                    _SourceSection<BookDetails>(
                      title: context.l10n.book,
                      name: hadith.book,
                      icon: Icons.menu_book_outlined,
                      load: () => _hasId(hadith.bookId)
                          ? ApiService().getBookDetails(hadith.bookId!)
                          : Future.value(ApiResult.error(ApiError.notFound)),
                      format: (book) =>
                          [
                                if (book.name.trim() != hadith.book.trim())
                                  (context.l10n.book, book.name),
                                (context.l10n.author, book.author),
                                (context.l10n.reviewer, book.reviewer),
                                (context.l10n.publisher, book.publisher),
                                (context.l10n.edition, book.edition),
                                (context.l10n.editionYear, book.editionYear),
                              ]
                              .where((field) => field.$2.trim().isNotEmpty)
                              .map((field) => '${field.$1}: ${field.$2}')
                              .join('\n\n'),
                    ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    ),
  );
}

class _SourceSection<T extends Object> extends StatefulWidget {
  final String title;
  final String name;
  final IconData icon;
  final Future<ApiResult<T>> Function() load;
  final String Function(T) format;

  const _SourceSection({
    required this.title,
    required this.name,
    required this.icon,
    required this.load,
    required this.format,
  });

  @override
  State<_SourceSection<T>> createState() => _SourceSectionState<T>();
}

class _SourceSectionState<T extends Object> extends State<_SourceSection<T>> {
  late Future<ApiResult<T>> _result;

  @override
  void initState() {
    super.initState();
    _result = widget.load();
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final style = context.watch<SettingsViewModel>().readingTextStyle;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colors.primaryContainer,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(widget.icon, color: colors.secondaryContainer),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  widget.title,
                  style: Theme.of(context).textTheme.labelLarge,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (widget.name.trim().isNotEmpty)
            SelectableText(
              widget.name,
              style: style,
              textDirection: TextDirection.rtl,
            ),
          const SizedBox(height: 12),
          FutureBuilder<ApiResult<T>>(
            future: _result,
            builder: (context, snapshot) {
              if (snapshot.connectionState != ConnectionState.done) {
                return const LinearProgressIndicator();
              }
              final result = snapshot.data;
              if (result?.isSuccess != true) {
                return _LoadMessage(
                  error: result?.error,
                  onRetry: () => setState(() {
                    _result = widget.load();
                  }),
                );
              }
              final text = widget.format(result!.data!).trim();
              return text.isEmpty
                  ? Text(context.l10n.noAdditionalInfo)
                  : SelectableText(
                      text,
                      style: style,
                      textDirection: TextDirection.rtl,
                    );
            },
          ),
        ],
      ),
    );
  }
}

class _LoadMessage extends StatelessWidget {
  final ApiError? error;
  final VoidCallback onRetry;

  const _LoadMessage({required this.error, required this.onRetry});

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        error == ApiError.notFound
            ? context.l10n.noAdditionalInfo
            : context.l10n.infoLoadFailed(
                error?.title(context.l10n) ?? context.l10n.retry,
              ),
      ),
      if (error != ApiError.notFound)
        TextButton.icon(
          onPressed: onRetry,
          icon: const Icon(Icons.refresh),
          label: Text(context.l10n.retry),
        ),
    ],
  );
}
