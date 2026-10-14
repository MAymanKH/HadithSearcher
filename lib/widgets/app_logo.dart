import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

class AppLogo extends StatelessWidget {
  final double size;

  const AppLogo({super.key, this.size = 112});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return SvgPicture.asset(
      isDark ? 'assets/icons/logo.svg' : 'assets/icons/logo_light.svg',
      width: size,
      height: size,
      colorFilter: isDark
          ? const ColorFilter.mode(Colors.white, BlendMode.srcIn)
          : null,
      excludeFromSemantics: true,
    );
  }
}
