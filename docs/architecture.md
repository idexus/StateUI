# Architecture

StateUI is a platform-neutral Swift model for native interfaces. Swift owns
the description tree, identity, state, diffing, and motion laws. A platform
host owns native objects, platform lifecycle, input callbacks, layout
integration, and display-frame updates.

The model has two reactive paths and one motion axis:

```text
                         a state is written
                                |
               +----------------+----------------+
               |                                 |
       a body read the state             a host surface carries
               |                           the state binding
               v                                 |
    rebuild that description                      v
               |                       update on a host cycle
               v                                 |
        diff -> HostPatch                         |
               |                                 |
               +----------------+----------------+
                                v
                       native object tree
                                |
                                v
                       host-side motion clock
```

Motion is not a third state system. It is how a changed property or a
host-carried state travels from its standing value to its destination.

## One state declaration

`@State` is the only declaration for mutable application state. A value type
keeps its storage while its identity remains in the tree. A class declares its
individual properties with `@State` as well.

```swift
final class Profile {
    @State var name = "Ada"
    @State var notifications = true
}

struct ProfileForm: ContentView {
    @State private var profile = Profile()

    var content: any View {
        VStack {
            Entry(profile.$name)
            Switch(profile.$notifications)
        }
    }
}
```

`@Binding` borrows existing storage. It creates neither another value nor
another owner. `@Environment` resolves the nearest object of a requested type
and is the route for session state and shared application models.

A state's identity is its storage, not its current value. A write is serialized
through that storage and is visible before the write returns.

## Reactive path 1: description invalidation

Reading a wrapped state value while a composed body is built records that body
as a reader. A later write invalidates only the current readers of that state.
StateUI rebuilds those descriptions and diffs their result against the retained
tree.

```swift
struct Greeting: ContentView {
    @State private var name = "StateUI"

    var content: any View {
        VStack {
            Entry($name).placeholder("Name")
            Label("Hello, \(name)")
        }
    }
}
```

`Label` reads `name`, so an edit rebuilds `Greeting`. The resulting patch
contains only values and descendants that actually changed. Reader sets are a
function of the current tree: when a body no longer reads a state, that state
no longer invalidates it.

This path is for structural decisions and authored values:

- choosing which views or pages exist;
- changing child order or identity;
- computing a property from ordinary Swift values;
- running `onChanged` after a value differs between two descriptions.

It is intentionally not a frame loop.

## Reactive path 2: host-carried state

Handing a `Binding` to a control, driven modifier, feed, conversion, or engine
does not read its wrapped value for dependency tracking. StateUI registers one
typed state channel and the host can read or report it without rebuilding the
body.

```swift
struct Level: ContentView {
    @State private var level = 0.25

    var content: any View {
        VStack {
            Slider($level)
            BoxView(.cornflowerBlue).scaleX($level)
            Label($level.convert { "\(Int($0 * 100))%" })
        }
    }
}
```

The slider, scale, and converted label share the state channel. The host
applies a program write to every attachment on its display cycle. A native
input report lands on the same state. A program write is not echoed as a user
event; a handler runs only for input or lifecycle reported by the platform.

A host attachment declares its direction:

| Mode | Meaning | Example |
| --- | --- | --- |
| output | state to native property | driven label text |
| input | native report to state | measured `frame` |
| input/output | both directions on one channel | `Slider($value)` |

One state has one carried shape. A journey channel cannot simultaneously be a
plain text/feed channel. Declare a second state when the two roles are
different.

This path is for continuous or platform-owned values:

- two-way control values;
- properties driven directly by state;
- frame, focus, size, scroll, and gesture feeds;
- conversions evaluated on host cycles;
- engine inputs and outputs.

## Feedback and handler ordering

Bindings and handlers may coexist on one control. The host first commits the
reported value to its state channel, then invokes the handler. The handler
therefore observes the new state.

Program writes are silent at the event boundary. This prevents a write such as
`enabled = true` from pretending that the reader toggled the native control.
The same-value guard exists on both sides of the boundary, so a native echo
does not create a render loop.

`onChanged` belongs to the description path. It compares the value carried by
the previous and current descriptions and runs after the tree walk. `onCreated`
and `onDestroying` describe StateUI element lifetime, not native allocation
callbacks.

## Journey

A state remains discrete: reading `value` answers its destination immediately.
For every `Walked` value, `$value.journey` exposes the continuous trip between
destinations.

| Journey member | Meaning |
| --- | --- |
| `value` | value currently shown on this host frame |
| `destination` | target; the same value a plain state read returns |
| `velocity` | per-second velocity, lane by lane |
| `motion` | law used wherever this state is shown |
| `move(to:_:)` | set a destination and await whether it was reached |
| `stop()` | end the active trip where it currently stands |
| `snap(to:)` | set current value, destination, and zero velocity together |
| `convert` | derive a host-driven value from the live journey |

```swift
struct Fader: ContentView {
    @State private var fade = 1.0

    var content: any View {
        VStack {
            Label("Native motion").opacity($fade)
            Button("Fade").onClicked {
                try await $fade.journey.move(to: 0.15, .eased(400, .cubicOut))
            }
            Button("Restore").onClicked { $fade.journey.snap(to: 1) }
            Button("Stop").onClicked { $fade.journey.stop() }
        }
    }
}
```

Reading `fade` in a body subscribes to destination writes. Reading
`$fade.journey.value` in a body subscribes to journey frames and therefore
rebuilds while the value moves. When a body does not need every frame, use
`.samples($fade, into: $shown, .every(100))`. When only a native property or
caption needs the live value, use a journey conversion and keep the work on the
host-cycle path.

One host-carried state is one motion channel shared by all controls attached to
it. Independent motion requires independent state.

## Motion

The complete motion contract, including selection precedence, awaited journey
outcomes, visibility, layout lanes, and the `Walked` value set, is in
[Motion and journeys](motion-and-journeys.md).

StateUI describes destinations once. A host that implements the corresponding
motion surface advances current property values and layout placements on its
native display clock and lands exactly on the described destination. Until a
host has that checked matrix row, an application relies only on the final
destination.

```swift
struct ResizingPanel: ContentView {
    @State private var expanded = false

    var content: any View {
        VStack {
            BoxView(.cornflowerBlue)
                .widthRequest(expanded ? 280 : 120)
                .cornerRadius(expanded ? 28 : 8)
                .motion(.spring(response: 320))

            Button("Resize").onClicked { expanded.toggle() }
        }
    }
}
```

The write rebuilds the body once. The sparse patch carries the final property
values with `HostTransition` entries. No intermediate description tree crosses
the boundary.

There are two movement laws:

- `Motion.eased` has a duration and easing curve;
- `Motion.spring` has a response and damping, retaining velocity when
  retargeted.

`Motion.none` snaps. `Motion.inherited` resolves through the element, then the
application, then `Motion.standard`. A law on `@State(motion:)` or
`journey.motion` belongs to that value and takes precedence wherever it is
attached. `.motion(_:_:)` can override semantic groups such as opacity, size,
place, transform, spacing, and text. Layout placement uses `HostLayoutMotion`
and `MotionLanes` because a child's native rectangle is a layout result rather
than a described property.

Reduced-motion input is part of the host cycle. The final state remains the
same; only the trip is shortened or removed.

## Custom engines

`Motion.custom` gives the walk to StateUI code. An engine runs inside the host
display cycle, reads and writes state, and returns `.again` while it needs
another frame or `.wait` until a followed state is written.

```swift
struct FallingDot: ContentView {
    @State(motion: .custom) private var y = 0.0

    var content: any View {
        BoxView(.cornflowerBlue)
            .translationY($y)
            .engine(following: $y) { cycle in
                let journey = $y.journey
                let elapsed = cycle.elapsed / 1000
                journey.velocity += 180 * elapsed
                journey.value += journey.velocity * elapsed
                return abs(journey.destination - journey.value) > 0.5
                    ? .again
                    : .wait
            }
    }
}
```

Only a write to a state named in `following:` wakes a waiting engine. An
engine's own write does not wake itself; it explicitly returns `.again` when it
has more work. Engines run by ascending priority and stable registration order.
They do not await, call controls, or create another thread-bound UI model.

## Application sessions

The structural path is:

```text
Application -> Scene -> Window -> Page -> View
```

Each structural protocol has one composition property. A window's page is
any `Page` - every view is one, and so is each arrangement - and the page a
container puts a view on holds that view's `PageSession`. Runtime values
belong to identity-bearing sessions and are obtained with `@Environment`.

```swift
struct HandbookApp: Application {
    var scene: any Scene { HandbookWindow() }
}

struct HandbookWindow: Window {
    var page: any Page { HandbookPage() }
}

struct HandbookPage: ContentView {
    @Environment private var page: PageSession

    var content: any View {
        Label("Hello from StateUI")
            .onCreated { page.title = "StateUI" }
    }
}
```

An application can own multiple scene sessions. A scene owns its main window
and any windows opened from its declared `WindowGroup`s. Activation,
restoration, focus, hiding, and closure are mapped to those sessions while
StateUI retains deterministic state and tree ownership.

Navigation paths, tab selections, sidebar visibility, and modal stacks are
state. A control method is invoked through an `@Aim`; an aim identifies a
control and is not state.

## Deterministic ownership

The invariant across every host is one concept with one owner:

- Swift owns state, reader tracking, identity, tree construction, diffing,
  conversions, engines, and motion laws;
- the host owns native objects, native layout integration, input reports,
  platform lifecycle, and the display clock;
- application state owns navigation and presentation choices;
- `HostPatch` is the only reconciliation result a host applies.

The concrete control/property/event surface and its implementation status are
defined in [Platform contract](platform-contract.md). The typed boundary is
defined in [Host contract](host-contract.md).
