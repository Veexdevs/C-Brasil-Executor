/// Exemplos prontos que aparecem na aba "Exemplos" e no botão "Novo".
class CbrExample {
  const CbrExample({
    required this.id,
    required this.title,
    required this.description,
    required this.filename,
    required this.code,
    this.dialect = CbrDialect.didatico,
    this.usesInput = false,
  });

  final String id;
  final String title;
  final String description;
  final String filename;
  final String code;
  final CbrDialect dialect;
  final bool usesInput;
}

enum CbrDialect {
  didatico('Português'),
  original('Original');

  const CbrDialect(this.label);

  final String label;
}

const String starterCode = '''// C Brasil (Cbr) — escreva, execute e veja o resultado
inicio
    escreva("Olá, C Brasil!")
    escreva("Esta é a sua primeira execução.")

    inteiro idade = 18

    se (idade >= 18) então
        escreva("Você é maior de idade.")
    senao
        escreva("Você é menor de idade.")
    fimse

    para (inteiro i = 1; i <= 5; i = i + 1) faça
        escreva("Contagem: ", i)
    fimpara
fim
''';

const List<CbrExample> cbrExamples = [
  CbrExample(
    id: 'primeiro',
    title: 'Primeiro programa',
    description:
        'O exemplo que abre o editor: texto, condição e laço com contagem.',
    filename: 'primeiro.cbr',
    code: starterCode,
  ),
  CbrExample(
    id: 'entrada',
    title: 'Ler dados do usuário',
    description:
        'O console pede os dados e o programa decide a mensagem final. '
        'Use leia() ou scan().',
    filename: 'idade.cbr',
    usesInput: true,
    code: '''inicio
    texto nome
    inteiro idade

    escreva("Vamos conferir sua idade.")
    leia(nome)
    leia(idade)

    se (idade >= 18) então
        escreva("Olá, ", nome, "! Acesso liberado.")
    senao
        escreva("Olá, ", nome, "! Acesso somente com um responsável.")
    fimse
fim
''',
  ),
  CbrExample(
    id: 'tabuada',
    title: 'Tabuada com laço',
    description: 'Laço "para" clássico montando a tabuada de um número.',
    filename: 'tabuada.cbr',
    code: '''inicio
    inteiro numero = 7
    escreva("Tabuada do ", numero)

    para (inteiro i = 1; i <= 10; i = i + 1) faça
        escreva(numero, " x ", i, " = ", numero * i)
    fimpara
fim
''',
  ),
  CbrExample(
    id: 'aprovacao',
    title: 'Média e aprovação',
    description:
        'Notas, média decimal e condição composta com "e" (&&) e "ou" (||).',
    filename: 'media.cbr',
    code: '''inicio
    real nota1 = 7.5
    real nota2 = 5.0
    real nota3 = 9.0
    real media = (nota1 + nota2 + nota3) / 3.0

    escreva("Média: ", media)

    se (media >= 7.0 e media <= 10.0) então
        escreva("Situação: aprovado")
    senao se (media >= 5.0) então
        escreva("Situação: recuperação")
    senao
        escreva("Situação: reprovado")
    fimse
fim
''',
  ),
  CbrExample(
    id: 'funcoes',
    title: 'Funções e matemática',
    description:
        'Funções do programador, biblioteca matemática e formatação com printf.',
    filename: 'funcoes.cbr',
    code: '''function dobro(valor) {
    return valor * 2
}

function media(a, b, c) {
    return (a + b + c) / 3
}

idade = 12
nota = 7.5
resultado = dobro(idade)
valor_media = media(7, 8, 9)

printf("Idade dobrada: {float.resultado}\\n")
printf("Média: {float.valor_media}\\n")
printf("Raiz de 81: {float.raiz}\\n")
printf("Potência 2^10: {float.potencia}\\n")
printf("Arredondado: {float.arredondado}\\n")
printf("Limite: {float.limitado}\\n")
end(0)
''',
  ),
  CbrExample(
    id: 'vetores',
    title: 'Arrays heterogêneos',
    description:
        'Listas com tipos misturados, adicionar, remover, limpar e tamanho.',
    filename: 'arrays.cbr',
    code: '''itens = [10, "Cbr", true, 3.14, -5]
vazio = []

itens[0] = 42
adicionar(itens, "novo item")
adicionar(itens, 99.5)
remover(itens, 1)

quantidade = tamanho(itens)
adicionar(vazio, "primeiro")
quantidade_vazio = tamanho(vazio)
limpar(vazio)

printf("Primeiro: {int.itens[0]}\\n")
printf("Quantidade: {int.quantidade}\\n")
printf("Array vazio: {int.quantidade_vazio}\\n")
printf("Texto guardado: {str.itens[1]}\\n")
end(0)
''',
  ),
  CbrExample(
    id: 'texto',
    title: 'Biblioteca de texto',
    description:
        'juntar, maiusculas, minusculas, contem, subtexto e substituir.',
    filename: 'texto.cbr',
    code: '''nome = "Brasil"
saudacao = juntar("Olá, ", nome)
completo = juntar(saudacao, "! Bem-vindo à Cbr.")

printf("Texto: {str.completo}\\n")
printf("Maiúsculas: {str.maiusculo}\\n")
printf("Minúsculas: {str.minusculo}\\n")
printf("Trecho: {str.trecho}\\n")
printf("Substituído: {str.trocado}\\n")
printf("Contém \\"Brasil\\": {bool.contem_nome}\\n")

maiusculo = maiusculas(completo)
minusculo = minusculas(completo)
trecho = subtexto(completo, 0, 9)
trocado = substituir(completo, "Cbr", "C Brasil")
contem_nome = contem(completo, "Brasil")
end(0)
''',
  ),
  CbrExample(
    id: 'switch',
    title: 'Escolha com switch',
    description: 'Menu simples usando switch, case, default e break.',
    filename: 'menu.cbr',
    code: '''inicio
    inteiro opcao = 2
    escolha (opcao)
        caso 1:
            escreva("Novo arquivo")
        caso 2:
            escreva("Abrir arquivo")
        padrao:
            escreva("Opção inválida")
    fimescolha
fim
''',
  ),
  CbrExample(
    id: 'upstream',
    title: 'Cbr 1.0 original',
    description:
        'Programa no dialeto original do repositório vorgweb/C-Brasil, com '
        'printf, scan, switch e for com range.',
    filename: 'cbr10.cbr',
    dialect: CbrDialect.original,
    usesInput: true,
    code: '''// Dialeto original da Cbr 1.0 (vorgweb/C-Brasil)
// Pede nome, idade e nota; depois gera um relatório.

nome = "Freud"
idade = 12
nota = 0.0

printf("\\n=== CBR 1.0 ===\\n")
scan("Digite seu nome: " {str.nome})
scan("Digite sua idade: " {int.idade})
scan("Digite sua nota (0 a 10): " {float.nota})

aprovado = nota >= 6 && nota <= 10
soma = idade + 10
divisao = idade / 2
potencia = 2 ** 3

if (aprovado) {
    printf("Situação: aprovado!\\n")
} else {
    printf("Situação: não aprovado.\\n")
}

switch (idade % 2) {
case 0:
    printf("A idade é par.\\n")
    break
default:
    printf("A idade é ímpar.\\n")
}

printf("For range: ")
for i in range(5) {
    printf("{int.i} ")
}
printf("\\n")

printf("\\n=== RELATÓRIO ===\\n")
printf("Nome: {str.nome}\\n")
printf("Idade: {int.idade}; nota: {float.nota}\\n")
printf("Soma: {int.soma}; divisão: {int.divisao}; potência: {int.potencia}\\n")
end(0)
''',
  ),
];

CbrExample? exampleById(String id) {
  for (final example in cbrExamples) {
    if (example.id == id) return example;
  }
  return null;
}
