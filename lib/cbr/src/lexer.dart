import 'token.dart';

/// Erro produzido durante a leitura (lexer), a análise (parser) ou a
/// execução do programa.
class CbrError implements Exception {
  const CbrError(
    this.message, {
    this.line = 1,
    this.column = 1,
    this.length = 1,
    this.hint,
    this.category = CbrErrorCategory.erro,
  });

  /// Mensagem em português, pronta para aparecer no console.
  final String message;
  final int line;
  final int column;

  /// Tamanho do trecho destacado no editor.
  final int length;

  /// Dica opcional para ajudar a corrigir o problema.
  final String? hint;

  final CbrErrorCategory category;

  String get formatted {
    final buffer = StringBuffer('Linha $line, coluna $column: $message');
    if (hint != null) buffer.write('\n  Dica: $hint');
    return buffer.toString();
  }

  @override
  String toString() => formatted;
}

enum CbrErrorCategory {
  erro('Erro'),
  lexico('Erro de leitura'),
  sintatico('Erro de sintaxe'),
  tipo('Erro de tipo'),
  execucao('Erro de execução'),
  limite('Limite de execução');

  const CbrErrorCategory(this.label);
  final String label;
}

/// Transforma o código fonte em uma lista de tokens.
///
/// Regras da linguagem reproduzidas aqui:
/// * palavras-chave são insensíveis a maiúsculas/minúsculas e ignoram acentos,
///   então `se`, `SE`, `entao` e `então` funcionam igualmente;
/// * números decimais usam ponto (`1.5`) e aceitam expoente (`1e3`);
/// * textos usam aspas duplas e aceitam `\n`, `\t`, `\r`, `\\`, `\"`;
/// * comentários: `// ...` até o fim da linha e `/* ... */` em bloco.
class CbrLexer {
  CbrLexer(this.source);

  final String source;
  final List<Token> _tokens = [];

  int _start = 0;
  int _current = 0;
  int _line = 1;
  int _column = 1;
  int _tokenLine = 1;
  int _tokenColumn = 1;

  static const Map<String, TokenType> _keywords = {
    // Funções.
    'function': TokenType.kwFunction,
    'funcao': TokenType.kwFunction,
    'funçao': TokenType.kwFunction,
    'define': TokenType.kwFunction,
    // Retorno.
    'return': TokenType.kwReturn,
    'retorne': TokenType.kwReturn,
    'retorna': TokenType.kwReturn,
    'devolva': TokenType.kwReturn,
    // Condicional.
    'if': TokenType.kwIf,
    'se': TokenType.kwIf,
    'else': TokenType.kwElse,
    'senao': TokenType.kwElse,
    'then': TokenType.kwThen,
    'entao': TokenType.kwThen,
    // Repetição.
    'while': TokenType.kwWhile,
    'enquanto': TokenType.kwWhile,
    'do': TokenType.kwDo,
    'faca': TokenType.kwDo,
    'for': TokenType.kwFor,
    'para': TokenType.kwFor,
    'in': TokenType.kwIn,
    'em': TokenType.kwIn,
    'range': TokenType.kwRange,
    'de': TokenType.kwOf,
    'from': TokenType.kwOf,
    'ate': TokenType.kwTo,
    'to': TokenType.kwTo,
    'passo': TokenType.kwStep,
    'step': TokenType.kwStep,
    // Escolha.
    'switch': TokenType.kwSwitch,
    'escolha': TokenType.kwSwitch,
    'case': TokenType.kwCase,
    'caso': TokenType.kwCase,
    'default': TokenType.kwDefault,
    'padrao': TokenType.kwDefault,
    // Desvios.
    'break': TokenType.kwBreak,
    'pare': TokenType.kwBreak,
    'continue': TokenType.kwContinue,
    'prossiga': TokenType.kwContinue,
    'end': TokenType.kwEnd,
    'exit': TokenType.kwEnd,
    'saida': TokenType.kwEnd,
    // Booleanos.
    'true': TokenType.kwTrue,
    'verdadeiro': TokenType.kwTrue,
    'false': TokenType.kwFalse,
    'falso': TokenType.kwFalse,
    // Operadores lógicos em palavra.
    'and': TokenType.kwAnd,
    'e': TokenType.kwAnd,
    'or': TokenType.kwOr,
    'ou': TokenType.kwOr,
    'not': TokenType.kwNot,
    'nao': TokenType.kwNot,
    // Blocos em português.
    'inicio': TokenType.kwBegin,
    'begin': TokenType.kwBegin,
    'programa': TokenType.kwBegin,
    'fim': TokenType.kwEndProgram,
    'fimprog': TokenType.kwEndProgram,
    'fimprograma': TokenType.kwEndProgram,
    'fimse': TokenType.kwEndIf,
    'fimescolha': TokenType.kwEndSwitch,
    'fimenquanto': TokenType.kwEndWhile,
    'fimpara': TokenType.kwEndFor,
    'fimfuncao': TokenType.kwEndFunction,
    // Tipos.
    'inteiro': TokenType.kwTypeInt,
    'int': TokenType.kwTypeInt,
    'integer': TokenType.kwTypeInt,
    'real': TokenType.kwTypeFloat,
    'decimal': TokenType.kwTypeFloat,
    'float': TokenType.kwTypeFloat,
    'double': TokenType.kwTypeFloat,
    'texto': TokenType.kwTypeText,
    'str': TokenType.kwTypeText,
    'string': TokenType.kwTypeText,
    'booleano': TokenType.kwTypeBool,
    'logico': TokenType.kwTypeBool,
    'bool': TokenType.kwTypeBool,
    'boolean': TokenType.kwTypeBool,
  };

  static const Map<String, TokenType> _symbols = {
    '+': TokenType.plus,
    '-': TokenType.minus,
    '*': TokenType.star,
    '/': TokenType.slash,
    '%': TokenType.percent,
    '=': TokenType.assign,
    '(': TokenType.lparen,
    ')': TokenType.rparen,
    '{': TokenType.lbrace,
    '}': TokenType.rbrace,
    '[': TokenType.lbracket,
    ']': TokenType.rbracket,
    ',': TokenType.comma,
    ';': TokenType.semicolon,
    ':': TokenType.colon,
    '.': TokenType.dot,
  };

  static const Map<String, String> _accents = {
    'á': 'a', 'à': 'a', 'â': 'a', 'ã': 'a', 'ä': 'a',
    'é': 'e', 'è': 'e', 'ê': 'e', 'ë': 'e',
    'í': 'i', 'ì': 'i', 'î': 'i', 'ï': 'i',
    'ó': 'o', 'ò': 'o', 'ô': 'o', 'õ': 'o', 'ö': 'o',
    'ú': 'u', 'ù': 'u', 'û': 'u', 'ü': 'u',
    'ç': 'c', 'ñ': 'n',
  };

  /// Remove acentos e normaliza para minúsculas (usado por palavras-chave).
  static String fold(String text) {
    final buffer = StringBuffer();
    for (final rune in text.toLowerCase().runes) {
      final char = String.fromCharCode(rune);
      buffer.write(_accents[char] ?? char);
    }
    return buffer.toString();
  }

  /// Devolve o tipo de palavra-chave de um lexema, ou `null` se não for
  /// palavra reservada. Usado pelo destaque de sintaxe do editor.
  static TokenType? keywordType(String lexeme) => _keywords[fold(lexeme)];

  /// Nomes reservados (palavras-chave), já normalizados.
  static Iterable<String> get keywordNames => _keywords.keys;

  List<Token> tokenize() {
    while (!_isAtEnd) {
      _start = _current;
      _tokenLine = _line;
      _tokenColumn = _column;
      _scanToken();
    }
    _tokens.add(Token(TokenType.eof, '', _line, _column));
    return List.unmodifiable(_tokens);
  }

  bool get _isAtEnd => _current >= source.length;

  String _advance() {
    final char = source[_current];
    _current++;
    if (char == '\n') {
      _line++;
      _column = 1;
    } else {
      _column++;
    }
    return char;
  }

  String _peek([int offset = 0]) {
    final index = _current + offset;
    if (index >= source.length) return '\u0000';
    return source[index];
  }

  bool _match(String expected) {
    if (_isAtEnd || source[_current] != expected) return false;
    _advance();
    return true;
  }

  void _add(TokenType type, {Object? literal}) {
    final lexeme = source.substring(_start, _current);
    _tokens.add(Token(
      type,
      lexeme,
      _tokenLine,
      _tokenColumn,
      literal: literal,
      endLine: _line,
      endColumn: _column,
    ));
  }

  void _scanToken() {
    final char = _advance();
    if (char == ' ' || char == '\t' || char == '\r' || char == '\f') return;
    if (char == '\n') {
      _add(TokenType.semicolon);
      return;
    }
    if (char == '/' && _peek() == '/') {
      while (!_isAtEnd && _peek() != '\n') {
        _advance();
      }
      return;
    }
    if (char == '/' && _peek() == '*') {
      _blockComment();
      return;
    }
    if (char == '"') {
      _text();
      return;
    }
    if (_isDigit(char) || (char == '.' && _isDigit(_peek()))) {
      _number();
      return;
    }
    if (_isIdentifierStart(char)) {
      _identifier();
      return;
    }

    final twoChars = '$char${_peek()}';
    const twoCharTokens = {
      '==': TokenType.equal,
      '!=': TokenType.notEqual,
      '<=': TokenType.lessEqual,
      '>=': TokenType.greaterEqual,
      '&&': TokenType.kwAnd,
      '||': TokenType.kwOr,
      '**': TokenType.power,
    };
    if (twoCharTokens.containsKey(twoChars)) {
      _advance();
      _add(twoCharTokens[twoChars]!);
      return;
    }
    if (char == '!') {
      _add(TokenType.kwNot);
      return;
    }
    if (char == '<') {
      _add(_match('=') ? TokenType.lessEqual : TokenType.less);
      return;
    }
    if (char == '>') {
      _add(_match('=') ? TokenType.greaterEqual : TokenType.greater);
      return;
    }
    if (char == '=') {
      _add(_match('=') ? TokenType.equal : TokenType.assign);
      return;
    }
    final type = _symbols[char];
    if (type != null) {
      _add(type);
      return;
    }

    throw CbrError(
      'Caractere inesperado "$char".',
      line: _tokenLine,
      column: _tokenColumn,
      category: CbrErrorCategory.lexico,
      hint: 'Remova o caractere ou coloque-o entre aspas duplas.',
    );
  }

  void _blockComment() {
    while (!_isAtEnd) {
      if (_peek() == '*' && _peek(1) == '/') {
        _advance();
        _advance();
        return;
      }
      _advance();
    }
    throw CbrError(
      'Comentário de bloco /* aberto e não fechado.',
      line: _tokenLine,
      column: _tokenColumn,
      category: CbrErrorCategory.lexico,
      hint: 'Feche o comentário com */.',
    );
  }

  void _text() {
    final buffer = StringBuffer();
    while (true) {
      if (_isAtEnd) {
        throw CbrError(
          'Texto iniciado com aspas não foi fechado.',
          line: _tokenLine,
          column: _tokenColumn,
          category: CbrErrorCategory.lexico,
          hint: 'Feche o texto com uma aspa dupla.',
        );
      }
      final char = _advance();
      if (char == '"') break;
      if (char == '\n') {
        throw CbrError(
          'Texto não pode ocupar várias linhas.',
          line: _tokenLine,
          column: _tokenColumn,
          category: CbrErrorCategory.lexico,
          hint: 'Use \\n dentro do texto para representar uma quebra de linha.',
        );
      }
      if (char == '\\') {
        if (_isAtEnd) continue;
        final escape = _advance();
        switch (escape) {
          case 'n':
            buffer.write('\n');
          case 't':
            buffer.write('\t');
          case 'r':
            buffer.write('\r');
          case '\\':
            buffer.write('\\');
          case '"':
            buffer.write('"');
          default:
            throw CbrError(
              'Sequência de escape desconhecida "\\$escape".',
              line: _line,
              column: _column - 2,
              category: CbrErrorCategory.lexico,
              hint: 'Use \\n, \\t, \\r, \\\\ ou \\".',
            );
        }
        continue;
      }
      buffer.write(char);
    }
    _add(TokenType.textLiteral, literal: buffer.toString());
  }

  void _number() {
    while (_isDigit(_peek()) || _peek() == '_') {
      _advance();
    }
    var isFloat = false;
    if (_peek() == '.' && _isDigit(_peek(1))) {
      isFloat = true;
      _advance();
      while (_isDigit(_peek()) || _peek() == '_') {
        _advance();
      }
    }
    if (_peek() == 'e' || _peek() == 'E') {
      final next = _peek(1);
      final afterSign = _peek(2);
      if (_isDigit(next) || ((next == '+' || next == '-') && _isDigit(afterSign))) {
        isFloat = true;
        _advance();
        if (_peek() == '+' || _peek() == '-') _advance();
        while (_isDigit(_peek())) {
          _advance();
        }
      }
    }
    final text = source.substring(_start, _current).replaceAll('_', '');
    if (isFloat) {
      _add(TokenType.floatLiteral, literal: double.parse(text));
    } else {
      final value = int.tryParse(text);
      if (value == null) {
        throw CbrError(
          'Número inteiro muito grande: $text.',
          line: _tokenLine,
          column: _tokenColumn,
          category: CbrErrorCategory.lexico,
        );
      }
      _add(TokenType.intLiteral, literal: value);
    }
  }

  void _identifier() {
    while (_isIdentifierPart(_peek())) {
      _advance();
    }
    final lexeme = source.substring(_start, _current);
    final keyword = _keywords[CbrLexer.fold(lexeme)];
    if (keyword != null) {
      _add(keyword);
      return;
    }
    _add(TokenType.identifier, literal: lexeme);
  }

  static bool _isDigit(String char) {
    final code = char.codeUnitAt(0);
    return code >= 48 && code <= 57;
  }

  static bool _isIdentifierStart(String char) {
    if (char == '_') return true;
    final code = char.codeUnitAt(0);
    if ((code >= 65 && code <= 90) || (code >= 97 && code <= 122)) return true;
    // Letras acentuadas também iniciam identificadores ("número", "ação").
    return code > 127;
  }

  static bool _isIdentifierPart(String char) {
    if (_isIdentifierStart(char)) return true;
    return _isDigit(char);
  }
}
