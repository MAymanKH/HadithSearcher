import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/hadith.dart';
import '../../models/hadith_details.dart';
import '../../services/api_service.dart';
import '../../viewmodels/settings_viewmodel.dart';
import '../../widgets/api_details_dialog.dart';

class HadithDetailsView extends StatefulWidget {
  final Hadith hadith;
  final bool fetchDetails;

  const HadithDetailsView({
    super.key,
    required this.hadith,
    this.fetchDetails = false,
  });

  @override
  State<HadithDetailsView> createState() => _HadithDetailsViewState();
}

class _HadithDetailsViewState extends State<HadithDetailsView> {
  late Hadith _hadith;
  bool _loading = false;
  ApiError? _error;

  @override
  void initState() {
    super.initState();
    _hadith = widget.hadith;
    if (widget.fetchDetails && _hadith.id.isNotEmpty) _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    final result = await ApiService().getHadithById(_hadith.id);
    if (!mounted) return;
    setState(() {
      _loading = false;
      _error = result.error;
      if (result.isSuccess) _hadith = result.data!;
    });
  }

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsViewModel>();
    final colors = Theme.of(context).colorScheme;
    final hadith = _hadith;
    final readingStyle = settings.readingTextStyle;
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'تفاصيل الحديث',
          style: TextStyle(fontSize: 25, fontWeight: FontWeight.bold),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (_loading) const LinearProgressIndicator(),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('تعذر تحميل التفاصيل الإضافية. ${_error!.arabicTitle}'),
                  TextButton(
                    onPressed: _load,
                    child: const Text('أعد المحاولة'),
                  ),
                ],
              ),
            ),
          Container(
            padding: settings.padding + const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: colors.primaryContainer,
              borderRadius: BorderRadius.circular(30),
            ),
            child: SelectableText(hadith.text, style: readingStyle),
          ),
          if (hadith.grade.trim().isNotEmpty)
            _section(
              context,
              'حكم المحدث',
              Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SelectableText(hadith.citation.grading, style: readingStyle),
                  if (hadith.explainGrade.trim().isNotEmpty &&
                      hadith.explainGrade.trim() != hadith.grade.trim()) ...[
                    const SizedBox(height: 8),
                    SelectableText(hadith.explainGrade, style: readingStyle),
                  ],
                ],
              ),
            ),
          if (hadith.rawi.trim().isNotEmpty)
            _section(
              context,
              'الراوي',
              SelectableText(hadith.rawi, style: readingStyle),
            ),
          if (hadith.mohdith.trim().isNotEmpty)
            _citationTile(
              context,
              label: 'المحدث',
              name: hadith.mohdith,
              onTap: hadith.mohdithId?.isNotEmpty == true
                  ? () => showApiDetailsDialog<ScholarDetails>(
                      context,
                      title: hadith.mohdith,
                      load: () =>
                          ApiService().getScholarDetails(hadith.mohdithId!),
                      format: (scholar) => [
                        if (scholar.name.trim() != hadith.mohdith.trim())
                          scholar.name,
                        scholar.info,
                      ].where((text) => text.trim().isNotEmpty).join('\n\n'),
                    )
                  : null,
            ),
          if (hadith.book.trim().isNotEmpty)
            _citationTile(
              context,
              label: 'المصدر',
              name: hadith.book,
              subtitle: hadith.numberOrPage.isNotEmpty
                  ? 'الصفحة أو الرقم: ${hadith.numberOrPage}'
                  : null,
              onTap: hadith.bookId?.isNotEmpty == true
                  ? () => showApiDetailsDialog<BookDetails>(
                      context,
                      title: hadith.book,
                      load: () => ApiService().getBookDetails(hadith.bookId!),
                      format: (book) => _fields([
                        if (book.name.trim() != hadith.book.trim())
                          ('الكتاب', book.name),
                        ('المؤلف', book.author),
                        ('المراجع', book.reviewer),
                        ('دار النشر', book.publisher),
                        ('الطبعة', book.edition),
                        ('سنة الطبعة', book.editionYear),
                      ]),
                    )
                  : null,
            ),
          if (hadith.takhrij.trim().isNotEmpty)
            _section(
              context,
              'التخريج',
              SelectableText(hadith.takhrij, style: readingStyle),
            ),
          if (hadith.categories.isNotEmpty)
            _section(
              context,
              'التصنيف الموضوعي',
              Wrap(
                spacing: 8,
                runSpacing: 4,
                children: [
                  for (final category in hadith.categories)
                    Chip(label: Text(category.name)),
                ],
              ),
            ),
          if (hadith.hasUsulHadith && hadith.id.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: ElevatedButton.icon(
                onPressed: () => showApiDetailsDialog<HadithOrigins>(
                  context,
                  title: 'أصول الحديث',
                  load: () => ApiService().getHadithOrigins(hadith.id),
                  format: (origins) => origins.sources
                      .map(
                        (source) => _fields([
                          ('المصدر', source.source),
                          ('الإسناد', source.chain),
                          ('المتن', source.text),
                        ]),
                      )
                      .join('\n\n'),
                ),
                icon: const Icon(Icons.account_tree_outlined),
                label: const Text('أصول الحديث وطرق إخراجه'),
              ),
            ),
        ],
      ),
    );
  }

  Widget _section(BuildContext context, String title, Widget content) =>
      Padding(
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              title,
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            content,
          ],
        ),
      );

  Widget _citationTile(
    BuildContext context, {
    required String label,
    required String name,
    String? subtitle,
    VoidCallback? onTap,
  }) => ListTile(
    contentPadding: EdgeInsets.zero,
    title: Text(
      label,
      style: Theme.of(
        context,
      ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
    ),
    subtitle: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(name, style: context.watch<SettingsViewModel>().readingTextStyle),
        if (subtitle != null) Text(subtitle),
      ],
    ),
    trailing: onTap != null ? const Icon(Icons.chevron_left) : null,
    onTap: onTap,
  );
}

String _fields(List<(String, String)> fields) => fields
    .where((field) => field.$2.trim().isNotEmpty)
    .map((field) => '${field.$1}: ${field.$2}')
    .join('\n\n');
