import gleam/dict
import gleam/list
import gleam/option
import gleam/result
import gleam/set
import internal/parser

pub type SemaError {
  DuplicateProductions(prods: List(String))
  UnusedProductions(prods: List(String))
  UndefinedProductions(prods: List(String))
}

pub fn analyze(ebnf: parser.Ebnf) -> Result(Nil, SemaError) {
  use _ <- result.try(analyze_duplicates(ebnf))
  use _ <- result.try(analyze_undefined_productions(ebnf))
  use _ <- result.try(analyze_unused_productions(ebnf))
  Ok(Nil)
}

fn analyze_duplicates(ebnf: parser.Ebnf) -> Result(Nil, SemaError) {
  let dups = find_duplicates(ebnf)
  case list.is_empty(dups) {
    True -> Ok(Nil)
    False -> Error(DuplicateProductions(dups))
  }
}

fn analyze_unused_productions(ebnf: parser.Ebnf) -> Result(Nil, SemaError) {
  let lhs_dict = list.map(ebnf, fn(prod) { #(prod.lhs, 0) }) |> dict.from_list
  let d = count_usages(ebnf, lhs_dict)
  let unused_prods =
    dict.fold(d, [], fn(acc, k, v) {
      case v {
        0 -> [k, ..acc]
        _ -> acc
      }
    })
  case list.is_empty(unused_prods) {
    True -> Ok(Nil)
    False -> Error(UnusedProductions(unused_prods))
  }
}

fn analyze_undefined_productions(ebnf: parser.Ebnf) -> Result(Nil, SemaError) {
  let lhs_set = list.map(ebnf, fn(prod) { prod.lhs }) |> set.from_list
  let undefined_prods =
    list.flat_map(ebnf, fn(prod) {
      fold_node(prod.rhs, [], fn(acc, node) {
        case node {
          parser.NonTerminal(s) -> {
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

fn find_duplicates(xs: parser.Ebnf) -> List(String) {
  let #(duplicates_rev, _seen) =
    list.fold(xs, #([], set.new()), fn(acc, item) {
      let #(dups, seen) = acc
      case set.contains(seen, item.lhs) {
        True -> #([item.lhs, ..dups], seen)
        False -> #(dups, set.insert(seen, item.lhs))
      }
    })
  duplicates_rev |> list.reverse
}

// fn map_node(
//   node: parser.Node,
//   f: fn(parser.Node) -> parser.Node,
// ) -> parser.Node {
//   let mapped_children = case node {
//     parser.Terminal(_) -> node
//     parser.NonTerminal(_) -> node
//     parser.Optional(children) ->
//       parser.Optional(list.map(children, map_node(_, f)))
//     parser.Repetition(children) ->
//       parser.Repetition(list.map(children, map_node(_, f)))
//     parser.Sequence(children) ->
//       parser.Sequence(list.map(children, map_node(_, f)))
//     parser.Alternative(children) ->
//       parser.Alternative(list.map(children, map_node(_, f)))
//   }
//   f(mapped_children)
// }

// fn each_node(node: parser.Node, f: fn(parser.Node) -> Nil) -> Nil {
//   f(node)
//   case node {
//     parser.Terminal(_) | parser.NonTerminal(_) -> f(node)
//     parser.Optional(children)
//     | parser.Repetition(children)
//     | parser.Sequence(children)
//     | parser.Alternative(children) -> list.each(children, each_node(_, f))
//   }
// }

fn count_usages(
  ebnf: parser.Ebnf,
  d: dict.Dict(String, Int),
) -> dict.Dict(String, Int) {
  let non_terms =
    list.flat_map(ebnf, fn(prod) {
      fold_node(prod.rhs, [], fn(acc, node) {
        case node {
          parser.NonTerminal(s) -> [s, ..acc]
          _ -> list.reverse(acc)
        }
      })
    })
  list.fold(non_terms, d, fn(acc, e) {
    dict.upsert(acc, e, fn(v) {
      case v {
        option.Some(i) -> i + 1
        option.None -> 0
      }
    })
  })
}

fn fold_node(node: parser.Node, acc: a, f: fn(a, parser.Node) -> a) -> a {
  let acc = f(acc, node)
  case node {
    parser.Terminal(_) -> acc
    parser.NonTerminal(_) -> acc
    parser.Optional(children)
    | parser.Repetition(children)
    | parser.Sequence(children)
    | parser.Alternative(children) ->
      list.fold(children, acc, fn(acc, child) { fold_node(child, acc, f) })
  }
}
