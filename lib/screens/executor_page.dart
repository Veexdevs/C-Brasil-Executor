import 'package:flutter/material.dart';

import '../data/examples.dart';
import '../services/platform_service.dart';
import '../state/executor_state.dart';
import '../theme/cbr_theme.dart';
import '../widgets/cbr_logo.dart';
import '../widgets/cbr_panel.dart';
import '../widgets/code_editor.dart';
import '../widgets/console_panel.dart';

/// Tela principal: editor + console.
class ExecutorPage extends StatefulWidget {
  const ExecutorPage({super.key, required this.state});

  final ExecutorState state;

  @override
  State<ExecutorPage> createState() => _ExecutorPageState();
}

class _ExecutorPageState extends State<ExecutorPage> {
  int _lastCaretLine = 1;
  int _lastCaretColumn = 1;

  @override
  void initState() {
    super.initState();
    widget.state.addListener(_onStateChanged);
    widget.state.controller.addListener(_onCaretMoved);
    widget.state.inputHandler = _askInput;
  }

  @override
  void dispose() {
    widget.state.removeListener(_onStateChanged);
    widget.state.controller.removeListener(_onCaretMoved);
    if (widget.state.inputHandler == _askInput) {
      widget.state.inputHandler = null;
    }
    super.dispose();
  }

  void _onStateChanged() {
    if (mounted) setState(() {});
  }

  void _onCaretMoved() {
    final selection = widget.state.controller.selection;
    final offset = selection.baseOffset;
    if (offset < 0) return;
    final text = widget.state.controller.text;
    final safeOffset = offset.clamp(0, text.length);
    final before = text.substring(0, safeOffset);
    final line = '\n'.allMatches(before).length + 1;
    final column = safeOffset - before.lastIndexOf('\n');
    if (line != _lastCaretLine || column != _lastCaretColumn) {
      setState(() {
        _lastCaretLine = line;
        _lastCaretColumn = column;
      });
    }
  }

  Future<String> _askInput(String prompt) async {
    if (!mounted) return '';
    final controller = TextEditingController();
    final result = await showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return AlertDialog(
          title: Row(
            children: [
              const Icon(Icons.keyboard_alt_outlined, color: CbrColors.green),
              const SizedBox(width: 10),
              Text(
                'O programa pediu uma entrada',
                style: CbrTextStyles.title.copyWith(fontSize: 15),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (prompt.trim().isNotEmpty) ...[
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: CbrColors.backgroundDeep,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: CbrColors.border),
                  ),
                  child: Text(
                    prompt.trimRight(),
                    style: CbrTextStyles.mono.copyWith(fontSize: 12.5),
                  ),
                ),
                const SizedBox(height: 14),
              ],
              TextField(
                controller: controller,
                autofocus: true,
                onSubmitted: (value) => Navigator.of(dialogContext).pop(value),
                decoration: const InputDecoration(hintText: 'Digite o valor'),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(''),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(controller.text),
              child: const Text('Enviar'),
            ),
          ],
        );
      },
    );
    controller.dispose();
    return result ?? '';
  }

  void _snack(String message, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              error ? Icons.error_outline_rounded : Icons.check_circle_outline_rounded,
              size: 17,
              color: error ? CbrColors.red : CbrColors.green,
            ),
            const SizedBox(width: 10),
            Expanded(child: Text(message)),
          ],
        ),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  Future<void> _openFile() async {
    final file = await PlatformService.openFile();
    if (file == null) return;
    widget.state.loadProgram(file.content, name: file.name);
    _snack('Arquivo "${file.name}" carregado.');
  }

  Future<void> _saveFile() async {
    final state = widget.state;
    final name = state.filename.toLowerCase().endsWith('.cbr')
        ? state.filename
        : '${state.filename}.cbr';
    final path = await PlatformService.saveFile(name, state.controller.text);
    if (path == null) {
      _snack('Não foi possível salvar o arquivo.', error: true);
      return;
    }
    state.dirty = false;
    state.filename = name;
    await state.persist();
    if (!mounted) return;
    setState(() {});
    _snack(PlatformService.isWeb ? 'Download de $name iniciado.' : 'Arquivo salvo em $path');
  }

  void _newFile() {
    widget.state.newProgram();
  }

  @override
  Widget build(BuildContext context) {
    final state = widget.state;
    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= 1020;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _hero(state, wide),
            const SizedBox(height: 18),
            Expanded(
              child: wide
                  ? Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Expanded(flex: 58, child: _editorPanel(state, wide)),
                        const SizedBox(width: 16),
                        Expanded(flex: 42, child: _console(state, wide)),
                      ],
                    )
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Expanded(flex: 56, child: _editorPanel(state, false)),
                        const SizedBox(height: 12),
                        Expanded(flex: 44, child: _console(state, false)),
                      ],
                    ),
            ),
          ],
        );
      },
    );
  }

  Widget _hero(ExecutorState state, bool wide) {
    final title = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 12,
          runSpacing: 6,
          children: [
            ShaderMask(
              shaderCallback: (rect) => const LinearGradient(
                colors: [CbrColors.text, Color(0xFFB7F5DA)],
              ).createShader(rect),
              child: Text(
                'C Brasil',
                style: CbrTextStyles.headline.copyWith(fontSize: wide ? 34 : 26),
              ),
            ),
            Text(
              'CBR',
              style: CbrTextStyles.headline.copyWith(
                fontSize: wide ? 20 : 15,
                color: CbrColors.greenBright,
                letterSpacing: 1.2,
              ),
            ),
            const CbrChip(label: 'linguagem 1.0', color: CbrColors.blue, icon: Icons.memory_rounded),
          ],
        ),
        const SizedBox(height: 6),
        Text(
          'Uma linguagem simples, moderna e poderosa. Escreva, execute e veja o '
          'resultado em tempo real — sem enviar seu código para nenhum servidor.',
          style: CbrTextStyles.bodyMuted.copyWith(fontSize: wide ? 13.5 : 12.5),
        ),
      ],
    );

    if (!wide) {
      return Padding(
        padding: const EdgeInsets.only(top: 4),
        child: title,
      );
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(child: title),
        const SizedBox(width: 24),
        _brandCard(),
      ],
    );
  }

  Widget _brandCard() {
    return Container(
      width: 300,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: CbrColors.heroGradient,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: CbrColors.border),
      ),
      child: Row(
        children: [
          const CbrLogo(size: 42, glow: true),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'C Brasil (CBR)',
                  style: CbrTextStyles.title.copyWith(fontSize: 13.5),
                ),
                const SizedBox(height: 2),
                Text(
                  'Código. Simples. Poderoso.',
                  style: CbrTextStyles.bodyMuted.copyWith(fontSize: 11.5),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Container(
                      width: 7,
                      height: 7,
                      decoration: const BoxDecoration(
                        color: CbrColors.green,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'execução local • offline',
                      style: CbrTextStyles.label.copyWith(fontSize: 10),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _editorPanel(ExecutorState state, bool wide) {
    final lineCount = state.controller.text.split('\n').length;
    return CbrPanel(
      padding: EdgeInsets.zero,
      radius: 14,
      color: CbrColors.surface,
      clip: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _toolbar(state, wide),
          Container(height: 1, color: CbrColors.border),
          Expanded(
            child: CbrCodeEditor(
              controller: state.controller,
              fontSize: state.fontSize,
              highlightLine: state.highlightedLine,
              onRun: state.run,
              onSave: _saveFile,
              onOpen: _openFile,
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
            decoration: const BoxDecoration(
              color: CbrColors.backgroundDeep,
              border: Border(top: BorderSide(color: CbrColors.border, width: 0.8)),
            ),
            child: Row(
              children: [
                const Icon(Icons.circle, size: 6, color: CbrColors.green),
                const SizedBox(width: 6),
                Text(
                  'UTF-8',
                  style: CbrTextStyles.label.copyWith(fontSize: 10),
                ),
                const SizedBox(width: 14),
                Text(
                  'Ln $_lastCaretLine, Col $_lastCaretColumn',
                  style: CbrTextStyles.label.copyWith(fontSize: 10),
                ),
                const Spacer(),
                if (wide)
                  Text(
                    'Ctrl+Enter executa • Ctrl+S salva',
                    style: CbrTextStyles.label.copyWith(fontSize: 10),
                  ),
                const SizedBox(width: 12),
                Text(
                  '$lineCount linhas',
                  style: CbrTextStyles.label.copyWith(fontSize: 10),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _toolbar(ExecutorState state, bool wide) {
    final dirty = state.dirty;
    return Container(
      padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
      color: CbrColors.surfaceAlt,
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: CbrColors.surface,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: CbrColors.border),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.description_outlined, size: 14, color: CbrColors.greenBright),
                const SizedBox(width: 7),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 150),
                  child: Text(
                    state.filename,
                    overflow: TextOverflow.ellipsis,
                    style: CbrTextStyles.mono.copyWith(
                      fontSize: 12,
                      color: CbrColors.text,
                    ),
                  ),
                ),
                if (dirty) ...[
                  const SizedBox(width: 6),
                  Container(
                    width: 6,
                    height: 6,
                    decoration: const BoxDecoration(
                      color: CbrColors.yellow,
                      shape: BoxShape.circle,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 8),
          if (wide) ...[
            CbrButton(
              label: 'Novo',
              icon: Icons.add_rounded,
              variant: CbrButtonVariant.ghost,
              onPressed: _newFile,
              tooltip: 'Novo arquivo',
            ),
            CbrButton(
              label: 'Abrir',
              icon: Icons.folder_open_rounded,
              variant: CbrButtonVariant.ghost,
              onPressed: _openFile,
              tooltip: 'Abrir .cbr',
            ),
            CbrButton(
              label: 'Salvar',
              icon: Icons.save_outlined,
              variant: CbrButtonVariant.ghost,
              onPressed: _saveFile,
              tooltip: 'Salvar .cbr',
            ),
          ] else ...[
            CbrButton(
              label: 'Abrir',
              icon: Icons.folder_open_rounded,
              variant: CbrButtonVariant.ghost,
              compact: true,
              onPressed: _openFile,
              tooltip: 'Abrir .cbr',
            ),
            CbrButton(
              label: 'Salvar',
              icon: Icons.save_outlined,
              variant: CbrButtonVariant.ghost,
              compact: true,
              onPressed: _saveFile,
              tooltip: 'Salvar .cbr',
            ),
          ],
          const Spacer(),
          PopupMenuButton<CbrExample>(
            tooltip: 'Abrir exemplo',
            color: CbrColors.surfaceRaised,
            onSelected: (example) {
              state.loadProgram(example.code, name: example.filename);
            },
            itemBuilder: (context) => [
              for (final example in cbrExamples)
                PopupMenuItem(
                  value: example,
                  child: Row(
                    children: [
                      const Icon(Icons.auto_awesome_outlined,
                          size: 15, color: CbrColors.yellow),
                      const SizedBox(width: 10),
                      Text(example.title, style: CbrTextStyles.body),
                    ],
                  ),
                ),
            ],
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(9),
                border: Border.all(color: CbrColors.border),
                color: CbrColors.surface,
              ),
              child: const Icon(Icons.auto_awesome_outlined,
                  size: 16, color: CbrColors.yellow),
            ),
          ),
          const SizedBox(width: 10),
          CbrButton(
            label: state.running ? 'Executando' : 'Executar',
            icon: state.running ? null : Icons.play_arrow_rounded,
            busy: state.running,
            variant: CbrButtonVariant.primary,
            compact: false,
            onPressed: state.running ? null : state.run,
            tooltip: 'Executar (Ctrl+Enter)',
          ),
        ],
      ),
    );
  }

  Widget _console(ExecutorState state, bool wide) {
    return ConsolePanel(
      state: state,
      compact: !wide,
      onClear: state.clearConsole,
      onStop: state.stop,
    );
  }
}
