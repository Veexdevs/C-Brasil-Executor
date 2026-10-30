import 'package:flutter/material.dart';

import '../cbr/cbr.dart';

sealed class DocBlock {
  const DocBlock();
}

class DocParagraph extends DocBlock {
  const DocParagraph(this.text);
  final String text;
}

class DocBullets extends DocBlock {
  const DocBullets(this.items);
  final List<String> items;
}

class DocCode extends DocBlock {
  const DocCode(this.code, {this.caption});
  final String code;
  final String? caption;
}

class DocRow {
  const DocRow(this.name, this.description);
  final String name;
  final String description;
}

class DocTable extends DocBlock {
  const DocTable({required this.title, required this.first, required this.second, required this.rows});
  final String title;
  final String first;
  final String second;
  final List<DocRow> rows;
}

class DocSection {
  const DocSection({
    required this.id,
    required this.title,
    required this.icon,
    required this.blocks,
  });

  final String id;
  final String title;
  final IconData icon;
  final List<DocBlock> blocks;
}

const List<DocSection> cbrDocumentation = [
  DocSection(
    id: 'primeiros-passos',
    title: 'Primeiros passos',
    icon: Icons.rocket_launch_outlined,
    blocks: [
      DocParagraph(
        'Um programa Cbr é uma sequência de instruções. No dialeto em português '
        'ele começa com "inicio" e termina com "fim"; no dialeto original são '
        'apenas as instruções, opcionalmente fechadas com end(0).',
      ),
      DocCode(
        '''inicio
    escreva("Olá, C Brasil!")
    inteiro idade = 18
    se (idade >= 18) então
        escreva("maior de idade")
    fimse
fim''',
        caption: 'Dialeto didático',
      ),
      DocCode(
        '''nome = "Freud"
printf("Olá, {str.nome}!\\n")
end(0)''',
        caption: 'Dialeto original do repositório vorgweb/C-Brasil',
      ),
      DocBullets([
        'Comentários: // até o fim da linha e /* ... */ em bloco.',
        'A indentação é livre — ela não muda o comportamento do programa.',
        'Use o ponto final decimal: 1.5, 10.0, 2e3.',
      ]),
    ],
  ),
  DocSection(
    id: 'tipos',
    title: 'Tipos e variáveis',
    icon: Icons.data_object_rounded,
    blocks: [
      DocParagraph(
        'A Cbr é tipada. O tipo de uma variável é definido na primeira atribuição '
        'e não muda depois — isso evita surpresas em programas grandes.',
      ),
      DocTable(
        title: 'Tipos disponíveis',
        first: 'Tipo',
        second: 'Para que serve',
        rows: [
          DocRow('inteiro / int', 'Números inteiros: -3, 0, 42'),
          DocRow('real / decimal / float', 'Números com casas decimais: 1.75, 3.0'),
          DocRow('texto / str', 'Textos entre aspas duplas: "Brasil"'),
          DocRow('logico / booleano / bool', 'true ou false (também verdadeiro/falso)'),
          DocRow('array', 'Lista heterogênea: [1, "dois", true, 3.5]'),
        ],
      ),
      DocCode(
        '''inteiro idade = 18
real altura = 1.75
texto nome = "Ana"
logico aprovado = true

idade = 19         // ok: mesmo tipo
// idade = "19"    // erro: tipo incompatível''',
      ),
      DocBullets([
        'No dialeto original a declaração é implícita: nome = "Freud" já cria a variável.',
        'Declarar sem valor usa o padrão do tipo (0, 0.0, "", false).',
        'inteiro recebendo real é erro de tipo; real aceita inteiro (conversão automática).',
      ]),
    ],
  ),
  DocSection(
    id: 'operadores',
    title: 'Operadores',
    icon: Icons.calculate_outlined,
    blocks: [
      DocTable(
        title: 'Aritméticos',
        first: 'Operador',
        second: 'Exemplo',
        rows: [
          DocRow('+  -  *  /', '10 + 2 → 12; 7 / 2 → 3 (divisão inteira)'),
          DocRow('%', '10 % 3 → 1 (apenas inteiros)'),
          DocRow('**', '2 ** 3 → 8; 2 ** 0.5 → 1.41421'),
          DocRow('( )', '(idade + 5) * 2'),
        ],
      ),
      DocTable(
        title: 'Comparação e lógica',
        first: 'Operador',
        second: 'Resultado',
        rows: [
          DocRow('==  !=', 'igualdade e diferença'),
          DocRow('<  <=  >  >=', 'ordenação'),
          DocRow('&&  e  ||  ou', 'lógica com curto-circuito'),
          DocRow('!  nao', 'negação'),
        ],
      ),
      DocParagraph(
        'A precedência segue a matemática: parênteses, potência, multiplicação e '
        'divisão, soma e subtração, comparações e, por último, && e ||. '
        'Condições precisam ser booleanas: use uma comparação em vez de "if (idade)".',
      ),
      DocCode(
        '''inteiro nota = 8
logico aprovado = nota >= 6 && nota <= 10
se (aprovado) então
    escreva("aprovado")
fimse''',
      ),
    ],
  ),
  DocSection(
    id: 'condicoes',
    title: 'Condições',
    icon: Icons.alt_route_rounded,
    blocks: [
      DocCode(
        '''se (idade >= 18) então
    escreva("adulto")
senao se (idade >= 12) então
    escreva("adolescente")
senao
    escreva("criança")
fimse''',
        caption: 'se / senao se / senao / fimse',
      ),
      DocCode(
        '''if (idade >= 18) {
    printf("adulto\\n")
} else {
    printf("menor\\n")
}

escolha (opcao)
    caso 1:
        escreva("Novo arquivo")
    caso 2:
        escreva("Abrir")
    padrao:
        escreva("Outra opção")
fimescolha''',
        caption: 'Estilo original com chaves e escolha/switch',
      ),
      DocBullets([
        'switch/escolha aceita inteiro, texto ou booleano.',
        'Use break para encerrar um caso; sem break o fluxo continua no caso seguinte.',
      ]),
    ],
  ),
  DocSection(
    id: 'repeticoes',
    title: 'Repetições',
    icon: Icons.loop_rounded,
    blocks: [
      DocCode(
        '''enquanto (contador < 5) faca
    escreva(contador)
    contador = contador + 1
fimenquanto''',
        caption: 'enquanto (while)',
      ),
      DocCode(
        '''para (inteiro i = 1; i <= 5; i = i + 1) faça
    escreva("Contagem: ", i)
fimpara''',
        caption: 'Para clássico',
      ),
      DocCode(
        '''para i de 1 ate 5 faca
    escreva(i)
fimpara

para j em range(0, 10, 2) faca
    escreva(j)      // 0, 2, 4, 6, 8
fimpara''',
        caption: 'Intervalos em português e range(início, fim, passo)',
      ),
      DocBullets([
        'break/pare encerra o laço; continue/prossiga vai para a próxima volta.',
        'O limite de instruções e de tempo interrompe laços infinitos automaticamente.',
      ]),
    ],
  ),
  DocSection(
    id: 'funcoes',
    title: 'Funções',
    icon: Icons.functions_rounded,
    blocks: [
      DocCode(
        '''funcao media(a, b, c)
    retorne (a + b + c) / 3
fimfuncao

inicio
    escreva("Média: ", media(7, 8, 9))
fim''',
      ),
      DocBullets([
        'Como no compilador oficial, funções recebem e devolvem números (decimais).',
        'Funções não enxergam variáveis globais: passe os valores por parâmetro.',
        'O resultado de uma função é decimal — use {float.nome} ao interpolar.',
      ]),
    ],
  ),
  DocSection(
    id: 'arrays',
    title: 'Arrays',
    icon: Icons.list_alt_rounded,
    blocks: [
      DocCode(
        '''itens = [10, "Cbr", true, 3.14]
adicionar(itens, "novo")
itens[0] = 42
remover(itens, 1)
limpar(itens)
quantidade = tamanho(itens)''',
      ),
      DocBullets([
        'Arrays são heterogêneos: cada posição pode guardar um tipo diferente.',
        'Capacidade máxima de 256 itens, igual ao compilador oficial.',
        'Índice fora do limite gera erro em vez de comportamento indefinido.',
      ]),
    ],
  ),
  DocSection(
    id: 'entrada-saida',
    title: 'Entrada e saída',
    icon: Icons.keyboard_rounded,
    blocks: [
      DocCode(
        '''printf("Nome: {str.nome}; idade: {int.idade}; nota: {float.nota}\\n")
printf("Aprovado: {bool.aprovado}\\n")

scan("Digite a idade: " {int.idade})
leia(idade)                       // abre uma caixa no console
escreva("Você tem ", idade, " anos.")''',
      ),
      DocBullets([
        'Marcadores: {int.variavel}, {float.variavel}, {str.variavel}, {bool.variavel}.',
        'Arrays usam índice: {int.lista[0]} — no dialeto original o índice deve ser literal.',
        'escreva() quebra a linha; imprima() continua na mesma linha.',
        'Quando o programa pede entrada, o executor mostra uma caixa de diálogo no console.',
      ]),
    ],
  ),
  DocSection(
    id: 'biblioteca',
    title: 'Biblioteca padrão',
    icon: Icons.auto_stories_outlined,
    blocks: [
      DocParagraph(
        'As funções abaixo fazem parte da linguagem e funcionam igual nos dois dialetos.',
      ),
    ],
  ),
  DocSection(
    id: 'dialetos',
    title: 'Dois dialetos, uma linguagem',
    icon: Icons.translate_rounded,
    blocks: [
      DocParagraph(
        'O executor entende o dialeto original da Cbr 1.0 (publicado em '
        'github.com/vorgweb/C-Brasil) e o dialeto didático em português. '
        'A tabela mostra os equivalentes:',
      ),
      DocTable(
        title: 'Equivalências',
        first: 'Português',
        second: 'Original',
        rows: [
          DocRow('inicio / fim', 'início e fim do arquivo'),
          DocRow('se / senao / fimse', 'if (...) { } else { }'),
          DocRow('enquanto / faca / fimenquanto', 'while (...) { }'),
          DocRow('para (i = 0; i < 10; i = i + 1) faca', 'for (i = 0; i < 10; i = i + 1) { }'),
          DocRow('para i de 1 ate 10 faca', 'for i in range(1, 10) { }'),
          DocRow('escolha / caso / padrao', 'switch (...) { case ...: default: }'),
          DocRow('funcao ... fimfuncao', 'function ... { }'),
          DocRow('retorne', 'return'),
          DocRow('escreva(...)', 'printf("... {int.x}")'),
          DocRow('leia(variavel)', 'scan("mensagem" {int.variavel})'),
          DocRow('pare / prossiga', 'break / continue'),
        ],
      ),
    ],
  ),
  DocSection(
    id: 'limites',
    title: 'Limites e cuidados',
    icon: Icons.info_outline_rounded,
    blocks: [
      DocBullets([
        'tamanho(texto) conta bytes, como strlen do C: "Olá" tem 4 bytes.',
        'maiusculas() e minusculas() respeitam acentos no executor; no compilador oficial apenas ASCII.',
        'Funções aceitam só números como parâmetro (regra do compilador oficial).',
        'Arrays têm no máximo 256 itens e não podem mudar de nome por reatribuição.',
        'Cada execução tem limite de instruções (4 milhões) e de tempo (20 segundos).',
        'import, try/catch, dicionários e depurador interativo ainda não existem (planejados para a Cbr 1.1).',
      ]),
    ],
  ),
  DocSection(
    id: 'atalhos',
    title: 'Atalhos do editor',
    icon: Icons.keyboard_command_key_rounded,
    blocks: [
      DocTable(
        title: 'Teclado',
        first: 'Atalho',
        second: 'Ação',
        rows: [
          DocRow('Ctrl/Cmd + Enter', 'Executar o programa'),
          DocRow('Ctrl/Cmd + R', 'Executar o programa'),
          DocRow('Ctrl/Cmd + S', 'Salvar o arquivo .cbr'),
          DocRow('Ctrl/Cmd + O', 'Abrir um arquivo .cbr'),
          DocRow('Tab / Shift + Tab', 'Indentar ou remover indentação'),
        ],
      ),
      DocParagraph(
        'O editor numera as linhas, destaca a sintaxe, grifa a linha do erro e '
        'mostra a posição do cursor na barra inferior.',
      ),
    ],
  ),
];

/// Seções completas da biblioteca, geradas a partir dos metadados oficiais.
List<DocTable> builtinTables() {
  final byCategory = <CbrBuiltinCategory, List<CbrBuiltin>>{};
  for (final builtin in cbrBuiltins) {
    byCategory.putIfAbsent(builtin.category, () => []).add(builtin);
  }
  return [
    for (final entry in byCategory.entries)
      DocTable(
        title: entry.key.label,
        first: 'Função',
        second: 'O que faz',
        rows: [
          for (final builtin in entry.value)
            DocRow(builtin.signature, builtin.description),
        ],
      ),
  ];
}
