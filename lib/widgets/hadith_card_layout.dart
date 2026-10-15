import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../viewmodels/settings_viewmodel.dart';

class HadithCardLayout extends StatelessWidget {
  static const borderRadius = BorderRadius.all(Radius.circular(30));
  final String text;
  final String? grading;
  final String attribution;
  final bool isFavourite;
  final VoidCallback onExplanation;
  final VoidCallback? onSimilar;
  final VoidCallback onShare;
  final VoidCallback onFavourite;
  final VoidCallback? onAlternate;
  final Widget? additionalInfo;

  const HadithCardLayout({
    super.key,
    required this.text,
    required this.grading,
    required this.attribution,
    required this.isFavourite,
    required this.onExplanation,
    required this.onSimilar,
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
      margin: const EdgeInsets.all(10),
      padding: settings.padding,
      decoration: BoxDecoration(
        color: colors.primaryContainer,
        borderRadius: borderRadius,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SelectableText(text, style: textStyle),
          Padding(
            padding: const EdgeInsets.only(top: 14, bottom: 12),
            child: Divider(
              height: 1,
              color: colors.secondaryContainer.withValues(alpha: 0.22),
            ),
          ),
          if (grading != null) ...[
            SelectableText(grading!, style: textStyle),
            if (onAlternate != null) _buildAlternateButton(),
            const SizedBox(height: 4),
          ],
          SelectableText(attribution, style: textStyle),
          if (grading == null && onAlternate != null) _buildAlternateButton(),
          if (additionalInfo != null) additionalInfo!,
          const SizedBox(height: 14),
          Material(
            color: colors.secondaryContainer,
            shape: const RoundedRectangleBorder(borderRadius: borderRadius),
            clipBehavior: Clip.antiAlias,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _CardAction(
                  icon: Icons.article_outlined,
                  label: 'الشرح',
                  onPressed: onExplanation,
                  foregroundColor: colors.surface,
                ),
                if (onSimilar != null)
                  _CardAction(
                    icon: Icons.library_books_outlined,
                    label: 'مشابهة',
                    onPressed: onSimilar!,
                    foregroundColor: colors.surface,
                  ),
                _CardAction(
                  icon: Icons.share_outlined,
                  label: 'مشاركة',
                  onPressed: onShare,
                  foregroundColor: colors.surface,
                ),
                _CardAction(
                  icon: isFavourite ? Icons.star : Icons.star_border,
                  label: 'المفضلة',
                  onPressed: onFavourite,
                  foregroundColor: colors.surface,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAlternateButton() {
    return Align(
      alignment: AlignmentDirectional.centerStart,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: ElevatedButton.icon(
          onPressed: onAlternate,
          icon: const Icon(Icons.fact_check_outlined, size: 22),
          label: const Text(
            'البديل الصحيح',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          style: ElevatedButton.styleFrom(
            minimumSize: const Size(0, 45),
            shape: RoundedRectangleBorder(borderRadius: borderRadius),
          ),
        ),
      ),
    );
  }
}

class _CardAction extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onPressed;
  final Color foregroundColor;

  const _CardAction({
    required this.icon,
    required this.label,
    required this.onPressed,
    required this.foregroundColor,
  });

  @override
  Widget build(BuildContext context) {
    final button = TextButton(
      onPressed: onPressed,
      style: TextButton.styleFrom(
        foregroundColor: foregroundColor,
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
