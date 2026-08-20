import internal/parser
import internal/scanner
import internal/sema
import simplifile

pub fn main() {
  let assert Ok(content) = simplifile.read("./test/sample1.ebnf")
  let assert Ok(tokens) = scanner.scan(content)
  let assert Ok(ast) = parser.parse(tokens)
  echo sema.analyze(ast)
}
