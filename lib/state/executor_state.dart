import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../cbr/cbr.dart';
import '../data/examples.dart';
import '../widgets/code_editor.dart';

/// Estado do editor e do console, compartilhado entre as telas.
class ExecutorState extends ChangeNotifier {
  ExecutorState();

  static const _keyCode = 'cbr.code';
  static const _keyFilename = 'cbr.filename';

  final CbrEditingController controller = CbrEditingController(text: starterCode);

  String filename = 'main.cbr';
  bool dirty = false;

  bool running = false;
  bool cancelRequested = false;
  String output = '';
  String? errorMessage;
  int? errorLine;
  int? highlightedLine;

  /// Chamado quando o programa pede uma entrada (`leia`/`scan`).
  Future<String> Function(String prompt)? inputHandler;

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  bool _disposed = false;

  Future<void> restore() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getString(_keyCode);
      final savedName = prefs.getString(_keyFilename);
      if (saved != null && saved.trim().isNotEmpty) {
        controller.text = saved;
        dirty = false;
      }
      if (savedName != null && savedName.isNotEmpty) filename = savedName;
      _notify();
    } catch (_) {
      // Sem armazenamento local: seguimos com o exemplo padrão.
    }
  }

  Future<void> persist() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_keyCode, controller.text);
      await prefs.setString(_keyFilename, filename);
    } catch (_) {
      // Persistência é opcional.
    }
  }

  void markDirty() {
    if (dirty) return;
    dirty = true;
    _notify();
  }

  void loadProgram(String code, {String? name, bool markAsDirty = false}) {
    controller.text = code;
    if (name != null) filename = name;
    dirty = markAsDirty;
    output = '';
    errorMessage = null;
    errorLine = null;
    highlightedLine = null;
    _notify();
  }

  void newProgram([CbrExample? example]) {
    final template = example ?? cbrExamples.first;
    loadProgram(template.code, name: template.filename);
  }

  void clearConsole() {
    output = '';
    errorMessage = null;
    errorLine = null;
    highlightedLine = null;
    _notify();
  }

  void stop() {
    if (!running) return;
    cancelRequested = true;
    _notify();
  }

  Future<void> run() async {
    if (running) return;
    running = true;
    cancelRequested = false;
    output = '';
    errorMessage = null;
    errorLine = null;
    highlightedLine = null;
    _notify();

    final buffer = StringBuffer();
    var lastFlush = DateTime.now();

    void flush({bool force = false}) {
      if (!force && DateTime.now().difference(lastFlush).inMilliseconds < 60) {
        return;
      }
      lastFlush = DateTime.now();
      output = buffer.toString();
      _notify();
    }

    try {
      final interpreter = CbrInterpreter(controller.text);
      final result = await interpreter.run(
        onOutput: (chunk) {
          buffer.write(chunk);
          flush();
        },
        onInput: (prompt) async {
          final provider = inputHandler;
          final answer = provider == null ? '' : await provider(prompt);
          // Ecoa a resposta no console para o histórico ficar legível.
          buffer.write('$answer\n');
          flush(force: true);
          return answer;
        },
        isCancelled: () => cancelRequested,
      );
      flush(force: true);
      if (result.cancelled) {
        errorMessage = 'Execução interrompida por você.';
      } else if (result.exitCode != 0) {
        errorMessage = 'O programa terminou com o código ${result.exitCode}.';
      }
    } on CbrError catch (error) {
      flush(force: true);
      errorMessage = error.formatted;
      errorLine = error.line;
      highlightedLine = error.line;
    } catch (error) {
      flush(force: true);
      errorMessage = 'Falha inesperada no executor: $error';
    } finally {
      running = false;
      _notify();
    }
  }

  @override
  void dispose() {
    _disposed = true;
    controller.dispose();
    super.dispose();
  }
}
