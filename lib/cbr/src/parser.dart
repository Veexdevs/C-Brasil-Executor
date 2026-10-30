import 'ast.dart';
import 'lexer.dart';
import 'token.dart';

typedef ParsedBlock = ({List<Stmt> body, bool braced});

/// Constrói a árvore sintática a partir dos tokens.
///
/// O parser entende os dois dialetos da Cbr ao mesmo tempo, porque o lexer já
/// converte as palavras-chave em tokens canônicos. Assim, os dois programas
/// abaixo são equivalentes:
///
/// ```text
/// inicio                          function dobro(x) {
///   inteiro idade = 18              return x * 2
///   se (idade >= 18) então         }
///     escreva("maior")             valor = dobro(21)
///   fimse                          printf("{float.valor}\n")
/// fim                              end(0)
/// ```
class CbrParser {
  CbrParser(this._tokens);

  final List<Token> _tokens;
  final Map<String, FunctionDecl> _functions = {};
  int _current = 0;
  int _loopDepth = 0;
  int _switchDepth = 0;

  Program parse() {
    _skipSeparators();
    if (_check(TokenType.kwBegin)) _advance();
    final statements =
        _statements(const {TokenType.kwEndProgram, TokenType.eof});
    if (_check(TokenType.kwEndProgram)) _advance();
    _skipSeparators();
    if (!_isAtEnd) {
      final token = _peek;
      throw _error(
        token,
        'Instrução inesperada depois do fim do programa ("${token.lexeme}").',
        hint: 'Remova o trecho ou coloque-o antes de "fim".',
      );
    }
    return Program(List.unmodifiable(statements), Map.unmodifiable(_functions));
  }

  // ---------------------------------------------------------------- helpers

  Token get _peek => _tokens[_current];

  Token get _peekNext =>
      _current + 1 >= _tokens.length ? _tokens.last : _tokens[_current + 1];

  Token get _previous => _tokens[_current - 1];

  bool get _isAtEnd => _peek.type == TokenType.eof;

  Token _advance() {
    if (!_isAtEnd) _current++;
    return _previous;
  }

  bool _check(TokenType type) => _peek.type == type;

  bool _match(TokenType type) {
    if (!_check(type)) return false;
    _advance();
    return true;
  }

  Token _expect(TokenType type, String message, {String? hint}) {
    if (_check(type)) return _advance();
    throw _error(_peek, message, hint: hint);
  }

  CbrError _error(Token token, String message, {String? hint}) {
    return CbrError(
      message,
      line: token.line,
      column: token.column,
      length: token.lexeme.isEmpty ? 1 : token.lexeme.length,
      hint: hint,
      category: CbrErrorCategory.sintatico,
    );
  }

  void _skipSeparators() {
    while (_check(TokenType.semicolon)) {
      _advance();
    }
  }

  CbrType? _typeKeyword() {
    switch (_peek.type) {
      case TokenType.kwTypeInt:
        _advance();
        return CbrType.inteiro;
      case TokenType.kwTypeFloat:
        _advance();
        return CbrType.decimal;
      case TokenType.kwTypeText:
        _advance();
        return CbrType.texto;
      case TokenType.kwTypeBool:
        _advance();
        return CbrType.booleano;
      default:
        return null;
    }
  }

  // ------------------------------------------------------------- statements

  List<Stmt> _statements(Set<TokenType> terminators) {
    final statements = <Stmt>[];
    _skipSeparators();
    while (!_isAtEnd && !terminators.contains(_peek.type)) {
      statements.add(_statement());
      _skipSeparators();
    }
    return statements;
  }

  /// Bloco com chaves (`{ ... }`) ou com terminador textual (`fimse`,
  /// `fimpara`, ...). `faca` e `entao` são aceitos como abertura.
  ParsedBlock _block({
    required TokenType endKeyword,
    required String instruction,
    TokenType? optionalIntro,
    bool consumeEnd = true,
  }) {
    final hasIntro = _match(TokenType.kwDo) ||
        _match(TokenType.kwThen) ||
        (optionalIntro != null && _match(optionalIntro));

    if (!hasIntro && _match(TokenType.lbrace)) {
      final body = _statements(const {TokenType.rbrace});
      _expect(
        TokenType.rbrace,
        'Faltou "}" para fechar o bloco de $instruction.',
        hint: 'Todo "{" precisa do "}" correspondente.',
      );
      return (body: body, braced: true);
    }
    // Estilo em português: o bloco começa direto depois do cabeçalho e
    // termina em "fimse", "fimpara", "fimfuncao"...
    final body = _statements({endKeyword, TokenType.kwElse});
    if (consumeEnd) {
      _expect(
        endKeyword,
        'Faltou "${_keywordLabel(endKeyword)}" para fechar o bloco de '
        '$instruction.',
        hint: 'Cada bloco aberto precisa ser fechado.',
      );
    }
    return (body: body, braced: false);
  }

  String _keywordLabel(TokenType type) {
    switch (type) {
      case TokenType.kwEndIf:
        return 'fimse';
      case TokenType.kwEndWhile:
        return 'fimenquanto';
      case TokenType.kwEndFor:
        return 'fimpara';
      case TokenType.kwEndFunction:
        return 'fimfuncao';
      case TokenType.kwEndProgram:
        return 'fim';
      case TokenType.rbrace:
        return '}';
      default:
        return type.name;
    }
  }

  Stmt _statement() {
    final token = _peek;
    switch (token.type) {
      case TokenType.semicolon:
        _advance();
        return EmptyStmt(token.line, token.column);
      case TokenType.kwTypeInt:
      case TokenType.kwTypeFloat:
      case TokenType.kwTypeText:
      case TokenType.kwTypeBool:
        // No dialeto original "texto" e "inteiro" podem ser nomes de
        // variáveis (`texto = "banana"`). Só tratamos como declaração quando
        // vem um identificador logo depois.
        if (_peekNext.type != TokenType.identifier) {
          return _expressionOrAssignment();
        }
        return _variableDeclaration();
      case TokenType.kwIf:
        return _ifStatement();
      case TokenType.kwWhile:
        return _whileStatement();
      case TokenType.kwFor:
        return _forStatement();
      case TokenType.kwSwitch:
        return _switchStatement();
      case TokenType.kwBreak:
        _advance();
        if (_loopDepth == 0 && _switchDepth == 0) {
          throw _error(
            token,
            '"break" só pode ser usado dentro de um laço ou de um "switch".',
          );
        }
        return BreakStmt(token.line, token.column);
      case TokenType.kwContinue:
        _advance();
        if (_loopDepth == 0) {
          throw _error(
            token,
            '"continue" só pode ser usado dentro de um laço.',
          );
        }
        return ContinueStmt(token.line, token.column);
      case TokenType.kwReturn:
        return _returnStatement();
      case TokenType.kwEnd:
        return _exitStatement();
      case TokenType.kwFunction:
        return _functionDeclaration();
      case TokenType.kwBegin:
        _advance();
        final body = _statements(const {TokenType.kwEndProgram});
        _match(TokenType.kwEndProgram);
        return IfStmt(
          const BoolLiteral(true, 1, 1),
          body,
          null,
          token.line,
          token.column,
        );
      case TokenType.identifier:
        if (_isReadBuiltin(token.lexeme) && _peekNext.type == TokenType.lparen) {
          return _readStatement();
        }
        return _expressionOrAssignment();
      default:
        return _expressionOrAssignment();
    }
  }

  Stmt _variableDeclaration() {
    final typeToken = _advance();
    final type = _typeFromToken(typeToken.type);
    final declarations = <VarDeclStmt>[];
    do {
      final name = _expect(
        TokenType.identifier,
        'Esperado o nome da variável depois de "${typeToken.lexeme}".',
      );
      Expr? initializer;
      if (_match(TokenType.assign)) {
        initializer = _expression();
      }
      declarations.add(
        VarDeclStmt(name.lexeme, type, initializer, name.line, name.column),
      );
    } while (_match(TokenType.comma));

    if (declarations.length == 1) return declarations.first;
    return IfStmt(
      const BoolLiteral(true, 1, 1),
      declarations,
      null,
      typeToken.line,
      typeToken.column,
    );
  }

  CbrType _typeFromToken(TokenType type) {
    switch (type) {
      case TokenType.kwTypeFloat:
        return CbrType.decimal;
      case TokenType.kwTypeText:
        return CbrType.texto;
      case TokenType.kwTypeBool:
        return CbrType.booleano;
      default:
        return CbrType.inteiro;
    }
  }

  Stmt _ifStatement({bool consumeEnd = true}) {
    final keyword = _advance();
    _match(TokenType.lparen);
    final condition = _expression();
    _match(TokenType.rparen);

    // Os dois blocos compartilham o mesmo "fimse" quando o estilo é textual.
    final thenBlock = _block(
      endKeyword: TokenType.kwEndIf,
      instruction: '"se"',
      optionalIntro: TokenType.kwThen,
      consumeEnd: false,
    );

    List<Stmt>? elseBranch;
    var elseBraced = true;
    if (_match(TokenType.kwElse)) {
      if (_check(TokenType.kwIf)) {
        // "senao se" compartilha o mesmo "fimse" da cadeia.
        elseBranch = [_ifStatement(consumeEnd: false)];
        elseBraced = false;
      } else {
        final elseBlock = _block(
          endKeyword: TokenType.kwEndIf,
          instruction: '"senao"',
          consumeEnd: false,
        );
        elseBranch = elseBlock.body;
        elseBraced = elseBlock.braced;
      }
    }

    final needsEnd = !thenBlock.braced || (elseBranch != null && !elseBraced);
    if (needsEnd && consumeEnd) {
      _expect(
        TokenType.kwEndIf,
        'Faltou "fimse" para fechar o bloco "se".',
        hint: 'Todo "se" aberto termina com "fimse".',
      );
    }
    return IfStmt(
      condition,
      thenBlock.body,
      elseBranch,
      keyword.line,
      keyword.column,
    );
  }

  Stmt _whileStatement() {
    final keyword = _advance();
    _match(TokenType.lparen);
    final condition = _expression();
    _match(TokenType.rparen);
    _loopDepth++;
    final body = _block(
      endKeyword: TokenType.kwEndWhile,
      instruction: '"enquanto"',
      optionalIntro: TokenType.kwDo,
    );
    _loopDepth--;
    return WhileStmt(condition, body.body, keyword.line, keyword.column);
  }

  Stmt _forStatement() {
    final keyword = _advance();

    // for x in range(...) / para x em range(...)
    if (_check(TokenType.identifier) && _peekNext.type == TokenType.kwIn) {
      final name = _advance();
      _advance();
      _expect(
        TokenType.kwRange,
        'Use "range(...)" depois de "em".',
        hint: 'Exemplo: para i em range(1, 5) faça',
      );
      _expect(TokenType.lparen, 'Esperado "(" depois de range.');
      final first = _expression();
      Expr? second;
      Expr? step;
      if (_match(TokenType.comma)) {
        second = _expression();
        if (_match(TokenType.comma)) step = _expression();
      }
      _expect(TokenType.rparen, 'Faltou ")" em range(...).');
      _loopDepth++;
      final body = _block(
        endKeyword: TokenType.kwEndFor,
        instruction: '"para"',
        optionalIntro: TokenType.kwDo,
      );
      _loopDepth--;
      final start = second == null ? const IntLiteral(0, 1, 1) : first;
      final end = second ?? first;
      return ForRangeStmt(
        name.lexeme,
        start,
        end,
        step,
        body.body,
        keyword.line,
        keyword.column,
      );
    }

    // para i de 1 ate 5 [passo 2] faca
    if (_check(TokenType.identifier) && _peekNext.type == TokenType.kwOf) {
      final name = _advance();
      _advance();
      final start = _expression();
      _expect(
        TokenType.kwTo,
        'Use "ate" para indicar o fim do intervalo.',
        hint: 'Exemplo: para i de 1 ate 5 faca',
      );
      final end = _expression();
      Expr? step;
      if (_match(TokenType.kwStep)) step = _expression();
      _loopDepth++;
      final body = _block(
        endKeyword: TokenType.kwEndFor,
        instruction: '"para"',
        optionalIntro: TokenType.kwDo,
      );
      _loopDepth--;
      return ForRangeStmt(
        name.lexeme,
        start,
        end,
        step,
        body.body,
        keyword.line,
        keyword.column,
        inclusive: true,
      );
    }

    if (!_match(TokenType.lparen)) {
      throw _error(
        _peek,
        'Formato de "para" não reconhecido.',
        hint: 'Use: para (inteiro i = 1; i <= 10; i = i + 1) faça\n'
            'ou:  para i de 1 ate 10 faca',
      );
    }
    Stmt? initializer;
    if (!_check(TokenType.semicolon)) {
      initializer = _statement();
    }
    _expect(TokenType.semicolon, 'Faltou ";" depois da inicialização do "para".');
    final condition = _expression();
    _expect(TokenType.semicolon, 'Faltou ";" depois da condição do "para".');
    Stmt? update;
    if (!_check(TokenType.rparen)) {
      update = _statement();
    }
    _expect(TokenType.rparen, 'Faltou ")" no "para".');
    _loopDepth++;
    final body = _block(
      endKeyword: TokenType.kwEndFor,
      instruction: '"para"',
      optionalIntro: TokenType.kwDo,
    );
    _loopDepth--;
    return ForClassicStmt(
      initializer,
      condition,
      update,
      body.body,
      keyword.line,
      keyword.column,
    );
  }

  Stmt _switchStatement() {
    final keyword = _advance();
    _match(TokenType.lparen);
    final subject = _expression();
    _match(TokenType.rparen);
    final usesBrace = _match(TokenType.lbrace);
    _switchDepth++;
    _skipSeparators();

    final caseTerminators = {
      TokenType.kwCase,
      TokenType.kwDefault,
      TokenType.rbrace,
      TokenType.kwEndSwitch,
    };
    final cases = <SwitchCase>[];
    while (!_isAtEnd &&
        !(usesBrace ? _check(TokenType.rbrace) : _check(TokenType.kwEndSwitch))) {
      if (_match(TokenType.kwCase)) {
        final label = _expression();
        _expect(TokenType.colon, 'Use ":" depois do valor de "caso".');
        final body = _statements(caseTerminators);
        cases.add(SwitchCase(label, body));
        _skipSeparators();
        continue;
      }
      if (_match(TokenType.kwDefault)) {
        _expect(TokenType.colon, 'Use ":" depois de "padrao".');
        final body = _statements(caseTerminators);
        cases.add(SwitchCase(null, body, isDefault: true));
        _skipSeparators();
        continue;
      }
      if (!usesBrace) break;
      throw _error(
        _peek,
        'Esperado "caso", "padrao" ou "}" dentro do "switch".',
      );
    }
    _switchDepth--;
    if (usesBrace) {
      _expect(TokenType.rbrace, 'Faltou "}" para fechar o "switch".');
    } else {
      _match(TokenType.kwEndSwitch);
    }
    return SwitchStmt(
      subject,
      cases,
      keyword.line,
      keyword.column,
      fallthrough: keyword.lexeme.toLowerCase() == 'switch',
    );
  }

  Stmt _returnStatement() {
    final keyword = _advance();
    if (_check(TokenType.semicolon) ||
        _check(TokenType.kwEndFunction) ||
        _check(TokenType.kwEndProgram) ||
        _check(TokenType.rbrace) ||
        _isAtEnd) {
      return ReturnStmt(null, keyword.line, keyword.column);
    }
    final value = _expression();
    return ReturnStmt(value, keyword.line, keyword.column);
  }

  Stmt _exitStatement() {
    final keyword = _advance();
    if (!_match(TokenType.lparen)) {
      return ExitStmt(const IntLiteral(0, 1, 1), keyword.line, keyword.column);
    }
    Expr code = const IntLiteral(0, 1, 1);
    if (!_check(TokenType.rparen)) code = _expression();
    _expect(TokenType.rparen, 'Faltou ")" em "end(...)".');
    return ExitStmt(code, keyword.line, keyword.column);
  }

  Stmt _functionDeclaration() {
    final keyword = _advance();
    final name = _expect(
      TokenType.identifier,
      'Esperado o nome da função depois de "funcao".',
    );
    _expect(TokenType.lparen, 'Esperado "(" depois do nome da função.');
    final parameters = <String>[];
    if (!_check(TokenType.rparen)) {
      do {
        _typeKeyword();
        final parameter = _expect(
          TokenType.identifier,
          'Esperado o nome do parâmetro.',
        );
        parameters.add(parameter.lexeme);
      } while (_match(TokenType.comma));
    }
    _expect(TokenType.rparen, 'Faltou ")" na lista de parâmetros.');
    final body = _block(
      endKeyword: TokenType.kwEndFunction,
      instruction: '"funcao"',
    );
    if (_functions.containsKey(name.lexeme)) {
      throw _error(
        name,
        'A função "${name.lexeme}" já foi declarada.',
        hint: 'Use outro nome para a função.',
      );
    }
    _functions[name.lexeme] = FunctionDecl(
      name.lexeme,
      List.unmodifiable(parameters),
      body.body,
      keyword.line,
    );
    return EmptyStmt(keyword.line, keyword.column);
  }

  bool _isReadBuiltin(String name) {
    final folded = CbrLexer.fold(name);
    return folded == 'scan' || folded == 'leia' || folded == 'ler';
  }

  Stmt _readStatement() {
    final nameToken = _advance();
    _expect(TokenType.lparen, 'Esperado "(" depois de ${nameToken.lexeme}.');
    Expr? prompt;
    if (_check(TokenType.textLiteral)) {
      final token = _advance();
      prompt = TextLiteral(token.literal! as String, token.line, token.column);
      _match(TokenType.comma);
    }
    String? target;
    if (_match(TokenType.lbrace)) {
      _typeKeyword();
      _match(TokenType.dot);
      final identifier = _expect(
        TokenType.identifier,
        'Esperado o nome da variável dentro das chaves.',
        hint: 'Exemplo: {int.idade}',
      );
      target = identifier.lexeme;
      _expect(TokenType.rbrace, 'Faltou "}" no marcador de leitura.');
    } else if (_check(TokenType.identifier)) {
      target = _advance().lexeme;
    }
    _expect(
      TokenType.rparen,
      'Faltou ")" na leitura.',
      hint: 'Use: leia(idade) ou scan("Idade: " {int.idade})',
    );
    if (target == null) {
      throw CbrError(
        'A leitura precisa saber em qual variável guardar o valor.',
        line: nameToken.line,
        column: nameToken.column,
        hint: 'Use: leia(idade) ou scan("Idade: " {int.idade})',
        category: CbrErrorCategory.sintatico,
      );
    }
    return ReadStmt(prompt, target, nameToken.line, nameToken.column);
  }

  Stmt _expressionOrAssignment() {
    final start = _peek;
    final expression = _expression();
    if (_match(TokenType.assign)) {
      final value = _expression();
      switch (expression) {
        case VariableExpr():
          return AssignStmt(
            NameTarget(expression.name),
            value,
            start.line,
            start.column,
          );
        case IndexExpr():
          return AssignStmt(
            IndexTarget(expression.target, expression.index),
            value,
            start.line,
            start.column,
          );
        default:
          throw _error(
            start,
            'Não é possível atribuir a este trecho de código.',
            hint: 'Atribua a uma variável, por exemplo: idade = 18',
          );
      }
    }
    return ExprStmt(expression, start.line, start.column);
  }

  // ------------------------------------------------------------ expressions

  Expr _expression() => _or();

  Expr _or() {
    var expression = _and();
    while (_check(TokenType.kwOr)) {
      final operator = _advance();
      final right = _and();
      expression = BinaryExpr(
        expression,
        operator.type,
        right,
        operator.line,
        operator.column,
      );
    }
    return expression;
  }

  Expr _and() {
    var expression = _equality();
    while (_check(TokenType.kwAnd)) {
      final operator = _advance();
      final right = _equality();
      expression = BinaryExpr(
        expression,
        operator.type,
        right,
        operator.line,
        operator.column,
      );
    }
    return expression;
  }

  Expr _equality() {
    var expression = _comparison();
    while (_check(TokenType.equal) || _check(TokenType.notEqual)) {
      final operator = _advance();
      final right = _comparison();
      expression = BinaryExpr(
        expression,
        operator.type,
        right,
        operator.line,
        operator.column,
      );
    }
    return expression;
  }

  Expr _comparison() {
    var expression = _sum();
    while (_check(TokenType.less) ||
        _check(TokenType.lessEqual) ||
        _check(TokenType.greater) ||
        _check(TokenType.greaterEqual)) {
      final operator = _advance();
      final right = _sum();
      expression = BinaryExpr(
        expression,
        operator.type,
        right,
        operator.line,
        operator.column,
      );
    }
    return expression;
  }

  Expr _sum() {
    var expression = _product();
    while (_check(TokenType.plus) || _check(TokenType.minus)) {
      final operator = _advance();
      final right = _product();
      expression = BinaryExpr(
        expression,
        operator.type,
        right,
        operator.line,
        operator.column,
      );
    }
    return expression;
  }

  Expr _product() {
    var expression = _power();
    while (_check(TokenType.star) ||
        _check(TokenType.slash) ||
        _check(TokenType.percent)) {
      final operator = _advance();
      final right = _power();
      expression = BinaryExpr(
        expression,
        operator.type,
        right,
        operator.line,
        operator.column,
      );
    }
    return expression;
  }

  Expr _power() {
    final expression = _unary();
    if (_check(TokenType.power)) {
      final operator = _advance();
      _skipSeparators();
      final right = _power();
      return BinaryExpr(
        expression,
        TokenType.power,
        right,
        operator.line,
        operator.column,
      );
    }
    return expression;
  }

  Expr _unary() {
    if (_check(TokenType.minus) ||
        _check(TokenType.plus) ||
        _check(TokenType.kwNot)) {
      final operator = _advance();
      final operand = _unary();
      return UnaryExpr(operator.type, operand, operator.line, operator.column);
    }
    return _postfix();
  }

  Expr _postfix() {
    var expression = _primary();
    while (true) {
      if (_match(TokenType.lbracket)) {
        final index = _expression();
        _expect(TokenType.rbracket, 'Faltou "]" no acesso ao array.');
        expression = IndexExpr(
          expression,
          index,
          expression.line,
          expression.column,
        );
        continue;
      }
      if (expression is VariableExpr && _check(TokenType.lparen)) {
        final name = expression.name;
        _advance();
        final arguments = <Expr>[];
        _skipSeparators();
        if (!_check(TokenType.rparen)) {
          do {
            _skipSeparators();
            arguments.add(_expression());
            _skipSeparators();
          } while (_match(TokenType.comma));
        }
        _skipSeparators();
        _expect(TokenType.rparen, 'Faltou ")" na chamada de $name.');
        expression = CallExpr(
          name,
          arguments,
          expression.line,
          expression.column,
        );
        continue;
      }
      break;
    }
    return expression;
  }

  Expr _primary() {
    final token = _peek;
    switch (token.type) {
      case TokenType.intLiteral:
        _advance();
        return IntLiteral(token.literal! as int, token.line, token.column);
      case TokenType.floatLiteral:
        _advance();
        return FloatLiteral(token.literal! as double, token.line, token.column);
      case TokenType.textLiteral:
        _advance();
        return TextLiteral(token.literal! as String, token.line, token.column);
      case TokenType.kwTrue:
        _advance();
        return BoolLiteral(true, token.line, token.column);
      case TokenType.kwFalse:
        _advance();
        return BoolLiteral(false, token.line, token.column);
      case TokenType.lbracket:
        _advance();
        final items = <Expr>[];
        _skipSeparators();
        if (!_check(TokenType.rbracket)) {
          do {
            _skipSeparators();
            items.add(_expression());
            _skipSeparators();
          } while (_match(TokenType.comma));
        }
        _expect(TokenType.rbracket, 'Faltou "]" no final do array.');
        return ListLiteral(items, token.line, token.column);
      case TokenType.lparen:
        _advance();
        final expression = _expression();
        _expect(TokenType.rparen, 'Faltou ")" para fechar a expressão.');
        return expression;
      case TokenType.identifier:
        _advance();
        return VariableExpr(token.lexeme, token.line, token.column);
      default:
        throw _error(
          token,
          'Esperado um valor, uma variável ou uma expressão, mas veio '
          '"${token.lexeme.isEmpty ? 'fim do arquivo' : token.lexeme}".',
          hint: 'Confira se falta um operador, um parêntese ou um valor.',
        );
    }
  }
}
