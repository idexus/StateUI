# Testing an application

An application's tests show its pages in a test window and use them as its
user does: they find a view by the identifier automation knows it by, act on
it, and read what it holds. The window stands over StateUI with no platform's
toolkit, where `swift test` runs, so a page is tested in the time a function
takes.

```swift
import StateUITesting

struct CounterPage: View {
    @State private var clicks = 0

    var body: some View {
        Button("Clicked \(clicks) times")
            .accessibilityIdentifier("counter.add")
            .onClicked { clicks += 1 }
    }
}

let window = try await TestWindow(motion: .none) { CounterPage() }
let button = try window.element("counter.add")

try await button.perform(.activate)

assert(button.value(TextualElementContract.text) == "Clicked 1 times")
```

A test target depends on the `StateUITesting` product of
`lib/StateUI/StateUI.Testing`, and its test functions run on `@MainActor`.

## Finding a view

`window.element("counter.add")` finds the view whose `accessibilityIdentifier`
is that name; `window.element(page.name)` finds the view a page's `@Aim` is
put on. A view is found again each time it is used, so it stays the same view
while the page builds again. Finding no view, or two, fails and names the
view.

## Acting and reading

`perform(_:)` takes what a user does - `.activate`, `.toggle`, `.type("Ada")`,
`.submit`, `.choose(2)`, `.slide(to: 0.5)`, `.tap(count: 2)`, a screen reader's
`.performAccessibilityAction("Clear")` and `.adjust(.increment)` - and returns
once the work it began is done: its handlers, what they started, and the
frames they asked for. `motion: .none` shows every change at once.

`value(_:)` reads a contract member - `TextualElementContract.text`,
`SwitchContract.isOn`, `VisualElementContract.accessibilityValue` - as the
member's own type, nil where the view holds none.
