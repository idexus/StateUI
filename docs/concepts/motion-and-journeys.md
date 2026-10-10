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

`Motion` has two destination-seeking laws:

- `.eased(length, curve)` takes the stated number of milliseconds and lands on
  the destination exactly;
- `.spring(response:damping:)` keeps standing velocity when retargeted and
  settles on the destination rather than at an unrelated resting point.

Three special values select ownership:

- `.inherited` resolves through the value or element, the application default,
  and finally `Motion.standard`;
- `.none` snaps to the destination;
- `.custom` leaves the walk to a StateUI engine attached to the state.

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
            ColorBox(.cornflowerBlue)
                .width(expanded ? 280 : 120)
                .cornerRadius(expanded ? 28 : 8)
                .motion(.spring(response: 280))

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
| `.size` | width and height plus outline and corner sizes |
| `.place` | host-arranged position and translation |
| `.transform` | scale, rotation, and anchors |
| `.spacing` | padding, margin, stack spacing, and grid spacing |
| `.text` | font size, line height, and character spacing |
| `.all` | every property, including one with no narrower group |

This lets size snap while placement travels:

```swift quote
VStack { content }
    .motion(.spring(response: 240))
    .motion(.none, .size)
```

Properties that represent an identity, index, count, selection boundary,
range, region, or layout rule are discrete even when encoded as numbers. They
do not acquire an in-between meaning merely because an interpolator could
process their bytes.

## Journey is part of state

Every `@State` whose value conforms to `Walked` has a journey. The state itself
remains discrete: reading it returns the destination immediately. Its journey
exposes what the host is showing between writes:

| Member | Meaning |
| --- | --- |
| `value` | visible value on the current host frame |
| `destination` | the state's ordinary value |
| `velocity` | per-second velocity, lane by lane |
| `motion` | law owned by this value wherever it is attached |
| `move(to:_:)` | set a destination; `arrived()` awaits its outcome |
| `stop()` | stop at the standing value |
| `snap(to:)` | set standing value, destination, and zero velocity together |
| `convert` | derive another host-driven value from live journey lanes |

The built-in `Walked` values are `Double`, `Point`, `Rect`, `Insets`, and
`Color`. Each has a fixed set of numeric lanes. A part binding and a binding
made from get/set closures do not own the complete storage image a host needs
to walk; move the complete state instead.

A move starts as it is sent and returns at once; its `arrived()` awaits the
outcome:

```swift quote
let arrived = try await $opacity.journey.move(
    to: 0.2,
    .eased(400, .cubicOut)).arrived()

if !arrived {
    // A newer destination, another write, or stop() ended this animation.
}
```

`true` means the value reached that move's destination. `false` means a newer
destination, another write to the state, or `stop()` superseded it. A move
already at its destination, or made while the user asks for less motion,
completes with `true` on the host's next frame; a state nothing wears yet
completes with `true` at once. A custom-engine state also answers at once
because the engine, rather than the host's animator, owns its completion.

The destination is written as `move` is called, so moves sent one after
another are in the air together, each awaited apart. An unrelated
body rebuild does not restart or cancel a journey: the motion channel belongs
to the state storage and continues from its standing value and velocity. A
later motion passed to `move` is retained as that value's law, so subsequent
plain writes use it until `journey.motion` changes again.

For a host-carried state, motion selection is:

1. an explicit law supplied to `move(to:_:)`;
2. the state's law from `@State(motion:)` or `journey.motion`;
3. the attached element's resolved law when the state says `.inherited`;
4. the application law, then `Motion.standard`.

One state is one host motion channel. Every control and driven property attached
to it observes the same standing value, destination, velocity, and completion.
Use separate states for independent animations.

## Stop, snap, and direct lane writes

`stop()` keeps the standing value and makes an active waiter return `false`.
`snap(to:)` synchronously makes the standing value and destination equal and
zeros velocity. It is the right operation for a measurement or report that was
observed rather than chosen as a destination.

Writing `journey.value` alone changes only the standing value. Writing
`journey.velocity` kicks the existing journey. These operations are primarily
for custom engines; an ordinary application decision writes the state or calls
`move(to:_:)`.

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
itself arrives while its place still travels. Where a frame under the layout is
read - an `onFrameChanged` handler, a driven frame - every child arrives,
because each step of a walk would report a room nobody chose. A child that
joins a layout already standing fades in under the same law, unless a state
owns its opacity.

Visibility motion and layout motion are part of the cross-platform contract,
but an application relies on them only where [Platform contract](../platform-contract.md)
shows verified host support.

## Custom engines

`@State(motion: .custom)` fixes who animates the state when it is first
registered. An engine reads destination, standing value, velocity, and frame
timing, and writes the next standing lanes. One declared with
`.engine(tracking:)` returns `.again` while it needs another frame or `.wait`
until a tracked state is written; one declared with `.engine(following:)` runs
on the display cycle after a state it follows is written - once, however many
writes came - and once after each render that describes its view. An engine's
own write does not wake it.

See [State and reactivity](state-and-reactivity.md) for conversions, sampling,
and engine composition, and [Host contract](../internals/host-contract.md) for the native
display-cycle obligations.
