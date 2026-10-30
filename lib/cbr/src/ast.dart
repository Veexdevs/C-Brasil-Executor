import 'token.dart';

/// Tipo declarado de uma variável na Cbr.
enum CbrType {
  inteiro('inteiro', 'int'),
  decimal('decimal', 'float'),
  texto('texto', 'str'),
  booleano('booleano', 'bool'),
  vetor('vetor', 'array');

  const CbrType(this.label, this.marker);

  /// Nome em português usado nas mensagens de erro.
  final String label;

  /// Marcador usado na interpolação de texto (`{int.nome}`, `{str.nome}`...).
  final String marker;
}

/// Expressões da linguagem.
sealed class Expr {
  const Expr(this.line, this.column);

  final int line;
  final int column;
}

class IntLiteral extends Expr {
  const IntLiteral(this.value, int line, int column) : super(line, column);
  final int value;
}

class FloatLiteral extends Expr {
  const FloatLiteral(this.value, int line, int column) : super(line, column);
  final double value;
}

class TextLiteral extends Expr {
  const TextLiteral(this.value, int line, int column) : super(line, column);
  final String value;
}

class BoolLiteral extends Expr {
  const BoolLiteral(this.value, int line, int column) : super(line, column);
  final bool value;
}

class ListLiteral extends Expr {
  const ListLiteral(this.items, int line, int column) : super(line, column);
  final List<Expr> items;
}

class VariableExpr extends Expr {
  const VariableExpr(this.name, int line, int column) : super(line, column);
  final String name;
}

class IndexExpr extends Expr {
  const IndexExpr(this.target, this.index, int line, int column)
      : super(line, column);
  final Expr target;
  final Expr index;
}

class UnaryExpr extends Expr {
  const UnaryExpr(this.operator, this.operand, int line, int column)
      : super(line, column);
  final TokenType operator;
  final Expr operand;
}

class BinaryExpr extends Expr {
  const BinaryExpr(this.left, this.operator, this.right, int line, int column)
      : super(line, column);
  final Expr left;
  final TokenType operator;
  final Expr right;
}

class CallExpr extends Expr {
  const CallExpr(this.name, this.arguments, int line, int column)
      : super(line, column);
  final String name;
  final List<Expr> arguments;
}

/// Destino de uma atribuição: `nome = ...` ou `lista[i] = ...`.
sealed class AssignTarget {
  const AssignTarget();
}

class NameTarget extends AssignTarget {
  const NameTarget(this.name);
  final String name;
}

class IndexTarget extends AssignTarget {
  const IndexTarget(this.target, this.index);
  final Expr target;
  final Expr index;
}

/// Instruções da linguagem.
sealed class Stmt {
  const Stmt(this.line, this.column);

  final int line;
  final int column;
}

class EmptyStmt extends Stmt {
  const EmptyStmt(int line, int column) : super(line, column);
}

class VarDeclStmt extends Stmt {
  const VarDeclStmt(this.name, this.type, this.initializer, int line, int column)
      : super(line, column);
  final String name;
  final CbrType? type;
  final Expr? initializer;
}

class AssignStmt extends Stmt {
  const AssignStmt(this.target, this.value, int line, int column)
      : super(line, column);
  final AssignTarget target;
  final Expr value;
}

class ExprStmt extends Stmt {
  const ExprStmt(this.expression, int line, int column) : super(line, column);
  final Expr expression;
}

class IfStmt extends Stmt {
  const IfStmt(this.condition, this.thenBranch, this.elseBranch, int line,
      int column)
      : super(line, column);
  final Expr condition;
  final List<Stmt> thenBranch;
  final List<Stmt>? elseBranch;
}

class WhileStmt extends Stmt {
  const WhileStmt(this.condition, this.body, int line, int column)
      : super(line, column);
  final Expr condition;
  final List<Stmt> body;
}

class ForRangeStmt extends Stmt {
  const ForRangeStmt(
    this.variable,
    this.start,
    this.end,
    this.step,
    this.body,
    int line,
    int column,
  ) : super(line, column);
  final String variable;
  final Expr start;
  final Expr end;
  final Expr? step;
  final List<Stmt> body;
}

class ForClassicStmt extends Stmt {
  const ForClassicStmt(
    this.initializer,
    this.condition,
    this.update,
    this.body,
    int line,
    int column,
  ) : super(line, column);
  final Stmt? initializer;
  final Expr condition;
  final Stmt? update;
  final List<Stmt> body;
}

class SwitchCase {
  const SwitchCase(this.label, this.body, {this.isDefault = false});
  final Expr? label;
  final List<Stmt> body;
  final bool isDefault;
}

class SwitchStmt extends Stmt {
  const SwitchStmt(this.subject, this.cases, int line, int column)
      : super(line, column);
  final Expr subject;
  final List<SwitchCase> cases;
}

class BreakStmt extends Stmt {
  const BreakStmt(int line, int column) : super(line, column);
}

class ContinueStmt extends Stmt {
  const ContinueStmt(int line, int column) : super(line, column);
}

class ReturnStmt extends Stmt {
  const ReturnStmt(this.value, int line, int column) : super(line, column);
  final Expr? value;
}

/// `end(0)` encerra o programa com um código de saída.
class ExitStmt extends Stmt {
  const ExitStmt(this.code, int line, int column) : super(line, column);
  final Expr code;
}

/// `scan("mensagem" {int.variavel})` ou `leia(variavel)`.
class ReadStmt extends Stmt {
  const ReadStmt(this.prompt, this.target, int line, int column)
      : super(line, column);
  final Expr? prompt;
  final String target;
}

class FunctionDecl {
  const FunctionDecl(this.name, this.parameters, this.body, this.line);
  final String name;
  final List<String> parameters;
  final List<Stmt> body;
  final int line;
}

class Program {
  const Program(this.statements, this.functions);
  final List<Stmt> statements;
  final Map<String, FunctionDecl> functions;
}
