# ebnf

[![Package Version](https://img.shields.io/hexpm/v/ebnf)](https://hex.pm/packages/ebnf)
[![Hex Docs](https://img.shields.io/badge/hex-docs-ffaff3)](https://ebnf.hexdocs.pm/)

[ISO-14977](http://www.iso.org/iso/en/CatalogueDetailPage.CatalogueDetail?CSNUMBER=26153) EBNF parser


```sh
gleam add ebnf@1
```

```gleam
import ebnf

pub fn main() -> Nil {
  let content = "some ebnf string"
  let ast = ebnf.parse(s)
  echo ast
}
```

Further documentation can be found at <https://ebnf.hexdocs.pm/>.

## Development

```sh
gleam run   # Run the project
gleam test  # Run the tests
```

