import 'package:flutter/material.dart';

import '../data/examples.dart';
import '../services/platform_service.dart';
import '../state/executor_state.dart';
import '../theme/cbr_theme.dart';
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
  @override
  void initState() {
    super.initState();
    widget.state.addListener(_onStateChanged);
    widget.state.inputHandler = _askInput;
  }

  @override
  void dispose() {
    widget.state.removeListener(_onStateChanged);
    if (widget.state.inputHandler == _askInput) {
      widget.state.inputHandler = null;
    }
    super.dispose();
  }

  void _onStateChanged() {
    if (mounted) setState(() {});
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
              const Icon(Icons.keyboard_alt_outlined, color: Colors.white),
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
              color: Colors.white,
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
        if (wide) {
          return Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(flex: 64, child: _editorPanel(state, true)),
              const SizedBox(width: 6),
              Expanded(flex: 36, child: _console(state, true)),
            ],
          );
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(flex: 62, child: _editorPanel(state, false)),
            const SizedBox(height: 6),
            Expanded(flex: 38, child: _console(state, false)),
          ],
        );
      },
    );
  }

  Widget _editorPanel(ExecutorState state, bool wide) {
    return CbrPanel(
      padding: EdgeInsets.zero,
      radius: 6,
      color: CbrColors.background,
      clip: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _toolbar(state, wide),
          Container(height: 1, color: CbrColors.border),
          Expanded(
            child: CbrCodeEditor(
              controller: state.controller,
              fontSize: 16.0,
              highlightLine: state.highlightedLine,
              onRun: state.run,
              onSave: _saveFile,
              onOpen: _openFile,
            ),
          ),
        ],
      ),
    );
  }

  Widget _toolbar(ExecutorState state, bool wide) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 720;
        return Container(
          padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
          color: CbrColors.surfaceAlt,
          child: Row(
            children: [
              Expanded(
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: _filenameChip(state),
                ),
              ),
              const SizedBox(width: 8),
              if (compact) ...[
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
              ] else ...[
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
              ],
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
                          const Icon(Icons.library_books_outlined,
                              size: 15, color: Colors.white),
                          const SizedBox(width: 10),
                          Flexible(
                            child: Text(
                              example.title,
                              overflow: TextOverflow.ellipsis,
                              style: CbrTextStyles.body,
                            ),
                          ),
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
                  child: const Icon(Icons.library_books_outlined,
                      size: 16, color: Colors.white),
                ),
              ),
              const SizedBox(width: 8),
              CbrButton(
                label: state.running ? 'Executando' : 'Executar',
                icon: state.running ? null : Icons.play_arrow_rounded,
                busy: state.running,
                variant: CbrButtonVariant.primary,
                compact: compact,
                onPressed: state.running ? null : state.run,
                tooltip: 'Executar (Ctrl+Enter)',
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _filenameChip(ExecutorState state) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: CbrColors.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: CbrColors.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.description_outlined, size: 14, color: Colors.white),
          const SizedBox(width: 7),
          Flexible(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 150),
              child: Text(
                state.filename,
                overflow: TextOverflow.ellipsis,
                softWrap: false,
                style: CbrTextStyles.mono.copyWith(
                  fontSize: 12,
                  color: CbrColors.text,
                ),
              ),
            ),
          ),
          if (state.dirty) ...[
            const SizedBox(width: 6),
            Container(
              width: 6,
              height: 6,
              decoration: const BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
              ),
            ),
          ],
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
