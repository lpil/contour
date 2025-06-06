import gleam/list
import gleam/pair
import gleam/string
import gleam_community/ansi
import glexer
import glexer/token as t
import houdini

pub type Token {
  Whitespace(String)
  Keyword(String)
  String(String)
  Number(String)
  Variant(String)
  Function(String)
  Module(String)
  Operator(String)
  Comment(String)
  Other(String)
}

/// Convert Gleam source code to a list of tokens, which you can then convert
/// into whatever format you want.
///
/// If you wish to print to the terminal using ansi colours see `to_ansi`.
///
pub fn to_tokens(code: String) -> List(Token) {
  glexer.new(code) |> glexer.lex |> list.map(pair.first) |> loop([])
}

/// Highlight source code using ansi colours!
///
/// | Token             | Colour      |
/// | ----------------- | ----------- |
/// | Keyword           | Yellow      |
/// | Module            | Cyan        |
/// | Variant           | Cyan        |
/// | Function          | Blue        |
/// | Operator          | Magenta     |
/// | Comment           | Italic grey |
/// | String, Number    | Green       |
/// | Whitespace, other | No colour   |
///
/// If you wish to use some other colours or other format entirely see
/// `to_tokens`.
///
pub fn to_ansi(code: String) -> String {
  to_tokens(code)
  |> list.map(fn(token) {
    case token {
      Whitespace(s) -> ansi.reset(s)
      Keyword(s) -> ansi.yellow(s)
      String(s) -> ansi.green(s)
      Number(s) -> ansi.green(s)
      Module(s) -> ansi.cyan(s)
      Variant(s) -> ansi.cyan(s)
      Function(s) -> ansi.blue(s)
      Operator(s) -> ansi.magenta(s)
      Comment(s) -> ansi.italic(ansi.gray(s))
      Other(s) -> ansi.reset(s)
    }
  })
  |> string.concat
}

/// Convert Gleam code into a HTML string! Each token is wrapped in a `<span>`
/// with a class indicating the type of token.
///
/// | Token             | CSS class   |
/// | ----------------- | ----------- |
/// | Keyword           | hl-keyword  |
/// | Module            | hl-module   |
/// | Variant           | hl-variant  |
/// | Function          | hl-function |
/// | Operator          | hl-operator |
/// | Comment           | hl-comment  |
/// | Number            | hl-number   |
/// | String            | hl-string   |
/// | Whitespace, other |             |
///
/// Place the output within a `<pre><code>...</code></pre>` and add styling for
/// these CSS classes to get highlightin on your website. Here's some CSS you
/// could use:
///
/// ```css
/// pre code .hl-comment  { color: #d4d4d4; font-style: italic }
/// pre code .hl-function { color: #9ce7ff }
/// pre code .hl-keyword  { color: #ffd596 }
/// pre code .hl-module   { color: #ffddfa }
/// pre code .hl-number   { color: #c8ffa7 }
/// pre code .hl-operator { color: #ffaff3 }
/// pre code .hl-string   { color: #c8ffa7 }
/// pre code .hl-variant  { color: #ffddfa }
/// ```
///
/// If you wish to use some other format see `to_tokens`.
///
pub fn to_html(code: String) -> String {
  to_tokens(code)
  |> list.fold("", fn(acc, token) {
    case token {
      Whitespace(s) -> acc <> s
      Keyword(s) ->
        acc <> "<span class=hl-keyword>" <> houdini.escape(s) <> "</span>"
      String(s) ->
        acc <> "<span class=hl-string>" <> houdini.escape(s) <> "</span>"
      Number(s) ->
        acc <> "<span class=hl-number>" <> houdini.escape(s) <> "</span>"
      Module(s) ->
        acc <> "<span class=hl-module>" <> houdini.escape(s) <> "</span>"
      Variant(s) ->
        acc <> "<span class=hl-variant>" <> houdini.escape(s) <> "</span>"
      Function(s) ->
        acc <> "<span class=hl-function>" <> houdini.escape(s) <> "</span>"
      Operator(s) ->
        acc <> "<span class=hl-operator>" <> houdini.escape(s) <> "</span>"
      Comment(s) ->
        acc <> "<span class=hl-comment>" <> houdini.escape(s) <> "</span>"
      Other(s) -> acc <> houdini.escape(s)
    }
  })
}

fn loop(in0: List(t.Token), out: List(Token)) -> List(Token) {
  case in0 {
    [] -> list.reverse(out)
    [t.Space(s), ..in] -> loop(in, [Whitespace(s), ..out])

    [t.Name(m), t.Dot, t.Name(n), t.LeftParen, ..in] ->
      loop(in, [Other("("), Function(n), Other("."), Module(m), ..out])

    [t.Pipe, t.Space(s), t.Name(m), t.Dot, t.Name(n), t.LeftParen, ..in] ->
      loop(in, [
        Other("("),
        Function(n),
        Other("."),
        Module(m),
        Whitespace(s),
        Operator("|>"),
        ..out
      ])

    [t.Pipe, t.Space(s), t.Name(m), t.Dot, t.Name(n), ..in] ->
      loop(in, [
        Function(n),
        Other("."),
        Module(m),
        Whitespace(s),
        Operator("|>"),
        ..out
      ])

    [t.Name(n), t.LeftParen, ..in] -> loop(in, [Other("("), Function(n), ..out])

    [t.CommentModule(c), ..in] -> loop(in, [Comment("////" <> c), ..out])
    [t.CommentDoc(c), ..in] -> loop(in, [Comment("///" <> c), ..out])
    [t.CommentNormal(c), ..in] -> loop(in, [Comment("//" <> c), ..out])

    [t.Int(i), ..in] -> loop(in, [Number(i), ..out])
    [t.Float(i), ..in] -> loop(in, [Number(i), ..out])

    [t.String(s), ..in] -> loop(in, [String("\"" <> s <> "\""), ..out])

    [t.Import, t.Space(s), t.Name(m), ..in] -> {
      let #(in, m) = loop_import(in, m)
      loop(in, [Module(m), Whitespace(s), Keyword("import"), ..out])
    }
    [t.Import, ..in] -> loop(in, [Keyword("import"), ..out])

    [t.At, t.Name(n), ..in] -> loop(in, [Keyword("@" <> n), ..out])

    [t.As, ..in] -> loop(in, [Keyword("as"), ..out])
    [t.Assert, ..in] -> loop(in, [Keyword("assert"), ..out])
    [t.Auto, ..in] -> loop(in, [Keyword("auto"), ..out])
    [t.Case, ..in] -> loop(in, [Keyword("case"), ..out])
    [t.Const, ..in] -> loop(in, [Keyword("const"), ..out])
    [t.Delegate, ..in] -> loop(in, [Keyword("delegate"), ..out])
    [t.Derive, ..in] -> loop(in, [Keyword("derive"), ..out])
    [t.Echo, ..in] -> loop(in, [Keyword("echo"), ..out])
    [t.Else, ..in] -> loop(in, [Keyword("else"), ..out])
    [t.Fn, ..in] -> loop(in, [Keyword("fn"), ..out])
    [t.If, ..in] -> loop(in, [Keyword("if"), ..out])
    [t.Implement, ..in] -> loop(in, [Keyword("implement"), ..out])
    [t.Let, ..in] -> loop(in, [Keyword("let"), ..out])
    [t.Macro, ..in] -> loop(in, [Keyword("macro"), ..out])
    [t.Opaque, ..in] -> loop(in, [Keyword("opaque"), ..out])
    [t.Panic, ..in] -> loop(in, [Keyword("panic"), ..out])
    [t.Pub, ..in] -> loop(in, [Keyword("pub"), ..out])
    [t.Test, ..in] -> loop(in, [Keyword("test"), ..out])
    [t.Todo, ..in] -> loop(in, [Keyword("todo"), ..out])
    [t.Type, ..in] -> loop(in, [Keyword("type"), ..out])
    [t.Use, ..in] -> loop(in, [Keyword("use"), ..out])

    [t.AmperAmper, ..in] -> loop(in, [Operator("&&"), ..out])
    [t.Bang, ..in] -> loop(in, [Operator("!"), ..out])
    [t.EqualEqual, ..in] -> loop(in, [Operator("=="), ..out])
    [t.Greater, ..in] -> loop(in, [Operator(">"), ..out])
    [t.GreaterDot, ..in] -> loop(in, [Operator(">."), ..out])
    [t.GreaterEqual, ..in] -> loop(in, [Operator(">="), ..out])
    [t.GreaterEqualDot, ..in] -> loop(in, [Operator(">=."), ..out])
    [t.GreaterGreater, ..in] -> loop(in, [Operator(">>"), ..out])
    [t.Less, ..in] -> loop(in, [Operator("<"), ..out])
    [t.LessDot, ..in] -> loop(in, [Operator("<."), ..out])
    [t.LessEqual, ..in] -> loop(in, [Operator("<="), ..out])
    [t.LessEqualDot, ..in] -> loop(in, [Operator("<=."), ..out])
    [t.LessGreater, ..in] -> loop(in, [Operator("<>"), ..out])
    [t.Minus, ..in] -> loop(in, [Operator("-"), ..out])
    [t.MinusDot, ..in] -> loop(in, [Operator("-."), ..out])
    [t.NotEqual, ..in] -> loop(in, [Operator("!="), ..out])
    [t.Percent, ..in] -> loop(in, [Operator("%"), ..out])
    [t.Pipe, ..in] -> loop(in, [Operator("|>"), ..out])
    [t.Plus, ..in] -> loop(in, [Operator("+"), ..out])
    [t.PlusDot, ..in] -> loop(in, [Operator("+."), ..out])
    [t.Slash, ..in] -> loop(in, [Operator("/"), ..out])
    [t.SlashDot, ..in] -> loop(in, [Operator("/."), ..out])
    [t.Star, ..in] -> loop(in, [Operator("*"), ..out])
    [t.StarDot, ..in] -> loop(in, [Operator("*."), ..out])
    [t.VBarVBar, ..in] -> loop(in, [Operator("||"), ..out])

    [t.At, ..in] -> loop(in, [Other("@"), ..out])
    [t.Colon, ..in] -> loop(in, [Other(":"), ..out])
    [t.Comma, ..in] -> loop(in, [Other(","), ..out])
    [t.Dot, ..in] -> loop(in, [Other("."), ..out])
    [t.DotDot, ..in] -> loop(in, [Other(".."), ..out])
    [t.Equal, ..in] -> loop(in, [Other("="), ..out])
    [t.Hash, ..in] -> loop(in, [Other("#"), ..out])
    [t.LeftArrow, ..in] -> loop(in, [Other("<-"), ..out])
    [t.LeftBrace, ..in] -> loop(in, [Other("{"), ..out])
    [t.LeftParen, ..in] -> loop(in, [Other("("), ..out])
    [t.LeftSquare, ..in] -> loop(in, [Other("["), ..out])
    [t.LessLess, ..in] -> loop(in, [Other("<<"), ..out])
    [t.RightArrow, ..in] -> loop(in, [Other("->"), ..out])
    [t.RightBrace, ..in] -> loop(in, [Other("}"), ..out])
    [t.RightParen, ..in] -> loop(in, [Other(")"), ..out])
    [t.RightSquare, ..in] -> loop(in, [Other("]"), ..out])
    [t.VBar, ..in] -> loop(in, [Other("|"), ..out])

    [t.Name(n), ..in] -> loop(in, [Other(n), ..out])
    [t.DiscardName(name), ..in] -> loop(in, [Other("_" <> name), ..out])

    [t.UpperName(n), ..in] -> loop(in, [Variant(n), ..out])

    [t.UnexpectedGrapheme(s), ..in] -> loop(in, [Other(s), ..out])
    [t.UnterminatedString(s), ..in] -> loop(in, [Other(s), ..out])
    [t.EndOfFile, ..in] -> loop(in, out)
  }
}

fn loop_import(in: List(t.Token), module: String) -> #(List(t.Token), String) {
  case in {
    [t.Slash, t.Name(n), ..in] -> loop_import(in, module <> "/" <> n)
    _ -> #(in, module)
  }
}
