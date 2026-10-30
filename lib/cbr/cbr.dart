/// Linguagem C Brasil (Cbr): léxico, parser, interpretador e destaque de
/// sintaxe, tudo em Dart puro (roda em navegador, celular e desktop).
library;

export 'src/ast.dart' show CbrType, Program, FunctionDecl;
export 'src/builtins.dart'
    show CbrBuiltin, CbrBuiltinCategory, cbrBuiltins, cbrBuiltinNames;
export 'src/highlight.dart'
    show
        CbrHighlightSpan,
        CbrHighlighter,
        CbrTokenStyle,
        highlightSource;
export 'src/lexer.dart' show CbrError, CbrErrorCategory, CbrLexer;
export 'src/runtime.dart'
    show
        CbrCancellationCheck,
        CbrExecutionResult,
        CbrInputProvider,
        CbrInterpreter,
        CbrOutput;
export 'src/values.dart' show formatGeneral;
