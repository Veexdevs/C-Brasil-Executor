import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../cbr/cbr.dart';
import '../theme/cbr_theme.dart';

/// Monta um [TextSpan] com o código já destacado.
TextSpan buildHighlightedSpan(
  String code, {
  double fontSize = 13.5,
  Color? baseColor,
  int? highlightLine,
  double height = 1.6,
}) {
  final highlighter = CbrHighlighter();
  final spans = <TextSpan>[];
  final lines = code.split('\n');
  for (var index = 0; index < lines.length; index++) {
    final line = lines[index];
    final lineSpans = highlighter.highlightLine(line)
      ..sort((a, b) => a.start.compareTo(b.start));
    final isMarked = highlightLine != null && index + 1 == highlightLine;
    var cursor = 0;
    for (final span in lineSpans) {
      if (span.end > line.length || span.start < cursor) continue;
      if (span.start > cursor) {
        spans.add(TextSpan(
          text: line.substring(cursor, span.start),
          style: _base(fontSize, baseColor, height, isMarked),
        ));
      }
      spans.add(TextSpan(
        text: line.substring(span.start, span.end),
        style: styleForToken(span.style, fontSize)
            .copyWith(height: height)
            .merge(_markStyle(isMarked)),
      ));
      cursor = span.end;
    }
    if (cursor < line.length) {
      spans.add(TextSpan(
        text: line.substring(cursor),
        style: _base(fontSize, baseColor, height, isMarked),
      ));
    }
    if (index < lines.length - 1) spans.add(TextSpan(text: '\n', style: _base(fontSize, baseColor, height, false)));
  }
  return TextSpan(children: spans);
}

TextStyle _base(double fontSize, Color? color, double height, bool marked) {
  return CbrTextStyles.mono.copyWith(
    fontSize: fontSize,
    height: height,
    color: marked ? CbrColors.text : (color ?? CbrColors.codeText),
  ).merge(_markStyle(marked));
}

TextStyle _markStyle(bool marked) {
  if (!marked) return const TextStyle();
  return const TextStyle(
    backgroundColor: Color(0x33FF7B7B),
    decoration: TextDecoration.underline,
    decorationColor: CbrColors.red,
  );
}

/// Bloco de código com destaque de sintaxe, opcionalmente com numeração e
/// botão de copiar.
class CodeBlock extends StatelessWidget {
  const CodeBlock(
    this.code, {
    super.key,
    this.fontSize = 13.5,
    this.showLineNumbers = false,
    this.showCopy = true,
    this.title,
    this.highlightLine,
    this.padding = const EdgeInsets.fromLTRB(16, 12, 16, 14),
  });

  final String code;
  final double fontSize;
  final bool showLineNumbers;
  final bool showCopy;
  final String? title;
  final int? highlightLine;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    final lines = code.split('\n');
    return Container(
      decoration: BoxDecoration(
        color: CbrColors.backgroundDeep,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: CbrColors.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (title != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: const BoxDecoration(
                color: CbrColors.surface,
                border: Border(bottom: BorderSide(color: CbrColors.border, width: 0.8)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.code_rounded, size: 14, color: CbrColors.greenBright),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      title!,
                      overflow: TextOverflow.ellipsis,
                      style: CbrTextStyles.label.copyWith(color: CbrColors.textMuted),
                    ),
                  ),
                ],
              ),
            ),
          Stack(
            children: [
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                padding: padding.add(
                  EdgeInsets.only(right: showCopy ? 44 : padding.right),
                ),
                child: showLineNumbers
                    ? Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            [
                              for (var index = 0; index < lines.length; index++)
                                '${index + 1}',
                            ].join('\n'),
                            textAlign: TextAlign.right,
                            style: CbrTextStyles.mono.copyWith(
                              fontSize: fontSize,
                              height: 1.6,
                              color: CbrColors.textFaint,
                            ),
                          ),
                          const SizedBox(width: 16),
                          RichText(
                            text: buildHighlightedSpan(
                              code,
                              fontSize: fontSize,
                              highlightLine: highlightLine,
                            ),
                          ),
                        ],
                      )
                    : RichText(
                        text: buildHighlightedSpan(
                          code,
                          fontSize: fontSize,
                          highlightLine: highlightLine,
                        ),
                      ),
              ),
              if (showCopy)
                Positioned(
                  top: 6,
                  right: 6,
                  child: _CopyButton(text: code),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _CopyButton extends StatefulWidget {
  const _CopyButton({required this.text});

  final String text;

  @override
  State<_CopyButton> createState() => _CopyButtonState();
}

class _CopyButtonState extends State<_CopyButton> {
  bool _copied = false;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: _copied ? 'Copiado!' : 'Copiar código',
      iconSize: 15,
      visualDensity: VisualDensity.compact,
      onPressed: () async {
        await Clipboard.setData(ClipboardData(text: widget.text));
        if (!mounted) return;
        setState(() => _copied = true);
        await Future<void>.delayed(const Duration(seconds: 2));
        if (mounted) setState(() => _copied = false);
      },
      icon: Icon(
        _copied ? Icons.check_rounded : Icons.copy_rounded,
        color: _copied ? CbrColors.greenBright : CbrColors.textFaint,
      ),
    );
  }
}
