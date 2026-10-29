import 'dart:async';
import 'dart:math' as math;

/// Erro de sintaxe ou de execução da linguagem Cbr, com a linha de origem.
class CbrException implements Exception {
  const CbrException(this.message, {this.line = 1});

  final String message;
  final int line;

  @override
  String toString() => 'Linha $line: $message';
}

/// Resultado de uma execução concluída.
class CbrExecutionResult {
  const CbrExecutionResult({
    required this.exitCode,
    required this.elapsed,
    required this.steps,
  });

  final int exitCode;
  final Duration elapsed;
  final int steps;
}

typedef CbrOutput = void Function(String text);
typedef CbrInput = Future<String> Function(String prompt);

/// Interpretador em Dart para a sintaxe Cbr publicada no repositório vorgweb/C-Brasil.
///
/// O núcleo cobre o Cbr 0.6 (expressões numéricas/lógicas, funções numéricas,
/// arrays mistos, printf/scan, if/else, while, for/range, break/continue e end).
/// Também aceita palavras-chave em português usadas nos exemplos visuais do app.
class CbrInterpreter {
  const CbrInterpreter(this.source, {this.stepLimit = 200000});

  final String source;
  final int stepLimit;

  Future<CbrExecutionResult> run({
    CbrOutput? onOutput,
    CbrInput? inputProvider,
  }) async {
    final stopwatch = Stopwatch()..start();
    final tokens = _Lexer(source).scanTokens();
    final program = _Parser(tokens).parse();
    final runtime = _Runtime(
      stepLimit: stepLimit,
      onOutput: onOutput ?? (_) {},
      inputProvider: inputProvider,
    );
    final exitCode = await runtime.executeProgram(program);
    stopwatch.stop();
    return CbrExecutionResult(
      exitCode: exitCode,
      elapsed: stopwatch.elapsed,
      steps: runtime.steps,
    );
  }
}

enum _TokenKind { identifier, number, string, symbol, newline, eof }

class _Token {
  const _Token(this.kind, this.lexeme, this.line, this.column, [this.literal]);

  final _TokenKind kind;
  final String lexeme;
  final int line;
  final int column;
  final Object? literal;

  @override
  String toString() => '$lexeme ($line:$column)';
}

class _Lexer {
  _Lexer(this.source);

  final String source;
  final List<_Token> _tokens = [];
  int _current = 0;
  int _line = 1;
  int _column = 1;

  List<_Token> scanTokens() {
    while (!_isAtEnd) {
      final start = _current;
      final line = _line;
      final column = _column;
      final char = _advance();

      if (char == ' ' || char == '\t' || char == '\f' || char == '\r') {
        continue;
      }
      if (char == '\n') {
        _tokens.add(_Token(_TokenKind.newline, '\n', line, column));
        continue;
      }
      if (char == '/' && _match('/')) {
        while (!_isAtEnd && _peek() != '\n') {
          _advance();
        }
        continue;
      }
      if (char == '/' && _match('*')) {
        _blockComment(line);
        continue;
      }
      if (char == '"') {
        _string(line, column);
        continue;
      }
      if (_isDigit(char) || (char == '.' && _isDigit(_peek()))) {
        _number(start, line, column);
        continue;
      }
      if (_isAlpha(char)) {
        _identifier(start, line, column);
        continue;
      }

      final twoCharacterOperators = <String>{
        '==',
        '!=',
        '<=',
        '>=',
        '&&',
        '||',
        '**',
      };
      var symbol = char;
      if (!_isAtEnd && twoCharacterOperators.contains('$char${_peek()}')) {
        symbol += _advance();
      }
      const symbols = <String>{
        '(', ')', '{', '}', '[', ']', ',', ';', '.',
        '+', '-', '*', '/', '%', '<', '>', '=', '!',
      };
      if (!symbols.contains(symbol)) {
        throw CbrException(
          'Caractere inesperado "$char".',
          line: line,
        );
      }
      _tokens.add(_Token(_TokenKind.symbol, symbol, line, column));
    }

    _tokens.add(_Token(_TokenKind.eof, '', _line, _column));
    return _tokens;
  }

  void _blockComment(int line) {
    while (!_isAtEnd) {
      if (_peek() == '*' && _peekNext() == '/') {
        _advance();
        _advance();
        return;
      }
      _advance();
    }
    throw CbrException('Comentário /* sem fechamento */.', line: line);
  }

  void _string(int line, int column) {
    final start = _current - 1;
    final buffer = StringBuffer();
    while (!_isAtEnd && _peek() != '"') {
      final char = _advance();
      if (char == '\\') {
        if (_isAtEnd) break;
        final escaped = _advance();
        switch (escaped) {
          case 'n':
            buffer.write('\n');
            break;
          case 'r':
            buffer.write('\r');
            break;
          case 't':
            buffer.write('\t');
            break;
          case '\\':
            buffer.write('\\');
            break;
          case '"':
            buffer.write('"');
            break;
          default:
            // Mantém escapes desconhecidos como o caractere escapado para não
            // surpreender quem usa sequências literais de caminhos.
            buffer.write(escaped);
        }
      } else {
        buffer.write(char);
      }
    }
    if (_isAtEnd) {
      throw CbrException('Texto entre aspas não foi fechado.', line: line);
    }
    _advance(); // aspas finais
    _tokens.add(
      _Token(
        _TokenKind.string,
        source.substring(start, _current),
        line,
        column,
        buffer.toString(),
      ),
    );
  }

  void _number(int start, int line, int column) {
    while (_isDigit(_peek())) {
      _advance();
    }
    if (_peek() == '.' && _isDigit(_peekNext())) {
      _advance();
      while (_isDigit(_peek())) {
        _advance();
      }
    }
    if (_peek() == 'e' || _peek() == 'E') {
      _advance();
      if (_peek() == '+' || _peek() == '-') _advance();
      if (!_isDigit(_peek())) {
        throw CbrException('Expoente numérico inválido.', line: line);
      }
      while (_isDigit(_peek())) {
        _advance();
      }
    }
    final lexeme = source.substring(start, _current);
    final literal = lexeme.contains('.') || lexeme.contains('e') || lexeme.contains('E')
        ? double.parse(lexeme)
        : int.parse(lexeme);
    _tokens.add(_Token(_TokenKind.number, lexeme, line, column, literal));
  }

  void _identifier(int start, int line, int column) {
    while (_isAlphaNumeric(_peek())) {
      _advance();
    }
    final text = source.substring(start, _current);
    _tokens.add(_Token(_TokenKind.identifier, text, line, column));
  }

  bool get _isAtEnd => _current >= source.length;

  String _advance() {
    final char = source[_current++];
    if (char == '\n') {
      _line++;
      _column = 1;
    } else {
      _column++;
    }
    return char;
  }

  bool _match(String expected) {
    if (_isAtEnd || source[_current] != expected) return false;
    _advance();
    return true;
  }

  String _peek() => _isAtEnd ? '\u0000' : source[_current];
  String _peekNext() => _current + 1 >= source.length ? '\u0000' : source[_current + 1];

  bool _isDigit(String char) => char.isNotEmpty && char.codeUnitAt(0) >= 48 && char.codeUnitAt(0) <= 57;

  bool _isAlpha(String char) {
    if (char.isEmpty) return false;
    final code = char.codeUnitAt(0);
    return char == '_' ||
        (code >= 65 && code <= 90) ||
        (code >= 97 && code <= 122) ||
        (code >= 0x00C0 && code <= 0x024F);
  }

  bool _isAlphaNumeric(String char) => _isAlpha(char) || _isDigit(char);
}

class _Program {
  const _Program(this.functions, this.statements);

  final Map<String, _FunctionDeclaration> functions;
  final List<_Statement> statements;
}

class _Parser {
  _Parser(this._tokens);

  final List<_Token> _tokens;
  int _current = 0;
  final Map<String, _FunctionDeclaration> _functions = {};

  _Program parse() {
    final statements = <_Statement>[];
    while (!_isAtEnd) {
      _skipSeparators();
      if (_isAtEnd) break;
      if (_matchWords('function', 'funcao')) {
        final function = _functionDeclaration(_previous);
        if (_functions.containsKey(function.name)) {
          _error(function.nameToken, 'A função "${function.name}" já foi declarada.');
        }
        _functions[function.name] = function;
      } else {
        statements.add(_statement());
      }
      _skipSeparators();
    }
    return _Program(Map.unmodifiable(_functions), List.unmodifiable(statements));
  }

  _FunctionDeclaration _functionDeclaration(_Token keyword) {
    final name = _consumeIdentifier('Esperado o nome da função.');
    _consume('(', 'Esperado "(" depois do nome da função.');
    final parameter = _consumeIdentifier('Esperado um parâmetro numérico.');
    _consume(')', 'Esperado ")" depois do parâmetro.');
    _consume('{', 'Esperado "{" para iniciar o corpo da função.');
    final body = _bracedStatements('função');
    return _FunctionDeclaration(name.lexeme, name, parameter.lexeme, body, keyword);
  }

  List<_Statement> _bracedStatements(String context) {
    final statements = <_Statement>[];
    while (!_check('}') && !_isAtEnd) {
      _skipSeparators();
      if (_check('}') || _isAtEnd) break;
      statements.add(_statement());
      _skipSeparators();
    }
    _consume('}', 'Esperado "}" para fechar o bloco de $context.');
    return statements;
  }

  _Statement _statement() {
    if (_matchWords('inicio', 'fim')) return _NoopStatement(_previous);
    if (_matchWords('if', 'se')) return _ifStatement(_previous);
    if (_matchWords('while', 'enquanto')) return _whileStatement(_previous);
    if (_matchWords('for', 'para')) return _forStatement(_previous);
    if (_matchWords('printf', 'escreva')) return _outputStatement(_previous);
    if (_match('scan')) return _scanStatement(_previous);
    if (_match('end')) return _endStatement(_previous);
    if (_match('retorne')) return _exitStatement(_previous);
    if (_match('return')) return _returnStatement(_previous);
    if (_matchWords('break', 'pare')) return _BreakStatement(_previous);
    if (_matchWords('continue', 'prossiga')) return _ContinueStatement(_previous);
    if (_matchTypeKeyword()) return _declarationStatement(_previous);

    if (_checkIdentifier() && _checkNext('=')) {
      final name = _advance();
      _advance();
      return _AssignmentStatement(name, _expression());
    }

    final token = _peek;
    _error(token, 'Instrução não reconhecida. Verifique a sintaxe da linha.');
  }

  _Statement _declarationStatement(_Token typeToken) {
    final name = _consumeIdentifier('Esperado o nome da variável depois do tipo.');
    _Expression value;
    if (_match('=')) {
      value = _expression();
    } else {
      value = _LiteralExpression(_defaultValue(typeToken.lexeme), typeToken);
    }
    return _AssignmentStatement(name, value, declaredType: _typeFromKeyword(typeToken.lexeme));
  }

  _Statement _ifStatement(_Token keyword) {
    final condition = _condition();
    _matchWords('entao', 'então');
    _skipSeparators();

    final usesKeywordTerminator = !_check('{');
    final thenBranch = _statementBlock(
      usesKeywordTerminator ? const {'senao', 'else', 'fimse'} : const {},
      'if',
    );
    _skipSeparators();

    List<_Statement> elseBranch = const [];
    if (_matchWords('else', 'senao')) {
      _skipSeparators();
      if (_matchWords('if', 'se')) {
        elseBranch = <_Statement>[_ifStatement(_previous)];
      } else {
        final elseUsesTerminator = !_check('{');
        elseBranch = _statementBlock(
          elseUsesTerminator ? const {'fimse'} : const {},
          'else',
        );
        _skipSeparators();
      }
    }

    if (usesKeywordTerminator || _check('fimse')) {
      _match('fimse');
    }
    return _IfStatement(condition, thenBranch, elseBranch, keyword);
  }

  _Statement _whileStatement(_Token keyword) {
    final condition = _condition();
    _matchWords('faca', 'faça');
    _skipSeparators();
    final usesKeywordTerminator = !_check('{');
    final body = _statementBlock(
      usesKeywordTerminator ? const {'fimenquanto', 'fimwhile'} : const {},
      'while',
    );
    _skipSeparators();
    if (usesKeywordTerminator) {
      if (!_matchWords('fimenquanto', 'fimwhile')) {
        _error(_peek, 'Esperado "fimenquanto" para fechar o loop.');
      }
    }
    return _WhileStatement(condition, body, keyword);
  }

  _Statement _forStatement(_Token keyword) {
    final parenthesized = _match('(');
    if (_checkTypeKeyword() || (_checkIdentifier() && _checkNext('='))) {
      final initializer = _forAssignment(allowDeclaration: true);
      _consume(';', 'Esperado ";" depois da inicialização do for.');
      final condition = _expression();
      _consume(';', 'Esperado ";" depois da condição do for.');
      final update = _forAssignment(allowDeclaration: false);
      if (parenthesized) _consume(')', 'Esperado ")" no cabeçalho do for.');
      _matchWords('faca', 'faça');
      _skipSeparators();
      final usesKeywordTerminator = !_check('{');
      final body = _statementBlock(
        usesKeywordTerminator ? const {'fimpara', 'endfor'} : const {},
        'for',
      );
      _skipSeparators();
      if (usesKeywordTerminator && !_matchWords('fimpara', 'endfor')) {
        _error(_peek, 'Esperado "fimpara" para fechar o loop.');
      }
      return _CStyleForStatement(initializer, condition, update, body, keyword);
    }

    _Token? typeToken;
    if (_checkTypeKeyword()) typeToken = _advance();
    final variable = _consumeIdentifier('Esperado a variável do for.');
    if (!_match('in')) _error(_peek, 'Use "for nome in range(...)".');
    if (!_match('range')) _error(_peek, 'Use "range(...)" no cabeçalho do for.');
    _consume('(', 'Esperado "(" depois de range.');
    final first = _expression();
    _Expression? stop;
    _Expression? step;
    if (_match(',')) {
      stop = _expression();
      if (_match(',')) step = _expression();
    }
    _consume(')', 'Esperado ")" para fechar range().');
    if (parenthesized) _consume(')', 'Esperado ")" no cabeçalho do for.');
    _matchWords('faca', 'faça');
    _skipSeparators();
    final usesKeywordTerminator = !_check('{');
    final body = _statementBlock(
      usesKeywordTerminator ? const {'fimpara', 'endfor'} : const {},
      'for',
    );
    _skipSeparators();
    if (usesKeywordTerminator && !_matchWords('fimpara', 'endfor')) {
      _error(_peek, 'Esperado "fimpara" para fechar o loop.');
    }
    return _RangeForStatement(
      variable,
      first,
      stop,
      step,
      typeToken == null ? null : _typeFromKeyword(typeToken.lexeme),
      body,
      keyword,
    );
  }

  _Statement _forAssignment({required bool allowDeclaration}) {
    if (_checkTypeKeyword()) {
      if (!allowDeclaration) {
        _error(_peek, 'A atualização do for não pode declarar outra variável.');
      }
      final type = _advance();
      return _declarationStatement(type);
    }
    final name = _consumeIdentifier('Esperado uma variável na expressão do for.');
    _consume('=', 'Esperado "=" na atribuição do for.');
    return _AssignmentStatement(name, _expression());
  }

  _Statement _outputStatement(_Token keyword) {
    _consume('(', 'Esperado "(" depois de ${keyword.lexeme}.');
    final arguments = <_Expression>[];
    if (!_check(')')) {
      do {
        arguments.add(_expression());
      } while (_match(','));
    }
    _consume(')', 'Esperado ")" depois dos argumentos de saída.');
    return _OutputStatement(arguments, keyword.lexeme == 'printf', keyword);
  }

  _Statement _scanStatement(_Token keyword) {
    _consume('(', 'Esperado "(" depois de scan.');
    final promptToken = _consumeKind(
      _TokenKind.string,
      'scan precisa começar com uma mensagem entre aspas.',
    );
    _match(',');
    _consume('{', 'Esperado marcador {tipo.variavel} depois da mensagem de scan.');
    final type = _consumeIdentifier('Esperado o tipo do marcador de scan.');
    _consume('.', 'Use o formato {tipo.variavel} em scan.');
    final variable = _consumeIdentifier('Esperado a variável do marcador de scan.');
    _consume('}', 'Esperado "}" para fechar o marcador de scan.');
    _consume(')', 'Esperado ")" depois do marcador de scan.');
    if (!const {'str', 'int', 'float', 'bool'}.contains(type.lexeme)) {
      _error(type, 'Tipo de scan desconhecido. Use str, int, float ou bool.');
    }
    return _ScanStatement(
      promptToken.literal! as String,
      type.lexeme,
      variable.lexeme,
      keyword,
    );
  }

  _Statement _endStatement(_Token keyword) {
    _consume('(', 'Use end(codigo).');
    final expression = _expression();
    _consume(')', 'Esperado ")" depois do código de end().');
    return _ExitStatement(expression, keyword);
  }

  _Statement _exitStatement(_Token keyword) {
    final expression = _expression();
    return _ExitStatement(expression, keyword);
  }

  _Statement _returnStatement(_Token keyword) {
    final expression = _expression();
    return _ReturnStatement(expression, keyword);
  }

  List<_Statement> _statementBlock(Set<String> terminators, String context) {
    if (_match('{')) return _bracedStatements(context);
    if (terminators.isEmpty) {
      _error(_peek, 'Esperado "{" para iniciar o bloco.');
    }
    final statements = <_Statement>[];
    _skipSeparators();
    while (!_isAtEnd && !_check('}') && !terminators.contains(_peek.lexeme)) {
      statements.add(_statement());
      _skipSeparators();
    }
    return statements;
  }

  _Expression _condition() {
    if (_match('(')) {
      final expression = _expression();
      _consume(')', 'Esperado ")" depois da condição.');
      return expression;
    }
    return _expression();
  }

  _Expression _expression() => _or();

  _Expression _or() {
    var expression = _and();
    while (_match('||')) {
      final operator = _previous;
      expression = _BinaryExpression(expression, operator, _and());
    }
    return expression;
  }

  _Expression _and() {
    var expression = _equality();
    while (_match('&&')) {
      final operator = _previous;
      expression = _BinaryExpression(expression, operator, _equality());
    }
    return expression;
  }

  _Expression _equality() {
    var expression = _comparison();
    while (_match('==', '!=')) {
      final operator = _previous;
      expression = _BinaryExpression(expression, operator, _comparison());
    }
    return expression;
  }

  _Expression _comparison() {
    var expression = _term();
    while (_match('<', '<=', '>', '>=')) {
      final operator = _previous;
      expression = _BinaryExpression(expression, operator, _term());
    }
    return expression;
  }

  _Expression _term() {
    var expression = _factor();
    while (_match('+', '-')) {
      final operator = _previous;
      expression = _BinaryExpression(expression, operator, _factor());
    }
    return expression;
  }

  _Expression _factor() {
    var expression = _power();
    while (_match('*', '/', '%')) {
      final operator = _previous;
      expression = _BinaryExpression(expression, operator, _power());
    }
    return expression;
  }

  _Expression _power() {
    final expression = _unary();
    if (_match('**')) {
      final operator = _previous;
      return _BinaryExpression(expression, operator, _power());
    }
    return expression;
  }

  _Expression _unary() {
    if (_match('!', '-', '+')) {
      final operator = _previous;
      return _UnaryExpression(operator, _unary());
    }
    return _primary();
  }

  _Expression _primary() {
    if (_match('true')) return _LiteralExpression(true, _previous);
    if (_match('false')) return _LiteralExpression(false, _previous);
    if (_checkKind(_TokenKind.number) || _checkKind(_TokenKind.string)) {
      final token = _advance();
      return _LiteralExpression(token.literal, token);
    }
    if (_match('(')) {
      final expression = _expression();
      _consume(')', 'Esperado ")" depois da expressão.');
      return expression;
    }
    if (_match('[')) {
      final token = _previous;
      final values = <_Expression>[];
      if (!_check(']')) {
        do {
          values.add(_expression());
        } while (_match(','));
      }
      _consume(']', 'Esperado "]" para fechar o array.');
      if (values.isEmpty) _error(token, 'Array vazio ainda não é suportado no Cbr 0.6.');
      return _ArrayExpression(values, token);
    }
    if (_checkIdentifier()) {
      final name = _advance();
      if (_match('(')) {
        final arguments = <_Expression>[];
        if (!_check(')')) {
          do {
            arguments.add(_expression());
          } while (_match(','));
        }
        _consume(')', 'Esperado ")" depois dos argumentos da função.');
        return _CallExpression(name, arguments);
      }
      return _VariableExpression(name);
    }
    _error(_peek, 'Esperado um número, texto, booleano, variável ou "(".');
  }

  bool _matchTypeKeyword() => _checkTypeKeyword() && _advance().kind == _TokenKind.identifier;

  bool _checkTypeKeyword() => const {
        'inteiro',
        'int',
        'real',
        'decimal',
        'float',
        'texto',
        'str',
        'string',
        'logico',
        'lógico',
        'booleano',
        'bool',
      }.contains(_peek.lexeme);

  bool _checkIdentifier() => _peek.kind == _TokenKind.identifier;
  bool _checkKind(_TokenKind kind) => _peek.kind == kind;
  bool _checkNext(String lexeme) => _current + 1 < _tokens.length && _tokens[_current + 1].lexeme == lexeme;

  bool _matchWords(String first, String second) => _match(first, second);

  bool _match(String first, [String? second, String? third, String? fourth]) {
    final choices = <String>{first, if (second != null) second, if (third != null) third, if (fourth != null) fourth};
    if (!choices.contains(_peek.lexeme)) return false;
    _advance();
    return true;
  }

  _Token _consumeIdentifier(String message) {
    if (_checkIdentifier()) return _advance();
    _error(_peek, message);
  }

  _Token _consumeKind(_TokenKind kind, String message) {
    if (_checkKind(kind)) return _advance();
    _error(_peek, message);
  }

  _Token _consume(String lexeme, String message) {
    if (_check(lexeme)) return _advance();
    _error(_peek, message);
  }

  bool _check(String lexeme) => _peek.lexeme == lexeme;

  _Token _advance() {
    if (!_isAtEnd) _current++;
    return _previous;
  }

  _Token get _peek => _tokens[_current];
  _Token get _previous => _tokens[_current - 1];
  bool get _isAtEnd => _peek.kind == _TokenKind.eof;

  void _skipSeparators() {
    while (_peek.kind == _TokenKind.newline || _check(';')) {
      _advance();
    }
  }

  Never _error(_Token token, String message) {
    throw CbrException(message, line: token.line);
  }

  static String _typeFromKeyword(String keyword) {
    switch (keyword) {
      case 'inteiro':
      case 'int':
        return 'int';
      case 'real':
      case 'decimal':
      case 'float':
        return 'float';
      case 'texto':
      case 'str':
      case 'string':
        return 'str';
      case 'logico':
      case 'lógico':
      case 'booleano':
      case 'bool':
        return 'bool';
      default:
        return 'dynamic';
    }
  }

  static Object _defaultValue(String keyword) {
    switch (_typeFromKeyword(keyword)) {
      case 'int':
        return 0;
      case 'float':
        return 0.0;
      case 'str':
        return '';
      case 'bool':
        return false;
      default:
        return 0;
    }
  }
}

abstract class _Expression {
  const _Expression(this.token);
  final _Token token;
  Future<Object?> evaluate(_Runtime runtime, _Environment environment);
}

class _LiteralExpression extends _Expression {
  const _LiteralExpression(this.value, super.token);
  final Object? value;

  @override
  Future<Object?> evaluate(_Runtime runtime, _Environment environment) async => value;
}

class _VariableExpression extends _Expression {
  const _VariableExpression(super.token);

  @override
  Future<Object?> evaluate(_Runtime runtime, _Environment environment) async =>
      environment.read(token.lexeme, token);
}

class _ArrayExpression extends _Expression {
  const _ArrayExpression(this.elements, super.token);
  final List<_Expression> elements;

  @override
  Future<Object?> evaluate(_Runtime runtime, _Environment environment) async {
    final values = <Object?>[];
    for (final element in elements) {
      values.add(await element.evaluate(runtime, environment));
    }
    return values;
  }
}

class _UnaryExpression extends _Expression {
  const _UnaryExpression(this.operator, this.operand) : super(operator);
  final _Token operator;
  final _Expression operand;

  @override
  Future<Object?> evaluate(_Runtime runtime, _Environment environment) async {
    final value = await operand.evaluate(runtime, environment);
    switch (operator.lexeme) {
      case '!':
        if (value is! bool) _typeError(operator, 'O operador ! exige um booleano.');
        return !value;
      case '-':
        if (value is! num) _typeError(operator, 'O operador unário exige um número.');
        return value is int ? -value : -value.toDouble();
      case '+':
        if (value is! num) _typeError(operator, 'O operador unário exige um número.');
        return value;
    }
    return null;
  }
}

class _BinaryExpression extends _Expression {
  const _BinaryExpression(this.left, this.operator, this.right) : super(operator);
  final _Expression left;
  final _Token operator;
  final _Expression right;

  @override
  Future<Object?> evaluate(_Runtime runtime, _Environment environment) async {
    final a = await left.evaluate(runtime, environment);
    if (operator.lexeme == '&&') {
      if (a is! bool) _typeError(operator, 'O operador && exige booleanos.');
      if (!a) return false;
      final b = await right.evaluate(runtime, environment);
      if (b is! bool) _typeError(operator, 'O operador && exige booleanos.');
      return b;
    }
    if (operator.lexeme == '||') {
      if (a is! bool) _typeError(operator, 'O operador || exige booleanos.');
      if (a) return true;
      final b = await right.evaluate(runtime, environment);
      if (b is! bool) _typeError(operator, 'O operador || exige booleanos.');
      return b;
    }
    final b = await right.evaluate(runtime, environment);
    switch (operator.lexeme) {
      case '+':
        if (a is num && b is num) return _numericResult(a + b, a, b);
        if (a is String || b is String) return '${_stringify(a)}${_stringify(b)}';
        _typeError(operator, 'O operador + exige números ou pelo menos um texto.');
      case '-':
        if (a is! num || b is! num) _typeError(operator, 'O operador - exige números.');
        return _numericResult(a - b, a, b);
      case '*':
        if (a is! num || b is! num) _typeError(operator, 'O operador * exige números.');
        return _numericResult(a * b, a, b);
      case '/':
        if (a is! num || b is! num) _typeError(operator, 'O operador / exige números.');
        if (b == 0) _typeError(operator, 'Divisão por zero.');
        return a / b;
      case '%':
        if (a is! num || b is! num) _typeError(operator, 'O operador % exige números.');
        if (b == 0) _typeError(operator, 'Resto de divisão por zero.');
        return _numericResult(a % b, a, b);
      case '**':
        if (a is! num || b is! num) _typeError(operator, 'O operador ** exige números.');
        final result = math.pow(a, b);
        if (a is int && b is int && result.isFinite && result == result.roundToDouble()) {
          return result.toInt();
        }
        return result;
      case '==':
        return _equals(a, b);
      case '!=':
        return !_equals(a, b);
      case '<':
        return _compare(a, b, operator) < 0;
      case '<=':
        return _compare(a, b, operator) <= 0;
      case '>':
        return _compare(a, b, operator) > 0;
      case '>=':
        return _compare(a, b, operator) >= 0;
    }
    return null;
  }
}

class _CallExpression extends _Expression {
  const _CallExpression(this.name, this.arguments) : super(name);
  final _Token name;
  final List<_Expression> arguments;

  @override
  Future<Object?> evaluate(_Runtime runtime, _Environment environment) async {
    if (arguments.length != 1) {
      throw CbrException(
        'A função "${name.lexeme}" aceita exatamente um argumento numérico no Cbr 0.6.',
        line: name.line,
      );
    }
    final argument = await arguments.single.evaluate(runtime, environment);
    if (argument is! num) {
      throw CbrException('Funções do Cbr 0.6 aceitam apenas argumento numérico.', line: name.line);
    }
    return runtime.invoke(name, argument);
  }
}

abstract class _Statement {
  const _Statement(this.token);
  final _Token token;
  Future<_Signal?> execute(_Runtime runtime, _Environment environment);
}

class _NoopStatement extends _Statement {
  const _NoopStatement(super.token);
  @override
  Future<_Signal?> execute(_Runtime runtime, _Environment environment) async => null;
}

class _AssignmentStatement extends _Statement {
  const _AssignmentStatement(
    super.token,
    this.expression, {
    this.declaredType,
  });

  final _Expression expression;
  final String? declaredType;

  @override
  Future<_Signal?> execute(_Runtime runtime, _Environment environment) async {
    await runtime.step(token);
    final value = await expression.evaluate(runtime, environment);
    if (declaredType != null) {
      environment.declare(token.lexeme, _coerce(value, declaredType!, token), token);
    } else {
      environment.assignOrDeclare(token.lexeme, value, token);
    }
    return null;
  }
}

class _IfStatement extends _Statement {
  const _IfStatement(this.condition, this.thenBranch, this.elseBranch, super.token);
  final _Expression condition;
  final List<_Statement> thenBranch;
  final List<_Statement> elseBranch;

  @override
  Future<_Signal?> execute(_Runtime runtime, _Environment environment) async {
    await runtime.step(token);
    final value = await condition.evaluate(runtime, environment);
    if (value is! bool) {
      throw CbrException('A condição de if precisa resultar em verdadeiro ou falso.', line: condition.token.line);
    }
    return runtime.executeStatements(value ? thenBranch : elseBranch, environment);
  }
}

class _WhileStatement extends _Statement {
  const _WhileStatement(this.condition, this.body, super.token);
  final _Expression condition;
  final List<_Statement> body;

  @override
  Future<_Signal?> execute(_Runtime runtime, _Environment environment) async {
    while (true) {
      await runtime.step(token);
      final value = await condition.evaluate(runtime, environment);
      if (value is! bool) {
        throw CbrException('A condição de while precisa resultar em verdadeiro ou falso.', line: condition.token.line);
      }
      if (!value) break;
      final signal = await runtime.executeStatements(body, environment);
      if (signal?.kind == _SignalKind.breakLoop) break;
      if (signal?.kind == _SignalKind.continueLoop) continue;
      if (signal != null) return signal;
    }
    return null;
  }
}

class _RangeForStatement extends _Statement {
  const _RangeForStatement(
    this.variable,
    this.first,
    this.stop,
    this.stepExpression,
    this.declaredType,
    this.body,
    super.token,
  );

  final _Token variable;
  final _Expression first;
  final _Expression? stop;
  final _Expression? stepExpression;
  final String? declaredType;
  final List<_Statement> body;

  @override
  Future<_Signal?> execute(_Runtime runtime, _Environment environment) async {
    await runtime.step(token);
    final startValue = await first.evaluate(runtime, environment);
    final stopValue = stop == null ? startValue : await stop!.evaluate(runtime, environment);
    final stepValue = stepExpression == null ? 1 : await stepExpression!.evaluate(runtime, environment);
    if (startValue is! int || stopValue is! int || stepValue is! int) {
      throw CbrException('range() aceita apenas expressões inteiras.', line: token.line);
    }
    if (stepValue == 0) throw CbrException('O passo de range() não pode ser zero.', line: token.line);

    final initial = stop == null ? 0 : startValue;
    final end = stop == null ? startValue : stopValue;
    final loopStep = stepValue;
    if (environment.containsLocal(variable.lexeme)) {
      throw CbrException('A variável "${variable.lexeme}" do for já existe; use outro nome.', line: variable.line);
    }
    environment.declare(variable.lexeme, initial, variable, type: declaredType ?? 'int');
    try {
      var current = initial;
      bool hasNext() => loopStep > 0 ? current < end : current > end;
      while (hasNext()) {
        await runtime.step(token);
        environment.setExisting(variable.lexeme, current, variable);
        final signal = await runtime.executeStatements(body, environment);
        if (signal?.kind == _SignalKind.breakLoop) break;
        if (signal != null && signal.kind != _SignalKind.continueLoop) return signal;
        current += loopStep;
      }
    } finally {
      environment.removeLocal(variable.lexeme);
    }
    // Range com um argumento é 0..n; range(inicio, fim) é inclusivo no início
    // e exclusivo no fim, igual à implementação de referência.
    return null;
  }
}

class _CStyleForStatement extends _Statement {
  const _CStyleForStatement(this.initializer, this.condition, this.update, this.body, super.token);
  final _Statement initializer;
  final _Expression condition;
  final _Statement update;
  final List<_Statement> body;

  @override
  Future<_Signal?> execute(_Runtime runtime, _Environment environment) async {
    await initializer.execute(runtime, environment);
    while (true) {
      await runtime.step(token);
      final value = await condition.evaluate(runtime, environment);
      if (value is! bool) {
        throw CbrException('A condição do for precisa resultar em verdadeiro ou falso.', line: condition.token.line);
      }
      if (!value) break;
      final signal = await runtime.executeStatements(body, environment);
      if (signal?.kind == _SignalKind.breakLoop) break;
      if (signal != null && signal.kind != _SignalKind.continueLoop) return signal;
      await update.execute(runtime, environment);
    }
    return null;
  }
}

class _OutputStatement extends _Statement {
  const _OutputStatement(this.arguments, this.isPrintf, super.token);
  final List<_Expression> arguments;
  final bool isPrintf;

  @override
  Future<_Signal?> execute(_Runtime runtime, _Environment environment) async {
    await runtime.step(token);
    final values = <Object?>[];
    for (final argument in arguments) {
      values.add(await argument.evaluate(runtime, environment));
    }
    if (isPrintf && values.length == 1 && values.single is String) {
      runtime.write(_interpolate(values.single! as String, environment, token));
    } else {
      final rendered = values.map(_stringify).join();
      runtime.write(isPrintf ? rendered : '$rendered\n');
    }
    return null;
  }
}

class _ScanStatement extends _Statement {
  const _ScanStatement(this.prompt, this.type, this.variable, super.token);
  final String prompt;
  final String type;
  final String variable;

  @override
  Future<_Signal?> execute(_Runtime runtime, _Environment environment) async {
    await runtime.step(token);
    final expectedType = environment.typeOf(variable, token);
    if (expectedType == 'array' || expectedType != type) {
      throw CbrException(
        'O marcador {$type.$variable} não corresponde ao tipo da variável.',
        line: token.line,
      );
    }
    final provider = runtime.inputProvider;
    if (provider == null) {
      throw CbrException('Este programa pediu entrada, mas não há um campo de entrada ativo.', line: token.line);
    }
    runtime.write(prompt);
    final input = await provider(prompt);
    final Object value;
    try {
      switch (type) {
        case 'str':
          value = input;
          break;
        case 'int':
          value = int.parse(input.trim());
          break;
        case 'float':
          value = double.parse(input.trim());
          break;
        case 'bool':
          final normalized = input.trim().toLowerCase();
          if (normalized == 'true' || normalized == '1' || normalized == 'verdadeiro') {
            value = true;
          } else if (normalized == 'false' || normalized == '0' || normalized == 'falso') {
            value = false;
          } else {
            throw const FormatException();
          }
          break;
        default:
          throw const FormatException();
      }
    } on FormatException {
      throw CbrException('Entrada inválida para o tipo $type.', line: token.line);
    }
    environment.setExisting(variable, value, token);
    return null;
  }
}

class _ExitStatement extends _Statement {
  const _ExitStatement(this.expression, super.token);
  final _Expression expression;

  @override
  Future<_Signal?> execute(_Runtime runtime, _Environment environment) async {
    await runtime.step(token);
    final value = await expression.evaluate(runtime, environment);
    if (value is! int) {
      throw CbrException('end()/retorne exige um código de saída inteiro.', line: token.line);
    }
    return _Signal(_SignalKind.exitProgram, value);
  }
}

class _ReturnStatement extends _Statement {
  const _ReturnStatement(this.expression, super.token);
  final _Expression expression;

  @override
  Future<_Signal?> execute(_Runtime runtime, _Environment environment) async {
    await runtime.step(token);
    final value = await expression.evaluate(runtime, environment);
    if (value is! num) {
      throw CbrException('return de função exige um valor numérico no Cbr 0.6.', line: token.line);
    }
    return _Signal(_SignalKind.returnFunction, value);
  }
}

class _BreakStatement extends _Statement {
  const _BreakStatement(super.token);
  @override
  Future<_Signal?> execute(_Runtime runtime, _Environment environment) async {
    await runtime.step(token);
    return const _Signal(_SignalKind.breakLoop);
  }
}

class _ContinueStatement extends _Statement {
  const _ContinueStatement(super.token);
  @override
  Future<_Signal?> execute(_Runtime runtime, _Environment environment) async {
    await runtime.step(token);
    return const _Signal(_SignalKind.continueLoop);
  }
}

class _FunctionDeclaration {
  const _FunctionDeclaration(this.name, this.nameToken, this.parameter, this.body, this.token);
  final String name;
  final _Token nameToken;
  final String parameter;
  final List<_Statement> body;
  final _Token token;
}

enum _SignalKind { breakLoop, continueLoop, returnFunction, exitProgram }

class _Signal {
  const _Signal(this.kind, [this.value]);
  final _SignalKind kind;
  final Object? value;
}

class _Runtime {
  _Runtime({
    required this.stepLimit,
    required this.onOutput,
    required this.inputProvider,
  });

  final int stepLimit;
  final CbrOutput onOutput;
  final CbrInput? inputProvider;
  final Map<String, _FunctionDeclaration> _functions = {};
  int steps = 0;
  int _callDepth = 0;

  Future<int> executeProgram(_Program program) async {
    _functions.addAll(program.functions);
    final signal = await executeStatements(program.statements, _Environment());
    if (signal == null) return 0;
    if (signal.kind == _SignalKind.exitProgram) return signal.value! as int;
    if (signal.kind == _SignalKind.breakLoop || signal.kind == _SignalKind.continueLoop) {
      throw CbrException('break/continue só podem ser usados dentro de loops.');
    }
    throw CbrException('return só pode ser usado dentro de uma função.');
  }

  Future<_Signal?> executeStatements(List<_Statement> statements, _Environment environment) async {
    for (final statement in statements) {
      final signal = await statement.execute(this, environment);
      if (signal != null) return signal;
    }
    return null;
  }

  Future<void> step(_Token token) async {
    steps++;
    if (steps > stepLimit) {
      throw CbrException(
        'Limite de $stepLimit instruções atingido. Verifique se há um loop infinito.',
        line: token.line,
      );
    }
    if (steps % 500 == 0) await Future<void>.delayed(Duration.zero);
  }

  void write(String text) => onOutput(text);

  Future<double> invoke(_Token name, num argument) async {
    final function = _functions[name.lexeme];
    if (function == null) {
      throw CbrException('Função "${name.lexeme}" não foi declarada.', line: name.line);
    }
    if (_callDepth >= 64) {
      throw CbrException('Profundidade máxima de chamadas de função excedida.', line: name.line);
    }
    _callDepth++;
    try {
      final environment = _Environment();
      environment.declare(function.parameter, argument.toDouble(), function.nameToken, type: 'float');
      final signal = await executeStatements(function.body, environment);
      if (signal?.kind != _SignalKind.returnFunction) {
        if (signal != null) {
          throw CbrException('Uma função não pode encerrar ou interromper o programa.', line: name.line);
        }
        throw CbrException('A função "${name.lexeme}" precisa retornar um número.', line: function.token.line);
      }
      return (signal!.value! as num).toDouble();
    } finally {
      _callDepth--;
    }
  }
}

class _Environment {
  final Map<String, Object?> _values = {};
  final Map<String, String> _types = {};

  bool containsLocal(String name) => _values.containsKey(name);

  Object? read(String name, _Token token) {
    if (!_values.containsKey(name)) {
      throw CbrException('Variável "$name" não foi declarada.', line: token.line);
    }
    return _values[name];
  }

  String typeOf(String name, _Token token) {
    if (!_types.containsKey(name)) {
      throw CbrException('Variável "$name" não foi declarada.', line: token.line);
    }
    return _types[name]!;
  }

  void declare(String name, Object? value, _Token token, {String? type}) {
    if (_values.containsKey(name)) {
      throw CbrException('Variável "$name" já foi declarada.', line: token.line);
    }
    final resolvedType = type ?? _inferType(value, token);
    _values[name] = _coerce(value, resolvedType, token);
    _types[name] = resolvedType;
  }

  void assignOrDeclare(String name, Object? value, _Token token) {
    if (!_values.containsKey(name)) {
      declare(name, value, token);
      return;
    }
    final type = _types[name]!;
    _values[name] = _coerce(value, type, token);
  }

  void setExisting(String name, Object? value, _Token token) {
    if (!_values.containsKey(name)) {
      throw CbrException('Variável "$name" não foi declarada.', line: token.line);
    }
    _values[name] = _coerce(value, _types[name]!, token);
  }

  void removeLocal(String name) {
    _values.remove(name);
    _types.remove(name);
  }
}

String _inferType(Object? value, _Token token) {
  if (value is int) return 'int';
  if (value is num) return 'float';
  if (value is String) return 'str';
  if (value is bool) return 'bool';
  if (value is List<Object?>) return 'array';
  throw CbrException('Tipo de valor não suportado.', line: token.line);
}

Object? _coerce(Object? value, String expected, _Token token) {
  switch (expected) {
    case 'int':
      if (value is int) return value;
      if (value is double && value.isFinite && value == value.roundToDouble()) return value.toInt();
      break;
    case 'float':
      if (value is num) return value.toDouble();
      break;
    case 'str':
      if (value is String) return value;
      break;
    case 'bool':
      if (value is bool) return value;
      break;
    case 'array':
      if (value is List) return value;
      break;
    case 'dynamic':
      return value;
  }
  throw CbrException('Tipo incompatível: esperado $expected.', line: token.line);
}

Object _numericResult(num result, num left, num right) {
  if (left is int && right is int && result.isFinite && result == result.roundToDouble()) {
    return result.toInt();
  }
  return result.toDouble();
}

bool _equals(Object? left, Object? right) {
  if (left is num && right is num) return left == right;
  return left == right;
}

int _compare(Object? left, Object? right, _Token token) {
  if (left is num && right is num) return left.compareTo(right);
  if (left is String && right is String) return left.compareTo(right);
  throw CbrException('Comparações exigem dois números ou dois textos.', line: token.line);
}

String _stringify(Object? value) {
  if (value is bool) return value ? 'true' : 'false';
  if (value is double) {
    if (!value.isFinite) return value.toString();
    if (value == value.roundToDouble()) return value.toInt().toString();
  }
  if (value is List) return '[${value.map(_stringify).join(', ')}]';
  return value?.toString() ?? 'nulo';
}

String _interpolate(String template, _Environment environment, _Token token) {
  final markerPattern = RegExp(r'\{(str|int|float|bool)\.([A-Za-z_][A-Za-z0-9_]*)(?:\[(-?\d+)\])?\}');
  final output = StringBuffer();
  var offset = 0;
  for (final match in markerPattern.allMatches(template)) {
    final unmatched = template.substring(offset, match.start);
    if (unmatched.contains('{') || unmatched.contains('}')) {
      throw CbrException('Marcador de interpolação inválido; use {tipo.variavel}.', line: token.line);
    }
    output.write(unmatched);
    final type = match.group(1)!;
    final name = match.group(2)!;
    var value = environment.read(name, token);
    final indexText = match.group(3);
    if (indexText != null) {
      if (value is! List) throw CbrException('Acesso por índice exige um array.', line: token.line);
      final index = int.parse(indexText);
      if (index < 0 || index >= value.length) {
        throw CbrException('Índice de array fora dos limites.', line: token.line);
      }
      value = value[index];
    }
    final bool valid;
    switch (type) {
      case 'str':
        valid = value is String;
        break;
      case 'int':
        valid = value is int;
        break;
      case 'float':
        valid = value is num;
        break;
      case 'bool':
        valid = value is bool;
        break;
      default:
        valid = false;
    }
    if (!valid) {
      throw CbrException('O marcador {$type.$name} não corresponde ao tipo do valor.', line: token.line);
    }
    output.write(_stringify(value));
    offset = match.end;
  }
  final tail = template.substring(offset);
  if (tail.contains('{') || tail.contains('}')) {
    throw CbrException('Marcador de interpolação inválido; use {tipo.variavel}.', line: token.line);
  }
  output.write(tail);
  return output.toString();
}

Never _typeError(_Token token, String message) => throw CbrException(message, line: token.line);
