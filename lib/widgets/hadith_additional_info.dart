import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/hadith.dart';
import '../models/hadith_details.dart';
import '../services/api_service.dart';
import '../viewmodels/settings_viewmodel.dart';
import 'api_details_dialog.dart';

class HadithAdditionalInfo extends StatefulWidget {
  final Hadith hadith;
  final bool fetchDetails;

  const HadithAdditionalInfo({
    super.key,
    required this.hadith,
    this.fetchDetails = false,
  });

  @override
  State<HadithAdditionalInfo> createState() => _HadithAdditionalInfoState();
}

class _HadithAdditionalInfoState extends State<HadithAdditionalInfo>
    with SingleTickerProviderStateMixin {
  late Hadith _hadith;
  late bool _loaded;
  late final AnimationController _controller;
  late final Animation<double> _size;
  bool _expanded = false;
  bool _loading = false;
  ApiError? _error;

  @override
  void initState() {
    super.initState();
    _hadith = widget.hadith;
    _loaded = !widget.fetchDetails;
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 250),
    );
    _size = _controller.drive(CurveTween(curve: Curves.easeInOutCubic));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _toggle() {
    setState(() => _expanded = !_expanded);
    if (MediaQuery.disableAnimationsOf(context)) {
      _controller.value = _expanded ? 1 : 0;
    } else if (_expanded) {
      _controller.forward();
    } else {
      _controller.reverse();
    }
    if (_expanded && !_loaded && !_loading) unawaited(_load());
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    final result = await ApiService().getHadithById(widget.hadith.id);
    if (!mounted) return;
    setState(() {
      _loading = false;
      _error = result.error;
      if (result.isSuccess) {
        _hadith = result.data!;
        _loaded = true;
      }
    });
  }

  bool get _hasGradingNote =>
      _hadith.explainGrade.trim().isNotEmpty &&
      _hadith.explainGrade.trim() != _hadith.grade.trim() &&
      _hadith.explainGrade.trim() != widget.hadith.grade.trim();

  bool get _hasContent =>
      _hasGradingNote ||
      _hadith.takhrij.trim().isNotEmpty ||
      _hadith.categories.isNotEmpty ||
      _hadith.hasUsulHadith;

  @override
  Widget build(BuildContext context) {
    if (!_hasContent && !(widget.fetchDetails && widget.hadith.id.isNotEmpty)) {
      return const SizedBox.shrink();
    }
    final readingStyle = context.watch<SettingsViewModel>().readingTextStyle;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Align(
          alignment: AlignmentDirectional.centerStart,
          child: TextButton.icon(
            onPressed: _toggle,
            icon: Icon(_expanded ? Icons.expand_less : Icons.expand_more),
            label: Text(
              _expanded ? 'إخفاء المعلومات الإضافية' : 'معلومات إضافية',
              style: readingStyle,
            ),
          ),
        ),
        AnimatedBuilder(
          animation: _controller,
          builder: (context, child) => Offstage(
            offstage: _controller.isDismissed,
            child: ClipRect(
              child: Align(
                alignment: Alignment.topCenter,
                heightFactor: _size.value,
                child: FadeTransition(opacity: _size, child: child),
              ),
            ),
          ),
          child: TickerMode(
            enabled: _expanded,
            child: Padding(
              padding: const EdgeInsets.only(top: 4, bottom: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (_loading) const LinearProgressIndicator(),
                  if (_error != null) ...[
                    Text(
                      'تعذر تحميل المعلومات الإضافية. ${_error!.arabicTitle}',
                    ),
                    Align(
                      alignment: AlignmentDirectional.centerStart,
                      child: TextButton(
                        onPressed: _load,
                        child: const Text('أعد المحاولة'),
                      ),
                    ),
                  ],
                  if (_loaded && !_hasContent)
                    const Text('لا تتوفر معلومات إضافية من المصدر'),
                  if (_hasGradingNote)
                    _infoLine(
                      'توضيح الحكم',
                      _hadith.explainGrade,
                      readingStyle,
                    ),
                  if (_hadith.takhrij.trim().isNotEmpty)
                    _infoLine('التخريج', _hadith.takhrij, readingStyle),
                  if (_hadith.categories.isNotEmpty)
                    _infoLine(
                      'التصنيف الموضوعي',
                      _hadith.categories
                          .map((category) => category.name)
                          .join('، '),
                      readingStyle,
                    ),
                  if (_hadith.hasUsulHadith && _hadith.id.isNotEmpty)
                    Align(
                      alignment: AlignmentDirectional.centerStart,
                      child: TextButton.icon(
                        onPressed: () => showApiDetailsDialog<HadithOrigins>(
                          context,
                          title: 'أصول الحديث',
                          load: () => ApiService().getHadithOrigins(_hadith.id),
                          format: (origins) => origins.sources
                              .map(
                                (source) => [
                                  if (source.source.trim().isNotEmpty)
                                    'المصدر: ${source.source}',
                                  if (source.chain.trim().isNotEmpty)
                                    'الإسناد: ${source.chain}',
                                  if (source.text.trim().isNotEmpty)
                                    'المتن: ${source.text}',
                                ].join('\n\n'),
                              )
                              .join('\n\n'),
                        ),
                        icon: const Icon(Icons.account_tree_outlined),
                        label: Text(
                          'أصول الحديث وطرق إخراجه',
                          style: readingStyle,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _infoLine(String title, String value, TextStyle style) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 4),
    child: SelectableText('$title: $value', style: style),
  );
}
