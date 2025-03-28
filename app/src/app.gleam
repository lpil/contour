import contour
import gleam/javascript/promise
import lustre
import lustre/attribute
import lustre/effect.{type Effect}
import lustre/element.{type Element}
import lustre/element/html
import lustre/event
import plinth/browser/clipboard
import plinth/javascript/global

pub fn main() {
  let app = lustre.application(init, update, view)
  let assert Ok(_) = lustre.start(app, "#app", Nil)
  Nil
}

pub type Model {
  Model(code: String, highlighted: String, copy_button_text: String)
}

const styles = "
.hl-comment  { color: #d4d4d4; font-style: italic }
.hl-function { color: #9ce7ff }
.hl-keyword  { color: #ffd596 }
.hl-module   { color: #ffddfa }
.hl-number   { color: #c8ffa7 }
.hl-operator { color: #ffaff3 }
.hl-string   { color: #c8ffa7 }
.hl-variant  { color: #ffddfa }
"

const copy_button_default_text = "Copy HTML 🧟"

const copy_button_copied_text = "Copied 🥰"

fn init(_flags) -> #(Model, Effect(e)) {
  let code =
    "import gleam/io

pub fn main() {
  io.println(\"hello, friend!\")
}
"
  let highlighted = contour.to_html(code)
  let model =
    Model(code:, highlighted:, copy_button_text: copy_button_default_text)
  #(model, effect.none())
}

pub type Msg {
  UserUpdatedCode(String)
  UserClickedCopy
  CopyFeedbackWindowEnded
}

pub fn update(model: Model, msg: Msg) -> #(Model, Effect(Msg)) {
  case msg {
    UserClickedCopy -> {
      let copy_effect = effect.from(copy_to_clipboard(_, model.highlighted))
      let model = Model(..model, copy_button_text: copy_button_copied_text)
      #(model, copy_effect)
    }

    CopyFeedbackWindowEnded -> {
      let model = Model(..model, copy_button_text: copy_button_default_text)
      #(model, effect.none())
    }

    UserUpdatedCode(code) -> {
      let highlighted = contour.to_html(code)
      let model = Model(..model, code:, highlighted:)
      #(model, effect.none())
    }
  }
}

fn view(model: Model) -> Element(Msg) {
  html.div([attribute.class("grid grid-cols-2 font-mono h-screen")], [
    html.style([], styles),
    html.section(
      [
        attribute.class(
          "block w-full h-full border-2 border-r-1 border-[#ffaff3]",
        ),
      ],
      [
        html.textarea(
          [
            attribute.class("bg-transparent p-4 block w-full h-full"),
            attribute.placeholder(
              "Hello!\nType your Gleam code here and I'll highlight it",
            ),
            attribute.attribute("spellcheck", "false"),
            event.on_input(UserUpdatedCode),
          ],
          model.code,
        ),
      ],
    ),
    html.section(
      [
        attribute.class(
          "bg-[#282c34] border-2 border-l-1 border-[#ffaff3] relative",
        ),
      ],
      [
        html.pre(
          [
            attribute.class(
              "bg-transparent text-gray-300 p-4 block w-full h-full",
            ),
          ],
          [
            html.code(
              [
                attribute.attribute(
                  "dangerous-unescaped-html",
                  model.highlighted,
                ),
              ],
              [],
            ),
          ],
        ),
        html.button(
          [
            event.on_click(UserClickedCopy),
            attribute.class(
              "absolute bottom-3 right-3 bg-[#ffaff3] py-2 px-3 rounded-md font-bold transition-opacity hover:opacity-75",
            ),
          ],
          [element.text(model.copy_button_text)],
        ),
      ],
    ),
  ])
}

fn copy_to_clipboard(dispatch: fn(Msg) -> Nil, text: String) -> Nil {
  {
    use _ <- promise.map(clipboard.write_text(text))
    use <- global.set_timeout(1000)
    dispatch(CopyFeedbackWindowEnded)
  }
  Nil
}
