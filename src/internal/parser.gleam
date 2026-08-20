import gleam/list
import gleam/result
import internal/scanner.{type Token, Token}

pub type Node {
  Terminal(String)
  NonTerminal(String)
  Optional(List(Node))
  Repetition(List(Node))
  Sequence(List(Node))
  Alternative(List(Node))
}

pub type Production {
  Production(lhs: String, rhs: Node)
}

pub type Ebnf =
  List(Production)

pub type ParseError {
  UnexpectedToken(token: Token, expected: String)
  UnexpectedEnd(expected: String)
}

pub fn parse(tokens: List(Token)) -> Result(Ebnf, ParseError) {
  use #(productions, rest) <- result.try(parse_productions(tokens, []))
  case rest {
    [] -> Error(UnexpectedEnd("nonterminal"))
    [Token(scanner.Eof, ..)] -> Ok(list.reverse(productions))
    [t, ..] -> Error(UnexpectedToken(t, "end of input"))
  }
}

fn parse_productions(
  tokens: List(scanner.Token),
  acc: List(Production),
) -> Result(#(List(Production), List(Token)), ParseError) {
  case tokens {
    [] -> Ok(#(acc, []))
    [Token(scanner.Eof, ..), ..] -> Ok(#(acc, tokens))
    _ -> {
      use #(prod, rest) <- result.try(parse_production(tokens))
      parse_productions(rest, [prod, ..acc])
    }
  }
}

fn parse_production(
  tokens: List(scanner.Token),
) -> Result(#(Production, List(scanner.Token)), ParseError) {
  case tokens {
    [Token(scanner.NonTerminal(name), ..), Token(scanner.Equal, ..), ..rest] -> {
      use #(rhs, rest2) <- result.try(parse_rhs(rest))
      case rest2 {
        [Token(scanner.Dot, ..), ..rest3] -> Ok(#(Production(name, rhs), rest3))
        [t, ..] -> Error(UnexpectedToken(t, "'.'"))
        [] -> Error(UnexpectedEnd("'.'"))
      }
    }
    [Token(scanner.NonTerminal(_), _), t, ..] ->
      Error(UnexpectedToken(t, "'='"))
    [t, ..] -> Error(UnexpectedToken(t, "production name"))
    [] -> Error(UnexpectedEnd("production"))
  }
}

fn parse_rhs(tokens: List(Token)) -> Result(#(Node, List(Token)), ParseError) {
  use #(first, rest) <- result.try(parse_sequence(tokens))
  use #(branches, rest2) <- result.try(parse_alternative_tail(rest, [first]))
  case branches {
    [only] -> Ok(#(only, rest2))
    many -> Ok(#(Alternative(list.reverse(many)), rest2))
  }
}

fn parse_alternative_tail(
  tokens: List(Token),
  acc: List(Node),
) -> Result(#(List(Node), List(Token)), ParseError) {
  case tokens {
    [Token(scanner.Bar, ..), ..rest] -> {
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
    [Token(scanner.NonTerminal(_), ..), ..]
    | [Token(scanner.Terminal(_), ..), ..]
    | [Token(scanner.LBracket, ..), ..]
    | [Token(scanner.LBrace, ..), ..]
    | [Token(scanner.LParen, ..), ..] -> {
      use #(term, rest) <- result.try(parse_term(tokens))
      parse_terms(rest, [term, ..acc])
    }
    _ -> Ok(#(acc, tokens))
  }
}

fn parse_term(tokens: List(Token)) -> Result(#(Node, List(Token)), ParseError) {
  case tokens {
    [Token(scanner.NonTerminal(name), ..), ..rest] ->
      Ok(#(NonTerminal(name), rest))
    [Token(scanner.Terminal(s), ..), ..rest] -> Ok(#(Terminal(s), rest))

    [Token(scanner.LBracket, ..), ..rest] -> {
      use #(inner, rest2) <- result.try(parse_rhs(rest))
      case rest2 {
        [Token(scanner.RBracket, ..), ..rest3] ->
          Ok(#(Optional([inner]), rest3))
        [t, ..] -> Error(UnexpectedToken(t, "']'"))
        [] -> Error(UnexpectedEnd("']'"))
      }
    }

    [Token(scanner.LBrace, ..), ..rest] -> {
      use #(inner, rest2) <- result.try(parse_rhs(rest))
      case rest2 {
        [Token(scanner.RBrace, ..), ..rest3] ->
          Ok(#(Repetition([inner]), rest3))
        [t, ..] -> Error(UnexpectedToken(t, "'}'"))
        [] -> Error(UnexpectedEnd("'}'"))
      }
    }

    [Token(scanner.LParen, ..), ..rest] -> {
      use #(inner, rest2) <- result.try(parse_rhs(rest))
      case rest2 {
        [Token(scanner.RParen, ..), ..rest3] -> Ok(#(inner, rest3))
        [t, ..] -> Error(UnexpectedToken(t, "')'"))
        [] -> Error(UnexpectedEnd("')'"))
      }
    }

    [t, ..] -> Error(UnexpectedToken(t, "term"))
    [] -> Error(UnexpectedEnd("term"))
  }
}
// fn to_string(node: Node) -> String {
//   case node {
//     Terminal(s) -> "Terminal(" <> s <> ")"
//     NonTerminal(s) -> "NonTerminal(" <> s <> ")"
//     Optional(children) -> "[" <> render_children(children, " ") <> "]"
//     Repetition(children) -> "{" <> render_children(children, " ") <> "}"
//     Sequence(children) | Alternative(children) ->
//       render_children(children, " | ")
//   }
// }

// fn render_children(children: List(Node), sep: String) -> String {
//   children
//   |> list.map(to_string)
//   |> string.join(sep)
// }
