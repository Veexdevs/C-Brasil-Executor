import 'dart:async';

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
  static const _keyFontSize = 'cbr.fontSize';

  final CbrEditingController controller = CbrEditingController(text: starterCode);

  String filename = 'main.cbr';
  bool dirty = false;
  double fontSize = 14;

  bool running = false;
  bool cancelRequested = false;
  String output = '';
  String? errorMessage;
  int? errorLine;
  int? exitCode;
  Duration? elapsed;
  int? steps;
  bool lastRunSucceeded = true;
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
      final savedSize = prefs.getDouble(_keyFontSize);
      if (saved != null && saved.trim().isNotEmpty) {
        controller.text = saved;
        dirty = false;
      }
      if (savedName != null && savedName.isNotEmpty) filename = savedName;
      if (savedSize != null) fontSize = savedSize.clamp(10, 28);
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
      await prefs.setDouble(_keyFontSize, fontSize);
    } catch (_) {
      // Persistência é opcional.
    }
  }

  void markDirty() {
    if (dirty) return;
    dirty = true;
    _notify();
  }

  void setFontSize(double value) {
    fontSize = value.clamp(10, 28);
    _notify();
    unawaited(persist());
  }

  void loadProgram(String code, {String? name, bool markAsDirty = false}) {
    controller.text = code;
    if (name != null) filename = name;
    dirty = markAsDirty;
    output = '';
    errorMessage = null;
    errorLine = null;
    highlightedLine = null;
    exitCode = null;
    elapsed = null;
    steps = null;
    lastRunSucceeded = true;
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
    exitCode = null;
    elapsed = null;
    steps = null;
    lastRunSucceeded = true;
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
    exitCode = null;
    elapsed = null;
    steps = null;
    lastRunSucceeded = true;
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
      exitCode = result.exitCode;
      elapsed = result.elapsed;
      steps = result.steps;
      lastRunSucceeded = result.exitCode == 0 && !result.cancelled;
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
      lastRunSucceeded = false;
      exitCode = null;
    } catch (error) {
      flush(force: true);
      errorMessage = 'Falha inesperada no executor: $error';
      lastRunSucceeded = false;
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
