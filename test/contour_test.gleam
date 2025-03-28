import birdie
import contour
import gleeunit

pub fn main() -> Nil {
  gleeunit.main()
}

pub fn tokens_0_test() {
  let source =
    "import gleam/io

pub fn main() {
  io.println(\"hello, friend!\")
}"
  birdie.snap(source <> "\n\n---\n\n" <> contour.to_ansi(source), "tokens_0")
}

pub fn tokens_1_test() {
  let source =
    "fn spawn_task(i) {
  task.async(fn() {
    let n = int.to_string(i)
    io.println(\"Hello from \" <> n)
  })
}

pub fn main() {
  // Run loads of threads, no problem
  list.range(0, 200_000)
  |> list.map(spawn_task)
  |> list.each(task.await_forever)
}"
  birdie.snap(source <> "\n\n---\n\n" <> contour.to_ansi(source), "tokens_1")
}

pub fn tokens_2_test() {
  let source =
    "@external(erlang, \"Elixir.HPAX\", \"new\")
pub fn new(size: Int) -> Table

pub fn register_event_handler() {
  let el = document.query_selector(\"a\")
  element.add_event_listener(el, fn() {
    io.println(\"Clicked!\")
  })
}"
  birdie.snap(source <> "\n\n---\n\n" <> contour.to_ansi(source), "tokens_2")
}
