import 'package:flutter/material.dart';

import '../state/executor_state.dart';
import '../theme/cbr_theme.dart';
import 'cbr_panel.dart';

/// Console de saída do programa.
class ConsolePanel extends StatefulWidget {
  const ConsolePanel({
    super.key,
    required this.state,
    this.onClear,
    this.onStop,
    this.compact = false,
  });

  final ExecutorState state;
  final VoidCallback? onClear;
  final VoidCallback? onStop;
  final bool compact;

  @override
  State<ConsolePanel> createState() => _ConsolePanelState();
}

class _ConsolePanelState extends State<ConsolePanel> {
  final ScrollController _scroll = ScrollController();
  String _lastOutput = '';

  @override
  void initState() {
    super.initState();
    widget.state.addListener(_onStateChanged);
  }

  @override
  void dispose() {
    widget.state.removeListener(_onStateChanged);
    _scroll.dispose();
    super.dispose();
  }

  void _onStateChanged() {
    if (!mounted) return;
    final output = widget.state.output;
    if (output != _lastOutput) {
      _lastOutput = output;
      WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
    }
    setState(() {});
  }

  void _scrollToBottom() {
    if (!_scroll.hasClients) return;
    _scroll.jumpTo(_scroll.position.maxScrollExtent);
  }

  @override
  Widget build(BuildContext context) {
    final state = widget.state;
    return CbrPanel(
      padding: EdgeInsets.zero,
      radius: 14,
      color: CbrColors.backgroundDeep,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _header(state),
          Container(height: 1, color: CbrColors.border),
          Expanded(
            child: ClipRRect(
              borderRadius: const BorderRadius.vertical(bottom: Radius.circular(14)),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(14, 12, 8, 8),
                child: _body(state),
              ),
            ),
          ),
          _footer(state),
        ],
      ),
    );
  }

  Widget _header(ExecutorState state) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 10, 10, 10),
      child: Row(
        children: [
          const Icon(Icons.terminal_rounded, size: 16, color: CbrColors.greenBright),
          const SizedBox(width: 8),
          Text('Console', style: CbrTextStyles.title.copyWith(fontSize: 13.5)),
          const Spacer(),
          if (state.running)
            CbrButton(
              label: 'Parar',
              icon: Icons.stop_rounded,
              variant: CbrButtonVariant.danger,
              compact: widget.compact,
              onPressed: widget.onStop,
              tooltip: 'Interromper a execução',
            )
          else
            CbrButton(
              label: 'Limpar',
              icon: Icons.delete_outline_rounded,
              variant: CbrButtonVariant.ghost,
              compact: widget.compact,
              onPressed: widget.onClear,
              tooltip: 'Limpar o console',
            ),
        ],
      ),
    );
  }

  Widget _body(ExecutorState state) {
    final hasOutput = state.output.isNotEmpty;
    final hasError = state.errorMessage != null;
    if (!hasOutput && !hasError && !state.running) {
      return Center(
        child: Text(
          'A saída aparecerá aqui.',
          style: CbrTextStyles.bodyMuted,
        ),
      );
    }

    return SingleChildScrollView(
      controller: _scroll,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (state.output.isNotEmpty)
            SelectableText.rich(
              TextSpan(
                text: state.output,
                style: CbrTextStyles.mono.copyWith(
                  fontSize: 13.5,
                  height: 1.65,
                  color: CbrColors.codeText,
                ),
              ),
            ),
          if (state.running)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Row(
                children: [
                  const SizedBox(
                    width: 12,
                    height: 12,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: CbrColors.greenBright,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'executando…',
                    style: CbrTextStyles.mono.copyWith(
                      fontSize: 12,
                      color: CbrColors.textMuted,
                    ),
                  ),
                ],
              ),
            ),
          if (state.errorMessage != null) _errorCard(state.errorMessage!),
        ],
      ),
    );
  }

  Widget _errorCard(String message) {
    return Container(
      margin: const EdgeInsets.only(top: 10, right: 6),
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      decoration: BoxDecoration(
        color: CbrColors.yellow.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: CbrColors.yellow.withValues(alpha: 0.35)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.error_outline_rounded, size: 16, color: CbrColors.yellow),
          const SizedBox(width: 8),
          Expanded(
            child: SelectableText(
              message,
              style: CbrTextStyles.mono.copyWith(
                fontSize: 12.5,
                height: 1.55,
                color: CbrColors.yellowSoft,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _footer(ExecutorState state) {
    Widget leading;
    if (state.running) {
      leading = Row(
        children: [
          const SizedBox(
            width: 8,
            height: 8,
            child: CircularProgressIndicator(strokeWidth: 1.5, color: CbrColors.yellow),
          ),
          const SizedBox(width: 7),
          Text(
            'Executando o programa…',
            style: CbrTextStyles.label.copyWith(color: CbrColors.yellow),
          ),
        ],
      );
    } else if (state.errorMessage != null) {
      leading = Row(
        children: [
          const Icon(Icons.error_outline_rounded, size: 13, color: CbrColors.yellow),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              state.errorLine != null
                  ? 'Erro na linha ${state.errorLine}.'
                  : 'O programa terminou com erro.',
              style: CbrTextStyles.label.copyWith(color: CbrColors.yellow),
            ),
          ),
        ],
      );
    } else if (state.lastRunSucceeded && state.elapsed != null) {
      final milliseconds = state.elapsed!.inMilliseconds;
      leading = Row(
        children: [
          const Icon(Icons.check_circle_outline_rounded, size: 13, color: CbrColors.green),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              'Concluído • ${milliseconds < 1 ? '< 1' : milliseconds} ms',
              overflow: TextOverflow.ellipsis,
              style: CbrTextStyles.label.copyWith(color: CbrColors.green),
            ),
          ),
        ],
      );
    } else {
      leading = Text(
        'Pronto para executar',
        style: CbrTextStyles.label,
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
      decoration: const BoxDecoration(
        color: CbrColors.surface,
        border: Border(top: BorderSide(color: CbrColors.border, width: 0.8)),
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(14)),
      ),
      child: Row(children: [leading]),
    );
  }
}
