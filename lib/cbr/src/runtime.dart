import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'ast.dart';
import 'builtins.dart';
import 'lexer.dart';
import 'parser.dart';
import 'token.dart';
import 'values.dart';

/// Recebe os textos produzidos pelo programa conforme ele executa.
typedef CbrOutput = void Function(String text);

/// Pede uma entrada ao usuário. No app, abre uma caixa de diálogo no console.
typedef CbrInputProvider = Future<String> Function(String prompt);

/// Consulta se a execução foi cancelada (botão "Parar").
typedef CbrCancellationCheck = bool Function();

/// Resultado de uma execução concluída.
class CbrExecutionResult {
  const CbrExecutionResult({
    required this.exitCode,
    required this.elapsed,
    required this.steps,
    required this.output,
    this.cancelled = false,
  });

  final int exitCode;
  final Duration elapsed;
  final int steps;
  final String output;
  final bool cancelled;

  bool get succeeded => !cancelled;
}

/// Interpreta a linguagem C Brasil (Cbr) diretamente em Dart.
///
/// O núcleo reproduz a especificação do compilador oficial (`Cbr 1.0`) e o
/// dialeto didático em português. O código do usuário nunca sai do
/// dispositivo: a execução acontece no próprio app (inclusive no navegador).
class CbrInterpreter {
  const CbrInterpreter(
    this.source, {
    this.stepLimit = 4000000,
    this.maxDuration = const Duration(seconds: 20),
  });

  final String source;
  final int stepLimit;
  final Duration maxDuration;

  /// Compila (lexer + parser) sem executar. Lança [CbrError] se houver erro.
  Program compile() {
    final tokens = CbrLexer(source).tokenize();
    return CbrParser(tokens).parse();
  }

  Future<CbrExecutionResult> run({
    CbrOutput? onOutput,
    CbrInputProvider? onInput,
    CbrCancellationCheck? isCancelled,
  }) async {
    final program = compile();
    final runner = _Runner(
      program: program,
      stepLimit: stepLimit,
      maxDuration: maxDuration,
      onOutput: onOutput,
      onInput: onInput,
      isCancelled: isCancelled,
    );
    return runner.execute();
  }
}

// ---------------------------------------------------------------- sinais

class _BreakSignal implements Exception {
  const _BreakSignal();
}

class _ContinueSignal implements Exception {
  const _ContinueSignal();
}

class _ReturnSignal implements Exception {
  const _ReturnSignal(this.value);
  final CbrValue? value;
}

class _ExitSignal implements Exception {
  const _ExitSignal(this.code);
  final int code;
}

// ---------------------------------------------------------------- escopo

class _Variable {
  _Variable(this.type, this.value);
  CbrType type;
  CbrValue value;
}

class _Scope {
  _Scope(this.parent);
  final _Scope? parent;
  final Map<String, _Variable> variables = {};

  _Variable? resolve(String name) {
    _Scope? scope = this;
    while (scope != null) {
      final variable = scope.variables[name];
      if (variable != null) return variable;
      scope = scope.parent;
    }
    return null;
  }

  _Variable? local(String name) => variables[name];

  _Variable declare(String name, CbrType type, CbrValue value) {
    final variable = _Variable(type, value);
    variables[name] = variable;
    return variable;
  }
}

// ---------------------------------------------------------------- executor

class _Runner {
  _Runner({
    required this.program,
    required this.stepLimit,
    required this.maxDuration,
    CbrOutput? onOutput,
    CbrInputProvider? onInput,
    CbrCancellationCheck? isCancelled,
  })  : _onOutput = onOutput,
        _onInput = onInput,
        _isCancelled = isCancelled;

  final Program program;
  final int stepLimit;
  final Duration maxDuration;
  final CbrOutput? _onOutput;
  final CbrInputProvider? _onInput;
  final CbrCancellationCheck? _isCancelled;

  final StringBuffer _output = StringBuffer();
  final Stopwatch _stopwatch = Stopwatch();
  int _steps = 0;
  int _callDepth = 0;
  bool _cancelled = false;

  static const int _maxCallDepth = 200;

  Future<CbrExecutionResult> execute() async {
    _stopwatch.start();
    final globals = _Scope(null);
    var exitCode = 0;

    try {
      await _executeBlock(program.statements, globals);
    } on _ExitSignal catch (signal) {
      exitCode = signal.code;
    } on _ReturnSignal catch (signal) {
      // No dialeto didático é comum terminar o programa com "retorne 0".
      final value = signal.value;
      if (value is CbrInt) {
        exitCode = value.value;
      } else if (value == null) {
        exitCode = 0;
      } else {
        throw const CbrError(
          '"retorne" com valor só pode ser usado dentro de uma função.',
          category: CbrErrorCategory.execucao,
          hint: 'Use "end(0)" para encerrar o programa com um código.',
        );
      }
    } finally {
      _stopwatch.stop();
    }

    return CbrExecutionResult(
      exitCode: exitCode,
      elapsed: _stopwatch.elapsed,
      steps: _steps,
      output: _output.toString(),
      cancelled: _cancelled,
    );
  }

  // ------------------------------------------------------------- infraestrutura

  void _emit(String text) {
    _output.write(text);
    _onOutput?.call(text);
  }

  CbrError _error(
    int line,
    int column,
    String message, {
    String? hint,
    CbrErrorCategory category = CbrErrorCategory.execucao,
  }) {
    return CbrError(
      message,
      line: line,
      column: column,
      hint: hint,
      category: category,
    );
  }

  Future<void> _tick(int line, int column) async {
    _steps++;
    if (_isCancelled?.call() ?? false) {
      _cancelled = true;
      throw _error(
        line,
        column,
        'Execução interrompida pelo usuário.',
        category: CbrErrorCategory.limite,
      );
    }
    if (_steps > stepLimit) {
      throw _error(
        line,
        column,
        'O programa passou do limite de $stepLimit instruções.',
        category: CbrErrorCategory.limite,
        hint: 'Verifique se algum laço "enquanto" não termina.',
      );
    }
    if (_steps % 2048 == 0) {
      if (_stopwatch.elapsed > maxDuration) {
        throw _error(
          line,
          column,
          'O programa passou do tempo limite de '
          '${maxDuration.inSeconds} segundos.',
          category: CbrErrorCategory.limite,
          hint: 'Verifique se algum laço "enquanto" não termina.',
        );
      }
      // Devolve o controle ao app para o console atualizar e o botão
      // "Parar" responder.
      await Future<void>.delayed(Duration.zero);
    }
  }

  // ------------------------------------------------------------- instruções

  Future<void> _executeBlock(List<Stmt> statements, _Scope scope) async {
    for (final statement in statements) {
      await _execute(statement, scope);
    }
  }

  Future<void> _execute(Stmt statement, _Scope scope) async {
    await _tick(statement.line, statement.column);
    switch (statement) {
      case EmptyStmt():
        return;
      case VarDeclStmt():
        await _declareVariable(statement, scope);
      case AssignStmt():
        await _assign(statement, scope);
      case ExprStmt():
        await _evaluate(statement.expression, scope);
      case IfStmt():
        final condition = await _evaluate(statement.condition, scope);
        final value = _requireBool(
          condition,
          statement.condition.line,
          statement.condition.column,
          context: 'A condição do "se"',
        );
        if (value) {
          await _executeBlock(statement.thenBranch, _Scope(scope));
        } else if (statement.elseBranch != null) {
          await _executeBlock(statement.elseBranch!, _Scope(scope));
        }
      case WhileStmt():
        await _runWhile(statement, scope);
      case ForRangeStmt():
        await _runForRange(statement, scope);
      case ForClassicStmt():
        await _runForClassic(statement, scope);
      case SwitchStmt():
        await _runSwitch(statement, scope);
      case BreakStmt():
        throw const _BreakSignal();
      case ContinueStmt():
        throw const _ContinueSignal();
      case ReturnStmt():
        final value =
            statement.value == null ? null : await _evaluate(statement.value!, scope);
        throw _ReturnSignal(value);
      case ExitStmt():
        final code = await _evaluate(statement.code, scope);
        final exitCode = _requireInt(
          code,
          statement.code.line,
          statement.code.column,
          context: 'O código de "end()"',
        );
        throw _ExitSignal(exitCode);
      case ReadStmt():
        await _read(statement, scope);
    }
  }

  Future<void> _declareVariable(VarDeclStmt statement, _Scope scope) async {
    if (scope.local(statement.name) != null) {
      throw _error(
        statement.line,
        statement.column,
        'A variável "${statement.name}" já foi declarada.',
        hint: 'Para trocar o valor use apenas ${statement.name} = ...',
        category: CbrErrorCategory.tipo,
      );
    }
    CbrValue value;
    CbrType type;
    if (statement.initializer != null) {
      value = await _evaluate(statement.initializer!, scope);
      type = statement.type ?? value.type;
      value = _convertForType(
        value,
        type,
        statement.name,
        statement.initializer!.line,
        statement.initializer!.column,
      );
    } else {
      type = statement.type ?? CbrType.inteiro;
      value = defaultValue(type);
    }
    scope.declare(statement.name, type, value);
  }

  Future<void> _assign(AssignStmt statement, _Scope scope) async {
    final value = await _evaluate(statement.value, scope);
    switch (statement.target) {
      case NameTarget(:final name):
        final variable = scope.resolve(name);
        if (variable == null) {
          // Declaração implícita, como no compilador oficial: nome = valor.
          scope.declare(name, value.type, value);
          return;
        }
        final converted = _convertForType(
          value,
          variable.type,
          name,
          statement.value.line,
          statement.value.column,
        );
        variable.value = converted;
      case IndexTarget(:final target, :final index):
        final array = await _evaluate(target, scope);
        final indexValue = await _evaluate(index, scope);
        if (array is! CbrArray) {
          throw _error(
            statement.line,
            statement.column,
            'A atribuição por índice exige um array.',
            hint: 'Declare o array antes: itens = [1, 2, 3]',
            category: CbrErrorCategory.tipo,
          );
        }
        final position = _requireInt(
          indexValue,
          index.line,
          index.column,
          context: 'O índice do array',
        );
        if (position < 0 || position >= array.items.length) {
          throw _error(
            statement.line,
            statement.column,
            'Índice $position fora do limite (o array tem '
            '${array.items.length} itens).',
            category: CbrErrorCategory.execucao,
          );
        }
        array.items[position] = value;
    }
  }

  Future<void> _read(ReadStmt statement, _Scope scope) async {
    final variable = scope.resolve(statement.target);
    if (variable == null) {
      throw _error(
        statement.line,
        statement.column,
        'A variável "${statement.target}" precisa ser declarada antes da '
        'leitura.',
        hint: 'Exemplo: inteiro idade\nleia(idade)',
        category: CbrErrorCategory.tipo,
      );
    }
    var prompt = '';
    if (statement.prompt != null) {
      final promptValue = await _evaluate(statement.prompt!, scope);
      prompt = promptValue.display;
      if (prompt.isNotEmpty) _emit(prompt);
    }
    final provider = _onInput;
    if (provider == null) {
      throw _error(
        statement.line,
        statement.column,
        'O programa pediu uma entrada, mas o console não está preparado.',
        category: CbrErrorCategory.execucao,
      );
    }
    final raw = await provider(prompt);
    variable.value = _parseInput(
      raw,
      variable.type,
      statement.line,
      statement.column,
      statement.target,
    );
  }

  CbrValue _parseInput(
    String raw,
    CbrType type,
    int line,
    int column,
    String name,
  ) {
    final text = raw.trim();
    switch (type) {
      case CbrType.inteiro:
        final parsed = int.tryParse(text);
        if (parsed == null) {
          throw _error(
            line,
            column,
            'Entrada inválida para inteiro: "$text".',
            hint: 'Digite apenas dígitos, por exemplo 18.',
            category: CbrErrorCategory.execucao,
          );
        }
        return CbrInt(parsed);
      case CbrType.decimal:
        final parsed = double.tryParse(text.replaceAll(',', '.'));
        if (parsed == null) {
          throw _error(
            line,
            column,
            'Entrada inválida para decimal: "$text".',
            hint: 'Use ponto ou vírgula, por exemplo 7.5.',
            category: CbrErrorCategory.execucao,
          );
        }
        return CbrFloat(parsed);
      case CbrType.booleano:
        final folded = CbrLexer.fold(text);
        if (folded == 'true' || folded == '1' || folded == 'verdadeiro' || folded == 'sim') {
          return const CbrBool(true);
        }
        if (folded == 'false' || folded == '0' || folded == 'falso' || folded == 'nao') {
          return const CbrBool(false);
        }
        throw _error(
          line,
          column,
          'Entrada inválida para booleano: "$text".',
          hint: 'Use true/false ou 1/0.',
          category: CbrErrorCategory.execucao,
        );
      case CbrType.texto:
        return CbrText(raw);
      case CbrType.vetor:
        throw _error(
          line,
          column,
          'A leitura não aceita arrays.',
          category: CbrErrorCategory.tipo,
        );
    }
  }

  Future<void> _runWhile(WhileStmt statement, _Scope scope) async {
    while (true) {
      await _tick(statement.line, statement.column);
      final condition = await _evaluate(statement.condition, scope);
      if (!_requireBool(
        condition,
        statement.condition.line,
        statement.condition.column,
        context: 'A condição do "enquanto"',
      )) {
        return;
      }
      try {
        await _executeBlock(statement.body, _Scope(scope));
      } on _BreakSignal {
        return;
      } on _ContinueSignal {
        continue;
      }
    }
  }

  Future<void> _runForRange(ForRangeStmt statement, _Scope scope) async {
    final startValue = await _evaluate(statement.start, scope);
    final endValue = await _evaluate(statement.end, scope);
    final start = _requireInt(
      startValue,
      statement.start.line,
      statement.start.column,
      context: 'O início do "para"',
    );
    final end = _requireInt(
      endValue,
      statement.end.line,
      statement.end.column,
      context: 'O fim do "para"',
    );
    var step = 1;
    if (statement.step != null) {
      step = _requireInt(
        await _evaluate(statement.step!, scope),
        statement.step!.line,
        statement.step!.column,
        context: 'O passo do "para"',
      );
      if (step == 0) {
        throw _error(
          statement.step!.line,
          statement.step!.column,
          'O passo do "para" não pode ser zero.',
          category: CbrErrorCategory.execucao,
        );
      }
    }
    final loopScope = _Scope(scope);
    final variable = loopScope.declare(statement.variable, CbrType.inteiro, CbrInt(start));
    var current = start;
    while (step > 0 ? current < end : current > end) {
      await _tick(statement.line, statement.column);
      variable.value = CbrInt(current);
      try {
        await _executeBlock(statement.body, _Scope(loopScope));
      } on _BreakSignal {
        return;
      } on _ContinueSignal {
        // segue para o incremento
      }
      current += step;
    }
  }

  Future<void> _runForClassic(ForClassicStmt statement, _Scope scope) async {
    final loopScope = _Scope(scope);
    if (statement.initializer != null) {
      await _execute(statement.initializer!, loopScope);
    }
    while (true) {
      await _tick(statement.line, statement.column);
      final condition = await _evaluate(statement.condition, loopScope);
      if (!_requireBool(
        condition,
        statement.condition.line,
        statement.condition.column,
        context: 'A condição do "para"',
      )) {
        return;
      }
      try {
        await _executeBlock(statement.body, _Scope(loopScope));
      } on _BreakSignal {
        return;
      } on _ContinueSignal {
        // segue para a atualização
      }
      if (statement.update != null) {
        await _execute(statement.update!, loopScope);
      }
    }
  }

  Future<void> _runSwitch(SwitchStmt statement, _Scope scope) async {
    final subject = await _evaluate(statement.subject, scope);
    if (subject is! CbrInt && subject is! CbrText && subject is! CbrBool) {
      throw _error(
        statement.line,
        statement.column,
        'O "switch" aceita inteiro, texto ou booleano (recebeu '
        '${subject.type.label}).',
        category: CbrErrorCategory.tipo,
      );
    }
    var start = -1;
    var defaultIndex = -1;
    for (var index = 0; index < statement.cases.length; index++) {
      final item = statement.cases[index];
      if (item.isDefault) {
        defaultIndex = index;
        continue;
      }
      final label = await _evaluate(item.label!, scope);
      if (_valuesEqual(subject, label)) {
        start = index;
        break;
      }
    }
    if (start < 0) start = defaultIndex;
    if (start < 0) return;

    try {
      for (var index = start; index < statement.cases.length; index++) {
        await _executeBlock(statement.cases[index].body, _Scope(scope));
      }
    } on _BreakSignal {
      return;
    }
  }

  // ------------------------------------------------------------- expressões

  Future<CbrValue> _evaluate(Expr expression, _Scope scope) async {
    switch (expression) {
      case IntLiteral(:final value):
        return CbrInt(value);
      case FloatLiteral(:final value):
        return CbrFloat(value);
      case TextLiteral(:final value):
        return CbrText(value);
      case BoolLiteral(:final value):
        return CbrBool(value);
      case ListLiteral(:final items):
        if (items.length > CbrArray.capacity) {
          throw _error(
            expression.line,
            expression.column,
            'O array tem ${items.length} itens; o limite é '
            '${CbrArray.capacity}.',
            category: CbrErrorCategory.limite,
          );
        }
        final values = <CbrValue>[];
        for (final item in items) {
          values.add(await _evaluate(item, scope));
        }
        return CbrArray(values);
      case VariableExpr(:final name):
        final variable = scope.resolve(name);
        if (variable == null) {
          throw _error(
            expression.line,
            expression.column,
            'A variável "$name" não foi declarada.',
            hint: 'Declare antes de usar: $name = 0',
            category: CbrErrorCategory.tipo,
          );
        }
        return variable.value;
      case IndexExpr(:final target, :final index):
        final array = await _evaluate(target, scope);
        final indexValue = await _evaluate(index, scope);
        if (array is! CbrArray) {
          throw _error(
            expression.line,
            expression.column,
            'Só é possível acessar posições de um array.',
            category: CbrErrorCategory.tipo,
          );
        }
        final position = _requireInt(
          indexValue,
          index.line,
          index.column,
          context: 'O índice do array',
        );
        if (position < 0 || position >= array.items.length) {
          throw _error(
            expression.line,
            expression.column,
            'Índice $position fora do limite (o array tem '
            '${array.items.length} itens).',
            category: CbrErrorCategory.execucao,
          );
        }
        return array.items[position];
      case UnaryExpr(:final operator, :final operand):
        final value = await _evaluate(operand, scope);
        switch (operator) {
          case TokenType.minus:
            switch (value) {
              case CbrInt(:final value):
                return CbrInt(-value);
              case CbrFloat(:final value):
                return CbrFloat(-value);
              default:
                throw _error(
                  expression.line,
                  expression.column,
                  'O operador "-" exige um número (recebeu '
                  '${value.type.label}).',
                  category: CbrErrorCategory.tipo,
                );
            }
          case TokenType.plus:
            if (value is CbrInt || value is CbrFloat) return value;
            throw _error(
              expression.line,
              expression.column,
              'O operador "+" exige um número.',
              category: CbrErrorCategory.tipo,
            );
          case TokenType.kwNot:
            return CbrBool(!_requireBool(
              value,
              expression.line,
              expression.column,
              context: 'O operador "!"',
            ));
          default:
            return value;
        }
      case BinaryExpr():
        return _evaluateBinary(expression, scope);
      case CallExpr():
        return _evaluateCall(expression, scope);
    }
  }

  Future<CbrValue> _evaluateBinary(BinaryExpr expression, _Scope scope) async {
    final operator = expression.operator;
    if (operator == TokenType.kwAnd || operator == TokenType.kwOr) {
      final left = _requireBool(
        await _evaluate(expression.left, scope),
        expression.left.line,
        expression.left.column,
        context: 'O operador "${operator == TokenType.kwAnd ? '&&' : '||'}"',
      );
      if (operator == TokenType.kwAnd && !left) return const CbrBool(false);
      if (operator == TokenType.kwOr && left) return const CbrBool(true);
      final right = _requireBool(
        await _evaluate(expression.right, scope),
        expression.right.line,
        expression.right.column,
        context: 'O operador "${operator == TokenType.kwAnd ? '&&' : '||'}"',
      );
      return CbrBool(right);
    }

    final left = await _evaluate(expression.left, scope);
    final right = await _evaluate(expression.right, scope);

    switch (operator) {
      case TokenType.equal:
        return CbrBool(_valuesEqual(left, right));
      case TokenType.notEqual:
        return CbrBool(!_valuesEqual(left, right));
      case TokenType.less:
      case TokenType.lessEqual:
      case TokenType.greater:
      case TokenType.greaterEqual:
        return CbrBool(_compare(expression, left, right));
      case TokenType.plus:
      case TokenType.minus:
      case TokenType.star:
      case TokenType.slash:
      case TokenType.percent:
      case TokenType.power:
        return _arithmetic(expression, left, right);
      default:
        throw _error(
          expression.line,
          expression.column,
          'Operador não suportado.',
          category: CbrErrorCategory.tipo,
        );
    }
  }

  CbrValue _arithmetic(BinaryExpr expression, CbrValue left, CbrValue right) {
    final operator = expression.operator;
    if ((left is! CbrInt && left is! CbrFloat) ||
        (right is! CbrInt && right is! CbrFloat)) {
      throw _error(
        expression.line,
        expression.column,
        'A operação exige números, mas recebeu ${left.type.label} e '
        '${right.type.label}.',
        hint: 'Textos usam juntar() e comparações; use números para calcular.',
        category: CbrErrorCategory.tipo,
      );
    }

    if (operator == TokenType.power) {
      final base = _asDouble(left);
      final exponent = _asDouble(right);
      final result = math.pow(base, exponent).toDouble();
      if (left is CbrInt && right is CbrInt) {
        return CbrInt(truncateToInt(result));
      }
      return CbrFloat(result);
    }

    if (operator == TokenType.percent && (left is! CbrInt || right is! CbrInt)) {
      throw _error(
        expression.line,
        expression.column,
        'O operador "%" exige dois inteiros.',
        category: CbrErrorCategory.tipo,
      );
    }

    if (left is CbrInt && right is CbrInt) {
      final a = left.value;
      final b = right.value;
      switch (operator) {
        case TokenType.plus:
          return CbrInt(a + b);
        case TokenType.minus:
          return CbrInt(a - b);
        case TokenType.star:
          return CbrInt(a * b);
        case TokenType.slash:
          if (b == 0) {
            throw _error(
              expression.line,
              expression.column,
              'Divisão inteira por zero.',
              hint: 'Verifique o valor do divisor antes de dividir.',
              category: CbrErrorCategory.execucao,
            );
          }
          return CbrInt(a ~/ b);
        case TokenType.percent:
          if (b == 0) {
            throw _error(
              expression.line,
              expression.column,
              'Resto de divisão por zero.',
              category: CbrErrorCategory.execucao,
            );
          }
          return CbrInt(a - (a ~/ b) * b);
        default:
          break;
      }
    }

    final a = _asDouble(left);
    final b = _asDouble(right);
    switch (operator) {
      case TokenType.plus:
        return CbrFloat(a + b);
      case TokenType.minus:
        return CbrFloat(a - b);
      case TokenType.star:
        return CbrFloat(a * b);
      case TokenType.slash:
        if (b == 0) {
          throw _error(
            expression.line,
            expression.column,
            'Divisão por zero.',
            category: CbrErrorCategory.execucao,
          );
        }
        return CbrFloat(a / b);
      default:
        throw _error(
          expression.line,
          expression.column,
          'Operador não suportado para decimais.',
          category: CbrErrorCategory.tipo,
        );
    }
  }

  bool _compare(BinaryExpr expression, CbrValue left, CbrValue right) {
    final operator = expression.operator;
    int comparison;
    if ((left is CbrInt || left is CbrFloat) &&
        (right is CbrInt || right is CbrFloat)) {
      comparison = _asDouble(left).compareTo(_asDouble(right));
    } else if (left is CbrText && right is CbrText) {
      comparison = left.value.compareTo(right.value);
    } else if (left is CbrBool && right is CbrBool) {
      comparison = (left.value ? 1 : 0).compareTo(right.value ? 1 : 0);
    } else {
      throw _error(
        expression.line,
        expression.column,
        'Não é possível comparar ${left.type.label} com '
        '${right.type.label}.',
        category: CbrErrorCategory.tipo,
      );
    }
    switch (operator) {
      case TokenType.less:
        return comparison < 0;
      case TokenType.lessEqual:
        return comparison <= 0;
      case TokenType.greater:
        return comparison > 0;
      case TokenType.greaterEqual:
        return comparison >= 0;
      default:
        return false;
    }
  }

  bool _valuesEqual(CbrValue left, CbrValue right) {
    if ((left is CbrInt || left is CbrFloat) &&
        (right is CbrInt || right is CbrFloat)) {
      return _asDouble(left) == _asDouble(right);
    }
    if (left is CbrText && right is CbrText) return left.value == right.value;
    if (left is CbrBool && right is CbrBool) return left.value == right.value;
    if (left is CbrArray && right is CbrArray) {
      if (left.items.length != right.items.length) return false;
      for (var index = 0; index < left.items.length; index++) {
        if (!_valuesEqual(left.items[index], right.items[index])) return false;
      }
      return true;
    }
    return false;
  }

  double _asDouble(CbrValue value) {
    if (value is CbrInt) return value.value.toDouble();
    if (value is CbrFloat) return value.value;
    throw const CbrError(
      'Valor não numérico.',
      category: CbrErrorCategory.tipo,
    );
  }

  bool _requireBool(
    CbrValue value,
    int line,
    int column, {
    required String context,
  }) {
    if (value is CbrBool) return value.value;
    throw _error(
      line,
      column,
      '$context precisa resultar em booleano (recebeu ${value.type.label}).',
      hint: 'Use uma comparação, por exemplo: idade >= 18',
      category: CbrErrorCategory.tipo,
    );
  }

  int _requireInt(
    CbrValue value,
    int line,
    int column, {
    required String context,
  }) {
    if (value is CbrInt) return value.value;
    throw _error(
      line,
      column,
      '$context precisa ser inteiro (recebeu ${value.type.label}).',
      category: CbrErrorCategory.tipo,
    );
  }

  CbrValue _convertForType(
    CbrValue value,
    CbrType type,
    String name,
    int line,
    int column,
  ) {
    if (value.type == type) return value;
    if (type == CbrType.decimal && value is CbrInt) {
      return CbrFloat(value.value.toDouble());
    }
    throw _error(
      line,
      column,
      'A variável "$name" é do tipo ${type.label} e recebeu um valor '
      '${value.type.label}.',
      hint: 'Não é permitido mudar o tipo de uma variável já criada.',
      category: CbrErrorCategory.tipo,
    );
  }

  // ------------------------------------------------------------- chamadas

  Future<CbrValue> _evaluateCall(CallExpr expression, _Scope scope) async {
    final arguments = <CbrValue>[];
    for (final argument in expression.arguments) {
      arguments.add(await _evaluate(argument, scope));
    }
    final name = expression.name;
    final folded = CbrLexer.fold(name);

    FunctionDecl? userFunction = program.functions[name];
    if (userFunction == null) {
      for (final entry in program.functions.entries) {
        if (CbrLexer.fold(entry.key) == folded) {
          userFunction = entry.value;
          break;
        }
      }
    }
    if (userFunction != null) {
      return _callUserFunction(userFunction, arguments, expression);
    }

    if (!_isBuiltin(folded)) {
      throw _error(
        expression.line,
        expression.column,
        'A função "$name" não existe.',
        hint: 'Consulte a aba Documentação para ver as funções disponíveis.',
        category: CbrErrorCategory.tipo,
      );
    }
    return _callBuiltin(folded, name, arguments, expression, scope);
  }

  Future<CbrValue> _callUserFunction(
    FunctionDecl function,
    List<CbrValue> arguments,
    CallExpr expression,
  ) async {
    if (arguments.length != function.parameters.length) {
      throw _error(
        expression.line,
        expression.column,
        'A função "${function.name}" espera ${function.parameters.length} '
        'argumento(s) e recebeu ${arguments.length}.',
        category: CbrErrorCategory.tipo,
      );
    }
    for (final argument in arguments) {
      if (argument is! CbrInt && argument is! CbrFloat) {
        throw _error(
          expression.line,
          expression.column,
          'A função "${function.name}" aceita apenas números, mas recebeu '
          '${argument.type.label}.',
          category: CbrErrorCategory.tipo,
        );
      }
    }
    if (_callDepth >= _maxCallDepth) {
      throw _error(
        expression.line,
        expression.column,
        'Muitas chamadas de função encadeadas (limite $_maxCallDepth).',
        hint: 'Verifique se a função chama a si mesma sem parar.',
        category: CbrErrorCategory.limite,
      );
    }
    _callDepth++;
    try {
      // Como no compilador oficial, funções recebem parâmetros decimais e não
      // enxergam variáveis globais.
      final functionScope = _Scope(null);
      for (var index = 0; index < function.parameters.length; index++) {
        functionScope.declare(
          function.parameters[index],
          CbrType.decimal,
          CbrFloat(_asDouble(arguments[index])),
        );
      }
      try {
        await _executeBlock(function.body, functionScope);
      } on _ReturnSignal catch (signal) {
        final value = signal.value;
        if (value == null) return const CbrFloat(0);
        if (value is CbrInt) return CbrFloat(value.value.toDouble());
        if (value is CbrFloat) return value;
        return value;
      }
      throw _error(
        function.line,
        1,
        'A função "${function.name}" terminou sem "retorne".',
        hint: 'Toda função precisa devolver um valor.',
        category: CbrErrorCategory.execucao,
      );
    } finally {
      _callDepth--;
    }
  }

  bool _isBuiltin(String folded) =>
      cbrBuiltinNames.contains(folded) || folded == 'escreval';


  Future<CbrValue> _callBuiltin(
    String folded,
    String originalName,
    List<CbrValue> arguments,
    CallExpr expression,
    _Scope scope,
  ) async {
    switch (folded) {
      case 'printf':
        _expectArguments(expression, arguments, 1);
        final template = _requireText(
          arguments.first,
          expression.arguments.first.line,
          expression.arguments.first.column,
          context: 'O texto de printf',
        );
        _emit(_interpolate(template, scope, expression));
        return const CbrText('');
      case 'escreva':
      case 'escreval':
        _emit('${arguments.map((value) => value.display).join()}\n');
        return const CbrText('');
      case 'imprima':
        _emit(arguments.map((value) => value.display).join());
        return const CbrText('');
      case 'tamanho':
        _expectArguments(expression, arguments, 1);
        final value = arguments.first;
        if (value is CbrArray) return CbrInt(value.items.length);
        if (value is CbrText) return CbrInt(utf8.encode(value.value).length);
        throw _error(
          expression.line,
          expression.column,
          'tamanho() aceita texto ou array (recebeu ${value.type.label}).',
          category: CbrErrorCategory.tipo,
        );
      case 'juntar':
        _expectArguments(expression, arguments, 2);
        return CbrText(
          _requireText(arguments[0], expression.line, expression.column,
                  context: 'O primeiro argumento de juntar')
              .value +
              _requireText(arguments[1], expression.line, expression.column,
                      context: 'O segundo argumento de juntar')
                  .value,
        );
      case 'maiusculas':
      case 'minusculas':
        _expectArguments(expression, arguments, 1);
        final text = _requireText(
          arguments.first,
          expression.line,
          expression.column,
          context: 'O argumento de $originalName',
        ).value;
        return CbrText(
          folded == 'maiusculas' ? text.toUpperCase() : text.toLowerCase(),
        );
      case 'contem':
        _expectArguments(expression, arguments, 2);
        final haystack = _requireText(arguments[0], expression.line,
                expression.column,
                context: 'O texto de contem')
            .value;
        final needle = _requireText(arguments[1], expression.line,
                expression.column,
                context: 'O trecho de contem')
            .value;
        return CbrBool(haystack.contains(needle));
      case 'subtexto':
        _expectArguments(expression, arguments, 3);
        final text = _requireText(arguments[0], expression.line,
                expression.column,
                context: 'O texto de subtexto')
            .value;
        final start = _requireInt(arguments[1], expression.line,
            expression.column,
            context: 'O início de subtexto');
        final count = _requireInt(arguments[2], expression.line,
            expression.column,
            context: 'O comprimento de subtexto');
        final safeStart = start < 0 ? 0 : (start > text.length ? text.length : start);
        final safeCount = count < 0 ? 0 : count;
        final end = math.min(safeStart + safeCount, text.length);
        return CbrText(text.substring(safeStart, end));
      case 'substituir':
        _expectArguments(expression, arguments, 3);
        final text = _requireText(arguments[0], expression.line,
                expression.column,
                context: 'O texto de substituir')
            .value;
        final from = _requireText(arguments[1], expression.line,
                expression.column,
                context: 'O trecho antigo de substituir')
            .value;
        final to = _requireText(arguments[2], expression.line,
                expression.column,
                context: 'O trecho novo de substituir')
            .value;
        if (from.isEmpty) return CbrText(text);
        return CbrText(text.replaceAll(from, to));
      case 'adicionar':
        _expectArguments(expression, arguments, 2);
        final array = _requireArray(arguments[0], expression, 'adicionar');
        if (array.items.length >= CbrArray.capacity) {
          throw _error(
            expression.line,
            expression.column,
            'O array chegou ao limite de ${CbrArray.capacity} itens.',
            category: CbrErrorCategory.limite,
          );
        }
        array.items.add(arguments[1]);
        return const CbrText('');
      case 'remover':
        _expectArguments(expression, arguments, 2);
        final array = _requireArray(arguments[0], expression, 'remover');
        final index = _requireInt(arguments[1], expression.line,
            expression.column,
            context: 'O índice de remover');
        if (index < 0 || index >= array.items.length) {
          throw _error(
            expression.line,
            expression.column,
            'Índice $index fora do limite (o array tem '
            '${array.items.length} itens).',
            category: CbrErrorCategory.execucao,
          );
        }
        array.items.removeAt(index);
        return const CbrText('');
      case 'limpar':
        _expectArguments(expression, arguments, 1);
        final array = _requireArray(arguments[0], expression, 'limpar');
        array.items.clear();
        return const CbrText('');
      case 'aleatorio':
        return _randomBuiltin(expression, arguments);
      case 'texto':
        _expectArguments(expression, arguments, 1);
        return CbrText(arguments.first.display);
      case 'numero':
        _expectArguments(expression, arguments, 1);
        final value = arguments.first;
        if (value is CbrInt || value is CbrFloat) return value;
        final raw = _requireText(value, expression.line, expression.column,
                context: 'O valor de numero')
            .value
            .trim()
            .replaceAll(',', '.');
        final asInt = int.tryParse(raw);
        if (asInt != null) return CbrInt(asInt);
        final asDouble = double.tryParse(raw);
        if (asDouble != null) return CbrFloat(asDouble);
        throw _error(
          expression.line,
          expression.column,
          'numero() não conseguiu converter "${value.display}".',
          category: CbrErrorCategory.tipo,
        );
      case 'inteiro':
        _expectArguments(expression, arguments, 1);
        final value = arguments.first;
        if (value is CbrInt) return value;
        if (value is CbrFloat) return CbrInt(truncateToInt(value.value));
        if (value is CbrText) {
          final parsed = int.tryParse(value.value.trim());
          if (parsed != null) return CbrInt(parsed);
        }
        throw _error(
          expression.line,
          expression.column,
          'inteiro() não conseguiu converter "${value.display}".',
          category: CbrErrorCategory.tipo,
        );
      case 'real':
        _expectArguments(expression, arguments, 1);
        final value = arguments.first;
        if (value is CbrInt) return CbrFloat(value.value.toDouble());
        if (value is CbrFloat) return value;
        if (value is CbrText) {
          final parsed =
              double.tryParse(value.value.trim().replaceAll(',', '.'));
          if (parsed != null) return CbrFloat(parsed);
        }
        throw _error(
          expression.line,
          expression.column,
          'real() não conseguiu converter "${value.display}".',
          category: CbrErrorCategory.tipo,
        );
      case 'tipo':
        _expectArguments(expression, arguments, 1);
        return CbrText(arguments.first.type.label);
      default:
        return _numericBuiltin(folded, arguments, expression);
    }
  }

  CbrValue _randomBuiltin(CallExpr expression, List<CbrValue> arguments) {
    // Mantido simples e determinístico por execução para os testes.
    final random = math.Random(_steps);
    if (arguments.isEmpty) return CbrInt(random.nextInt(100));
    if (arguments.length == 1) {
      final limit = _requireInt(arguments.first, expression.line,
          expression.column,
          context: 'O limite de aleatorio');
      if (limit <= 0) return const CbrInt(0);
      return CbrInt(random.nextInt(limit));
    }
    final start = _requireInt(arguments.first, expression.line,
        expression.column,
        context: 'O início de aleatorio');
    final end = _requireInt(arguments[1], expression.line, expression.column,
        context: 'O fim de aleatorio');
    if (end <= start) return CbrInt(start);
    return CbrInt(start + random.nextInt(end - start));
  }

  CbrValue _numericBuiltin(
    String folded,
    List<CbrValue> arguments,
    CallExpr expression,
  ) {
    double arg(int index) {
      if (index >= arguments.length) {
        throw _error(
          expression.line,
          expression.column,
          'Faltam argumentos para $folded().',
          category: CbrErrorCategory.tipo,
        );
      }
      final value = arguments[index];
      if (value is CbrInt) return value.value.toDouble();
      if (value is CbrFloat) return value.value;
      throw _error(
        expression.arguments[index].line,
        expression.arguments[index].column,
        'A função $folded() exige números (recebeu ${value.type.label}).',
        category: CbrErrorCategory.tipo,
      );
    }

    switch (folded) {
      case 'raiz':
        return CbrFloat(math.sqrt(arg(0)));
      case 'absoluto':
        return CbrFloat(arg(0).abs());
      case 'arredondar':
        return CbrFloat(arg(0).roundToDouble());
      case 'piso':
        return CbrFloat(arg(0).floorToDouble());
      case 'teto':
        return CbrFloat(arg(0).ceilToDouble());
      case 'seno':
        return CbrFloat(math.sin(arg(0)));
      case 'cosseno':
        return CbrFloat(math.cos(arg(0)));
      case 'tangente':
        return CbrFloat(math.tan(arg(0)));
      case 'logaritmo':
        return CbrFloat(math.log(arg(0)));
      case 'log10':
        return CbrFloat(math.log(arg(0)) / math.ln10);
      case 'exponencial':
        return CbrFloat(math.exp(arg(0)));
      case 'maximo':
        return CbrFloat(math.max(arg(0), arg(1)));
      case 'minimo':
        return CbrFloat(math.min(arg(0), arg(1)));
      case 'potencia':
        return CbrFloat(math.pow(arg(0), arg(1)).toDouble());
      case 'limitar':
        final value = arg(0);
        final low = arg(1);
        final high = arg(2);
        return CbrFloat(math.min(math.max(value, low), high));
      default:
        throw _error(
          expression.line,
          expression.column,
          'Função "$folded" não reconhecida.',
          category: CbrErrorCategory.tipo,
        );
    }
  }

  void _expectArguments(CallExpr expression, List<CbrValue> arguments, int count) {
    if (arguments.length == count) return;
    throw _error(
      expression.line,
      expression.column,
      'A função "${expression.name}" espera $count argumento(s) e recebeu '
      '${arguments.length}.',
      category: CbrErrorCategory.tipo,
    );
  }

  CbrText _requireText(
    CbrValue value,
    int line,
    int column, {
    required String context,
  }) {
    if (value is CbrText) return value;
    throw _error(
      line,
      column,
      '$context precisa ser texto (recebeu ${value.type.label}).',
      hint: 'Use aspas duplas: "exemplo".',
      category: CbrErrorCategory.tipo,
    );
  }

  CbrArray _requireArray(CbrValue value, CallExpr expression, String name) {
    if (value is CbrArray) return value;
    throw _error(
      expression.line,
      expression.column,
      '$name() exige um array (recebeu ${value.type.label}).',
      category: CbrErrorCategory.tipo,
    );
  }

  // ------------------------------------------------------- interpolação

  String _interpolate(String template, _Scope scope, CallExpr expression) {
    final buffer = StringBuffer();
    var index = 0;
    while (index < template.length) {
      final char = template[index];
      if (char != '{') {
        buffer.write(char);
        index++;
        continue;
      }
      final close = template.indexOf('}', index);
      if (close < 0) {
        throw _error(
          expression.line,
          expression.column,
          'Marcador de interpolação sem "}" no texto.',
          hint: 'Use {int.nome}, {float.nome}, {bool.nome} ou {str.nome}.',
          category: CbrErrorCategory.tipo,
        );
      }
      final marker = template.substring(index + 1, close);
      buffer.write(_markerValue(marker, scope, expression));
      index = close + 1;
    }
    return buffer.toString();
  }

  String _markerValue(String marker, _Scope scope, CallExpr expression) {
    final dot = marker.indexOf('.');
    if (dot <= 0) {
      throw _error(
        expression.line,
        expression.column,
        'Marcador "{$marker}" inválido.',
        hint: 'Use {int.nome}, {float.nome}, {bool.nome} ou {str.nome}.',
        category: CbrErrorCategory.tipo,
      );
    }
    final typeName = marker.substring(0, dot);
    final expected = typeFromMarker(typeName);
    if (expected == null) {
      throw _error(
        expression.line,
        expression.column,
        'Tipo de interpolação "$typeName" desconhecido.',
        hint: 'Use int, float, bool ou str.',
        category: CbrErrorCategory.tipo,
      );
    }
    var rest = marker.substring(dot + 1).trim();
    int? arrayIndex;
    final bracket = rest.indexOf('[');
    if (bracket >= 0) {
      final closing = rest.indexOf(']', bracket);
      if (closing < 0) {
        throw _error(
          expression.line,
          expression.column,
          'Índice de array inválido no marcador "{$marker}".',
          category: CbrErrorCategory.tipo,
        );
      }
      final rawIndex = rest.substring(bracket + 1, closing).trim();
      arrayIndex = int.tryParse(rawIndex);
      if (arrayIndex == null) {
        final variable = scope.resolve(rawIndex);
        if (variable?.value is CbrInt) {
          arrayIndex = (variable!.value as CbrInt).value;
        } else {
          throw _error(
            expression.line,
            expression.column,
            'O índice "$rawIndex" no marcador precisa ser um inteiro.',
            category: CbrErrorCategory.tipo,
          );
        }
      }
      rest = rest.substring(0, bracket).trim();
    }
    final variable = scope.resolve(rest);
    if (variable == null) {
      throw _error(
        expression.line,
        expression.column,
        'A variável "$rest" usada na interpolação não foi declarada.',
        category: CbrErrorCategory.tipo,
      );
    }
    CbrValue value = variable.value;
    if (arrayIndex != null) {
      if (value is! CbrArray) {
        throw _error(
          expression.line,
          expression.column,
          'A variável "$rest" não é um array.',
          category: CbrErrorCategory.tipo,
        );
      }
      if (arrayIndex < 0 || arrayIndex >= value.items.length) {
        throw _error(
          expression.line,
          expression.column,
          'Índice $arrayIndex fora do limite (o array tem '
          '${value.items.length} itens).',
          category: CbrErrorCategory.execucao,
        );
      }
      value = value.items[arrayIndex];
      if (expected == CbrType.decimal && value is CbrInt) {
        return formatGeneral(value.value.toDouble());
      }
    } else if (value is CbrArray) {
      throw _error(
        expression.line,
        expression.column,
        'O array "$rest" precisa de um índice na interpolação.',
        hint: 'Use {$typeName.$rest[0]}.',
        category: CbrErrorCategory.tipo,
      );
    }
    if (value.type != expected) {
      throw _error(
        expression.line,
        expression.column,
        'O marcador {$typeName.$rest} espera ${expected.label}, mas a '
        'variável é ${value.type.label}.',
        hint: 'Use {${markerFor(value.type)}.$rest}.',
        category: CbrErrorCategory.tipo,
      );
    }
    return value.display;
  }
}
