import 'package:flutter/material.dart';

import '../theme/cbr_theme.dart';

/// Logo oficial (arquivo `assets/branding/logo.png`), com cantos arredondados.
class CbrLogo extends StatelessWidget {
  const CbrLogo({super.key, this.size = 40, this.radius, this.glow = false});

  final double size;
  final double? radius;
  final bool glow;

  @override
  Widget build(BuildContext context) {
    final rounded = ClipRRect(
      borderRadius: BorderRadius.circular(radius ?? size * 0.26),
      child: Image.asset(
        'assets/branding/logo.png',
        width: size,
        height: size,
        filterQuality: FilterQuality.high,
        isAntiAlias: true,
      ),
    );
    if (!glow) return rounded;
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(radius ?? size * 0.26),
        boxShadow: [
          BoxShadow(
            color: CbrColors.green.withValues(alpha: 0.32),
            blurRadius: size * 0.5,
            spreadRadius: 1,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: rounded,
    );
  }
}

/// Marca completa: logo + "C Brasil" + sigla.
class CbrWordmark extends StatelessWidget {
  const CbrWordmark({
    super.key,
    this.logoSize = 40,
    this.showSubtitle = false,
    this.showAcronym = true,
    this.onTap,
  });

  final double logoSize;
  final bool showSubtitle;
  final bool showAcronym;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final titleSize = logoSize * 0.45;
    final content = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        CbrLogo(size: logoSize),
        SizedBox(width: logoSize * 0.3),
        Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
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
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.6,
                    color: CbrColors.text,
                  ),
                ),
                if (showAcronym) ...[
                  const SizedBox(width: 6),
                  Text(
                    '(CBR)',
                    style: TextStyle(
                      fontFamily: 'monospace',
                      fontFamilyFallback: kMonoFallback,
                      fontSize: titleSize * 0.62,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.5,
                      color: CbrColors.greenBright,
                    ),
                  ),
                ],
              ],
            ),
            if (showSubtitle)
              Text(
                'Linguagem de programação brasileira',
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontFamilyFallback: kSansFallback,
                  fontSize: titleSize * 0.5,
                  height: 1.25,
                  color: CbrColors.textMuted,
                ),
              ),
          ],
        ),
      ],
    );
    if (onTap == null) return content;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(padding: const EdgeInsets.all(2), child: content),
    );
  }
}
