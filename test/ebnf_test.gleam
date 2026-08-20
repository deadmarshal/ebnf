import gleeunit
import gleeunit/should
import internal/scanner
import simplifile

pub fn main() -> Nil {
  gleeunit.main()
}

pub fn sample_one_test() {
  let assert Ok(content) = simplifile.read("test/sample1.ebnf")
  case scanner.scan(content) {
    Ok(tokens) -> {
      let res = [
        // expression:
        scanner.Token(
          scanner.NonTerminal("expression"),
          scanner.Position(0, 0, 0),
        ),
        scanner.Token(scanner.Equal, scanner.Position(0, 0, 0)),
        scanner.Token(scanner.NonTerminal("term"), scanner.Position(0, 0, 0)),
        scanner.Token(scanner.LBrace, scanner.Position(0, 0, 0)),
        scanner.Token(scanner.LParen, scanner.Position(0, 0, 0)),
        scanner.Token(scanner.Terminal("+"), scanner.Position(0, 0, 0)),
        scanner.Token(scanner.Bar, scanner.Position(0, 0, 0)),
        scanner.Token(scanner.Terminal("-"), scanner.Position(0, 0, 0)),
        scanner.Token(scanner.RParen, scanner.Position(0, 0, 0)),
        scanner.Token(scanner.NonTerminal("term"), scanner.Position(0, 0, 0)),
        scanner.Token(scanner.RBrace, scanner.Position(0, 0, 0)),
        scanner.Token(scanner.Dot, scanner.Position(0, 0, 0)),
        // term:
        scanner.Token(scanner.NonTerminal("term"), scanner.Position(0, 0, 0)),
        scanner.Token(scanner.Equal, scanner.Position(0, 0, 0)),
        scanner.Token(scanner.NonTerminal("factor"), scanner.Position(0, 0, 0)),
        scanner.Token(scanner.LBrace, scanner.Position(0, 0, 0)),
        scanner.Token(scanner.LParen, scanner.Position(0, 0, 0)),
        scanner.Token(scanner.Terminal("*"), scanner.Position(0, 0, 0)),
        scanner.Token(scanner.Bar, scanner.Position(0, 0, 0)),
        scanner.Token(scanner.Terminal("/"), scanner.Position(0, 0, 0)),
        scanner.Token(scanner.RParen, scanner.Position(0, 0, 0)),
        scanner.Token(scanner.NonTerminal("factor"), scanner.Position(0, 0, 0)),
        scanner.Token(scanner.RBrace, scanner.Position(0, 0, 0)),
        scanner.Token(scanner.Dot, scanner.Position(0, 0, 0)),
        // factor:
        scanner.Token(scanner.NonTerminal("factor"), scanner.Position(0, 0, 0)),
        scanner.Token(scanner.Equal, scanner.Position(0, 0, 0)),
        scanner.Token(scanner.NonTerminal("number"), scanner.Position(0, 0, 0)),
        scanner.Token(scanner.Bar, scanner.Position(0, 0, 0)),
        scanner.Token(
          scanner.NonTerminal("variable"),
          scanner.Position(0, 0, 0),
        ),
        scanner.Token(scanner.Bar, scanner.Position(0, 0, 0)),
        scanner.Token(scanner.Terminal("("), scanner.Position(0, 0, 0)),
        scanner.Token(
          scanner.NonTerminal("expression"),
          scanner.Position(0, 0, 0),
        ),
        scanner.Token(scanner.Terminal(")"), scanner.Position(0, 0, 0)),
        scanner.Token(scanner.Dot, scanner.Position(0, 0, 0)),
        // variable:
        scanner.Token(scanner.Terminal("x"), scanner.Position(0, 0, 0)),
        scanner.Token(scanner.Terminal("y"), scanner.Position(0, 0, 0)),
        scanner.Token(scanner.Terminal("z"), scanner.Position(0, 0, 0)),
        scanner.Token(scanner.Dot, scanner.Position(0, 0, 0)),
        // number:
        scanner.Token(scanner.NonTerminal("number"), scanner.Position(0, 0, 0)),
        scanner.Token(scanner.Equal, scanner.Position(0, 0, 0)),
        scanner.Token(scanner.NonTerminal("digit"), scanner.Position(0, 0, 0)),
        scanner.Token(scanner.LBrace, scanner.Position(0, 0, 0)),
        scanner.Token(scanner.NonTerminal("digit"), scanner.Position(0, 0, 0)),
        scanner.Token(scanner.RBrace, scanner.Position(0, 0, 0)),
        scanner.Token(scanner.Dot, scanner.Position(0, 0, 0)),
        // digit:
        scanner.Token(scanner.NonTerminal("digit"), scanner.Position(0, 0, 0)),
        scanner.Token(scanner.Equal, scanner.Position(0, 0, 0)),
        scanner.Token(scanner.Terminal("0"), scanner.Position(0, 0, 0)),
        scanner.Token(scanner.Bar, scanner.Position(0, 0, 0)),
        scanner.Token(scanner.Terminal("1"), scanner.Position(0, 0, 0)),
        scanner.Token(scanner.Bar, scanner.Position(0, 0, 0)),
        scanner.Token(scanner.Terminal("2"), scanner.Position(0, 0, 0)),
        scanner.Token(scanner.Bar, scanner.Position(0, 0, 0)),
        scanner.Token(scanner.Terminal("3"), scanner.Position(0, 0, 0)),
        scanner.Token(scanner.Bar, scanner.Position(0, 0, 0)),
        scanner.Token(scanner.Terminal("4"), scanner.Position(0, 0, 0)),
        scanner.Token(scanner.Bar, scanner.Position(0, 0, 0)),
        scanner.Token(scanner.Terminal("5"), scanner.Position(0, 0, 0)),
        scanner.Token(scanner.Bar, scanner.Position(0, 0, 0)),
        scanner.Token(scanner.Terminal("6"), scanner.Position(0, 0, 0)),
        scanner.Token(scanner.Bar, scanner.Position(0, 0, 0)),
        scanner.Token(scanner.Terminal("7"), scanner.Position(0, 0, 0)),
        scanner.Token(scanner.Bar, scanner.Position(0, 0, 0)),
        scanner.Token(scanner.Terminal("8"), scanner.Position(0, 0, 0)),
        scanner.Token(scanner.Bar, scanner.Position(0, 0, 0)),
        scanner.Token(scanner.Terminal("9"), scanner.Position(0, 0, 0)),
        scanner.Token(scanner.Dot, scanner.Position(0, 0, 0)),
      ]
      should.equal(tokens, res)
    }
    Error(_e) -> should.fail()
  }
}
