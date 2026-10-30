import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/cbr_theme.dart';
import 'highlighted_text.dart';

/// Controlador do editor com destaque de sintaxe e marcação da linha do erro.
class CbrEditingController extends TextEditingController {
  CbrEditingController({super.text});

  double fontSize = 14;
  int? highlightLine;

  String? _cacheKey;
  TextSpan? _cache;

  @override
  TextSpan buildTextSpan({
    required BuildContext context,
    TextStyle? style,
    required bool withComposing,
  }) {
    final key = '$fontSize|$highlightLine|$text';
    if (_cacheKey == key && _cache != null) return _cache!;
    _cacheKey = key;
    _cache = buildHighlightedSpan(
      text,
      fontSize: fontSize,
      highlightLine: highlightLine,
      height: 1.6,
    );
    return _cache!;
  }

  void refreshHighlight() {
    _cacheKey = null;
    _cache = null;
    notifyListeners();
  }
}

/// Editor de código com numeração de linhas, rolagem nos dois eixos e
/// atalhos de teclado.
class CbrCodeEditor extends StatefulWidget {
  const CbrCodeEditor({
    super.key,
    required this.controller,
    required this.fontSize,
    this.highlightLine,
    this.onRun,
    this.onSave,
    this.onOpen,
  });

  final CbrEditingController controller;
  final double fontSize;
  final int? highlightLine;
  final VoidCallback? onRun;
  final VoidCallback? onSave;
  final VoidCallback? onOpen;

  @override
  State<CbrCodeEditor> createState() => _CbrCodeEditorState();
}

class _CbrCodeEditorState extends State<CbrCodeEditor> {
  final ScrollController _vertical = ScrollController();
  final ScrollController _horizontal = ScrollController();
  final FocusNode _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    widget.controller.fontSize = widget.fontSize;
    widget.controller.highlightLine = widget.highlightLine;
    widget.controller.addListener(_onTextChanged);
  }

  @override
  void didUpdateWidget(CbrCodeEditor oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.fontSize != widget.fontSize) {
      widget.controller.fontSize = widget.fontSize;
      widget.controller.refreshHighlight();
    }
    if (oldWidget.highlightLine != widget.highlightLine) {
      widget.controller.highlightLine = widget.highlightLine;
      widget.controller.refreshHighlight();
    }
  }

  void _onTextChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onTextChanged);
    _vertical.dispose();
    _horizontal.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  double get _lineHeight => widget.fontSize * 1.6;

  void _insertIndent({bool outdent = false}) {
    final value = widget.controller.value;
    final selection = value.selection;
    if (!selection.isValid) return;
    final text = value.text;
    final lineStart = text.lastIndexOf('\n', math.max(0, selection.start - 1)) + 1;
    final indent = '    ';
    if (!outdent) {
      final newText = text.replaceRange(selection.start, selection.end, indent);
      widget.controller.value = value.copyWith(
        text: newText,
        selection: TextSelection.collapsed(offset: selection.start + indent.length),
        composing: TextRange.empty,
      );
      return;
    }
    var remove = 0;
    for (var index = 0; index < indent.length; index++) {
      if (lineStart + index < text.length && text[lineStart + index] == ' ') {
        remove++;
      } else {
        break;
      }
    }
    if (remove == 0) return;
    final newText = text.replaceRange(lineStart, lineStart + remove, '');
    widget.controller.value = value.copyWith(
      text: newText,
      selection: TextSelection.collapsed(
        offset: math.max(lineStart, selection.start - remove),
      ),
      composing: TextRange.empty,
    );
  }

  @override
  Widget build(BuildContext context) {
    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.keyR, control: true): () =>
            widget.onRun?.call(),
        const SingleActivator(LogicalKeyboardKey.keyR, meta: true): () =>
            widget.onRun?.call(),
        const SingleActivator(LogicalKeyboardKey.enter, control: true): () =>
            widget.onRun?.call(),
        const SingleActivator(LogicalKeyboardKey.enter, meta: true): () =>
            widget.onRun?.call(),
        const SingleActivator(LogicalKeyboardKey.keyS, control: true): () =>
            widget.onSave?.call(),
        const SingleActivator(LogicalKeyboardKey.keyS, meta: true): () =>
            widget.onSave?.call(),
        const SingleActivator(LogicalKeyboardKey.keyO, control: true): () =>
            widget.onOpen?.call(),
        const SingleActivator(LogicalKeyboardKey.keyO, meta: true): () =>
            widget.onOpen?.call(),
        const SingleActivator(LogicalKeyboardKey.tab): () => _insertIndent(),
        const SingleActivator(LogicalKeyboardKey.tab, shift: true): () =>
            _insertIndent(outdent: true),
      },
      child: Focus(
        focusNode: _focusNode,
        autofocus: true,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final digits = '${widget.controller.text.split('\n').length}'.length;
            final gutterWidth = 18.0 + digits * (widget.fontSize * 0.62);
            final contentWidth = math.max(
              constraints.maxWidth - gutterWidth,
              _longestLineWidth(constraints.maxWidth - gutterWidth),
            );
            return Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _Gutter(
                  controller: widget.controller,
                  scrollController: _vertical,
                  fontSize: widget.fontSize,
                  lineHeight: _lineHeight,
                  width: gutterWidth,
                ),
                Container(width: 1, color: CbrColors.border.withValues(alpha: 0.7)),
                Expanded(
                  child: Scrollbar(
                    controller: _horizontal,
                    scrollbarOrientation: ScrollbarOrientation.bottom,
                    child: SingleChildScrollView(
                      controller: _horizontal,
                      scrollDirection: Axis.horizontal,
                      padding: EdgeInsets.zero,
                      child: SizedBox(
                        width: contentWidth,
                        height: constraints.maxHeight,
                        child: TextField(
                          controller: widget.controller,
                          scrollController: _vertical,
                          focusNode: _focusNode,
                          expands: true,
                          maxLines: null,
                          minLines: null,
                          autocorrect: false,
                          enableSuggestions: false,
                          keyboardType: TextInputType.multiline,
                          textCapitalization: TextCapitalization.none,
                          cursorColor: CbrColors.greenBright,
                          cursorWidth: 2,
                          style: CbrTextStyles.mono.copyWith(
                            fontSize: widget.fontSize,
                            height: 1.6,
                          ),
                          strutStyle: StrutStyle(
                            fontFamily: 'monospace',
                            fontFamilyFallback: kMonoFallback,
                            fontSize: widget.fontSize,
                            height: 1.6,
                            forceStrutHeight: true,
                          ),
                          decoration: const InputDecoration(
                            border: InputBorder.none,
                            filled: false,
                            isCollapsed: true,
                            contentPadding: EdgeInsets.fromLTRB(14, 12, 32, 24),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  double _longestLineWidth(double available) {
    var longest = 0;
    for (final line in widget.controller.text.split('\n')) {
      if (line.length > longest) longest = line.length;
    }
    final estimated = longest * widget.fontSize * 0.62 + 80;
    return math.max(estimated, available);
  }
}

class _Gutter extends StatelessWidget {
  const _Gutter({
    required this.controller,
    required this.scrollController,
    required this.fontSize,
    required this.lineHeight,
    required this.width,
  });

  final TextEditingController controller;
  final ScrollController scrollController;
  final double fontSize;
  final double lineHeight;
  final double width;

  @override
  Widget build(BuildContext context) {
    final count = controller.text.split('\n').length;
    return SizedBox(
      width: width,
      child: ClipRect(
        child: AnimatedBuilder(
          animation: scrollController,
          builder: (context, _) {
            final offset = scrollController.hasClients ? scrollController.offset : 0.0;
            return Stack(
              children: [
                Positioned(
                  top: 12 - offset,
                  left: 0,
                  right: 0,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: List<Widget>.generate(
                      count,
                      (index) => SizedBox(
                        height: lineHeight,
                        child: Align(
                          alignment: Alignment.centerRight,
                          child: Padding(
                            padding: const EdgeInsets.only(right: 9),
                            child: Text(
                              '${index + 1}',
                              style: CbrTextStyles.mono.copyWith(
                                fontSize: fontSize - 1.5,
                                height: 1.6,
                                color: CbrColors.textFaint,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
