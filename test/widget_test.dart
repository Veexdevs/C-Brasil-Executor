import 'package:c_brasil_executor/main.dart';
import 'package:c_brasil_executor/theme/cbr_theme.dart';
import 'package:c_brasil_executor/widgets/cbr_logo.dart';
import 'package:c_brasil_executor/widgets/code_editor.dart';
import 'package:c_brasil_executor/widgets/console_panel.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Future<void> pumpApp(WidgetTester tester) async {
  await tester.binding.setSurfaceSize(const Size(1440, 980));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(const CbrApp());
  await tester.pump(const Duration(milliseconds: 300));
}

void expectWhiteIcons(WidgetTester tester) {
  final icons = tester.widgetList<Icon>(find.byType(Icon));
  expect(icons, isNotEmpty);
  for (final icon in icons) {
    expect(icon.color, Colors.white);
  }
}

void main() {
  testWidgets('abre no editor com a marca e o console', (tester) async {
    await pumpApp(tester);

    expect(find.byType(CbrLogo), findsWidgets);
    expect(find.byType(CbrCodeEditor), findsOneWidget);
    expect(find.byType(ConsolePanel), findsOneWidget);
    expect(find.text('Executar'), findsOneWidget);
    expect(find.text('C Brasil'), findsOneWidget);
    expect(find.text('(cbr)'), findsNothing);
    expect(find.text('CBR'), findsNothing);
    expect(find.text('Concluído'), findsNothing);
    expect(find.text('Tamanho da fonte'), findsNothing);
    expect(find.byTooltip('Preferências'), findsNothing);
    expect(find.textContaining('GitHub'), findsNothing);
    expect(find.textContaining('conectado'), findsNothing);
    expect(CbrColors.background, Colors.black);

    expectWhiteIcons(tester);

    final editor = tester.getRect(find.byType(CbrCodeEditor));
    final console = tester.getRect(find.byType(ConsolePanel));
    expect(editor.height, greaterThan(700));
    expect(console.height, greaterThan(700));
  });

  testWidgets('navega para a documentação', (tester) async {
    await pumpApp(tester);

    await tester.tap(find.text('Documentação').first);
    await tester.pumpAndSettle();

    expect(find.text('Primeiros passos'), findsWidgets);
    expectWhiteIcons(tester);
  });

  testWidgets('abre um exemplo e volta para o editor', (tester) async {
    await pumpApp(tester);

    await tester.tap(find.text('Exemplos').first);
    await tester.pumpAndSettle();
    expect(find.text('Abrir no editor'), findsWidgets);
    expectWhiteIcons(tester);

    await tester.tap(find.text('Abrir no editor').first);
    await tester.pump();
    await tester.pump(const Duration(seconds: 4));
    await tester.pumpAndSettle();

    expect(find.text('Executar'), findsOneWidget);
    expect(find.byType(ConsolePanel), findsOneWidget);
  });
}
