import ebnf.{
  Alternative, NonTerminal, Production, Repetition, Sequence, Terminal,
}

import gleeunit
import gleeunit/should
import simplifile

pub fn main() -> Nil {
  gleeunit.main()
}

pub fn sample_empty_test() {
  let s = ""
  let ast = ebnf.parse(s)
  echo ast
}

pub fn sample_one_test() {
  let assert Ok(content) = simplifile.read("test/sample1.ebnf")
  case ebnf.parse(content) {
    Ok(ast) -> {
      let res = [
        Production(
          "expression",
          Sequence([
            NonTerminal("term"),
            Repetition(
              Sequence([
                Alternative(Sequence([Terminal("+"), Terminal("-")])),
                NonTerminal("term"),
              ]),
            ),
          ]),
          True,
        ),
        Production(
          "term",
          Sequence([
            NonTerminal("factor"),
            Repetition(
              Sequence([
                Alternative(Sequence([Terminal("*"), Terminal("/")])),
                NonTerminal("factor"),
              ]),
            ),
          ]),
          False,
        ),
        Production(
          "factor",
          Alternative(
            Sequence([
              NonTerminal("number"),
              NonTerminal("variable"),
              Sequence([Terminal("("), NonTerminal("expression"), Terminal(")")]),
            ]),
          ),
          False,
        ),
        Production(
          "variable",
          Alternative(Sequence([Terminal("x"), Terminal("y"), Terminal("z")])),
          False,
        ),
        Production(
          "number",
          Sequence([NonTerminal("digit"), Repetition(NonTerminal("digit"))]),
          False,
        ),
        Production(
          "digit",
          Alternative(
            Sequence([
              Terminal("0"),
              Terminal("1"),
              Terminal("2"),
              Terminal("3"),
              Terminal("4"),
              Terminal("5"),
              Terminal("6"),
              Terminal("7"),
              Terminal("8"),
              Terminal("9"),
            ]),
          ),
          False,
        ),
      ]
      should.equal(ast, res)
    }
    Error(e) -> {
      echo ebnf.to_string(e)
      should.fail()
    }
  }
}
// pub fn sample_two_test() {
//   let assert Ok(content) = simplifile.read("test/sample2.ebnf")
//   case ebnf.parse(content) {
//     Ok(ast) -> {
//       echo ast
//       should.fail()
//     }
//     Error(e) -> {
//       echo e
//       should.fail()
//     }
//   }
// }
