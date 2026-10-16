import 'package:flutter/material.dart';

/// A decorative miniature using the same color roles as a hadith card.
class ColorSchemeCardPreview extends StatelessWidget {
  const ColorSchemeCardPreview({super.key, required this.colors});

  final ColorScheme colors;

  @override
  Widget build(BuildContext context) => ExcludeSemantics(
    child: Container(
      width: 72,
      height: 52,
      padding: const EdgeInsets.all(5),
      decoration: BoxDecoration(
        color: colors.surfaceContainer,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: colors.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _line(colors.onSurface, 1),
          const SizedBox(height: 3),
          _line(colors.onSurface, .8),
          const SizedBox(height: 3),
          _line(colors.onSurfaceVariant, .55),
          const Spacer(),
          Container(
            height: 13,
            decoration: BoxDecoration(
              color: colors.inverseSurface,
              borderRadius: BorderRadius.circular(5),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                for (var index = 0; index < 4; index++)
                  Container(
                    width: 6,
                    height: 3,
                    decoration: BoxDecoration(
                      color: colors.onInverseSurface,
                      borderRadius: BorderRadius.circular(1),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    ),
  );

  Widget _line(Color color, double widthFactor) => Align(
    alignment: AlignmentDirectional.centerStart,
    child: FractionallySizedBox(
      widthFactor: widthFactor,
      child: Container(height: 3, color: color),
    ),
  );
}
