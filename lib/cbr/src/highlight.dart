import 'builtins.dart';
import 'lexer.dart';
import 'token.dart';

/// Classes de destaque usadas pelo editor de código.
enum CbrTokenStyle {
  keyword,
  type,
  builtin,
  function,
  text,
  number,
  comment,
  operator,
  punctuation,
  identifier,
  marker,
}

/// Um trecho de uma linha com um estilo de destaque.
class CbrHighlightSpan {
  const CbrHighlightSpan(this.start, this.end, this.style);

  final int start;
  final int end;
  final CbrTokenStyle style;

  @override
  String toString() => '[$start,$end) ${style.name}';
}

/// Destaca uma linha por vez mantendo o estado de comentários de bloco entre
/// as chamadas, o que permite atualizar apenas o que mudou no editor.
class CbrHighlighter {
  bool _inBlockComment = false;

  void reset() => _inBlockComment = false;

  List<CbrHighlightSpan> highlightLine(String line) {
    final spans = <CbrHighlightSpan>[];
    var index = 0;

    while (index < line.length) {
      if (_inBlockComment) {
        final end = line.indexOf('*/', index);
        if (end < 0) {
          spans.add(CbrHighlightSpan(index, line.length, CbrTokenStyle.comment));
          index = line.length;
        } else {
          spans.add(CbrHighlightSpan(index, end + 2, CbrTokenStyle.comment));
          _inBlockComment = false;
          index = end + 2;
        }
        continue;
      }

      final char = line[index];
      if (char == '/' && index + 1 < line.length && line[index + 1] == '/') {
        spans.add(CbrHighlightSpan(index, line.length, CbrTokenStyle.comment));
        break;
      }
      if (char == '/' && index + 1 < line.length && line[index + 1] == '*') {
        _inBlockComment = true;
        continue;
      }
      if (char == '"') {
        index = _text(line, index, spans);
        continue;
      }
      if (_isDigit(char)) {
        final end = _number(line, index);
        spans.add(CbrHighlightSpan(index, end, CbrTokenStyle.number));
        index = end;
        continue;
      }
      if (_isIdentifierStart(char)) {
        final end = _identifier(line, index);
        spans.add(CbrHighlightSpan(index, end, _styleFor(line, index, end)));
        index = end;
        continue;
      }
      if (_isOperator(char)) {
        final end = index + 1 < line.length && _isOperator(line[index + 1])
            ? index + 2
            : index + 1;
        spans.add(CbrHighlightSpan(index, end, CbrTokenStyle.operator));
        index = end;
        continue;
      }
      if ('()[]{},;:'.contains(char)) {
        spans.add(CbrHighlightSpan(index, index + 1, CbrTokenStyle.punctuation));
      }
      index++;
    }
    return spans;
  }

  int _text(String line, int start, List<CbrHighlightSpan> spans) {
    var index = start + 1;
    var closed = false;
    while (index < line.length) {
      if (line[index] == '\\') {
        index += 2;
        continue;
      }
      if (line[index] == '"') {
        closed = true;
        index++;
        break;
      }
      index++;
    }
    final end = index > line.length ? line.length : index;
    spans.add(CbrHighlightSpan(start, end, CbrTokenStyle.text));
    if (closed) {
      _markersInside(line, start, end, spans);
    }
    return end;
  }

  /// Destaca `{int.nome}` dentro de um texto para diferenciar a interpolação
  /// do restante da string.
  void _markersInside(
    String line,
    int start,
    int end,
    List<CbrHighlightSpan> spans,
  ) {
    var index = start;
    while (index < end) {
      final open = line.indexOf('{', index);
      if (open < 0 || open >= end) return;
      final close = line.indexOf('}', open);
      if (close < 0 || close >= end) return;
      spans.add(CbrHighlightSpan(open, close + 1, CbrTokenStyle.marker));
      index = close + 1;
    }
  }

  int _number(String line, int start) {
    var index = start;
    while (index < line.length &&
        (_isDigit(line[index]) || line[index] == '.' || line[index] == '_')) {
      index++;
    }
    if (index < line.length && (line[index] == 'e' || line[index] == 'E')) {
      index++;
      if (index < line.length && (line[index] == '+' || line[index] == '-')) {
        index++;
      }
      while (index < line.length && _isDigit(line[index])) {
        index++;
      }
    }
    return index;
  }

  int _identifier(String line, int start) {
    var index = start;
    while (index < line.length && _isIdentifierPart(line[index])) {
      index++;
    }
    return index;
  }

  CbrTokenStyle _styleFor(String line, int start, int end) {
    final word = line.substring(start, end);
    final keyword = CbrLexer.keywordType(word);
    if (keyword != null) {
      switch (keyword) {
        case TokenType.kwTypeInt:
        case TokenType.kwTypeFloat:
        case TokenType.kwTypeText:
        case TokenType.kwTypeBool:
          return CbrTokenStyle.type;
        case TokenType.kwTrue:
        case TokenType.kwFalse:
          return CbrTokenStyle.number;
        default:
          return CbrTokenStyle.keyword;
      }
    }
    if (cbrBuiltinNames.contains(CbrLexer.fold(word))) {
      return CbrTokenStyle.builtin;
    }
    var index = end;
    while (index < line.length && line[index] == ' ') {
      index++;
    }
    if (index < line.length && line[index] == '(') {
      return CbrTokenStyle.function;
    }
    return CbrTokenStyle.identifier;
  }

  static bool _isDigit(String char) {
    final code = char.codeUnitAt(0);
    return code >= 48 && code <= 57;
  }

  static bool _isIdentifierStart(String char) {
    if (char == '_') return true;
    final code = char.codeUnitAt(0);
    if ((code >= 65 && code <= 90) || (code >= 97 && code <= 122)) return true;
    return code > 127;
  }

  static bool _isIdentifierPart(String char) {
    if (_isIdentifierStart(char)) return true;
    return _isDigit(char);
  }

  static bool _isOperator(String char) => '+-*/%<>=!&|'.contains(char);
}

/// Atalho para destacar um programa inteiro de uma vez (usado nos exemplos e
/// na documentação).
List<List<CbrHighlightSpan>> highlightSource(String source) {
  final highlighter = CbrHighlighter();
  return [
    for (final line in source.split('\n')) highlighter.highlightLine(line),
  ];
}
