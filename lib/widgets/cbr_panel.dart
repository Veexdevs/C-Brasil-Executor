import 'package:flutter/material.dart';

import '../theme/cbr_theme.dart';

/// Cartão de superfície usado em todo o app.
class CbrPanel extends StatelessWidget {
  const CbrPanel({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(20),
    this.radius = 8,
    this.color,
    this.borderColor,
    this.gradient,
    this.clip = false,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final double radius;
  final Color? color;
  final Color? borderColor;
  final Gradient? gradient;
  final bool clip;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding,
      clipBehavior: clip ? Clip.antiAlias : Clip.none,
      decoration: BoxDecoration(
        color: gradient == null ? (color ?? CbrColors.surface) : null,
        gradient: gradient,
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: borderColor ?? CbrColors.border),
      ),
      child: child,
    );
  }
}

/// Cabeçalho de painel com ícone, título e ações à direita.
class CbrPanelHeader extends StatelessWidget {
  const CbrPanelHeader({
    super.key,
    required this.title,
    this.icon,
    this.trailing,
    this.subtitle,
  });

  final String title;
  final Widget? icon;
  final Widget? trailing;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        if (icon != null) ...[icon!, const SizedBox(width: 10)],
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              title,
              style: CbrTextStyles.title.copyWith(fontSize: 14.5),
            ),
            if (subtitle != null)
              Text(subtitle!, style: CbrTextStyles.bodyMuted.copyWith(fontSize: 11.5)),
          ],
        ),
        const Spacer(),
        if (trailing != null) trailing!,
      ],
    );
  }
}

/// Etiqueta pequena (dialeto, status, versão).
class CbrChip extends StatelessWidget {
  const CbrChip({
    super.key,
    required this.label,
    this.color = CbrColors.green,
    this.icon,
    this.filled = false,
    this.tooltip,
  });

  final String label;
  final Color color;
  final IconData? icon;
  final bool filled;
  final String? tooltip;

  @override
  Widget build(BuildContext context) {
    final content = Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: filled ? color.withValues(alpha: 0.16) : Colors.transparent,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: filled ? 0.45 : 0.35)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 12, color: Colors.white),
            const SizedBox(width: 5),
          ],
          Text(
            label,
            style: TextStyle(
              fontFamily: 'monospace',
              fontFamilyFallback: kMonoFallback,
              fontSize: 10.5,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.3,
              color: color,
            ),
          ),
        ],
      ),
    );
    if (tooltip == null) return content;
    return Tooltip(message: tooltip!, child: content);
  }
}

/// Botão principal e variações usadas nas barras.
class CbrButton extends StatelessWidget {
  const CbrButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.variant = CbrButtonVariant.secondary,
    this.compact = false,
    this.busy = false,
    this.tooltip,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final CbrButtonVariant variant;
  final bool compact;
  final bool busy;
  final String? tooltip;

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null && !busy;
    final child = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (busy)
          const SizedBox(
            width: 14,
            height: 14,
            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
          )
        else if (icon != null)
          Icon(icon, size: compact ? 16 : 17, color: Colors.white),
        if ((icon != null || busy) && !compact) const SizedBox(width: 8),
        if (!compact)
          Text(
            label,
            style: TextStyle(
              fontFamily: 'Inter',
              fontFamilyFallback: kSansFallback,
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: variant == CbrButtonVariant.primary
                  ? CbrColors.greenBright
                  : CbrColors.text,
            ),
          ),
      ],
    );

    final button = switch (variant) {
      CbrButtonVariant.primary => DecoratedBox(
          decoration: BoxDecoration(
            color: CbrColors.surfaceRaised,
            border: Border.all(
              color: enabled ? CbrColors.greenBright : CbrColors.border,
            ),
            borderRadius: BorderRadius.circular(6),
          ),
          child: TextButton(
            onPressed: enabled ? onPressed : null,
            style: TextButton.styleFrom(
              padding: EdgeInsets.symmetric(horizontal: compact ? 10 : 16, vertical: 12),
              minimumSize: const Size(0, 40),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
              foregroundColor: CbrColors.greenBright,
            ),
            child: child,
          ),
        ),
      CbrButtonVariant.secondary => OutlinedButton(
          onPressed: enabled ? onPressed : null,
          style: OutlinedButton.styleFrom(
            padding: EdgeInsets.symmetric(horizontal: compact ? 10 : 14, vertical: 12),
            minimumSize: const Size(0, 40),
            side: const BorderSide(color: CbrColors.border),
            backgroundColor: CbrColors.surfaceAlt,
            foregroundColor: CbrColors.text,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
          ),
          child: child,
        ),
      CbrButtonVariant.ghost => TextButton(
          onPressed: enabled ? onPressed : null,
          style: TextButton.styleFrom(
            padding: EdgeInsets.symmetric(horizontal: compact ? 10 : 12, vertical: 12),
            minimumSize: const Size(0, 38),
            foregroundColor: CbrColors.textMuted,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
          ),
          child: child,
        ),
      CbrButtonVariant.danger => OutlinedButton(
          onPressed: enabled ? onPressed : null,
          style: OutlinedButton.styleFrom(
            padding: EdgeInsets.symmetric(horizontal: compact ? 10 : 14, vertical: 12),
            minimumSize: const Size(0, 40),
            side: BorderSide(color: CbrColors.yellow.withValues(alpha: 0.5)),
            backgroundColor: CbrColors.yellow.withValues(alpha: 0.1),
            foregroundColor: CbrColors.yellow,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
          ),
          child: child,
        ),
    };
    if (tooltip == null) return button;
    return Tooltip(message: tooltip!, child: button);
  }
}

enum CbrButtonVariant { primary, secondary, ghost, danger }

/// Título de seção com uma linha de apoio.
class SectionHeader extends StatelessWidget {
  const SectionHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.icon,
  });

  final String title;
  final String? subtitle;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            if (icon != null) ...[
              Icon(icon, size: 18, color: Colors.white),
              const SizedBox(width: 8),
            ],
            Flexible(
              child: Text(title, style: CbrTextStyles.title.copyWith(fontSize: 18)),
            ),
          ],
        ),
        if (subtitle != null) ...[
          const SizedBox(height: 4),
          Text(subtitle!, style: CbrTextStyles.bodyMuted),
        ],
      ],
    );
  }
}
