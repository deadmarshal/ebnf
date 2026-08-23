import gleam/bool
import gleam/dict.{type Dict}
import gleam/list
import gleam/result
import gleam/set.{type Set}
import gleam/string

// ============================================================================
// Scanner:
// ============================================================================
pub type Position {
  Position(row: Int, col: Int)
}

pub type TokenKind {
  Eof
  LParen
  RParen
  LBracket
  RBracket
  LBrace
  RBrace
  Dot
  Bar
  Equal
  STerminal(String)
  SNonTerminal(String)
}

pub type Token {
  Token(TokenKind, Position)
}

fn scan(s: String) -> Result(List(Token), ParseError) {
  s |> string.to_graphemes |> scan_helper(Position(0, 0), [])
}

fn scan_helper(chars: List(String), pos: Position, acc: List(Token)) {
  case chars {
    [] -> Ok(list.reverse([Token(Eof, pos), ..acc]))
    ["\n", ..rest] -> scan_helper(rest, Position(row: pos.row + 1, col: 0), acc)
    [" ", ..rest] | ["\t", ..rest] | ["\r", ..rest] ->
      scan_helper(rest, Position(..pos, col: pos.col + 1), acc)
    ["(", "*", ..rest] ->
      case skip_comment(rest, Position(..pos, col: pos.col + 2), 1) {
        Ok(#(remaining, new_pos)) -> scan_helper(remaining, new_pos, acc)
        Error(e) -> Error(e)
      }
    ["(", ..rest] ->
      scan_helper(rest, Position(..pos, col: pos.col + 1), [
        Token(LParen, pos),
        ..acc
      ])
    [")", ..rest] ->
      scan_helper(rest, Position(..pos, col: pos.col + 1), [
        Token(RParen, pos),
        ..acc
      ])
    ["[", ..rest] ->
      scan_helper(rest, Position(..pos, col: pos.col + 1), [
        Token(LBracket, pos),
        ..acc
      ])
    ["]", ..rest] ->
      scan_helper(rest, Position(..pos, col: pos.col + 1), [
        Token(RBracket, pos),
        ..acc
      ])
    ["{", ..rest] ->
      scan_helper(rest, Position(..pos, col: pos.col + 1), [
        Token(LBrace, pos),
        ..acc
      ])
    ["}", ..rest] ->
      scan_helper(rest, Position(..pos, col: pos.col + 1), [
        Token(RBrace, pos),
        ..acc
      ])
    ["=", ..rest] ->
      scan_helper(rest, Position(..pos, col: pos.col + 1), [
        Token(Equal, pos),
        ..acc
      ])
    ["|", ..rest] ->
      scan_helper(rest, Position(..pos, col: pos.col + 1), [
        Token(Bar, pos),
        ..acc
      ])
    [".", ..rest] ->
      scan_helper(rest, Position(..pos, col: pos.col + 1), [
        Token(Dot, pos),
        ..acc
      ])
    ["'", ..rest] ->
      case scan_terminal(rest, Position(..pos, col: pos.col + 1), "'", "") {
        Ok(#(str, remaining, new_pos)) ->
          scan_helper(remaining, new_pos, [Token(STerminal(str), pos), ..acc])
        Error(e) -> Error(e)
      }
    ["\"", ..rest] ->
      case scan_terminal(rest, Position(..pos, col: pos.col + 1), "\"", "") {
        Ok(#(str, remaining, new_pos)) ->
          scan_helper(remaining, new_pos, [Token(STerminal(str), pos), ..acc])
        Error(e) -> Error(e)
      }
    [c, ..rest] -> {
      case is_ident_char(c) {
        True -> {
          let #(ident, remaining, new_pos) =
            scan_while(
              rest,
              Position(..pos, col: pos.col + 1),
              c,
              is_ident_char,
            )
          scan_helper(remaining, new_pos, [
            Token(SNonTerminal(ident), pos),
            ..acc
          ])
        }
        False -> Error(UnexpectedCharacter(c, pos))
      }
    }
  }
}

fn skip_comment(
  chars: List(String),
  pos: Position,
  depth: Int,
) -> Result(#(List(String), Position), ParseError) {
  case chars {
    [] -> Error(UnterminatedComment(pos))
    ["(", "*", ..rest] ->
      skip_comment(rest, Position(..pos, col: pos.col + 2), depth + 1)
    ["*", ")", ..rest] ->
      case depth - 1 {
        0 -> Ok(#(rest, Position(..pos, col: pos.col + 2)))
        d -> skip_comment(rest, Position(..pos, col: pos.col + 2), d)
      }
    [_, ..rest] -> skip_comment(rest, Position(..pos, col: pos.col + 1), depth)
  }
}

fn scan_terminal(
  chars: List(String),
  pos: Position,
  quote: String,
  acc: String,
) -> Result(#(String, List(String), Position), ParseError) {
  case chars {
    [] -> Error(UnterminatedTerminal(pos))
    [c, ..rest] ->
      case c == quote {
        True ->
          case string.is_empty(acc) {
            True -> Error(EmptyTerminal(pos))
            False -> Ok(#(acc, rest, Position(..pos, col: pos.col + 1)))
          }
        False ->
          scan_terminal(
            rest,
            Position(..pos, col: pos.col + 1),
            quote,
            acc <> c,
          )
      }
  }
}

fn scan_while(
  chars: List(String),
  pos: Position,
  first: String,
  pred: fn(String) -> Bool,
) -> #(String, List(String), Position) {
  scan_while_helper(chars, pos, first, pred)
}

fn scan_while_helper(
  chars: List(String),
  pos: Position,
  acc: String,
  pred: fn(String) -> Bool,
) -> #(String, List(String), Position) {
  case chars {
    [c, ..rest] ->
      case pred(c) {
        True ->
          scan_while_helper(
            rest,
            Position(..pos, col: pos.col + 1),
            acc <> c,
            pred,
          )
        False -> #(acc, chars, pos)
      }
    [] -> #(acc, chars, pos)
  }
}

// ============================================================================
// Parser:
// ============================================================================
pub type Node {
  Terminal(String)
  NonTerminal(String)
  Optional(Node)
  Repetition(Node)
  Sequence(List(Node))
  Alternative(Node)
}

pub type Production {
  Production(lhs: String, rhs: Node, is_start: Bool)
}

pub type Ebnf =
  List(Production)

/// Parser errors
pub type ParseError {
  // Scanner errors:
  UnterminatedTerminal(pos: Position)
  UnterminatedComment(pos: Position)
  EmptyTerminal(pos: Position)
  UnexpectedCharacter(c: String, pos: Position)
  // Parser errors:
  UnexpectedToken(token: Token, expected: String)
  UnexpectedEnd(expected: String)
  // Semantic analyzer errors:
  DuplicateProductions(prods: List(String))
  UnusedProductions(prods: List(String))
  UndefinedProductions(prods: List(String))
}

// Parses a string into an Ebnf type
pub fn parse(s: String) -> Result(Ebnf, ParseError) {
  use tokens <- result.try(scan(s))
  // TODO: Isn't tokens a List(Token) inside the callback func?
  // then why would I need to wrap it in Ok here?
  let assert Ok(Token(kind, ..)) = list.first(tokens)
  use <- bool.guard(kind == Eof, Error(UnexpectedEnd("nonterminal")))

  use #(productions, rest) <- result.try(parse_productions(tokens, []))
  case rest {
    [] -> Error(UnexpectedEnd("nonterminal"))
    [Token(Eof, ..)] -> {
      let rev = list.reverse(productions)
      use _ <- result.try(analyze(rev))
      Ok(rev)
    }
    [t, ..] -> Error(UnexpectedToken(t, "end of input"))
  }
}

fn parse_productions(
  tokens: List(Token),
  acc: List(Production),
) -> Result(#(List(Production), List(Token)), ParseError) {
  case tokens {
    [] -> Ok(#(acc, []))
    [Token(Eof, ..), ..] -> Ok(#(acc, tokens))
    _ -> {
      use #(prod, rest) <- result.try(parse_production(tokens))
      case list.is_empty(acc) {
        True -> {
          let prod = Production(..prod, is_start: True)
          parse_productions(rest, [prod, ..acc])
        }
        False -> parse_productions(rest, [prod, ..acc])
      }
    }
  }
}

fn parse_production(
  tokens: List(Token),
) -> Result(#(Production, List(Token)), ParseError) {
  case tokens {
    [Token(SNonTerminal(name), ..), Token(Equal, ..), ..rest] -> {
      use #(rhs, rest2) <- result.try(parse_rhs(rest))
      case rest2 {
        [Token(Dot, ..), ..rest3] -> Ok(#(Production(name, rhs, False), rest3))
        [t, ..] -> Error(UnexpectedToken(t, "'.'"))
        [] -> Error(UnexpectedEnd("'.'"))
      }
    }
    [Token(SNonTerminal(_), _), t, ..] -> Error(UnexpectedToken(t, "'='"))
    [t, ..] -> Error(UnexpectedToken(t, "production name"))
    [] -> Error(UnexpectedEnd("production"))
  }
}

fn parse_rhs(tokens: List(Token)) -> Result(#(Node, List(Token)), ParseError) {
  use #(first, rest) <- result.try(parse_sequence(tokens))
  use #(branches, rest2) <- result.try(parse_alternative_tail(rest, [first]))
  case branches {
    [only] -> Ok(#(only, rest2))
    many -> Ok(#(Alternative(Sequence(list.reverse(many))), rest2))
  }
}

fn parse_alternative_tail(
  tokens: List(Token),
  acc: List(Node),
) -> Result(#(List(Node), List(Token)), ParseError) {
  case tokens {
    [Token(Bar, ..), ..rest] -> {
      use #(seq, rest2) <- result.try(parse_sequence(rest))
      parse_alternative_tail(rest2, [seq, ..acc])
    }
    _ -> Ok(#(acc, tokens))
  }
}

fn parse_sequence(
  tokens: List(Token),
) -> Result(#(Node, List(Token)), ParseError) {
  use #(terms, rest) <- result.try(parse_terms(tokens, []))
  case terms {
    [only] -> Ok(#(only, rest))
    many -> Ok(#(Sequence(list.reverse(many)), rest))
  }
}

fn parse_terms(
  tokens: List(Token),
  acc: List(Node),
) -> Result(#(List(Node), List(Token)), ParseError) {
  case tokens {
    [Token(SNonTerminal(_), ..), ..]
    | [Token(STerminal(_), ..), ..]
    | [Token(LBracket, ..), ..]
    | [Token(LBrace, ..), ..]
    | [Token(LParen, ..), ..] -> {
      use #(term, rest) <- result.try(parse_term(tokens))
      parse_terms(rest, [term, ..acc])
    }
    _ -> Ok(#(acc, tokens))
  }
}

fn parse_term(tokens: List(Token)) -> Result(#(Node, List(Token)), ParseError) {
  case tokens {
    [Token(SNonTerminal(name), ..), ..rest] -> Ok(#(NonTerminal(name), rest))
    [Token(STerminal(s), ..), ..rest] -> Ok(#(Terminal(s), rest))

    [Token(LBracket, ..), ..rest] -> {
      use #(inner, rest2) <- result.try(parse_rhs(rest))
      case rest2 {
        [Token(RBracket, ..), ..rest3] -> Ok(#(Optional(inner), rest3))
        [t, ..] -> Error(UnexpectedToken(t, "']'"))
        [] -> Error(UnexpectedEnd("']'"))
      }
    }

    [Token(LBrace, ..), ..rest] -> {
      use #(inner, rest2) <- result.try(parse_rhs(rest))
      case rest2 {
        [Token(RBrace, ..), ..rest3] -> Ok(#(Repetition(inner), rest3))
        [t, ..] -> Error(UnexpectedToken(t, "'}'"))
        [] -> Error(UnexpectedEnd("'}'"))
      }
    }

    [Token(LParen, ..), ..rest] -> {
      use #(inner, rest2) <- result.try(parse_rhs(rest))
      case rest2 {
        [Token(RParen, ..), ..rest3] -> Ok(#(inner, rest3))
        [t, ..] -> Error(UnexpectedToken(t, "')'"))
        [] -> Error(UnexpectedEnd("')'"))
      }
    }

    [t, ..] -> Error(UnexpectedToken(t, "term"))
    [] -> Error(UnexpectedEnd("term"))
  }
}

// ============================================================================
// Semantic Analyzer:
// ============================================================================

/// analyzes an ebnf for semantic errors.
fn analyze(ebnf: Ebnf) -> Result(Nil, ParseError) {
  use _ <- result.try(analyze_duplicates(ebnf))
  use _ <- result.try(analyze_undefined_productions(ebnf))
  use _ <- result.try(analyze_unused_productions(ebnf))
  Ok(Nil)
}

/// analyses an ebnf for duplicate productions.
fn analyze_duplicates(ebnf: Ebnf) -> Result(Nil, ParseError) {
  let dups = find_duplicates(ebnf)
  case list.is_empty(dups) {
    True -> Ok(Nil)
    False -> Error(DuplicateProductions(dups))
  }
}

/// analyzes unused productions in the grammar.
fn analyze_unused_productions(ebnf: Ebnf) -> Result(Nil, ParseError) {
  let index = build_index(ebnf)

  let start_names =
    ebnf |> list.filter(fn(p) { p.is_start }) |> list.map(fn(p) { p.lhs })

  let visited =
    start_names |> list.fold(set.new(), fn(acc, name) { dfs(name, index, acc) })

  let unused_prods =
    ebnf |> list.filter(fn(p) { !set.contains(visited, p.lhs) })

  case list.is_empty(unused_prods) {
    True -> Ok(Nil)
    False -> {
      Error(UnusedProductions(unused_prods |> list.map(fn(p) { p.lhs })))
    }
  }
}

fn build_index(ebnf: Ebnf) -> Dict(String, Node) {
  list.fold(ebnf, dict.new(), fn(acc, p) { dict.insert(acc, p.lhs, p.rhs) })
}

fn dfs(
  name: String,
  index: Dict(String, Node),
  visited: Set(String),
) -> Set(String) {
  case set.contains(visited, name) {
    True -> visited
    False -> {
      let visited = set.insert(visited, name)
      case dict.get(index, name) {
        Ok(rhs) -> visit_node(rhs, index, visited)
        Error(_) -> visited
      }
    }
  }
}

fn visit_node(
  node: Node,
  index: Dict(String, Node),
  visited: Set(String),
) -> Set(String) {
  case node {
    Terminal(_) -> visited
    NonTerminal(name) -> dfs(name, index, visited)
    Optional(n) | Repetition(n) | Alternative(n) ->
      visit_node(n, index, visited)
    Sequence(nodes) ->
      list.fold(nodes, visited, fn(acc, n) { visit_node(n, index, acc) })
  }
}

/// analyzes undefined productions.
fn analyze_undefined_productions(ebnf: Ebnf) -> Result(Nil, ParseError) {
  let lhs_set = list.map(ebnf, fn(prod) { prod.lhs }) |> set.from_list
  let undefined_prods =
    list.flat_map(ebnf, fn(prod) {
      fold_node(prod.rhs, [], fn(acc, node) {
        case node {
          NonTerminal(s) -> {
            case set.contains(lhs_set, s) {
              True -> acc
              False -> [s, ..acc]
            }
          }
          _ -> list.reverse(acc)
        }
      })
    })

  case list.is_empty(undefined_prods) {
    True -> Ok(Nil)
    False -> Error(UndefinedProductions(undefined_prods))
  }
}

// Utils:

/// find duplicate productions in an Ebnf.
fn find_duplicates(xs: Ebnf) -> List(String) {
  let #(duplicates, _seen) =
    list.fold(xs, #([], set.new()), fn(acc, item) {
      let #(dups, seen) = acc
      case set.contains(seen, item.lhs) {
        True -> #([item.lhs, ..dups], seen)
        False -> #(dups, set.insert(seen, item.lhs))
      }
    })
  duplicates |> list.reverse
}

/// Folds over a Node type.
fn fold_node(node: Node, acc: a, f: fn(a, Node) -> a) -> a {
  let acc = f(acc, node)
  case node {
    Terminal(_) -> acc
    NonTerminal(_) -> acc
    Optional(inner) -> fold_node(inner, acc, f)
    Repetition(inner) -> fold_node(inner, acc, f)
    Sequence(children) ->
      list.fold(children, acc, fn(acc, child) { fold_node(child, acc, f) })
    Alternative(inner) -> fold_node(inner, acc, f)
  }
}

/// Checks if a character is alphabetic.
fn is_letter(c: String) -> Bool {
  case string.lowercase(c) {
    "a"
    | "b"
    | "c"
    | "d"
    | "e"
    | "f"
    | "g"
    | "h"
    | "i"
    | "j"
    | "k"
    | "l"
    | "m"
    | "n"
    | "o"
    | "p"
    | "q"
    | "r"
    | "s"
    | "t"
    | "u"
    | "v"
    | "w"
    | "x"
    | "y"
    | "z"
    | "A"
    | "B"
    | "C"
    | "D"
    | "E"
    | "F"
    | "G"
    | "H"
    | "I"
    | "J"
    | "K"
    | "L"
    | "M"
    | "N"
    | "O"
    | "P"
    | "Q"
    | "R"
    | "S"
    | "T"
    | "U"
    | "V"
    | "W"
    | "X"
    | "Y"
    | "Z" -> True
    _ -> False
  }
}

/// Checks if a character is valid in an identifier.
fn is_ident_char(c: String) -> Bool {
  is_letter(c) || c == "_"
}
