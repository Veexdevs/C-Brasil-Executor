import 'package:c_brasil_executor/cbr/src/values.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('truncateToInt', () {
    test('truncates toward zero', () {
      expect(truncateToInt(5.9), 5);
      expect(truncateToInt(-5.9), -5);
    });

    test('returns zero for non-finite values', () {
      expect(truncateToInt(double.nan), 0);
      expect(truncateToInt(double.infinity), 0);
      expect(truncateToInt(double.negativeInfinity), 0);
    });

    test('clamps to the portable safe-integer range', () {
      const maxSafeInteger = 9007199254740991;
      expect(truncateToInt(1e30), maxSafeInteger);
      expect(truncateToInt(-1e30), -maxSafeInteger);
    });
  });
}
