import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../l10n/localization.dart';
import '../viewmodels/settings_viewmodel.dart';
import 'app_snack_bar.dart';
import 'hadith_detail_button.dart';

class HadithCardLayout extends StatelessWidget {
  static const borderRadius = BorderRadius.all(Radius.circular(30));
  static const panelBorderRadius = BorderRadius.all(Radius.circular(20));
  final EdgeInsetsGeometry margin;
  final String text;
  final String? narrator;
  final String? grading;
  final String attribution;
  final VoidCallback? onSourceInfo;
  final bool isFavourite;
  final VoidCallback? onExplanation;
  final VoidCallback? onSimilar;
  final bool showSimilarButton;
  final VoidCallback onShare;
  final VoidCallback onFavourite;
  final VoidCallback? onAlternate;
  final Widget? additionalInfo;

  const HadithCardLayout({
    super.key,
    this.margin = const EdgeInsets.all(10),
    required this.text,
    this.narrator,
    required this.grading,
    required this.attribution,
    this.onSourceInfo,
    required this.isFavourite,
    required this.onExplanation,
    required this.onSimilar,
    this.showSimilarButton = true,
    required this.onShare,
    required this.onFavourite,
    required this.onAlternate,
    this.additionalInfo,
  });

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsViewModel>();
    final colors = Theme.of(context).colorScheme;
    final textStyle = settings.readingTextStyle.copyWith(
      color: colors.secondaryContainer,
    );
    return Container(
      margin: margin,
      padding: settings.padding,
      decoration: BoxDecoration(
        color: colors.primaryContainer,
        borderRadius: borderRadius,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (narrator?.trim().isNotEmpty ?? false)
            SelectableText.rich(
              TextSpan(
                children: [
                  TextSpan(
                    text: 'عن ${narrator!.trim()}: ',
                    style: TextStyle(
                      color: Color.alphaBlend(
                        colors.secondaryContainer.withValues(alpha: 0.65),
                        colors.primaryContainer,
                      ),
                    ),
                  ),
                  TextSpan(text: text),
                ],
              ),
              style: textStyle,
              textDirection: TextDirection.rtl,
            )
          else
            SelectableText(
              text,
              style: textStyle,
              textDirection: TextDirection.rtl,
            ),
          Padding(
            padding: const EdgeInsets.only(top: 14, bottom: 12),
            child: Divider(
              height: 1,
              color: colors.secondaryContainer.withValues(alpha: 0.22),
            ),
          ),
          if (grading != null) ...[
            SelectableText(grading!, style: textStyle),
            if (onAlternate != null) _buildAlternateButton(context),
            const SizedBox(height: 4),
          ],
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(child: SelectableText(attribution, style: textStyle)),
              if (onSourceInfo != null)
                IconButton(
                  tooltip: context.l10n.sourceDetails,
                  onPressed: onSourceInfo,
                  icon: const Icon(Icons.error_outline_rounded),
                  color: colors.secondaryContainer,
                ),
            ],
          ),
          if (grading == null && onAlternate != null)
            _buildAlternateButton(context),
          ?additionalInfo,
          const SizedBox(height: 14),
          Material(
            color: colors.secondaryContainer,
            shape: const RoundedRectangleBorder(
              borderRadius: panelBorderRadius,
            ),
            clipBehavior: Clip.antiAlias,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _CardAction(
                  icon: Icons.article_outlined,
                  label: context.l10n.explanation,
                  onPressed: onExplanation,
                  unavailableMessage: context.l10n.noExplanation,
                  foregroundColor: colors.surface,
                ),
                if (showSimilarButton)
                  _CardAction(
                    icon: Icons.library_books_outlined,
                    label: context.l10n.similar,
                    onPressed: onSimilar,
                    unavailableMessage: context.l10n.noSimilarForHadith,
                    foregroundColor: colors.surface,
                  ),
                _CardAction(
                  icon: isFavourite ? Icons.star : Icons.star_border,
                  label: context.l10n.favourites,
                  onPressed: onFavourite,
                  foregroundColor: colors.surface,
                ),
                _CardAction(
                  icon: Icons.share_outlined,
                  label: context.l10n.share,
                  onPressed: onShare,
                  foregroundColor: colors.surface,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAlternateButton(BuildContext context) => HadithDetailButton(
    icon: Icons.fact_check_outlined,
    label: context.l10n.alternate,
    onPressed: onAlternate,
  );
}

class _CardAction extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback? onPressed;
  final Color foregroundColor;
  final String? unavailableMessage;

  const _CardAction({
    required this.icon,
    required this.label,
    required this.onPressed,
    required this.foregroundColor,
    this.unavailableMessage,
  });

  @override
  Widget build(BuildContext context) {
    final button = TextButton(
      onPressed:
          onPressed ??
          (unavailableMessage == null
              ? null
              : () {
                  ScaffoldMessenger.of(context).removeCurrentSnackBar();
                  showAppSnackBar(
                    context,
                    SnackBar(
                      content: Text(unavailableMessage!),
                      duration: const Duration(seconds: 2),
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                }),
      style: TextButton.styleFrom(
        foregroundColor: onPressed == null
            ? foregroundColor.withValues(alpha: 0.38)
            : foregroundColor,
        disabledForegroundColor: foregroundColor.withValues(alpha: 0.38),
        padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 8),
        minimumSize: const Size(0, 62),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        shape: const RoundedRectangleBorder(),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 22),
          const SizedBox(height: 4),
          Text(
            label,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
    return Expanded(child: button);
  }
}
