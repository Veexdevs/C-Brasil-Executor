import 'package:c_brasil_executor/main.dart';
import 'package:c_brasil_executor/widgets/cbr_logo.dart';
import 'package:c_brasil_executor/widgets/console_panel.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Future<void> pumpApp(WidgetTester tester) async {
  await tester.binding.setSurfaceSize(const Size(1440, 980));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(const CbrApp());
  await tester.pump(const Duration(milliseconds: 300));
}

void main() {
  testWidgets('abre no editor com a marca e o console', (tester) async {
    await pumpApp(tester);

    expect(find.byType(CbrLogo), findsWidgets);
    expect(find.byType(ConsolePanel), findsOneWidget);
    expect(find.text('Executar'), findsOneWidget);
    expect(find.text('C Brasil'), findsOneWidget);
    expect(find.text('(cbr)'), findsOneWidget);
    expect(find.text('CBR'), findsNothing);
    expect(find.textContaining('GitHub'), findsNothing);
    expect(find.textContaining('conectado'), findsNothing);
  });

  testWidgets('navega para a documentação', (tester) async {
    await pumpApp(tester);

    await tester.tap(find.text('Documentação').first);
    await tester.pumpAndSettle();

    expect(find.text('Primeiros passos'), findsWidgets);
  });

  testWidgets('abre um exemplo e volta para o editor', (tester) async {
    await pumpApp(tester);

    await tester.tap(find.text('Exemplos').first);
    await tester.pumpAndSettle();
    expect(find.text('Abrir no editor'), findsWidgets);

    await tester.tap(find.text('Abrir no editor').first);
    await tester.pump();
    await tester.pump(const Duration(seconds: 4));
    await tester.pumpAndSettle();

    expect(find.text('Executar'), findsOneWidget);
    expect(find.byType(ConsolePanel), findsOneWidget);
  });
}
