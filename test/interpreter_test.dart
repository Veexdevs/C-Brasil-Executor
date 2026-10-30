import 'dart:io';

import 'package:c_brasil_executor/cbr/cbr.dart';
import 'package:flutter_test/flutter_test.dart';

class RunOutcome {
  RunOutcome(this.output, this.result);

  final String output;
  final CbrExecutionResult result;
}

Future<RunOutcome> runCbr(
  String source, {
  List<String> inputs = const [],
  int stepLimit = 4000000,
}) async {
  final buffer = StringBuffer();
  var inputIndex = 0;
  final result = await CbrInterpreter(source, stepLimit: stepLimit).run(
    onOutput: buffer.write,
    onInput: (prompt) async {
      if (inputIndex >= inputs.length) return '';
      return inputs[inputIndex++];
    },
  );
  return RunOutcome(buffer.toString(), result);
}

void main() {
  group('Conformidade com o compilador oficial Cbr 1.0', () {
    final programs = <String, List<String>>{
      'biblioteca': [],
      'funcoes_switch': [],
      'programa': ['Freud', '12', '7.5'],
    };

    for (final entry in programs.entries) {
      test('testes do repositório vorgweb/C-Brasil: ${entry.key}', () async {
        final source = File(
          'test/conformance/programs/${entry.key}.cbr',
        ).readAsStringSync();
        final expected = File(
          'test/conformance/expected/${entry.key}.out',
        ).readAsStringSync();
        final outcome = await runCbr(source, inputs: entry.value);
        expect(outcome.output, expected);
        expect(outcome.result.exitCode, 0);
      });
    }

    test('rejeita variável não declarada como o compilador oficial', () async {
      final source = File(
        'test/conformance/programs/erro_variavel.cbr',
      ).readAsStringSync();
      await expectLater(
        CbrInterpreter(source).run(),
        throwsA(
          isA<CbrError>().having(
            (error) => error.message,
            'mensagem',
            contains('não foi declarada'),
          ),
        ),
      );
    });
  });

  group('Núcleo da linguagem', () {
    test('aritmética inteira trunca a divisão e o resto como o C', () async {
      final outcome = await runCbr(r'''
a = 7 / 2
b = -7 / 2
c = 7 % 2
d = -7 % 2
printf("{int.a}|{int.b}|{int.c}|{int.d}\n")
''');
      expect(outcome.output, '3|-3|1|-1\n');
    });

    test('potência inteira continua inteira e decimal vira decimal', () async {
      final outcome = await runCbr(r'''
potencia_inteira = 2 ** 3
potencia_decimal = 2 ** 0.5
printf("{int.potencia_inteira}|{float.potencia_decimal}\n")
''');
      expect(outcome.output, '8|1.41421\n');
    });

    test('promoção de tipos em expressões mistas', () async {
      final outcome = await runCbr(r'''
a = 3 + 0.5
b = 10 / 4.0
printf("{float.a}|{float.b}\n")
''');
      expect(outcome.output, '3.5|2.5\n');
    });

    test('textos interpolados com marcadores tipados', () async {
      final outcome = await runCbr(r'''
nome = "Brasil"
idade = 18
altura = 1.75
maior = true
printf("{str.nome}|{int.idade}|{float.altura}|{bool.maior}\n")
''');
      expect(outcome.output, 'Brasil|18|1.75|true\n');
    });

    test('erro claro ao usar marcador com tipo errado', () async {
      await expectLater(
        CbrInterpreter('idade = 18\nprintf("{float.idade}\\n")\n').run(),
        throwsA(
          isA<CbrError>()
              .having(
                  (error) => error.category, 'categoria', CbrErrorCategory.tipo)
              .having(
                  (error) => error.message, 'mensagem', contains('inteiro')),
        ),
      );
    });

    test('não permite trocar o tipo de uma variável', () async {
      await expectLater(
        CbrInterpreter('idade = 18\nidade = "18"\n').run(),
        throwsA(
          isA<CbrError>().having(
            (error) => error.message,
            'mensagem',
            contains('recebeu um valor texto'),
          ),
        ),
      );
    });

    test('array heterogêneo com adicionar, remover e limpar', () async {
      final outcome = await runCbr(r'''
itens = [1, "dois", true, 4.5]
adicionar(itens, "novo")
remover(itens, 0)
tamanho_atual = tamanho(itens)
printf("{str.itens[0]}|{int.tamanho_atual}|{str.itens[3]}\n")
limpar(itens)
vazio = tamanho(itens)
printf("{int.vazio}\n")
''');
      expect(outcome.output, 'dois|4|novo\n0\n');
    });

    test('índice fora do limite gera erro de execução', () async {
      await expectLater(
        CbrInterpreter('lista = [1]\nprintf("{int.lista[3]}\\n")\n').run(),
        throwsA(
          isA<CbrError>().having(
            (error) => error.message,
            'mensagem',
            contains('fora do limite'),
          ),
        ),
      );
    });

    test('switch com break e fallthrough', () async {
      final outcome = await runCbr(r'''
chave = 2
switch (chave) {
case 1:
    printf("um\n")
    break
case 2:
    printf("dois\n")
case 3:
    printf("tres\n")
    break
default:
    printf("outro\n")
}
printf("fim\n")
end(0)
''');
      expect(outcome.output, 'dois\ntres\nfim\n');
    });

    test('laços com break e continue', () async {
      final outcome = await runCbr(r'''
contador = 0
while (contador < 5) {
    contador = contador + 1
    if (contador == 2) {
        continue
    }
    if (contador == 5) {
        break
    }
    printf("{int.contador} ")
}
printf("\n")
''');
      expect(outcome.output, '1 3 4 \n');
    });

    test('funções recebem decimais e devolvem decimal', () async {
      final outcome = await runCbr(r'''
function dobro(x) {
    return x * 2
}
valor = dobro(21)
printf("{float.valor}\n")
end(0)
''');
      expect(outcome.output, '42\n');
    });

    test('função sem retorne gera erro', () async {
      await expectLater(
        CbrInterpreter(
          'function nada(x) {\n    printf("oi\\n")\n}\nnada(1)\n',
        ).run(),
        throwsA(
          isA<CbrError>().having(
            (error) => error.message,
            'mensagem',
            contains('sem "retorne"'),
          ),
        ),
      );
    });

    test('limite de passos interrompe laços infinitos', () async {
      await expectLater(
        CbrInterpreter('x = 1\nwhile (x > 0) {\n    x = x + 1\n}\n',
                stepLimit: 200)
            .run(),
        throwsA(
          isA<CbrError>().having(
            (error) => error.category,
            'categoria',
            CbrErrorCategory.limite,
          ),
        ),
      );
    });

    test('end() define o código de saída', () async {
      final outcome = await runCbr('printf("fim\\n")\nend(3)\n');
      expect(outcome.result.exitCode, 3);
    });
  });

  group('Dialeto didático em português', () {
    test('inicio/fim, se/senao/fimse e escreva', () async {
      final outcome = await runCbr(r'''
inicio
    inteiro idade = 18
    se (idade >= 18) então
        escreva("Você é maior de idade.")
    senao
        escreva("Você é menor de idade.")
    fimse
fim
''');
      expect(outcome.output, 'Você é maior de idade.\n');
    });

    test('senao se compartilha o fimse', () async {
      final outcome = await runCbr(r'''
inicio
    real media = 6.0
    se (media >= 7.0) então
        escreva("aprovado")
    senao se (media >= 5.0) então
        escreva("recuperação")
    senao
        escreva("reprovado")
    fimse
fim
''');
      expect(outcome.output, 'recuperação\n');
    });

    test('para clássico com faça/fimpara', () async {
      final outcome = await runCbr(r'''
inicio
    para (inteiro i = 1; i <= 3; i = i + 1) faça
        escreva("Contagem: ", i)
    fimpara
fim
''');
      expect(outcome.output, 'Contagem: 1\nContagem: 2\nContagem: 3\n');
    });

    test('para de 1 ate 3 e enquanto', () async {
      final outcome = await runCbr(r'''
inicio
    para i de 1 ate 3 faca
        escreva(i)
    fimpara
    inteiro contador = 0
    enquanto (contador < 2) faca
        escreva("volta ", contador)
        contador = contador + 1
    fimenquanto
fim
''');
      expect(outcome.output, '1\n2\n3\nvolta 0\nvolta 1\n');
    });

    test('escolha/caso/padrao com fimescolha', () async {
      final outcome = await runCbr(r'''
inicio
    inteiro opcao = 2
    escolha (opcao)
        caso 1:
            escreva("Novo")
        caso 2:
            escreva("Abrir")
        padrao:
            escreva("Outro")
    fimescolha
fim
''');
      expect(outcome.output, 'Abrir\n');
    });

    test('função em português e retorne', () async {
      final outcome = await runCbr(r'''
funcao somar(a, b)
    retorne a + b
fimfuncao

inicio
    escreva("Total: ", somar(2, 3))
fim
''');
      expect(outcome.output, 'Total: 5\n');
    });

    test('leia() converte a entrada conforme o tipo da variável', () async {
      final outcome = await runCbr(r'''
inicio
    texto nome
    inteiro idade
    leia(nome)
    leia(idade)
    escreva("Olá, ", nome, "! Você tem ", idade, " anos.")
fim
''', inputs: ['Ana', '24']);
      expect(outcome.output, 'Olá, Ana! Você tem 24 anos.\n');
    });

    test('entrada inválida gera mensagem amigável', () async {
      await expectLater(
        runCbr('inteiro idade\nleia(idade)\n', inputs: ['abc']),
        throwsA(
          isA<CbrError>().having(
            (error) => error.message,
            'mensagem',
            contains('Entrada inválida para inteiro'),
          ),
        ),
      );
    });

    test('retorne 0 no fim do programa encerra com sucesso', () async {
      final outcome =
          await runCbr('inicio\nescreva("ok")\nretorne 0\nfim\n');
      expect(outcome.output, 'ok\n');
      expect(outcome.result.exitCode, 0);
    });
  });

  group('Formatação de números', () {
    test('imita %g do C com seis dígitos significativos', () {
      expect(formatGeneral(8.0), '8');
      expect(formatGeneral(1.39), '1.39');
      expect(formatGeneral(2.718281828), '2.71828');
      expect(formatGeneral(0.0001), '0.0001');
      expect(formatGeneral(0.00001), '1e-05');
      expect(formatGeneral(1234567.0), '1.23457e+06');
      expect(formatGeneral(-0.5), '-0.5');
      expect(formatGeneral(100.0), '100');
    });
  });

  group('Erros de sintaxe', () {
    test('aponta a linha do problema', () async {
      try {
        await CbrInterpreter('inicio\nescreva("a"\nfim\n').run();
        fail('deveria falhar');
      } on CbrError catch (error) {
        expect(error.line, 3);
        expect(error.category, CbrErrorCategory.sintatico);
      }
    });

    test('condição precisa ser booleana', () async {
      await expectLater(
        CbrInterpreter('x = 1\nif (x) {\nprintf("a")\n}\n').run(),
        throwsA(
          isA<CbrError>().having(
            (error) => error.message,
            'mensagem',
            contains('booleano'),
          ),
        ),
      );
    });
  });
}
