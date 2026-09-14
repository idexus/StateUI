# Concurrency

StateUI handlers may suspend without leaving the platform UI thread. The
library expresses that guarantee with its own `@MainThread` global actor and a
host-drained executor. Application code uses ordinary Swift concurrency while
the host remains the owner of its native event loop.

## Handler isolation

Every StateUI event, change, lifetime, ticker, and host-event handler already
runs on `@MainThread`. It can read and write state directly and may call an
asynchronous function:

```swift
@State var status = "Idle"

Button("Load").onClicked {
    status = "Loading"
    try await Task.sleep(for: .milliseconds(100))
    status = "Ready"
}
```

A handler without an `await` completes during the event dispatch that started
it. After a suspension, continuation requires a later turn of the platform UI
loop. The host wakes for queued jobs even when the awaited work was not a host
action, so `Task.sleep`, task values, streams, and continuations all resume
promptly.

An uncaught handler error is reported through the active host. Use `do` and
`catch` only when the application can recover or present a more useful state.

## Application async functions

An asynchronous helper called by a handler must inherit its caller's executor
or state its isolation explicitly:

```swift quote
@MainThread
func loadDocument() async throws {
    let name = try await Dialogs.prompt(
        "Open", message: "Document name", placeholder: "Name")
    if let name { currentDocument = name }
}
```

Every Swift module in an application enables
`NonisolatedNonsendingByDefault` so an unannotated nonisolated async function
inherits its caller's executor. The setting is per target:

```swift quote
.target(
    name: "NotesUI",
    dependencies: ["StateUI"],
    swiftSettings: [
        .enableUpcomingFeature("NonisolatedNonsendingByDefault")
    ]
)
```

Keep this setting on platform-neutral application modules, native entry
targets, and test targets. `@MainThread` remains useful when the function's
contract is specifically UI-isolated rather than merely caller-inheriting.

Do not use `@MainActor` as StateUI's portable UI abstraction. A native host can
use the isolation its toolkit requires internally; application handlers and
cross-platform helpers use StateUI's executor contract.

## State across tasks

Each `@State` value has synchronized storage. Independent reads and writes are
safe from any thread. A read-modify-write operation must remain one operation;
use the projected box's `update` method:

```swift
@State var total = 0

let counter = _total
counter.update { value in value + 1 }
```

`total += 1` is appropriate on `@MainThread`, where application handlers are
serialized. Use `update` when several tasks may modify the same state
concurrently.

Thread safety does not turn a group of separate states into one transaction.
If several fields must change as one invariant, place that invariant behind
one synchronized owner or return the work to `@MainThread` for the complete
change.

A write requests a render; the renderer coalesces pending work. A task that
reads state outside a description does not become a view reader. Read tracking
belongs to descriptions the differ is currently building.

## Ordering host actions

Host actions are asynchronous requests with typed replies. Starting several
actions in one handler preserves the order in which they are issued, but the
batch is not a transaction and their completions can arrive independently.
Use `await` to express a dependency:

```swift quote
Button("Rename and confirm").onClicked {
    guard let name = try await Dialogs.prompt(
        "Rename", message: "New name", placeholder: "Name")
    else { return }

    title = name
    try await Dialogs.alert("Renamed", message: name)
}
```

An `async let` or child task may run work concurrently. Registry, state, and
wake-up mechanics are safe for that route, but UI decisions still belong to
the handler's `@MainThread` continuation. Concurrency changes completion order;
it does not weaken StateUI's identity or render ordering.

## Sleeping and deadlines

Use `Task.sleep` for a one-off delay. Repeated `sleep(for:)` loops accumulate
the small time spent resuming and doing work on every lap. For a repeating
interface clock, use `Ticker`, which advances a deadline and spends that
lateness instead of adding it to the next interval.

```swift
struct Countdown: ContentView {
    @State private var ticker = Ticker(every: .seconds(1), limit: 10)

    var content: any View {
        VStack {
            Label("\((ticker.limit ?? 0) - ticker.ticks)")

            Button(ticker.isRunning ? "Stop" : "Start")
                .onClicked {
                    ticker.isRunning ? ticker.stop() : ticker.start()
                }
        }
        .onDestroying { ticker.stop() }
    }
}
```

Hold a ticker in `@State` so the same instance survives view rebuilds. Reading
`ticks`, `isRunning`, `isFinished`, `interval`, `limit`, or `isRepeating`
subscribes the current description to that ticker. A tick and each public
configuration change request a render.

`start()` returns immediately and does nothing while the same run is already
active. A completed limited ticker starts again from zero. `stop()` keeps the
count; `reset()` stops and sets it to zero. Stop a view-owned ticker from
`onDestroying` so a removed element cannot keep doing work.

Intervals shorter than one millisecond are clamped to one millisecond. The
platform scheduler may have a coarser practical resolution.

## Work on each tick

`onTick` is an optional `@MainThread` asynchronous closure. Ticks never overlap:
the next interval is scheduled after the current closure finishes. If work
takes more than a whole interval, the next deadline starts from completion
instead of releasing a burst of missed ticks.

A nonrepeating ticker is a reusable delay. It is useful for polling that must
not overlap:

```swift quote
@State private var status = "Waiting"
@State private var poll = Ticker(every: .seconds(30), isRepeating: false)

VStack { Label(status) }
    .onCreated {
        poll.onTick = {
            status = await service.status()
            poll.start()
        }
        poll.start()
    }
    .onDestroying { poll.stop() }
```

The final tick clears `isRunning` before invoking `onTick`, so that closure may
start the next run. Consequently, `isRunning == false` means that no later tick
is scheduled; it does not promise that the current closure has returned.

Use a host clock such as `ClockTime.now()` when the value represents civil time.
A wall clock should ask what time it is rather than infer time by counting
ticks.

## Foundation boundary

The cross-platform StateUI module does not import Foundation. Application code
may use Foundation for networking, serialization, and domain models. At the UI
boundary use StateUI's portable values and execution primitives:

- `CalendarDate` and `ClockTime` for picker state;
- `LocaleInfo` and `TimeZoneInfo` for host-normalized locale and zone facts;
- `Task.sleep` and `Ticker` for timing;
- `@MainThread` for UI isolation.

This keeps the core deterministic and gives each native host one explicit
place to connect Swift concurrency to its toolkit event loop.
