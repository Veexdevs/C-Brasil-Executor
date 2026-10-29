import 'package:c_brasil_executor/cbr/interpreter.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Interpretador Cbr', () {
    test('executa o exemplo em português com condição e for clássico', () async {
      const source = '''
inicio
escreva("Olá, C Brasil!")
inteiro idade
idade = 18
se (idade >= 18) então
  escreva("maior de idade")
senao
  escreva("menor de idade")
fimse
para (inteiro i = 1; i <= 3; i = i + 1) faça
  escreva("Contagem: ", i)
fimpara
retorne 0
fim
''';
      final output = StringBuffer();
      final result = await CbrInterpreter(source).run(onOutput: output.write);

      expect(result.exitCode, 0);
      expect(output.toString(), 'Olá, C Brasil!\nmaior de idade\nContagem: 1\nContagem: 2\nContagem: 3\n');
    });

    test('executa construções do repositório Cbr 0.6', () async {
      const source = '''
function dobro(x) {
    return x * 2
}

base = 2
expoente = 3
potencia = base ** expoente
resultado = dobro(5)
dados = [12, "Carlos", true, 3.14]
idade = 12
maior = idade >= 10
if (maior) {
    printf("Idade: {int.idade}; dobro: {float.resultado}; potência: {int.potencia}\\n")
} else {
    printf("Idade abaixo do limite\\n")
}
printf("Array: {int.dados[0]}, {str.dados[1]}, {bool.dados[2]}, {float.dados[3]}\\n")
for i in range(3) {
    printf("Contagem: {int.i}\\n")
}
end(0)
''';
      final output = StringBuffer();
      final result = await CbrInterpreter(source).run(onOutput: output.write);

      expect(result.exitCode, 0);
      expect(
        output.toString(),
        'Idade: 12; dobro: 10; potência: 8\nArray: 12, Carlos, true, 3.14\nContagem: 0\nContagem: 1\nContagem: 2\n',
      );
    });

    test('scan solicita entrada e atualiza a variável', () async {
      const source = '''
idade = 0
scan("Idade? ", {int.idade})
printf("valor={int.idade}\\n")
end(0)
''';
      final output = StringBuffer();
      final result = await CbrInterpreter(source).run(
        onOutput: output.write,
        inputProvider: (_) async => '24',
      );

      expect(result.exitCode, 0);
      expect(output.toString(), 'Idade? valor=24\n');
    });

    test('limita loops infinitos e informa a linha', () async {
      const source = '''
while (true) {
}
''';
      await expectLater(
        CbrInterpreter(source, stepLimit: 12).run(),
        throwsA(
          isA<CbrException>()
              .having((error) => error.line, 'linha', 2)
              .having((error) => error.message, 'mensagem', contains('loop infinito')),
        ),
      );
    });
  });
}
