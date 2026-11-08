# Testing an application

An application's tests show its pages in a test window and use them as its
user does: they find a view by the identifier automation knows it by, act on
it, and read what it holds. The window stands over StateUI with no platform's
toolkit, where `swift test` runs, so a page is tested in the time a function
takes.

```swift
import StateUI
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

let words = try button.value(TextElementContract.text)
assert(words == "Clicked 1 times")
try await window.close()
```

A test target depends on the `StateUITesting` product of
`lib/StateUI/StateUI.Testing` and imports both `StateUI` and
`StateUITesting`; its test functions run on `@MainActor`.

## Finding a view

`window.element("counter.add")` finds the view whose `accessibilityIdentifier`
is that name, a `TestElement`; `window.element(page.name)` finds the view a
page's `@Aim` is put on. A view is found again each time it is used, so it
stays the same view while the page builds again. Finding no view, or two,
fails and names the view. One window stands at a time: a new one closes the
last, whose views are found no more.

## Closing a window

`try await window.close()` removes the page, cancels the work it owns and
waits for its disappearing and destroying handlers. Calling it again waits
for the same cleanup; an old window never closes a newer one. The wait
throws `TestFailure` if cleanup still runs after ten seconds, or
`CancellationError` if the waiting task is cancelled. The window stays
closed in either case.

Replacing the window or releasing its last reference begins the same
cleanup. Call `close()` explicitly when a test needs to read the effects
of asynchronous cleanup before it finishes. The closed window has no
controls to act on. A host act begun by its farewell throws
`StateUIError.notPerformed`; host work needed by cleanup belongs before
closure. This restriction concerns closing the whole test window, not a
page leaving an application that keeps running.

## Acting and reading

`perform(_:)` takes a `UserAct`, what a user does - `.activate`,
`.tap(count: 2)`, `.toggle`, `.type("Ada")`, `.submit`, `.focus`,
`.slide(to: 0.5)`, `.step(up: true)`, `.choose("Week")` by the words the
picker shows, `.pickDate`, `.pickTime`, `.pickColor`, a screen reader's
`.performAccessibilityAction("Clear")` and `.adjust(.increment)` - and returns
once the work it began is done: its handlers, what they started, and the
frames they asked for, whatever task the test calls it from. Work the page
began before the act, a service begun as it appeared, is not waited on, nor
is what that work begins. Work the act began that is still under way after
ten seconds fails the act, saying how many runs stand. `motion: .none`
shows every change at once. The window
acts as the user can: an act on a disabled view, words typed into a
read-only field, a step past a stepper's range, a day its calendar leaves out
or a choice the picker does not offer fails and says why; words typed are
held as the field holds them - in its case, within its bound - and a color
picked keeps its opacity only where the picker chooses it.

`value(_:)` reads a contract member - `TextElementContract.text`,
`ToggleElementContract.isOn`, `VisualElementContract.accessibilityValue` - as the
member's own type, nil where the view holds none. Like `perform(_:)`, it
fails where no view, or two, is the one it names - a view gone with its
window included - and where the view wears no contract of the member's.
