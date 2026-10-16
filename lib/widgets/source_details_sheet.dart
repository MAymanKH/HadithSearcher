import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../l10n/localization.dart';
import '../models/hadith_details.dart';
import '../services/api_service.dart';
import '../viewmodels/settings_viewmodel.dart';

bool hasSourceId(String? id) =>
    id != null && id.trim().isNotEmpty && id.trim() != '0';

Future<void> showSourceDetailsSheet(
  BuildContext context, {
  required String title,
  required Widget child,
}) => showModalBottomSheet<void>(
  context: context,
  isScrollControlled: true,
  useSafeArea: true,
  showDragHandle: true,
  shape: const RoundedRectangleBorder(
    borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
  ),
  builder: (context) => SafeArea(
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
                    title,
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
            child,
          ],
        ),
      ),
    ),
  ),
);

class ScholarSourceDetails extends StatelessWidget {
  final String name;
  final String? id;
  const ScholarSourceDetails({super.key, required this.name, required this.id});

  @override
  Widget build(BuildContext context) => _SourceDetailsSection<ScholarDetails>(
    title: context.l10n.scholar,
    name: name,
    icon: Icons.person_outline,
    load: () => hasSourceId(id)
        ? ApiService().getScholarDetails(id!.trim())
        : Future.value(ApiResult.error(ApiError.notFound)),
    format: (scholar) => [
      if (scholar.name.trim() != name.trim()) scholar.name,
      scholar.info,
    ].where((text) => text.trim().isNotEmpty).join('\n\n'),
  );
}

class BookSourceDetails extends StatelessWidget {
  final String name;
  final String? id;
  const BookSourceDetails({super.key, required this.name, required this.id});

  @override
  Widget build(BuildContext context) => _SourceDetailsSection<BookDetails>(
    title: context.l10n.book,
    name: name,
    icon: Icons.menu_book_outlined,
    load: () => hasSourceId(id)
        ? ApiService().getBookDetails(id!.trim())
        : Future.value(ApiResult.error(ApiError.notFound)),
    format: (book) =>
        [
              if (book.name.trim() != name.trim())
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
  );
}

class _SourceDetailsSection<T extends Object> extends StatefulWidget {
  final String title;
  final String name;
  final IconData icon;
  final Future<ApiResult<T>> Function() load;
  final String Function(T) format;

  const _SourceDetailsSection({
    required this.title,
    required this.name,
    required this.icon,
    required this.load,
    required this.format,
  });

  @override
  State<_SourceDetailsSection<T>> createState() =>
      _SourceDetailsSectionState<T>();
}

class _SourceDetailsSectionState<T extends Object>
    extends State<_SourceDetailsSection<T>> {
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
        color: colors.surfaceContainer,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(widget.icon, color: colors.onSurface),
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
                return SourceDetailsMessage(
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

class SourceDetailsMessage extends StatelessWidget {
  final ApiError? error;
  final VoidCallback onRetry;

  const SourceDetailsMessage({
    super.key,
    required this.error,
    required this.onRetry,
  });

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
