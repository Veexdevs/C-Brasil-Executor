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
      radius: 6,
      color: CbrColors.background,
      clip: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _header(state),
          Container(height: 1, color: CbrColors.border),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 8, 8),
              child: _body(state),
            ),
          ),
        ],
      ),
    );
  }

  Widget _header(ExecutorState state) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 6, 8, 6),
      child: Row(
        children: [
          const Icon(Icons.terminal_rounded, size: 16, color: Colors.white),
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
    if (state.output.isEmpty && state.errorMessage == null && !state.running) {
      return const SizedBox.expand();
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
                  fontSize: 15,
                  height: 1.6,
                  color: CbrColors.codeText,
                ),
              ),
            ),
          if (state.running)
            const Padding(
              padding: EdgeInsets.only(top: 8),
              child: SizedBox(
                width: 14,
                height: 14,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: CbrColors.greenBright,
                ),
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
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: CbrColors.yellow.withValues(alpha: 0.35)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.error_outline_rounded, size: 16, color: Colors.white),
          const SizedBox(width: 8),
          Expanded(
            child: SelectableText(
              message,
              style: CbrTextStyles.mono.copyWith(
                fontSize: 13.5,
                height: 1.5,
                color: CbrColors.yellowSoft,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
