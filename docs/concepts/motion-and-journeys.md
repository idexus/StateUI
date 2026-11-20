# Motion and journeys

StateUI describes a destination once. A native host that implements the
corresponding motion surface advances the visible value on its display clock,
while the Swift tree continues to say where the value is going. Motion
therefore does not create another state system or a frame-by-frame description
tree.

This chapter defines the semantic motion contract, not blanket platform
availability. An unverified host or unsupported `(NodeType, Prop)` pair must
still apply the final destination, normally by snapping. Only checked rows in
[Platform contract](../platform-contract.md) authorize reliance on the journey.

## Motion laws

`Motion` has three destination-seeking laws:

- `.eased(length, curve: curve)` takes the stated `Duration` - `.milliseconds(300)` -
  and lands on the destination exactly;
- `.spring(response:damping:)` takes how quickly the spring answers and how it is
  damped - `.spring(response: .milliseconds(260), damping: 0.8)`, 300 milliseconds
  and never past the destination where neither is said - keeps standing velocity
  when retargeted and settles on the destination rather than at an unrelated
  resting point;
- `.glide(longest:)` sets out at the speed the value has and slows onto the
  destination, as long as that speed takes to get there and no longer than
  `longest` - what a value thrown by the hand goes on with.

Two values name no timing:

- `.inherited` resolves through the value or element, the application default,
  and finally `Motion.standard`;
- `.none` snaps to the destination.

A state an engine of the application's animates says so where it is
declared, `@State(animatedBy: .engine)`, not by a motion
([An engine that animates](#an-engine-that-animates)).

`Motion.standard` is a 200-millisecond cubic-out movement. Reduced-motion input
may shorten or remove an animation, but never changes its destination.

## Described property motion

A property that depends on ordinary state rebuilds its reader once and places
the final value in `HostPatch`. A matching `HostTransition` tells the host how
to reach it:

```swift
struct MovingPanel: View {
    @State private var expanded = false

    var body: some View {
        VStack {
            Rectangle()
                .fill(.cornflowerBlue)
                .width(expanded ? 280 : 120)
                .cornerRadius(expanded ? 28 : 8)
                .motion(.spring(response: .milliseconds(280)))

            Button("Resize").onClicked { expanded.toggle() }
        }
    }
}
```

The host interpolates only a semantic `(NodeType, Prop)` pair it implements and
only between compatible value shapes. Unknown pairs, discrete properties, a
first value with no representable native starting point, and incompatible
compound values snap to their destination. The platform matrix records which
motion surfaces have native tests.

### Selection precedence

For an ordinary described property, StateUI chooses its law in this order:

1. the last `.motion(motion, values)` rule on that element whose group matches;
2. the element's `.motion(motion)` base rule;
3. `ApplicationSession.motion`;
4. `Motion.standard`.

A later selective rule wins over an earlier matching rule. An element's rule
applies to that element, not recursively to its descendants. A composed view
may supply a default motion plan, and modifiers written where it is used are
merged over that plan.

`MotionValues` groups semantic changes rather than platform properties:

| Group | Meaning |
| --- | --- |
| `.opacity` | opacity |
| `.color` | every color-valued property |
| `.width` | requested, minimum and maximum width, and the widths a layout gives its children |
| `.height` | requested, minimum and maximum height, and the heights a layout gives its children |
| `.size` | width and height |
| `.shape` | corner radius and outline width |
| `.place` | host-arranged position and translation |
| `.transform` | scale, rotation, and anchors |
| `.spacing` | padding, margin, stack spacing, and grid spacing |
| `.text` | font size, line height, and character spacing |
| `.all` | every property, including one with no narrower group |

This lets size snap while placement travels:

```swift
let content = Text("Content")

VStack { content }
    .motion(.spring(response: .milliseconds(240)))
    .motion(.none, .size)
```

Properties that represent an identity, index, count, selection boundary,
range, region, or layout rule are discrete even when encoded as numbers. They
do not acquire an in-between meaning merely because an interpolator could
process their bytes.

## A state and its journey

Every `@State` whose value conforms to `Walked` has a journey, `$value.journey`.
The state itself remains discrete: reading it returns the destination
immediately. The journey is a handle to how a host shows the value between
two destinations. It owns nothing and starts nothing:

| Member | Meaning |
| --- | --- |
| `sample` | where the host shows the value on this frame - its place, the destination it is taken to, its speed - or `nil` while nothing shows the state |
| `motion` | the motion this value travels under wherever it is shown; `nil` for a state an engine animates |
| `setMotion(_:)` | give the value the motion its next destination travels under |
| `move(to:_:)` | set a destination; the `MotionRun` it returns awaits how the movement ends |
| `reach(_:)` | where a motion would carry the value on alone, at the speed it has; `nil` while nothing shows the state |
| `stop()` | stop at the standing value |
| `snap(to:)` | put the value there at once: standing there, going nowhere, still |

The built-in `Walked` values are `Double`, `Point`, `Rect`, `Insets`, and
`Color`. Each has a fixed set of numeric lanes. A part binding does not own the
complete storage image a host needs to walk; move the complete state instead.

A state is shown once a control, a driven modifier or a scroller is handed
it; an engine following its journey and a reading of it count too. Only then
does the host carry it, and only then is there a sample:

```swift
struct Fader: View {
    @State private var fade = 1.0
    @State private var words = "100%"

    var body: some View {
        VStack {
            Rectangle().fill(.cornflowerBlue).height(40).opacity($fade)
            Text($words)
                .engine(following: $fade.journey) { _ in
                    guard let sample = $fade.journey.sample else { return }
                    words = "\(Int(sample.value * 100))%"
                }
            Button("Fade").onClicked { fade = 0.2 }
        }
    }
}
```

Every field of a sample is of one frame, and `sample.destination` is the
destination the host had taken by that frame: a state written since already
holds a newer one.

## A movement and its result

A move is a write of the destination, under a motion of its choosing: the
state reads the new value at once and every body that read it is built again,
as after an assignment, while the host walks the value there. It returns at
once, answering a `MotionRun`, whose `result()` awaits how the movement ends:

```swift
@State private var opacity = 1.0

let result = try await $opacity.journey.move(
    to: 0.2,
    .eased(.milliseconds(400))).result()

if case .reached = result {
    // The value stands at 0.2.
}
```

Every movement ends exactly once:

| Result | Meaning |
| --- | --- |
| `.reached(.animated)` | it traveled to its destination |
| `.reached(.immediate(reason))` | it was put there at once: it stood there already, its motion does not animate, or the user asks for less motion |
| `.superseded` | a newer destination, a snap or the user's hand took the value |
| `.stopped` | `stop()` ended it |
| `.detached` | nothing shows the state any more |
| `.notStarted(reason)` | no movement was made |

`.notStarted(.noReceiver)` is the answer where nothing shows the state: the
destination is written, and nothing moved. The other reasons say a refusal:
the state refuses the destination, an engine's state was given a motion, a
derived state has no way back.

The destination is written as `move` is called, so moves sent one after
another are in the air together, each awaited apart. A task cancelled while it
waits stops waiting; the movement goes on. An unrelated body rebuild does not
restart or cancel a movement: the motion channel belongs to the state and
continues from its standing value and velocity. A motion passed to `move` is
that move's alone: the next plain write, or a move that names no motion,
travels under the value's own again.

```swift
struct Drawer: View {
    @State(motion: .spring()) private var offset = 0.0

    var body: some View {
        Button("Open")
            .onClicked {
                $offset.journey.move(to: 300, .eased(.milliseconds(2000)))
                offset = 0   // on the value's own spring, not the two seconds
            }
            .translationY($offset)
    }
}
```

For a state a host shows, the motion is chosen in this order:

1. an explicit motion supplied to `move(to:_:)`;
2. the state's own, from `@State(motion:)` or `journey.setMotion(_:)`;
3. the application's motion, then `Motion.standard`.

One state is one host motion channel, and the channel is every receiver's:
each control and driven property attached to it shows the same standing value,
destination and velocity, and none of them decides the motion - an element's
`.motion(_:)` says how its own described properties travel. Use separate
states for independent animations.

## Stop and snap

`stop()` keeps the standing value and ends the movement `.stopped`.
`snap(to:)` synchronously makes the standing value and destination equal and
zeros velocity. It is the right operation for a measurement or report that was
observed rather than chosen as a destination. On a state nothing shows, a snap
is a plain write and a stop changes nothing.

## A throw

A gesture's report says how fast the hand goes, and its end how fast it
lifted. A cubic-out journey sets out three times as fast as it averages, so a
journey a third of that speed's way long leaves at the hand's speed and slows
to rest:

```swift
struct Strip: View {
    @State private var offset = 0.0
    @State private var start = 0.0

    var body: some View {
        Rectangle()
            .fill(.cornflowerBlue)
            .width(60)
            .height(60)
            .translationX($offset)
            .onPanUpdated { pan in
                switch pan.phase {
                case .began:
                    // Where the strip stands as the hand takes it - a throw still under way included.
                    start = $offset.journey.sample?.value ?? offset
                case .changed:
                    $offset.journey.snap(to: start + pan.total.x)
                case .ended:
                    let seconds = 0.8
                    let thrown = start + pan.total.x + pan.velocity.x * seconds / 3
                    // The nearest stop of every hundred points to where the throw would land.
                    let stop = (thrown / 100).rounded() * 100
                    $offset.journey.move(to: stop, .eased(.seconds(seconds)))
                default:
                    break
                }
            }
    }
}
```

`reach(_:)` answers the same question for a value already moving: where a
motion alone would carry it on from where it stands, at the speed it has.

## Visibility and layout motion

`isVisible` is a semantic visibility transition for a host that implements its
motion contract. On a continuing element, hiding retains the element while it
leaves, removes it from hit testing during that animation, and hides it after
the motion lands. Showing starts from the hidden presentation and enters. The
first description has no before-state to cross, and `.motion(.none)` makes
visibility an immediate flag.

Child placement is not an ordinary authored property. A layout emits one
`HostLayoutMotion` containing a law and `MotionLanes`; the host moves the
existing native child rectangle from its standing placement to the newly
arranged rectangle. `.place`, `.width`, and `.height` rules decide which lanes
travel. The Swift tree still sends only the final arrangement.

Why a layout arranges decides whether its children travel. An arrangement a
patch caused means the layout holds something different - a row inserted, a
card grown - so its children travel, under the layout's own motion or, where it
says nothing, the application's. A room that moves with no patch behind it - a
window resized, a sidebar dragged - is followed exactly, and so is a layout
whose own width changed: a child gliding after the user's hand is late on
every frame. A layout's first arrangement arrives. A size a child states for
itself arrives while its place still travels. A label or a button travels no
narrower than its words need, and a button whose new words need more room
than its box keeps showing its former words until the box holds the new ones. Where a frame under the layout is
read - an `onFrameChanged` handler, a driven frame - every child arrives,
because each step of a walk would report a room nobody chose. A child that
joins a layout already standing fades in under the same law, unless a state
owns its opacity or the child says how it enters.

Visibility motion and layout motion are part of the cross-platform contract,
but an application relies on them only where [Platform contract](../platform-contract.md)
shows verified host support.

## A view that enters

A view the tree gains can say how it comes. `.transition(_:)` names the
effect its entry sets out from, and the view travels from that effect to how
it stands:

```swift
import StateUI

struct Details: View {
    @State private var expanded = false

    var body: some View {
        VStack {
            Button("Details").onClicked { expanded.toggle() }

            if expanded {
                Text("More to read")
                    .transition(.symmetric(.opacity.combined(with: .translation(y: 12))))
                    .motion(.spring(response: .milliseconds(260), damping: 0.85))
            }
        }
        .spacing(12)
    }
}
```

A `TransitionEffect` is the view as it is drawn while absent: `.opacity`
faded out, `.translation(x:y:)` moved from its place, `.scale(_:)` drawn so
many times as large about its middle. `combined(with:)` puts effects together
in the order written: a move written after a scale is the move as written,
and a scale written after a move scales the move with the view. A
`Transition` holds the effect an entry comes from and the one an exit goes
to; `symmetric(_:)` is one effect for both.

| What happens | What the view does |
| --- | --- |
| it joins a layout already standing | enters from its effect, in place of the fade a joining view comes with |
| it appears with what holds it - a page shown, a window opened | is simply there; with `.initialAppearance(true)` it enters |
| a transition is given to it as it stands | nothing moves |
| the tree drops it | it goes at once |

The entry moves under the view's own `.motion(_:)`, else the application's:
a transition says no law of its own. Where neither animates, or the user
asked for less motion, the view is simply there. A number a state drives -
an opacity carried from a state - stays that state's, and the entry moves
the others.

Hiding a view with `isVisible(_:)` keeps the view and its state, and crosses
as [visibility](#visibility-and-layout-motion) does, whatever transition the
view declares.

## An engine that animates

`@State(animatedBy: .engine)` - the one `AnimationOwner` - fixes who animates
the state where it is declared: an engine of the application, registered with
`.engine(animating:)`, and no motion can be given to it later. On each frame
the engine is handed an `EngineMotion`: it reads the destination, where it
last put the value and at what speed, and says where the value stands now
with `update(value:velocity:)`, or `finish()` once it is there.

```swift
struct Ball: View {
    @State(animatedBy: .engine) private var y = 0.0

    var body: some View {
        VStack {
            Button("Drop").onClicked { y = y == 0 ? 160 : 0 }

            Rectangle()
                .fill(.cornflowerBlue)
                .width(40)
                .height(40)
                .translationY($y)
                .engine(animating: $y) { cycle, motion in
                    let seconds = cycle.elapsedSeconds
                    let pull = (motion.destination - motion.value) * 180 - motion.velocity * 24
                    let velocity = motion.velocity + pull * seconds
                    let value = motion.value + velocity * seconds

                    guard abs(motion.destination - value) > 0.5 || abs(velocity) > 1 else {
                        motion.finish()
                        return .wait
                    }
                    motion.update(value: value, velocity: velocity)
                    return .again
                }
        }
    }
}
```

A state has one animator. The engine runs when the destination is written
and again each frame it answers `.again`; `.wait` waits for the next
destination and is no arrival - `finish()` is what ends a movement awaited
with `move(to:)`. Where the user asks for less motion the value is put at its
destination for the engine, whose arithmetic is not run.

See [State and reactivity](state-and-reactivity.md) for conversions, sampling,
and engine composition, and [Host contract](../internals/host-contract.md) for the native
display-cycle obligations.
