import gleam/int
import gleam/list
import gleam/string

pub type Position {
  Position(row: Int, col: Int, off: Int)
}

pub fn to_string(pos: Position) -> String {
  "Position(row: "
  <> int.to_string(pos.row)
  <> ",col: "
  <> int.to_string(pos.col)
  <> ",off: "
  <> int.to_string(pos.off)
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
  Terminal(String)
  NonTerminal(String)
}

pub type Token {
  Token(TokenKind, Position)
}

pub type ScanError {
  UnterminatedTerminal(pos: Position)
  UnterminatedComment(pos: Position)
  EmptyTerminal(pos: Position)
  UnexpectedCharacter(c: String, pos: Position)
}

pub fn scan(s: String) -> Result(List(Token), ScanError) {
  s |> string.to_graphemes |> scan_helper(Position(0, 0, 0), [])
}

fn scan_helper(chars: List(String), pos: Position, acc: List(Token)) {
  case chars {
    [] -> Ok(list.reverse([Token(Eof, pos), ..acc]))
    ["\n", ..rest] ->
      scan_helper(rest, Position(..pos, row: pos.row + 1, col: 0), acc)
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
          scan_helper(remaining, new_pos, [Token(Terminal(str), pos), ..acc])
        Error(e) -> Error(e)
      }
    ["\"", ..rest] ->
      case scan_terminal(rest, Position(..pos, col: pos.col + 1), "\"", "") {
        Ok(#(str, remaining, new_pos)) ->
          scan_helper(remaining, new_pos, [Token(Terminal(str), pos), ..acc])
        Error(e) -> Error(e)
      }
    [c, ..rest] -> {
      case is_letter(c) {
        True -> {
          let #(ident, remaining, new_pos) =
            scan_while(
              rest,
              Position(..pos, col: pos.col + 1),
              c,
              is_ident_char,
            )
          scan_helper(remaining, new_pos, [
            Token(NonTerminal(ident), pos),
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
) -> Result(#(List(String), Position), ScanError) {
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
) -> Result(#(String, List(String), Position), ScanError) {
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

fn is_digit(c: String) -> Bool {
  case c {
    "0" | "1" | "2" | "3" | "4" | "5" | "6" | "7" | "8" | "9" -> True
    _ -> False
  }
}

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
    | "z" -> True
    _ -> False
  }
}

fn is_ident_char(c: String) -> Bool {
  is_letter(c) || is_digit(c) || c == "_"
}
