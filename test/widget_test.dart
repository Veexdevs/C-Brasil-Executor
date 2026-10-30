import 'package:c_brasil_executor/main.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('shows the C Brasil editor without GitHub status copy', (tester) async {
    await tester.pumpWidget(const CbrApp());

    expect(find.byType(CbrHome), findsOneWidget);
    expect(find.text('C Brasil'), findsOneWidget);
    expect(find.text('(cbr)'), findsOneWidget);
    expect(find.textContaining('GitHub'), findsNothing);
    expect(find.textContaining('conectado'), findsNothing);
  });
}
