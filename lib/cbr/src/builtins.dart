/// Funções embutidas da linguagem, agrupadas para a documentação e para o
/// destaque de sintaxe do editor.
class CbrBuiltin {
  const CbrBuiltin(this.name, this.signature, this.category, this.description);

  final String name;
  final String signature;
  final CbrBuiltinCategory category;
  final String description;
}

enum CbrBuiltinCategory {
  saida('Saída'),
  entrada('Entrada'),
  texto('Texto'),
  matematica('Matemática'),
  vetor('Arrays'),
  conversao('Conversão');

  const CbrBuiltinCategory(this.label);
  final String label;
}

const List<CbrBuiltin> cbrBuiltins = [
  CbrBuiltin(
    'printf',
    'printf("texto {tipo.variavel}")',
    CbrBuiltinCategory.saida,
    'Escreve texto no console e substitui marcadores como {int.idade} pelo '
        'valor da variável.',
  ),
  CbrBuiltin(
    'escreva',
    'escreva(valor, ...)',
    CbrBuiltinCategory.saida,
    'Escreve os valores em sequência e quebra a linha. Aceita texto, números '
        'e booleanos.',
  ),
  CbrBuiltin(
    'imprima',
    'imprima(valor, ...)',
    CbrBuiltinCategory.saida,
    'Igual a escreva(), mas sem quebrar a linha no final.',
  ),
  CbrBuiltin(
    'leia',
    'leia(variavel)',
    CbrBuiltinCategory.entrada,
    'Lê uma linha do console e guarda na variável, convertendo para o tipo '
        'dela.',
  ),
  CbrBuiltin(
    'scan',
    'scan("mensagem" {int.variavel})',
    CbrBuiltinCategory.entrada,
    'Forma original de entrada da Cbr: mostra a mensagem e lê o valor.',
  ),
  CbrBuiltin(
    'tamanho',
    'tamanho(texto ou array)',
    CbrBuiltinCategory.texto,
    'Quantidade de itens do array ou de bytes do texto.',
  ),
  CbrBuiltin(
    'juntar',
    'juntar(texto, texto)',
    CbrBuiltinCategory.texto,
    'Une dois textos em um novo texto.',
  ),
  CbrBuiltin(
    'maiusculas',
    'maiusculas(texto)',
    CbrBuiltinCategory.texto,
    'Converte o texto para maiúsculas.',
  ),
  CbrBuiltin(
    'minusculas',
    'minusculas(texto)',
    CbrBuiltinCategory.texto,
    'Converte o texto para minúsculas.',
  ),
  CbrBuiltin(
    'contem',
    'contem(texto, trecho)',
    CbrBuiltinCategory.texto,
    'Diz se o trecho aparece dentro do texto.',
  ),
  CbrBuiltin(
    'subtexto',
    'subtexto(texto, inicio, quantidade)',
    CbrBuiltinCategory.texto,
    'Copia parte do texto a partir de uma posição.',
  ),
  CbrBuiltin(
    'substituir',
    'substituir(texto, antigo, novo)',
    CbrBuiltinCategory.texto,
    'Troca todas as ocorrências de um trecho por outro.',
  ),
  CbrBuiltin(
    'adicionar',
    'adicionar(array, valor)',
    CbrBuiltinCategory.vetor,
    'Acrescenta um item no fim do array (limite de 256 itens).',
  ),
  CbrBuiltin(
    'remover',
    'remover(array, indice)',
    CbrBuiltinCategory.vetor,
    'Remove o item na posição indicada e desloca os seguintes.',
  ),
  CbrBuiltin(
    'limpar',
    'limpar(array)',
    CbrBuiltinCategory.vetor,
    'Remove todos os itens do array.',
  ),
  CbrBuiltin(
    'raiz',
    'raiz(numero)',
    CbrBuiltinCategory.matematica,
    'Raiz quadrada.',
  ),
  CbrBuiltin(
    'absoluto',
    'absoluto(numero)',
    CbrBuiltinCategory.matematica,
    'Valor sem sinal (módulo).',
  ),
  CbrBuiltin(
    'arredondar',
    'arredondar(numero)',
    CbrBuiltinCategory.matematica,
    'Arredonda para o inteiro mais próximo.',
  ),
  CbrBuiltin(
    'piso',
    'piso(numero)',
    CbrBuiltinCategory.matematica,
    'Maior inteiro menor ou igual ao número.',
  ),
  CbrBuiltin(
    'teto',
    'teto(numero)',
    CbrBuiltinCategory.matematica,
    'Menor inteiro maior ou igual ao número.',
  ),
  CbrBuiltin(
    'seno',
    'seno(angulo)',
    CbrBuiltinCategory.matematica,
    'Seno em radianos.',
  ),
  CbrBuiltin(
    'cosseno',
    'cosseno(angulo)',
    CbrBuiltinCategory.matematica,
    'Cosseno em radianos.',
  ),
  CbrBuiltin(
    'tangente',
    'tangente(angulo)',
    CbrBuiltinCategory.matematica,
    'Tangente em radianos.',
  ),
  CbrBuiltin(
    'logaritmo',
    'logaritmo(numero)',
    CbrBuiltinCategory.matematica,
    'Logaritmo natural.',
  ),
  CbrBuiltin(
    'log10',
    'log10(numero)',
    CbrBuiltinCategory.matematica,
    'Logaritmo na base 10.',
  ),
  CbrBuiltin(
    'exponencial',
    'exponencial(numero)',
    CbrBuiltinCategory.matematica,
    'Número de Euler elevado à potência indicada.',
  ),
  CbrBuiltin(
    'maximo',
    'maximo(a, b)',
    CbrBuiltinCategory.matematica,
    'Maior entre dois números.',
  ),
  CbrBuiltin(
    'minimo',
    'minimo(a, b)',
    CbrBuiltinCategory.matematica,
    'Menor entre dois números.',
  ),
  CbrBuiltin(
    'potencia',
    'potencia(base, expoente)',
    CbrBuiltinCategory.matematica,
    'Potência com expoente decimal.',
  ),
  CbrBuiltin(
    'limitar',
    'limitar(valor, minimo, maximo)',
    CbrBuiltinCategory.matematica,
    'Prende o valor dentro de um intervalo.',
  ),
  CbrBuiltin(
    'aleatorio',
    'aleatorio(limite)',
    CbrBuiltinCategory.matematica,
    'Inteiro pseudoaleatório entre 0 e o limite (ou entre início e fim).',
  ),
  CbrBuiltin(
    'texto',
    'texto(valor)',
    CbrBuiltinCategory.conversao,
    'Converte qualquer valor para texto.',
  ),
  CbrBuiltin(
    'numero',
    'numero(valor)',
    CbrBuiltinCategory.conversao,
    'Converte texto em número, quando possível.',
  ),
  CbrBuiltin(
    'inteiro',
    'inteiro(valor)',
    CbrBuiltinCategory.conversao,
    'Trunca um decimal ou converte texto em inteiro.',
  ),
  CbrBuiltin(
    'real',
    'real(valor)',
    CbrBuiltinCategory.conversao,
    'Converte inteiro ou texto em decimal.',
  ),
  CbrBuiltin(
    'tipo',
    'tipo(valor)',
    CbrBuiltinCategory.conversao,
    'Devolve o tipo do valor como texto ("inteiro", "decimal"...).',
  ),
];

/// Conjunto normalizado usado pelo interpretador e pelo editor.
final Set<String> cbrBuiltinNames = {
  for (final builtin in cbrBuiltins) builtin.name,
};
