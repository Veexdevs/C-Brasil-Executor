/// Tipos de token reconhecidos pela linguagem C Brasil (Cbr).
///
/// A Cbr aceita dois dialetos com o mesmo núcleo: o dialeto original
/// (`vorgweb/C-Brasil`, com palavras em inglês e chaves) e o dialeto
/// didático em português (`inicio`, `se`, `entao`, `fimse`, ...). O lexer
/// traduz os dois para os mesmos tokens, portanto o restante do
/// interpretador não precisa saber qual dialeto foi usado.
enum TokenType {
  identifier,
  intLiteral,
  floatLiteral,
  textLiteral,

  // Palavras-chave do núcleo.
  kwFunction,
  kwReturn,
  kwIf,
  kwElse,
  kwThen,
  kwWhile,
  kwDo,
  kwFor,
  kwIn,
  kwRange,
  kwOf,
  kwTo,
  kwStep,
  kwSwitch,
  kwCase,
  kwDefault,
  kwBreak,
  kwContinue,
  kwEnd,
  kwTrue,
  kwFalse,
  kwAnd,
  kwOr,
  kwNot,
  kwBegin,
  kwEndProgram,
  kwEndIf,
  kwEndSwitch,
  kwEndWhile,
  kwEndFor,
  kwEndFunction,

  // Tipos declarados.
  kwTypeInt,
  kwTypeFloat,
  kwTypeText,
  kwTypeBool,

  // Operadores e pontuação.
  plus,
  minus,
  star,
  slash,
  percent,
  power,
  equal,
  notEqual,
  less,
  lessEqual,
  greater,
  greaterEqual,
  assign,
  lparen,
  rparen,
  lbrace,
  rbrace,
  lbracket,
  rbracket,
  comma,
  semicolon,
  colon,
  dot,
  eof,
}

/// Um token com a posição exata (linha e coluna, base 1) no código fonte.
class Token {
  const Token(this.type, this.lexeme, this.line, this.column,
      {this.literal, this.endLine, this.endColumn});

  final TokenType type;
  final String lexeme;
  final int line;
  final int column;
  final int? endLine;
  final int? endColumn;
  final Object? literal;

  bool get isKeyword {
    final name = type.name;
    return name.startsWith('kw');
  }

  /// Uma posição curta no estilo `linha:coluna` usada em mensagens.
  String get position => '$line:$column';

  @override
  String toString() => '${type.name}("$lexeme") @$position';
}
