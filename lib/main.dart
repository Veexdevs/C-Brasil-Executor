import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;

import 'cbr/interpreter.dart';

const _background = Color(0xFF0B1118);
const _surface = Color(0xFF101821);
const _surfaceRaised = Color(0xFF151F2A);
const _border = Color(0xFF25313D);
const _textPrimary = Color(0xFFEAF0F6);
const _textSecondary = Color(0xFF9AA9B8);
const _green = Color(0xFF20C77A);
const _greenBright = Color(0xFF45E39A);
const _yellow = Color(0xFFFFD166);
const _blue = Color(0xFF52B7F5);
const _red = Color(0xFFFF717B);
const _compiledUpstreamRevision = String.fromEnvironment(
  'CBR_UPSTREAM_COMMIT',
  defaultValue: '935b21d8a482f8073dd613a6901894fb6530c1d4',
);

const _starterProgram = '''inicio
escreva("Olá, C Brasil!")
escreva("Esta é uma linguagem poderosa.")

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

const _upstreamProgram = '''// Exemplo compatível com o repositório vorgweb/C-Brasil (Cbr 0.6)
function dobro(x) {
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

const _inputProgram = '''// O executor abre uma caixa de entrada quando encontra scan().
idade = 0
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
      error: _red,
    );
    return MaterialApp(
      title: 'C Brasil — Executor CBR',
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
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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

enum _AppPage { executor, documentation, examples, about }

class CbrHome extends StatefulWidget {
  const CbrHome({super.key});

  @override
  State<CbrHome> createState() => _CbrHomeState();
}

class _CbrHomeState extends State<CbrHome> {
  late final _SyntaxController _editorController;
  final ScrollController _editorScrollController = ScrollController();
  final ScrollController _consoleScrollController = ScrollController();
  final _UpstreamStatus _upstreamStatus = _UpstreamStatus();
  Timer? _upstreamTimer;

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
    _upstreamStatus.refresh();
    _upstreamTimer = Timer.periodic(
      const Duration(minutes: 30),
      (_) => _upstreamStatus.refresh(),
    );
  }

  void _onEditorChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _upstreamTimer?.cancel();
    _upstreamStatus.dispose();
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
            ? 'Processo finalizado com sucesso • ${_formatDuration(result.elapsed)}'
            : 'Processo finalizado com código ${result.exitCode} • ${_formatDuration(result.elapsed)}';
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
      final selection = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: const ['cbr', 'txt'],
        withData: true,
      );
      if (selection == null || selection.files.isEmpty) return;
      final file = selection.files.single;
      final bytes = file.bytes;
      if (bytes == null) {
        throw const FormatException('Não foi possível ler os dados do arquivo.');
      }
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
      final path = await FilePicker.platform.saveFile(
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
      case _AppPage.documentation:
        return _DocumentationPage(onOpenExample: () => _loadExample(_upstreamProgram, filename: 'cbr-06.cbr'));
      case _AppPage.examples:
        return _ExamplesPage(
          onOpenPortuguese: () => _loadExample(_starterProgram, filename: 'primeiro-programa.cbr'),
          onOpenUpstream: () => _loadExample(_upstreamProgram, filename: 'cbr-06.cbr'),
          onOpenInput: () => _loadExample(_inputProgram, filename: 'entrada.cbr'),
        );
      case _AppPage.about:
        return _AboutPage(status: _upstreamStatus, onRefresh: _upstreamStatus.refresh);
    }
  }

  Widget _buildExecutor(double width) {
    final isWide = width >= 920;
    if (isWide) {
      return Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1480),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(34, 22, 34, 12),
            child: Column(
              children: [
                _HeroSection(status: _upstreamStatus, onRefresh: _upstreamStatus.refresh),
                const SizedBox(height: 20),
                Expanded(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Expanded(
                        flex: 6,
                        child: _EditorPanel(
                          controller: _editorController,
                          scrollController: _editorScrollController,
                          filename: _filename,
                          running: _running,
                          fontSize: _fontSize,
                          onOpen: _openFile,
                          onSave: _saveFile,
                          onRun: _runProgram,
                          onClose: _newFile,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        flex: 4,
                        child: _ConsolePanel(
                          output: _output,
                          scrollController: _consoleScrollController,
                          message: _runMessage,
                          success: _runSuccess,
                          running: _running,
                          onClear: _clearConsole,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                const _Footer(),
              ],
            ),
          ),
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 24),
      children: [
        _HeroSection(status: _upstreamStatus, onRefresh: _upstreamStatus.refresh, compact: true),
        const SizedBox(height: 18),
        SizedBox(
          height: 510,
          child: _EditorPanel(
            controller: _editorController,
            scrollController: _editorScrollController,
            filename: _filename,
            running: _running,
            fontSize: _fontSize,
            compact: true,
            onOpen: _openFile,
            onSave: _saveFile,
            onRun: _runProgram,
            onClose: _newFile,
          ),
        ),
        const SizedBox(height: 14),
        SizedBox(
          height: 320,
          child: _ConsolePanel(
            output: _output,
            scrollController: _consoleScrollController,
            message: _runMessage,
            success: _runSuccess,
            running: _running,
            onClear: _clearConsole,
          ),
        ),
        const SizedBox(height: 14),
        const _Footer(),
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
    final width = MediaQuery.sizeOf(context).width;
    final compact = width < 740;
    return Container(
      height: 68,
      padding: EdgeInsets.symmetric(horizontal: compact ? 16 : 38),
      decoration: const BoxDecoration(
        color: Color(0xFF0A1016),
        border: Border(bottom: BorderSide(color: _border, width: 0.7)),
      ),
      child: Row(
        children: [
          const _BrandMark(size: 40),
          const SizedBox(width: 12),
          const Text(
            'C BRASIL',
            style: TextStyle(
              color: _textPrimary,
              fontSize: 16,
              fontWeight: FontWeight.w800,
              letterSpacing: 2.2,
            ),
          ),
          const SizedBox(width: 8),
          const Text('(CBR)', style: TextStyle(color: _textSecondary, fontSize: 12)),
          const Spacer(),
          if (!compact) ...[
            _NavButton(label: 'Executor', page: _AppPage.executor, selected: selected, onSelect: onSelect),
            _NavButton(label: 'Documentação', page: _AppPage.documentation, selected: selected, onSelect: onSelect),
            _NavButton(label: 'Exemplos', page: _AppPage.examples, selected: selected, onSelect: onSelect),
            _NavButton(label: 'Sobre', page: _AppPage.about, selected: selected, onSelect: onSelect),
            const SizedBox(width: 12),
          ] else ...[
            PopupMenuButton<_AppPage>(
              tooltip: 'Abrir navegação',
              icon: const Icon(Icons.menu_rounded, color: _textSecondary),
              onSelected: onSelect,
              itemBuilder: (context) => const [
                PopupMenuItem(value: _AppPage.executor, child: Text('Executor')),
                PopupMenuItem(value: _AppPage.documentation, child: Text('Documentação')),
                PopupMenuItem(value: _AppPage.examples, child: Text('Exemplos')),
                PopupMenuItem(value: _AppPage.about, child: Text('Sobre')),
              ],
            ),
          ],
          IconButton(
            tooltip: 'Configurações do editor',
            onPressed: onSettings,
            icon: const Icon(Icons.tune_rounded, size: 20, color: _textSecondary),
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
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 5),
      child: TextButton(
        onPressed: () => onSelect(page),
        style: TextButton.styleFrom(
          foregroundColor: active ? _greenBright : _textSecondary,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(9)),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(label, style: TextStyle(fontSize: 13, fontWeight: active ? FontWeight.w700 : FontWeight.w500)),
            const SizedBox(height: 6),
            AnimatedContainer(
              duration: const Duration(milliseconds: 160),
              width: active ? 34 : 0,
              height: 2,
              decoration: BoxDecoration(color: _green, borderRadius: BorderRadius.circular(2)),
            ),
          ],
        ),
      ),
    );
  }
}

class _BrandMark extends StatelessWidget {
  const _BrandMark({this.size = 42});
  final double size;

  @override
  Widget build(BuildContext context) {
    // Marca provisória substituível pela logo final quando ela estiver pronta.
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [_green, Color(0xFF168AD0)],
        ),
        borderRadius: BorderRadius.circular(size * 0.2),
        boxShadow: [BoxShadow(color: _green.withValues(alpha: 0.18), blurRadius: 16, offset: const Offset(0, 4))],
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Text(
            'C',
            style: TextStyle(color: Colors.white, fontSize: size * 0.72, height: 1, fontWeight: FontWeight.w900),
          ),
          Positioned(
            right: size * 0.12,
            top: size * 0.11,
            child: Container(
              width: size * 0.12,
              height: size * 0.12,
              decoration: const BoxDecoration(color: _yellow, shape: BoxShape.circle),
            ),
          ),
        ],
      ),
    );
  }
}

class _HeroSection extends StatelessWidget {
  const _HeroSection({required this.status, required this.onRefresh, this.compact = false});

  final _UpstreamStatus status;
  final VoidCallback onRefresh;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final heading = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 12,
          children: [
            Text(
              'C Brasil',
              style: TextStyle(
                color: _textPrimary,
                fontSize: compact ? 32 : 38,
                fontWeight: FontWeight.w800,
                letterSpacing: -1.1,
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
              decoration: BoxDecoration(
                color: _green.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(7),
                border: Border.all(color: _green.withValues(alpha: 0.3)),
              ),
              child: const Text('CBR', style: TextStyle(color: _greenBright, fontSize: 13, fontWeight: FontWeight.w800)),
            ),
          ],
        ),
        const SizedBox(height: 7),
        const Text(
          'Uma linguagem simples, moderna e poderosa.',
          style: TextStyle(color: _textSecondary, fontSize: 15, fontWeight: FontWeight.w500),
        ),
        const SizedBox(height: 3),
        const Text(
          'Escreva, execute e veja o resultado em tempo real.',
          style: TextStyle(color: Color(0xFF7F8D9B), fontSize: 13),
        ),
      ],
    );

    final badge = _UpstreamBadge(status: status, onRefresh: onRefresh);
    if (compact) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [heading, const SizedBox(height: 14), badge],
      );
    }
    return Row(
      children: [
        Expanded(child: heading),
        const SizedBox(width: 20),
        badge,
      ],
    );
  }
}

class _UpstreamBadge extends StatelessWidget {
  const _UpstreamBadge({required this.status, required this.onRefresh});

  final _UpstreamStatus status;
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: status,
      builder: (context, _) {
        final revision = status.revision;
        final summary = status.checking
            ? 'Verificando repositório…'
            : status.available
                ? 'Repositório conectado'
                : 'Executor local • Cbr 0.6';
        return Container(
          constraints: const BoxConstraints(minWidth: 245, maxWidth: 318),
          padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 11),
          decoration: BoxDecoration(
            color: _surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: _green.withValues(alpha: 0.38)),
          ),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(color: _green.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(9)),
                child: const Icon(Icons.cloud_sync_rounded, color: _greenBright, size: 20),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(summary, style: const TextStyle(color: _textPrimary, fontSize: 12, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 3),
                    Text(
                      'vorgweb/C-Brasil  •  ${revision.substring(0, revision.length > 7 ? 7 : revision.length)}',
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: _textSecondary, fontSize: 10.5),
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: 'Verificar atualizações',
                visualDensity: VisualDensity.compact,
                onPressed: status.checking ? null : onRefresh,
                icon: Icon(Icons.refresh_rounded, size: 17, color: status.checking ? _textSecondary : _greenBright),
              ),
            ],
          ),
        );
      },
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
        color: const Color(0xFF0C1219),
        borderRadius: BorderRadius.circular(13),
        border: Border.all(color: _border),
        boxShadow: const [BoxShadow(color: Color(0x18000000), blurRadius: 25, offset: Offset(0, 10))],
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
              color: Color(0xFF0A1016),
              border: Border(top: BorderSide(color: _border, width: 0.6)),
            ),
            child: Row(
              children: [
                const Icon(Icons.circle, size: 7, color: _green),
                const SizedBox(width: 7),
                const Text('CBR 0.6', style: TextStyle(color: _textSecondary, fontSize: 10)),
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
              decoration: BoxDecoration(color: _surfaceRaised, borderRadius: BorderRadius.circular(9)),
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
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(9)),
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
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(9)),
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
        color: const Color(0xFF0C1219),
        borderRadius: BorderRadius.circular(13),
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
                  TextButton.icon(
                    onPressed: onClear,
                    style: TextButton.styleFrom(foregroundColor: _greenBright, visualDensity: VisualDensity.compact),
                    icon: const Icon(Icons.delete_outline_rounded, size: 17),
                    label: const Text('Limpar', style: TextStyle(fontSize: 12)),
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
                    output.isEmpty ? (running ? 'Executando o programa…' : 'A saída do seu programa aparecerá aqui.') : output,
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
              color: success ? _green.withValues(alpha: 0.035) : _red.withValues(alpha: 0.045),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    running ? Icons.more_horiz_rounded : success ? Icons.check_circle_outline_rounded : Icons.error_outline_rounded,
                    size: 16,
                    color: running ? _yellow : success ? _greenBright : _red,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      message!,
                      style: TextStyle(color: running ? _yellow : success ? _greenBright : _red, fontSize: 11.5),
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

class _Footer extends StatelessWidget {
  const _Footer();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 30,
      child: Row(
        children: [
          const Text('C Brasil (CBR)', style: TextStyle(color: _textSecondary, fontSize: 10.5)),
          const SizedBox(width: 14),
          const Text('Dart + Flutter', style: TextStyle(color: Color(0xFF71808F), fontSize: 10.5)),
          const Spacer(),
          Container(width: 7, height: 7, decoration: const BoxDecoration(color: _green, shape: BoxShape.circle)),
          const SizedBox(width: 7),
          const Text('Executor local', style: TextStyle(color: _textSecondary, fontSize: 10.5)),
        ],
      ),
    );
  }
}

class _DocumentationPage extends StatelessWidget {
  const _DocumentationPage({required this.onOpenExample});
  final VoidCallback onOpenExample;

  @override
  Widget build(BuildContext context) {
    return _InfoScaffold(
      eyebrow: 'GUIA RÁPIDO',
      title: 'Aprenda Cbr',
      subtitle: 'O executor implementa a sintaxe do repositório C Brasil e inclui atalhos de escrita em português nos exemplos.',
      children: [
        _DocCard(
          icon: Icons.play_circle_outline_rounded,
          accent: _green,
          title: 'Comece com um programa',
          code: 'nome = "Brasil"\nprintf("Olá, {str.nome}!\\n")\nend(0)',
          description: 'Atribua valores com = e mostre texto com printf. As quebras de linha são escritas como \\n.',
        ),
        _DocCard(
          icon: Icons.alt_route_rounded,
          accent: _blue,
          title: 'Condições e repetição',
          code: 'if (idade >= 18) {\n    printf("Maior de idade\\n")\n} else {\n    printf("Menor de idade\\n")\n}\n\nfor i in range(1, 6) {\n    printf("{int.i}\\n")\n}',
          description: 'Há suporte para if/else, while, range, for clássico, break e continue.',
        ),
        _DocCard(
          icon: Icons.data_object_rounded,
          accent: _yellow,
          title: 'Valores, arrays e funções',
          code: 'function dobro(x) {\n    return x * 2\n}\n\ndados = [12, "Cbr", true, 3.14]\nresultado = dobro(5)',
          description: 'Tipos são inferidos. Funções numéricas aceitam um parâmetro e retornam um número; arrays podem misturar valores.',
        ),
        _DocCard(
          icon: Icons.keyboard_alt_outlined,
          accent: _green,
          title: 'Entrada do teclado',
          code: 'idade = 0\nscan("Sua idade: ", {int.idade})',
          description: 'scan() abre uma caixa de entrada durante a execução. Marcadores aceitos: str, int, float e bool.',
        ),
        const SizedBox(height: 18),
        Align(
          alignment: Alignment.centerLeft,
          child: FilledButton.icon(
            onPressed: onOpenExample,
            icon: const Icon(Icons.code_rounded),
            label: const Text('Abrir exemplo do Cbr 0.6 no editor'),
          ),
        ),
      ],
    );
  }
}

class _DocCard extends StatelessWidget {
  const _DocCard({required this.icon, required this.accent, required this.title, required this.code, required this.description});

  final IconData icon;
  final Color accent;
  final String title;
  final String code;
  final String description;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(17),
      decoration: BoxDecoration(color: _surface, borderRadius: BorderRadius.circular(13), border: Border.all(color: _border)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: accent, size: 19),
              const SizedBox(width: 9),
              Text(title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(13),
            decoration: BoxDecoration(color: const Color(0xFF080D12), borderRadius: BorderRadius.circular(9)),
            child: SelectableText(code, style: const TextStyle(fontFamily: 'monospace', fontSize: 12, height: 1.6, color: _textPrimary)),
          ),
          const SizedBox(height: 10),
          Text(description, style: const TextStyle(color: _textSecondary, fontSize: 12.5, height: 1.5)),
        ],
      ),
    );
  }
}

class _ExamplesPage extends StatelessWidget {
  const _ExamplesPage({required this.onOpenPortuguese, required this.onOpenUpstream, required this.onOpenInput});

  final VoidCallback onOpenPortuguese;
  final VoidCallback onOpenUpstream;
  final VoidCallback onOpenInput;

  @override
  Widget build(BuildContext context) {
    return _InfoScaffold(
      eyebrow: 'EXEMPLOS',
      title: 'Escolha um ponto de partida',
      subtitle: 'Abra um programa no editor, altere o código e pressione Executar.',
      children: [
        _ExampleCard(
          accent: _green,
          icon: Icons.waving_hand_outlined,
          title: 'Primeiro programa',
          description: 'Exemplo guiado em português: saída, variável inteira, condição e contagem de 1 a 5.',
          tags: const ['iniciante', 'Português'],
          onOpen: onOpenPortuguese,
        ),
        _ExampleCard(
          accent: _blue,
          icon: Icons.functions_rounded,
          title: 'Recursos do Cbr 0.6',
          description: 'Função numérica, potência, array misto, interpolação e repetição com range.',
          tags: const ['Cbr 0.6', 'repositório'],
          onOpen: onOpenUpstream,
        ),
        _ExampleCard(
          accent: _yellow,
          icon: Icons.keyboard_alt_outlined,
          title: 'Entrada com scan()',
          description: 'Receba um inteiro do usuário e escolha uma resposta com if/else.',
          tags: const ['entrada', 'interativo'],
          onOpen: onOpenInput,
        ),
      ],
    );
  }
}

class _ExampleCard extends StatelessWidget {
  const _ExampleCard({required this.accent, required this.icon, required this.title, required this.description, required this.tags, required this.onOpen});

  final Color accent;
  final IconData icon;
  final String title;
  final String description;
  final List<String> tags;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(color: _surface, borderRadius: BorderRadius.circular(13), border: Border.all(color: _border)),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 43,
            height: 43,
            decoration: BoxDecoration(color: accent.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(11)),
            child: Icon(icon, color: accent, size: 21),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                const SizedBox(height: 6),
                Text(description, style: const TextStyle(color: _textSecondary, height: 1.45, fontSize: 12.5)),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: tags.map((tag) => _Tag(label: tag, color: accent)).toList(),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          IconButton.filledTonal(
            tooltip: 'Abrir no editor',
            onPressed: onOpen,
            style: IconButton.styleFrom(foregroundColor: accent, backgroundColor: accent.withValues(alpha: 0.12)),
            icon: const Icon(Icons.arrow_forward_rounded),
          ),
        ],
      ),
    );
  }
}

class _Tag extends StatelessWidget {
  const _Tag({required this.label, required this.color});
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.09), borderRadius: BorderRadius.circular(6)),
      child: Text(label, style: TextStyle(color: color, fontSize: 10.5, fontWeight: FontWeight.w600)),
    );
  }
}

class _AboutPage extends StatelessWidget {
  const _AboutPage({required this.status, required this.onRefresh});
  final _UpstreamStatus status;
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    return _InfoScaffold(
      eyebrow: 'SOBRE O PROJETO',
      title: 'Feito para programar em Cbr',
      subtitle: 'O C Brasil Executor é um editor e interpretador local, gratuito e multiplataforma, desenvolvido em Dart + Flutter.',
      children: [
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            gradient: const LinearGradient(colors: [Color(0xFF11271F), Color(0xFF10202B)]),
            border: Border.all(color: _green.withValues(alpha: 0.24)),
          ),
          child: Row(
            children: [
              const _BrandMark(size: 54),
              const SizedBox(width: 16),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('C Brasil (CBR)', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
                    SizedBox(height: 5),
                    Text('Código. Simples. Poderoso.', style: TextStyle(color: _textSecondary, fontSize: 13)),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        _UpstreamInfoCard(status: status, onRefresh: onRefresh),
        const SizedBox(height: 14),
        const _FeatureList(),
      ],
    );
  }
}

class _UpstreamInfoCard extends StatelessWidget {
  const _UpstreamInfoCard({required this.status, required this.onRefresh});
  final _UpstreamStatus status;
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: status,
      builder: (context, _) => Container(
        padding: const EdgeInsets.all(17),
        decoration: BoxDecoration(color: _surface, borderRadius: BorderRadius.circular(13), border: Border.all(color: _border)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.hub_outlined, color: _blue, size: 19),
                const SizedBox(width: 9),
                const Expanded(child: Text('Repositório de origem', style: TextStyle(fontWeight: FontWeight.w700))),
                IconButton(
                  tooltip: 'Verificar agora',
                  onPressed: status.checking ? null : onRefresh,
                  icon: const Icon(Icons.refresh_rounded, size: 18),
                ),
              ],
            ),
            const SizedBox(height: 4),
            const SelectableText('github.com/vorgweb/C-Brasil', style: TextStyle(color: _blue, fontFamily: 'monospace', fontSize: 12)),
            const SizedBox(height: 8),
            Text(
              status.checking
                  ? 'Consultando a revisão mais recente…'
                  : status.available
                      ? 'Última revisão consultada: ${status.revision.substring(0, status.revision.length > 12 ? 12 : status.revision.length)}${status.checkedAt == null ? '' : ' • ${TimeOfDay.fromDateTime(status.checkedAt!).format(context)}'}'
                      : 'Sem conexão no momento${status.error == null ? '' : ': ${status.error}'} O executor continua funcionando localmente.',
              style: const TextStyle(color: _textSecondary, fontSize: 12, height: 1.5),
            ),
            const SizedBox(height: 8),
            const Text(
              'O app verifica o repositório periodicamente. As mudanças do núcleo são acompanhadas pelo fluxo de atualização do projeto; recursos novos da linguagem precisam ser portados para o interpretador Dart.',
              style: TextStyle(color: Color(0xFF7F8D9B), fontSize: 11.5, height: 1.55),
            ),
          ],
        ),
      ),
    );
  }
}

class _FeatureItem {
  const _FeatureItem(this.title, this.icon, this.color);

  final String title;
  final IconData icon;
  final Color color;
}

class _FeatureList extends StatelessWidget {
  const _FeatureList();

  @override
  Widget build(BuildContext context) {
    const features = <_FeatureItem>[
      _FeatureItem('Editor com destaque de sintaxe', Icons.code_rounded, _green),
      _FeatureItem('Interpretador Cbr em Dart, sem enviar código para um servidor', Icons.phonelink_lock_rounded, _blue),
      _FeatureItem('Web, Android, iOS, Windows, macOS e Linux', Icons.devices_rounded, _yellow),
      _FeatureItem('Abertura e salvamento de arquivos .cbr', Icons.save_alt_rounded, _green),
    ];
    return Container(
      padding: const EdgeInsets.all(17),
      decoration: BoxDecoration(color: _surface, borderRadius: BorderRadius.circular(13), border: Border.all(color: _border)),
      child: Column(
        children: features
            .map(
              (feature) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Row(
                  children: [
                    Icon(feature.icon, color: feature.color, size: 18),
                    const SizedBox(width: 10),
                    Expanded(child: Text(feature.title, style: const TextStyle(color: _textSecondary, fontSize: 12.5))),
                    const Icon(Icons.check_rounded, color: _green, size: 17),
                  ],
                ),
              ),
            )
            .toList(),
      ),
    );
  }
}

class _InfoScaffold extends StatelessWidget {
  const _InfoScaffold({required this.eyebrow, required this.title, required this.subtitle, required this.children});

  final String eyebrow;
  final String title;
  final String subtitle;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1060),
        child: ListView(
          padding: const EdgeInsets.fromLTRB(24, 28, 24, 40),
          children: [
            Text(eyebrow, style: const TextStyle(color: _greenBright, letterSpacing: 1.8, fontSize: 10.5, fontWeight: FontWeight.w800)),
            const SizedBox(height: 9),
            Text(title, style: const TextStyle(fontSize: 31, fontWeight: FontWeight.w800, letterSpacing: -0.8)),
            const SizedBox(height: 7),
            Text(subtitle, style: const TextStyle(color: _textSecondary, fontSize: 13.5, height: 1.55)),
            const SizedBox(height: 22),
            ...children,
          ],
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
            const Text(
              'A quebra de linha permanece ativa para facilitar a leitura em telas menores.',
              style: TextStyle(color: _textSecondary, fontSize: 12),
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
        color = const Color(0xFFFFA96B);
      } else if (_keywords.contains(token)) {
        color = const Color(0xFF69B8FF);
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

class _UpstreamStatus extends ChangeNotifier {
  _UpstreamStatus() : revision = _compiledUpstreamRevision;

  String revision;
  bool checking = false;
  bool available = false;
  DateTime? checkedAt;
  String? error;
  bool _disposed = false;

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  Future<void> refresh() async {
    if (checking || _disposed) return;
    checking = true;
    _notify();
    try {
      final response = await http
          .get(
            Uri.https('api.github.com', '/repos/vorgweb/C-Brasil/commits/main'),
            headers: const {
              'Accept': 'application/vnd.github+json',
              'X-GitHub-Api-Version': '2022-11-28',
              'User-Agent': 'C-Brasil-Executor',
            },
          )
          .timeout(const Duration(seconds: 8));
      if (response.statusCode != 200) {
        throw StateError('GitHub respondeu HTTP ${response.statusCode}.');
      }
      final payload = jsonDecode(response.body) as Map<String, dynamic>;
      revision = payload['sha'] as String? ?? revision;
      available = true;
      checkedAt = DateTime.now();
      error = null;
    } catch (exception) {
      available = false;
      error = exception.toString();
    } finally {
      checking = false;
      _notify();
    }
  }
}
