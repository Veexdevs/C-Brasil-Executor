import 'ast.dart';
import 'lexer.dart';

/// Valores possíveis em um programa Cbr.
sealed class CbrValue {
  const CbrValue();

  CbrType get type;

  /// Representação usada por `escreva`, `juntar` e conversões.
  String get display;
}

class CbrInt extends CbrValue {
  const CbrInt(this.value);
  final int value;

  @override
  CbrType get type => CbrType.inteiro;

  @override
  String get display => value.toString();
}

class CbrFloat extends CbrValue {
  const CbrFloat(this.value);
  final double value;

  @override
  CbrType get type => CbrType.decimal;

  @override
  String get display => formatGeneral(value);
}

class CbrBool extends CbrValue {
  const CbrBool(this.value);
  final bool value;

  @override
  CbrType get type => CbrType.booleano;

  @override
  String get display => value ? 'true' : 'false';
}

class CbrText extends CbrValue {
  const CbrText(this.value);
  final String value;

  @override
  CbrType get type => CbrType.texto;

  @override
  String get display => value;
}

class CbrArray extends CbrValue {
  CbrArray([List<CbrValue>? items]) : items = items ?? <CbrValue>[];

  static const int capacity = 256;

  final List<CbrValue> items;

  @override
  CbrType get type => CbrType.vetor;

  @override
  String get display => '[${items.map((item) => item.display).join(', ')}]';
}

/// Formata um número decimal do mesmo jeito que `printf("%g")` em C.
///
/// Usado em `{float.nome}`, em `escreva` e nas conversões para texto, para que
/// o resultado no executor seja idêntico ao do compilador oficial.
String formatGeneral(double value, {int precision = 6}) {
  if (value.isNaN) return 'nan';
  if (value.isInfinite) return value.isNegative ? '-inf' : 'inf';
  if (value == 0) return '0';
  final exponential = value.toStringAsExponential(precision - 1);
  final eIndex = exponential.indexOf('e');
  final exponent = int.parse(exponential.substring(eIndex + 1));
  if (exponent < -4 || exponent >= precision) {
    final mantissa = _stripTrailingZeros(exponential.substring(0, eIndex));
    return '$mantissa${_formatExponent(exponent)}';
  }
  final decimals = (precision - 1 - exponent).clamp(0, 20);
  return _stripTrailingZeros(value.toStringAsFixed(decimals));
}

String _stripTrailingZeros(String text) {
  if (!text.contains('.')) return text;
  var result = text;
  while (result.contains('.') &&
      (result.endsWith('0') || result.endsWith('.'))) {
    result = result.substring(0, result.length - 1);
  }
  return result.isEmpty ? '0' : result;
}

String _formatExponent(int exponent) {
  final sign = exponent < 0 ? '-' : '+';
  final digits = exponent.abs().toString().padLeft(2, '0');
  return 'e$sign$digits';
}

/// Converte um decimal para inteiro truncando, limitado ao intervalo que pode
/// ser representado exatamente em todas as plataformas (incluindo Web).
int truncateToInt(double value) {
  if (value.isNaN || value.isInfinite) return 0;
  const maxSafeInteger = 9007199254740991;
  if (value >= maxSafeInteger) return maxSafeInteger;
  if (value <= -maxSafeInteger) return -maxSafeInteger;
  return value.truncate();
}

/// Nome do marcador usado em `{int.nome}`, `{float.nome}` etc.
String markerFor(CbrType type) {
  switch (type) {
    case CbrType.inteiro:
      return 'int';
    case CbrType.decimal:
      return 'float';
    case CbrType.booleano:
      return 'bool';
    case CbrType.texto:
      return 'str';
    case CbrType.vetor:
      return 'vetor';
  }
}

CbrType? typeFromMarker(String marker) {
  switch (CbrLexer.fold(marker)) {
    case 'int':
    case 'inteiro':
      return CbrType.inteiro;
    case 'float':
    case 'real':
    case 'decimal':
      return CbrType.decimal;
    case 'bool':
    case 'booleano':
    case 'logico':
      return CbrType.booleano;
    case 'str':
    case 'string':
    case 'texto':
      return CbrType.texto;
    default:
      return null;
  }
}

/// Valor padrão para uma declaração sem inicialização (`inteiro idade`).
CbrValue defaultValue(CbrType type) {
  switch (type) {
    case CbrType.inteiro:
      return const CbrInt(0);
    case CbrType.decimal:
      return const CbrFloat(0);
    case CbrType.texto:
      return const CbrText('');
    case CbrType.booleano:
      return const CbrBool(false);
    case CbrType.vetor:
      return CbrArray();
  }
}

/// Descreve o valor para mensagens de erro.
String describeValue(CbrValue value) {
  switch (value) {
    case CbrInt(:final value):
      return 'inteiro $value';
    case CbrFloat(:final value):
      return 'decimal ${formatGeneral(value)}';
    case CbrBool(:final value):
      return 'booleano ${value ? 'true' : 'false'}';
    case CbrText(:final value):
      return 'texto "${_ellipsis(value)}"';
    case CbrArray(:final items):
      return 'vetor com ${items.length} itens';
  }
}

String _ellipsis(String text, [int limit = 24]) {
  final flat = text.replaceAll('\n', '\\n');
  if (flat.length <= limit) return flat;
  return '${flat.substring(0, limit)}…';
}
