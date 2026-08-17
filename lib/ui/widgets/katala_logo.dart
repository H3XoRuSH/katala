import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:katala/ui/theme/colors.dart';

/// A theme-aware logo for Katala rendering the raw SVG asset directly.
class KatalaLogo extends StatelessWidget {
  final double size;
  final Color? color;
  final bool showBackground;

  const KatalaLogo({
    super.key,
    this.size = 48.0,
    this.color,
    this.showBackground = false,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final iconColor = color ?? (isDark ? AppColors.accentSecondary : AppColors.accentPrimary);
    final bgColor = isDark ? AppColors.darkSurfaceCard : AppColors.lightSurfaceCard;

    Widget icon = SvgPicture.asset(
      'assets/icons/katala_logo.svg',
      width: size,
      height: size,
      fit: BoxFit.contain,
      colorFilter: ColorFilter.mode(iconColor, BlendMode.srcIn),
    );

    if (showBackground) {
      return Container(
        width: size * 1.35,
        height: size * 1.35,
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(size * 0.3),
          boxShadow: [
            BoxShadow(
              color: iconColor.withAlpha(isDark ? 40 : 25),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        alignment: Alignment.center,
        child: icon,
      );
    }

    return icon;
  }
}
