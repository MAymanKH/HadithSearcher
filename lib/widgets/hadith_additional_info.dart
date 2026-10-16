import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../l10n/localization.dart';
import '../models/hadith.dart';
import '../models/hadith_details.dart';
import '../services/api_service.dart';
import '../services/favourite_details_service.dart';
import '../viewmodels/settings_viewmodel.dart';
import 'api_details_sheet.dart';
import 'app_loading_indicator.dart';
import 'hadith_card_layout.dart';
import 'hadith_detail_button.dart';

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
    _controller.addStatusListener((status) {
      if (status == AnimationStatus.dismissed && mounted) setState(() {});
    });
    _size = _controller.drive(CurveTween(curve: Curves.easeInOutCubic));
  }

  @override
  void didUpdateWidget(covariant HadithAdditionalInfo oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(widget.hadith, oldWidget.hadith)) {
      _hadith = widget.hadith;
      _loaded = !widget.fetchDetails;
    }
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
    final result = await FavouriteDetailsService().getSavedDetails(
      widget.hadith.id,
    );
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
    final colors = Theme.of(context).colorScheme;
    final readingStyle = context
        .watch<SettingsViewModel>()
        .readingTextStyle
        .copyWith(color: colors.onSurface);
    return Container(
      margin: const EdgeInsets.only(top: 12),
      child: Material(
        color: colors.surfaceContainerHigh,
        shape: RoundedRectangleBorder(
          side: BorderSide(color: colors.outlineVariant),
          borderRadius: HadithCardLayout.panelBorderRadius,
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: _toggle,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 10,
                ),
                child: Row(
                  children: [
                    Icon(
                      _expanded ? Icons.expand_less : Icons.expand_more,
                      color: colors.onSurface,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _expanded
                            ? context.l10n.hideAdditionalInfo
                            : context.l10n.additionalInfo,
                        style: readingStyle,
                      ),
                    ),
                  ],
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
                child: !_expanded && _controller.isDismissed
                    ? null
                    : TickerMode(
                        enabled: _expanded,
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              if (_loading) const AppLoadingIndicator(),
                              if (_error != null) ...[
                                Text(
                                  context.l10n.additionalInfoLoadFailed(
                                    _error!.title(context.l10n),
                                  ),
                                ),
                                Align(
                                  alignment: AlignmentDirectional.centerStart,
                                  child: TextButton(
                                    onPressed: _load,
                                    child: Text(context.l10n.retry),
                                  ),
                                ),
                              ],
                              if (_loaded && !_hasContent)
                                Text(context.l10n.noAdditionalInfo),
                              if (_hasGradingNote)
                                _infoLine(
                                  context.l10n.gradeExplanation,
                                  _hadith.explainGrade,
                                  readingStyle,
                                ),
                              if (_hadith.takhrij.trim().isNotEmpty)
                                _infoLine(
                                  context.l10n.takhrij,
                                  _hadith.takhrij,
                                  readingStyle,
                                ),
                              if (_hadith.categories.isNotEmpty)
                                _infoLine(
                                  context.l10n.categories,
                                  _hadith.categories
                                      .map((category) => category.name)
                                      .join('، '),
                                  readingStyle,
                                ),
                              if (_hadith.hasUsulHadith &&
                                  _hadith.id.isNotEmpty)
                                HadithDetailButton(
                                  onPressed: () =>
                                      showApiDetailsSheet<HadithOrigins>(
                                        context,
                                        title: context.l10n.hadithSources,
                                        load: () => FavouriteDetailsService()
                                            .getOrigins(_hadith.id),
                                        format: (origins) => origins.sources
                                            .map(
                                              (source) => [
                                                if (source.source
                                                    .trim()
                                                    .isNotEmpty)
                                                  context.l10n.sourceLabel(
                                                    source.source,
                                                  ),
                                                if (source.chain
                                                    .trim()
                                                    .isNotEmpty)
                                                  context.l10n.chainLabel(
                                                    source.chain,
                                                  ),
                                                if (source.text
                                                    .trim()
                                                    .isNotEmpty)
                                                  context.l10n.textLabel(
                                                    source.text,
                                                  ),
                                              ].join('\n\n'),
                                            )
                                            .join('\n\n'),
                                      ),
                                  icon: Icons.account_tree_outlined,
                                  label: context.l10n.hadithChains,
                                ),
                            ],
                          ),
                        ),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _infoLine(String title, String value, TextStyle style) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 4),
    child: SelectableText('$title: $value', style: style),
  );
}
