import 'package:flutter/material.dart';

import '../theme/cbr_theme.dart';

class CbrLogo extends StatelessWidget {
  const CbrLogo({super.key, this.size = 40, this.radius});

  final double size;
  final double? radius;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius ?? size * 0.26),
      child: Image.asset(
        'assets/branding/logo.png',
        width: size,
        height: size,
        fit: BoxFit.contain,
        filterQuality: FilterQuality.high,
        isAntiAlias: true,
      ),
    );
  }
}

/// Brand lockup: logo followed by “C Brasil (cbr)”.
class CbrWordmark extends StatelessWidget {
  const CbrWordmark({super.key, this.logoSize = 40, this.onTap});

  final double logoSize;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final titleSize = logoSize * 0.45;
    final content = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        CbrLogo(size: logoSize),
        SizedBox(width: logoSize * 0.3),
        Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Text(
              'C Brasil',
              style: TextStyle(
                fontFamily: 'Inter',
                fontFamilyFallback: kSansFallback,
                fontSize: titleSize,
                fontWeight: FontWeight.w700,
                letterSpacing: -0.35,
                color: CbrColors.text,
              ),
            ),
            const SizedBox(width: 5),
            Text(
              '(cbr)',
              style: TextStyle(
                fontFamily: 'monospace',
                fontFamilyFallback: kMonoFallback,
                fontSize: titleSize * 0.66,
                fontWeight: FontWeight.w600,
                color: CbrColors.greenBright,
              ),
            ),
          ],
        ),
      ],
    );

    if (onTap == null) return content;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Padding(padding: const EdgeInsets.all(2), child: content),
    );
  }
}
