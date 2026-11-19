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
read-only field, a step past a stepper's range, a slide to no number, a day
its calendar leaves out or a choice the picker does not offer fails and says
why, as does an act the view does not take - a toggle of a label; words typed
are held as the field holds them - in its case, within its bound - a slider
let go past an end stands at that end, and a color picked keeps its opacity
only where the picker chooses it.

`value(_:)` reads a contract member - `TextElementContract.text`,
`ToggleElementContract.isOn`, `VisualElementContract.accessibilityValue` - as the
member's own type, nil where the view holds none. Like `perform(_:)`, it
fails where no view, or two, is the one it names - a view gone with its
window included - and where the view wears no contract of the member's.

## Time wound by hand

A window given a `TestClock` stands at the clock's time. A movement begun
in it travels only as far as the test advances the clock, so a test stops
half-way, reads, interrupts and goes on, and never waits:

```swift
import StateUI
import StateUITesting

struct PanelPage: View {
    @State private var lift = 0.0
    @State private var said = "closed"

    var body: some View {
        VStack {
            Rectangle()
                .translationY($lift)
                .accessibilityIdentifier("panel")
            Text(said)
                .accessibilityIdentifier("panel.said")
            Button("Open")
                .accessibilityIdentifier("panel.open")
                .onClicked(policy: .ignoreWhileRunning) {
                    let result = try await $lift.journey.move(to: -240, .eased(.milliseconds(300), curve: .linear)).result()
                    said = result == .reached(.animated) ? "open" : "stopped on the way"
                }
            Button("Stop")
                .accessibilityIdentifier("panel.stop")
                .onClicked { $lift.journey.stop() }
        }
    }
}

let clock = TestClock()
let window = try await TestWindow(clock: clock) { PanelPage() }
let panel = try window.element("panel")

try window.element("panel.open").send(.activate)
try await clock.advance(by: .milliseconds(150))
let halfWay = try panel.presentation()
assert(abs(halfWay.translation.y + 120) < 0.5)

try window.element("panel.stop").send(.activate)
try await window.flush()
let words = try window.element("panel.said").value(TextElementContract.text)
assert(words == "stopped on the way")

try await clock.advance(by: .seconds(1))
let later = try panel.presentation()
assert(abs(later.translation.y + 120) < 0.5)
try await window.close()
```

`TestWindow(clock:)` mounts the page moving no time. `send(_:)` does an act
and waits for nothing. `flush()` runs the work that is ready - the handlers
the act raised, the build they asked for - and shows it at the present
time: a movement begun stands where it began. `clock.advance(by:)` moves
the time on a display frame at a time, every ten milliseconds unless `step:`
says otherwise, with a last shorter step for what is left; `clock.now` is
how far it has come. A clock is never wound back, winds one window at a
time, and winds nothing once its window closed - each a `TestFailure`.
Closing moves no time. `perform(_:)` waits by running frames, so in a
window wound by hand it fails and names `send(_:)`.

A press is told in phases: `.pressDown(at:)`, `.drag(to:)`, then `.lift`
or `.cancelInteraction`, the press taken away as a call arriving takes it.
A point is the view's own, in the rectangle its layout put it in. Past
where it went down the press is a pan, at the speed the clock gives its
moves - twenty points in ten milliseconds is two thousand a second; let go
where it went down it is the view's tap, or a button's click.

```swift
import StateUI
import StateUITesting

struct SlidingPage: View {
    @State private var across = 0.0

    var body: some View {
        Rectangle()
            .translationX($across)
            .onPanUpdated { update in
                switch update.phase {
                case .changed: $across.journey.snap(to: update.total.x)
                case .cancelled: $across.journey.snap(to: 0)
                default: break
                }
            }
            .accessibilityIdentifier("slide")
    }
}

let clock = TestClock()
let window = try await TestWindow(clock: clock) { SlidingPage() }
let box = try window.element("slide")

try box.send(.pressDown(at: Point(x: 10, y: 10)))
try await clock.advance(by: .milliseconds(10))
try box.send(.drag(to: Point(x: 40, y: 10)))
try await window.flush()
let dragged = try box.presentation()
assert(dragged.translation.x == 30)

try box.send(.cancelInteraction)
try await window.flush()
let back = try box.presentation()
assert(back.translation.x == 0)
try await window.close()
```

`presentation()` answers a `TestPresentation`, how a view stands now - its
`opacity`, its `translation`, `scaleX`, `scaleY` and `rotation`, whether it
`takesInput` and its `accessibilityPresence` - where a movement has got it
to, while its states hold where they are going. Its `id`, a `TestPresentationID`, may be
kept: `window.presentation(id)` answers how that view stands later, nil
once it is off the page, and `generation` tells one mounting of a view from
the next. It reads what StateUI decided, the same on every platform, and
proves nothing of a platform's pixels. Nor does a window with no toolkit
size anything: a view a layout measures (`sizeThatFits(_:)`) answers nought
in it, so arithmetic of measured sizes is proved on a platform.
