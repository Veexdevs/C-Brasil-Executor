import 'dart:convert';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'cbr/interpreter.dart';

const _background = Color(0xFF0D1117);
const _surface = Color(0xFF161B22);
const _surfaceRaised = Color(0xFF1C2128);
const _border = Color(0xFF30363D);
const _textPrimary = Color(0xFFE6EDF3);
const _textSecondary = Color(0xFF8B949E);
const _green = Color(0xFF2DA44E);
const _greenBright = Color(0xFF3FB950);
const _yellow = Color(0xFFD29922);
const _blue = Color(0xFF58A6FF);

const _starterProgram = '''inicio
escreva("Olá, C Brasil!")

inteiro idade
idade = 18

se (idade >= 18) então
    escreva("Você é maior de idade.")
senao
    escreva("Você é menor de idade.")
fimse

para (inteiro i = 1; i <= 5; i = i + 1) faça
    escreva("Contagem: ", i)
fimpara

retorne 0
fim
''';

const _functionsProgram = '''function dobro(x) {
    return x * 2
}

base = 2
expoente = 3
potencia = base ** expoente
resultado = dobro(5)
dados = [12, "Brasil", true, 3.14]
idade = 18
maior = idade >= 18

if (maior) {
    printf("Idade: {int.idade}; dobro: {float.resultado}; potência: {int.potencia}\\n")
} else {
    printf("Idade abaixo do limite\\n")
}
printf("Array: {int.dados[0]}, {str.dados[1]}, {bool.dados[2]}, {float.dados[3]}\\n")

for i in range(1, 6) {
    printf("Contagem: {int.i}\\n")
}
end(0)
''';

const _inputProgram = '''idade = 0
scan("Qual é a sua idade? ", {int.idade})
if (idade >= 18) {
    printf("Acesso liberado.\\n")
} else {
    printf("Acesso somente com um responsável.\\n")
}
end(0)
''';

void main() {
  runApp(const CbrApp());
}

class CbrApp extends StatelessWidget {
  const CbrApp({super.key});

  @override
  Widget build(BuildContext context) {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: _green,
      brightness: Brightness.dark,
    ).copyWith(
      primary: _green,
      secondary: _yellow,
      tertiary: _blue,
      surface: _surface,
      error: _blue,
    );
    return MaterialApp(
      title: 'C Brasil (cbr)',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        colorScheme: colorScheme,
        scaffoldBackgroundColor: _background,
        dialogTheme: const DialogThemeData(
          backgroundColor: _surfaceRaised,
          surfaceTintColor: Colors.transparent,
        ),
        snackBarTheme: SnackBarThemeData(
          backgroundColor: _surfaceRaised,
          contentTextStyle: const TextStyle(color: _textPrimary),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
        tooltipTheme: const TooltipThemeData(
          decoration: BoxDecoration(color: _surfaceRaised),
          textStyle: TextStyle(color: _textPrimary),
        ),
      ),
      home: const CbrHome(),
    );
  }
}

enum _AppPage { executor, examples }

class CbrHome extends StatefulWidget {
  const CbrHome({super.key});

  @override
  State<CbrHome> createState() => _CbrHomeState();
}

class _CbrHomeState extends State<CbrHome> {
  late final _SyntaxController _editorController;
  final ScrollController _editorScrollController = ScrollController();
  final ScrollController _consoleScrollController = ScrollController();

  _AppPage _page = _AppPage.executor;
  String _filename = 'main.cbr';
  String _output = '';
  String? _runMessage;
  bool _runSuccess = true;
  bool _running = false;
  double _fontSize = 14;

  @override
  void initState() {
    super.initState();
    _editorController = _SyntaxController(text: _starterProgram);
    _editorController.addListener(_onEditorChanged);
  }

  void _onEditorChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _editorController.removeListener(_onEditorChanged);
    _editorController.dispose();
    _editorScrollController.dispose();
    _consoleScrollController.dispose();
    super.dispose();
  }

  Future<void> _runProgram() async {
    if (_running) return;
    setState(() {
      _running = true;
      _output = '';
      _runSuccess = true;
      _runMessage = 'Executando…';
    });

    try {
      final result = await CbrInterpreter(_editorController.text).run(
        onOutput: (chunk) {
          if (!mounted) return;
          setState(() => _output += chunk);
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (_consoleScrollController.hasClients) {
              _consoleScrollController.jumpTo(_consoleScrollController.position.maxScrollExtent);
            }
          });
        },
        inputProvider: _requestProgramInput,
      );
      if (!mounted) return;
      setState(() {
        _runSuccess = result.exitCode == 0;
        _runMessage = result.exitCode == 0
            ? 'Executado em ${_formatDuration(result.elapsed)}'
            : 'Código ${result.exitCode} • ${_formatDuration(result.elapsed)}';
      });
    } on CbrException catch (error) {
      if (!mounted) return;
      setState(() {
        _runSuccess = false;
        _runMessage = 'Erro na linha ${error.line}: ${error.message}';
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _runSuccess = false;
        _runMessage = 'Falha inesperada: $error';
      });
    } finally {
      if (mounted) setState(() => _running = false);
    }
  }

  String _formatDuration(Duration duration) {
    if (duration.inMilliseconds < 1) return '< 1 ms';
    return '${duration.inMilliseconds} ms';
  }

  Future<String> _requestProgramInput(String prompt) async {
    final controller = TextEditingController();
    final value = await showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.keyboard_alt_outlined, color: _green),
            SizedBox(width: 10),
            Text('Entrada do programa'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (prompt.isNotEmpty) ...[
              Text(prompt, style: const TextStyle(color: _textSecondary)),
              const SizedBox(height: 14),
            ],
            TextField(
              controller: controller,
              autofocus: true,
              onSubmitted: (_) => Navigator.of(dialogContext).pop(controller.text),
              decoration: const InputDecoration(
                hintText: 'Digite um valor',
                border: OutlineInputBorder(),
              ),
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
      ),
    );
    controller.dispose();
    return value ?? '';
  }

  Future<void> _openFile() async {
    try {
      final files = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: const ['cbr', 'txt'],
      );
      if (files.isEmpty) return;
      final file = files.single;
      final bytes = await file.readAsBytes();
      if (!mounted) return;
      setState(() {
        _filename = file.name;
        _editorController.text = utf8.decode(bytes, allowMalformed: true);
        _output = '';
        _runMessage = null;
        _page = _AppPage.executor;
      });
    } on PlatformException catch (error) {
      _showMessage('Não foi possível abrir o arquivo: ${error.message ?? error.code}');
    } catch (error) {
      _showMessage('Não foi possível abrir o arquivo: $error');
    }
  }

  Future<void> _saveFile() async {
    try {
      final filename = _filename.toLowerCase().endsWith('.cbr') ? _filename : '$_filename.cbr';
      final path = await FilePicker.saveFile(
        fileName: filename,
        type: FileType.custom,
        allowedExtensions: const ['cbr', 'txt'],
        bytes: Uint8List.fromList(utf8.encode(_editorController.text)),
      );
      if (path != null) _showMessage('Arquivo salvo com sucesso.');
    } on PlatformException catch (error) {
      _showMessage('Não foi possível salvar: ${error.message ?? error.code}');
    } catch (error) {
      _showMessage('Não foi possível salvar: $error');
    }
  }

  void _newFile() {
    setState(() {
      _filename = 'sem-titulo.cbr';
      _editorController.text = '';
      _output = '';
      _runMessage = null;
    });
  }

  void _loadExample(String code, {String filename = 'exemplo.cbr'}) {
    setState(() {
      _filename = filename;
      _editorController.text = code;
      _output = '';
      _runMessage = null;
      _page = _AppPage.executor;
    });
  }

  void _clearConsole() {
    setState(() {
      _output = '';
      _runMessage = null;
    });
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _showSettings() async {
    final result = await showDialog<_EditorSettings>(
      context: context,
      builder: (context) => _SettingsDialog(fontSize: _fontSize),
    );
    if (result == null || !mounted) return;
    setState(() => _fontSize = result.fontSize);
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        return Scaffold(
          body: SafeArea(
            child: Column(
              children: [
                _TopBar(
                  selected: _page,
                  onSelect: (page) => setState(() => _page = page),
                  onSettings: _showSettings,
                ),
                Expanded(child: _buildPage(width)),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildPage(double width) {
    switch (_page) {
      case _AppPage.executor:
        return _buildExecutor(width);
      case _AppPage.examples:
        return _ExamplesPage(
          onOpenPortuguese: () => _loadExample(_starterProgram, filename: 'primeiro-programa.cbr'),
          onOpenFunctions: () => _loadExample(_functionsProgram, filename: 'funcoes.cbr'),
          onOpenInput: () => _loadExample(_inputProgram, filename: 'entrada.cbr'),
        );
    }
  }

  Widget _buildExecutor(double width) {
    final isWide = width >= 920;
    final editor = _EditorPanel(
      controller: _editorController,
      scrollController: _editorScrollController,
      filename: _filename,
      running: _running,
      fontSize: _fontSize,
      compact: !isWide,
      onOpen: _openFile,
      onSave: _saveFile,
      onRun: _runProgram,
      onClose: _newFile,
    );
    final console = _ConsolePanel(
      output: _output,
      scrollController: _consoleScrollController,
      message: _runMessage,
      success: _runSuccess,
      running: _running,
      onClear: _clearConsole,
    );

    if (isWide) {
      return Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1560),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 20, 24, 20),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(flex: 6, child: editor),
                const SizedBox(width: 12),
                Expanded(flex: 4, child: console),
              ],
            ),
          ),
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        SizedBox(height: 510, child: editor),
        const SizedBox(height: 12),
        SizedBox(height: 320, child: console),
      ],
    );
  }

}

class _TopBar extends StatelessWidget {
  const _TopBar({
    required this.selected,
    required this.onSelect,
    required this.onSettings,
  });

  final _AppPage selected;
  final ValueChanged<_AppPage> onSelect;
  final VoidCallback onSettings;

  @override
  Widget build(BuildContext context) {
    final compact = MediaQuery.sizeOf(context).width < 720;
    return Container(
      height: 64,
      padding: EdgeInsets.symmetric(horizontal: compact ? 14 : 26),
      decoration: const BoxDecoration(
        color: _surface,
        border: Border(bottom: BorderSide(color: _border)),
      ),
      child: Row(
        children: [
          const _BrandMark(size: 40),
          const SizedBox(width: 9),
          const Text(
            'C Brasil',
            style: TextStyle(
              color: _textPrimary,
              fontSize: 17,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.2,
            ),
          ),
          const SizedBox(width: 6),
          const Text('(cbr)', style: TextStyle(color: _textSecondary, fontSize: 12)),
          const Spacer(),
          if (compact)
            PopupMenuButton<_AppPage>(
              tooltip: 'Navegação',
              icon: const Icon(Icons.menu_rounded, color: _textSecondary),
              onSelected: onSelect,
              itemBuilder: (context) => const [
                PopupMenuItem(value: _AppPage.executor, child: Text('Editor')),
                PopupMenuItem(value: _AppPage.examples, child: Text('Exemplos')),
              ],
            )
          else ...[
            _NavButton(label: 'Editor', page: _AppPage.executor, selected: selected, onSelect: onSelect),
            const SizedBox(width: 4),
            _NavButton(label: 'Exemplos', page: _AppPage.examples, selected: selected, onSelect: onSelect),
          ],
          const SizedBox(width: 6),
          IconButton(
            tooltip: 'Configurações',
            onPressed: onSettings,
            icon: const Icon(Icons.settings_outlined, size: 20, color: _textSecondary),
          ),
        ],
      ),
    );
  }
}

class _NavButton extends StatelessWidget {
  const _NavButton({required this.label, required this.page, required this.selected, required this.onSelect});

  final String label;
  final _AppPage page;
  final _AppPage selected;
  final ValueChanged<_AppPage> onSelect;

  @override
  Widget build(BuildContext context) {
    final active = page == selected;
    return TextButton(
      onPressed: () => onSelect(page),
      style: TextButton.styleFrom(
        foregroundColor: active ? _greenBright : _textSecondary,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
      ),
      child: Text(label, style: TextStyle(fontSize: 13, fontWeight: active ? FontWeight.w600 : FontWeight.w400)),
    );
  }
}

class _BrandMark extends StatelessWidget {
  const _BrandMark({this.size = 42});

  final double size;

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      'assets/images/cbrasil-logo.png',
      width: size,
      height: size,
      fit: BoxFit.contain,
      semanticLabel: 'Logo C Brasil',
    );
  }
}

class _EditorPanel extends StatelessWidget {
  const _EditorPanel({
    required this.controller,
    required this.scrollController,
    required this.filename,
    required this.running,
    required this.fontSize,
    required this.onOpen,
    required this.onSave,
    required this.onRun,
    required this.onClose,
    this.compact = false,
  });

  final _SyntaxController controller;
  final ScrollController scrollController;
  final String filename;
  final bool running;
  final double fontSize;
  final VoidCallback onOpen;
  final VoidCallback onSave;
  final VoidCallback onRun;
  final VoidCallback onClose;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: _border),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          _EditorToolbar(
            filename: filename,
            running: running,
            compact: compact,
            onOpen: onOpen,
            onSave: onSave,
            onRun: onRun,
            onClose: onClose,
          ),
          const Divider(height: 1, color: _border),
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _LineNumberGutter(controller: controller, scrollController: scrollController, fontSize: fontSize),
                Container(width: 1, color: const Color(0xFF202B36)),
                Expanded(
                  child: Scrollbar(
                    controller: scrollController,
                    thumbVisibility: true,
                    child: TextField(
                      controller: controller,
                      scrollController: scrollController,
                      expands: true,
                      maxLines: null,
                      minLines: null,
                      autocorrect: false,
                      enableSuggestions: false,
                      keyboardType: TextInputType.multiline,
                      textCapitalization: TextCapitalization.none,
                      style: TextStyle(
                        fontFamily: 'monospace',
                        fontSize: fontSize,
                        height: 1.55,
                        color: _textPrimary,
                      ),
                      cursorColor: _greenBright,
                      decoration: const InputDecoration(
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.fromLTRB(14, 12, 28, 20),
                        isCollapsed: false,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          Container(
            height: 28,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: const BoxDecoration(
              color: _surface,
              border: Border(top: BorderSide(color: _border)),
            ),
            child: Row(
              children: [
                const Spacer(),
                Text('${controller.text.split('\n').length} linhas', style: const TextStyle(color: _textSecondary, fontSize: 10)),
                const SizedBox(width: 12),
                const Text('UTF-8', style: TextStyle(color: _textSecondary, fontSize: 10)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _EditorToolbar extends StatelessWidget {
  const _EditorToolbar({
    required this.filename,
    required this.running,
    required this.compact,
    required this.onOpen,
    required this.onSave,
    required this.onRun,
    required this.onClose,
  });

  final String filename;
  final bool running;
  final bool compact;
  final VoidCallback onOpen;
  final VoidCallback onSave;
  final VoidCallback onRun;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 55,
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: compact ? 8 : 12),
        child: Row(
          children: [
            Container(
              constraints: BoxConstraints(maxWidth: compact ? 145 : 210),
              padding: const EdgeInsets.only(left: 10, right: 5),
              height: 38,
              decoration: BoxDecoration(color: _surfaceRaised, borderRadius: BorderRadius.circular(6)),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.insert_drive_file_outlined, size: 16, color: _blue),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(filename, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12, color: _textPrimary)),
                  ),
                  IconButton(
                    tooltip: 'Novo arquivo',
                    visualDensity: VisualDensity.compact,
                    onPressed: onClose,
                    icon: const Icon(Icons.close_rounded, size: 16, color: _textSecondary),
                  ),
                ],
              ),
            ),
            const Spacer(),
            if (!compact) ...[
              _ToolbarButton(icon: Icons.upload_file_rounded, label: 'Abrir', onPressed: onOpen),
              const SizedBox(width: 8),
              _ToolbarButton(icon: Icons.save_outlined, label: 'Salvar', onPressed: onSave),
              const SizedBox(width: 10),
            ] else ...[
              IconButton(
                tooltip: 'Abrir arquivo',
                onPressed: onOpen,
                visualDensity: VisualDensity.compact,
                icon: const Icon(Icons.folder_open_rounded, color: _textSecondary, size: 19),
              ),
              IconButton(
                tooltip: 'Salvar arquivo',
                onPressed: onSave,
                visualDensity: VisualDensity.compact,
                icon: const Icon(Icons.save_outlined, color: _textSecondary, size: 19),
              ),
              const SizedBox(width: 3),
            ],
            _RunButton(running: running, compact: compact, onPressed: onRun),
          ],
        ),
      ),
    );
  }
}

class _ToolbarButton extends StatelessWidget {
  const _ToolbarButton({required this.icon, required this.label, required this.onPressed});
  final IconData icon;
  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: onPressed,
      style: OutlinedButton.styleFrom(
        foregroundColor: _textPrimary,
        side: const BorderSide(color: _border),
        padding: const EdgeInsets.symmetric(horizontal: 12),
        minimumSize: const Size(0, 36),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
      ),
      icon: Icon(icon, size: 16),
      label: Text(label, style: const TextStyle(fontSize: 12)),
    );
  }
}

class _RunButton extends StatelessWidget {
  const _RunButton({required this.running, required this.compact, required this.onPressed});
  final bool running;
  final bool compact;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return FilledButton.icon(
      onPressed: running ? null : onPressed,
      style: FilledButton.styleFrom(
        backgroundColor: _green,
        foregroundColor: const Color(0xFF07150E),
        disabledBackgroundColor: _green.withValues(alpha: 0.55),
        padding: EdgeInsets.symmetric(horizontal: compact ? 11 : 17),
        minimumSize: Size(0, compact ? 36 : 39),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
      ),
      icon: running
          ? const SizedBox(width: 15, height: 15, child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF07150E)))
          : const Icon(Icons.play_arrow_rounded, size: 19),
      label: Text(running ? 'Rodando' : 'Executar', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800)),
    );
  }
}

class _LineNumberGutter extends StatelessWidget {
  const _LineNumberGutter({required this.controller, required this.scrollController, required this.fontSize});

  final _SyntaxController controller;
  final ScrollController scrollController;
  final double fontSize;

  @override
  Widget build(BuildContext context) {
    final lineCount = controller.text.split('\n').length;
    return SizedBox(
      width: 48,
      child: ClipRect(
        child: AnimatedBuilder(
          animation: scrollController,
          builder: (context, _) {
            final offset = scrollController.hasClients ? scrollController.offset : 0.0;
            return Transform.translate(
              offset: Offset(0, 12 - offset),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: List<Widget>.generate(
                  lineCount,
                  (index) => SizedBox(
                    height: fontSize * 1.55,
                    child: Align(
                      alignment: Alignment.centerRight,
                      child: Padding(
                        padding: const EdgeInsets.only(right: 11),
                        child: Text(
                          '${index + 1}',
                          style: TextStyle(color: const Color(0xFF667483), fontFamily: 'monospace', fontSize: fontSize - 1),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _ConsolePanel extends StatelessWidget {
  const _ConsolePanel({
    required this.output,
    required this.scrollController,
    required this.message,
    required this.success,
    required this.running,
    required this.onClear,
  });

  final String output;
  final ScrollController scrollController;
  final String? message;
  final bool success;
  final bool running;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: _border),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          SizedBox(
            height: 55,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 15),
              child: Row(
                children: [
                  const Icon(Icons.terminal_rounded, size: 20, color: _textPrimary),
                  const SizedBox(width: 9),
                  const Text('Console', style: TextStyle(color: _textPrimary, fontWeight: FontWeight.w700, fontSize: 13)),
                  const Spacer(),
                  IconButton(
                    tooltip: 'Limpar console',
                    onPressed: onClear,
                    visualDensity: VisualDensity.compact,
                    icon: const Icon(Icons.delete_outline_rounded, size: 18, color: _textSecondary),
                  ),
                ],
              ),
            ),
          ),
          const Divider(height: 1, color: _border),
          Expanded(
            child: Scrollbar(
              controller: scrollController,
              thumbVisibility: true,
              child: SingleChildScrollView(
                controller: scrollController,
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 18),
                child: Align(
                  alignment: Alignment.topLeft,
                  child: SelectableText(
                    output.isEmpty ? (running ? 'Executando…' : '') : output,
                    style: TextStyle(
                      color: output.isEmpty ? const Color(0xFF738292) : const Color(0xFFD6E0EA),
                      fontFamily: 'monospace',
                      fontSize: 13,
                      height: 1.65,
                    ),
                  ),
                ),
              ),
            ),
          ),
          if (message != null) ...[
            const Divider(height: 1, color: _border),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(15, 11, 15, 12),
              color: success ? _green.withValues(alpha: 0.035) : _blue.withValues(alpha: 0.045),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    running ? Icons.more_horiz_rounded : success ? Icons.check_circle_outline_rounded : Icons.error_outline_rounded,
                    size: 16,
                    color: running ? _yellow : success ? _greenBright : _blue,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      message!,
                      style: TextStyle(color: running ? _yellow : success ? _greenBright : _blue, fontSize: 11.5),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _ExamplesPage extends StatelessWidget {
  const _ExamplesPage({
    required this.onOpenPortuguese,
    required this.onOpenFunctions,
    required this.onOpenInput,
  });

  final VoidCallback onOpenPortuguese;
  final VoidCallback onOpenFunctions;
  final VoidCallback onOpenInput;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 760),
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            const Text(
              'Exemplos',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: _textPrimary),
            ),
            const SizedBox(height: 18),
            _ExampleCard(title: 'Primeiro programa', onOpen: onOpenPortuguese),
            _ExampleCard(title: 'Funções e repetição', onOpen: onOpenFunctions),
            _ExampleCard(title: 'Entrada de dados', onOpen: onOpenInput),
          ],
        ),
      ),
    );
  }
}

class _ExampleCard extends StatelessWidget {
  const _ExampleCard({required this.title, required this.onOpen});

  final String title;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: _border),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onOpen,
          borderRadius: BorderRadius.circular(8),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
            child: Row(
              children: [
                const Icon(Icons.code_rounded, size: 18, color: _textSecondary),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(color: _textPrimary, fontSize: 14, fontWeight: FontWeight.w600),
                  ),
                ),
                const Icon(Icons.arrow_forward_rounded, size: 18, color: _textSecondary),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SettingsDialog extends StatefulWidget {
  const _SettingsDialog({required this.fontSize});
  final double fontSize;

  @override
  State<_SettingsDialog> createState() => _SettingsDialogState();
}

class _SettingsDialogState extends State<_SettingsDialog> {
  late double _fontSize = widget.fontSize;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Row(
        children: [
          Icon(Icons.tune_rounded, color: _green),
          SizedBox(width: 10),
          Text('Editor'),
        ],
      ),
      content: SizedBox(
        width: 390,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Expanded(child: Text('Tamanho da fonte')),
                Text('${_fontSize.round()} px', style: const TextStyle(color: _greenBright, fontWeight: FontWeight.w700)),
              ],
            ),
            Slider(
              value: _fontSize,
              min: 12,
              max: 20,
              divisions: 8,
              label: '${_fontSize.round()} px',
              onChanged: (value) => setState(() => _fontSize = value),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
        FilledButton(
          onPressed: () => Navigator.pop(context, _EditorSettings(_fontSize)),
          child: const Text('Aplicar'),
        ),
      ],
    );
  }
}

class _EditorSettings {
  const _EditorSettings(this.fontSize);
  final double fontSize;
}

class _SyntaxController extends TextEditingController {
  _SyntaxController({super.text});

  static final _tokens = RegExp(
    r'//[^\n]*|"(?:\\.|[^"\\])*"|\b(?:function|funcao|return|retorne|if|se|else|senao|while|enquanto|for|para|range|in|entao|então|faca|faça|fimse|fimpara|fimenquanto|inicio|fim|break|continue|end|printf|escreva|scan|inteiro|int|real|decimal|float|texto|str|string|logico|lógico|booleano|bool|true|false)\b|\b\d+(?:\.\d+)?\b',
  );
  static const _keywords = {
    'function', 'funcao', 'return', 'retorne', 'if', 'se', 'else', 'senao', 'while', 'enquanto', 'for', 'para',
    'range', 'in', 'entao', 'então', 'faca', 'faça', 'fimse', 'fimpara', 'fimenquanto', 'inicio', 'fim', 'break',
    'continue', 'end', 'inteiro', 'int', 'real', 'decimal', 'float', 'texto', 'str', 'string', 'logico', 'lógico',
    'booleano', 'bool', 'true', 'false',
  };

  @override
  TextSpan buildTextSpan({required BuildContext context, TextStyle? style, required bool withComposing}) {
    final textValue = text;
    final children = <TextSpan>[];
    var last = 0;
    for (final match in _tokens.allMatches(textValue)) {
      if (match.start > last) children.add(TextSpan(text: textValue.substring(last, match.start)));
      final token = match.group(0)!;
      Color color = _textPrimary;
      if (token.startsWith('//')) {
        color = const Color(0xFF70808F);
      } else if (token.startsWith('"')) {
        color = _yellow;
      } else if (RegExp(r'^\d').hasMatch(token)) {
        color = _blue;
      } else if (_keywords.contains(token)) {
        color = _greenBright;
      } else if (token == 'printf' || token == 'escreva' || token == 'scan') {
        color = _greenBright;
      }
      children.add(TextSpan(text: token, style: TextStyle(color: color)));
      last = match.end;
    }
    if (last < textValue.length) children.add(TextSpan(text: textValue.substring(last)));
    return TextSpan(style: style, children: children);
  }
}
