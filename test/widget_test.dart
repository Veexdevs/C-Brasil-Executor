import 'package:c_brasil_executor/main.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('starts on the C Brasil executor', (tester) async {
    await tester.pumpWidget(const CbrApp(autoCheckUpstream: false));

    expect(find.byType(CbrHome), findsOneWidget);
  });
}
