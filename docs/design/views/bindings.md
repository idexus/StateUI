# Bindings

Every property a view has can be handed a state instead of a value. The value
modifier takes a value; its binding twin takes the state as `$x`, and the host
carries it. A property whose value moves is then never a reason to build the
view again. This is the second of the core's two reactive paths: a value
reaches a native control with no rebuild, and the user's change comes back
into the state.

## Binding twins

What the host does with a carried state follows from the value:

```text
  journey   a number, a colour, a thickness,     the host animates the property there under the
            an inset, a point                    element's motion; $x.journey is the animation,
                                                 and .motion(.none) lands it at once. Reading the
                                                 state answers where the value is going.

  plain     a Bool, an Int, a member of a        the host sets the property as the value stands,
            closed vocabulary, and numbers       on its own frames, with nothing animating
            that never animate: a range's
            ends, a spacing, a step

  words     a String                             the host writes the text, as it writes a
                                                 driven text
```

Each twin is one line over one of three helpers of `PropertyContainer` -
`journey(_:by:)`, `plain(_:by:mode:)` and `words(_:by:mode:)` - and
`Bound.swift` is generated from the value forms.
`testEveryValueModifierHasABindingTwin` holds the two lists together: a value
modifier added without its twin is named there. The few allowed out are listed
with their reason - a value the host cannot be handed whole (a brush, a
picture, a date, a shape, a transform), a name rather than a value (a style
key, a font family, a radio group), a rectangle, and the tiers no view wears.

## The image never the value

A registration takes the state's image - the storage the host carries it on -
and never reads its value. Taking the image asks the host to carry the state
and reads nothing at build, so handing `$x` to a control does not make the
body a reader: a write renders only a body that reads the state somewhere
else, and a value moving many times a second rebuilds nothing.

After the registration no message mentions the property. The host reads it
off the image on its own frames: the state's value says where it is going, a
written `$x.journey.value` is a jump and a `velocity` a kick. A value moving
under a finger costs the arithmetic and nothing else.

A part of a state (`$room.width`) has no image of its own for the host to write
into, and a binding made from closures has none either. A driven property
refuses both with a complaint naming the property; a two-way control falls
back to its described form instead.

## Element side only

The twins sit on the element-side tiers - `VisualElement`, `View`, `Layout`,
`StackBase`, `Shape`, `InputView`, and the control itself where the property is
one control's own - and never on the `…Properties` protocols the value forms
sit on. A `StyleBag` wears every property protocol there is, so a twin written
there would appear inside `Style<Label>`, where it would compile and mean
nothing: a style is driven by nothing. The mixins have no element half, so
their twins are written `where Self: VisualElement`.

## Modes

No twin takes a mode, because an argument that cannot change lies. The mode is
`.inOut` for every property the host animates: a journey's `value` means where
the value is, so a carried property has to report where it got to, and `.out`
would refuse what the platform reports and make the value untrue.

The other modes are stated by whoever knows. A placement and a caption are
`.out`: there is nothing to report. A frame is `.in`: the host tells the state
where the layout put the view. A field's text is `.inOut` with nothing
animating, what the user types landing on the state. An application
registering a control of its own picks the mode on the public
`setValue(_:on:mode:kind:)`, because only it knows whether its property is one
the platform answers.

## A stated value beside a driven one

A value and a state may stand together on one property:
`.opacity(dim).opacity($fade)`. A change of the stated value crosses as a value
like any other, a write to the state crosses as nothing, and the newest of the
two destinations is the one in force.

## Driven text

Text cannot be interpolated, so nothing animates it: the host writes a text
property when its state is dirty and its bytes differ from what it last wrote.
That makes a driven text the way to show a moving number - a slider, an engine
following it, a label - for no render at all. What it costs is measuring the
label again on the frame the words change, which any changed caption costs.

There is no driven `text` on the `TextElement` tier, though the value form sits
there. A Label's and a Button's text is `.out`, written by the host and
reported by nobody. The text of a `TextField`, a `TextEditor` and a
`SearchField` goes both ways: the user types into it, and the typed words land
on the state whole as the host's own write. The two directions differ per
control, so the driven text is written per control.

## Two way controls

A control the user changes - a switch, a check box, a radio button, a picker,
the date and time pickers, a slider, a stepper, the text fields, a refresh
view - takes its binding in one of two ways, decided by the binding:

```text
  $x of a @State or @Binding      handed over: the host sets the control from the state on
                                  its own frames and lands the user's change on it as its
                                  own write. The control is no reader of the state, and
                                  what a change costs is decided by who reads the state.

  a part of a state, or a         described: the value read at build goes into the
  binding made from closures      description, and each report is written back through the
                                  binding. The closure that wrote the control is a reader
                                  and renders on every report.
```

The date and time pickers carry their value as three lanes: year, month and
day, or hour, minute and second. A value the platform cannot show - a day
outside the picker's range, a time longer than a day - is shown as the platform
clamps or folds it while the state keeps what was written; the user's next
choice lands the value shown.

## Both spellings

A two-way control takes its binding in the initializer - the short way to say
what gives the control its purpose - and in a modifier of the same name, the
way every other property is written: `TextField($name)` and
`TextField().text($name)`. The initializer delegates to the modifier, so there
is one body and neither is the real one. A value modifier written beside the
initializer's binding wins for the value, while the binding goes on being
written back to, which is how the two can then disagree.

`RefreshView` is the exception: its two-way form is the initializer alone,
`RefreshView($refreshing) { … }`.

## A report lands before its handler

A control's report lands on a carried state before its event handlers run,
wherever the binding is written in the chain, so a handler reads the value
already in the state. Over a described binding, the binding is itself a
handler and handlers run in writing order: one written after the binding sees
the state updated, one written before it still sees the old value. The payload
carries the new value either way.

## Feeds

A feed is a value only the platform knows, written into a state:
`.frame($room)` writes the frame layout gave the view, and `.panX($turn)` and
`.panY` write how far a drag has moved. Nothing this side writes reaches the
platform through them. A pan feed writes the state's number onto the view, so
the platform knows where to report, and reads nothing at build, so a drag
under a finger rebuilds nothing while an engine following the state places
views frame by frame. A drag moves the value on from where it stood rather than
setting it, so a second drag carries on where the first left off.

## Sampling an animating value

A state is at its value the moment it is written: `fade = 0.1` puts the
destination on the state at once and the host animates the control there, so
reading `fade` answers where it is going from the first frame to the last.
Where it has got to is the journey, `$fade.journey.value`, and reading that in
a body builds the body on every frame the value moves. `.samples(_:into:_:)`
is the road between: some of those frames, copied into an ordinary state that
renders under the ordinary rules while the source goes on costing nothing.

A reading copies only what changed, so a landed value writes nothing, and the
host stops sending once the state channel stops moving. The last frame of an
animation is booked for the end of its window rather than dropped, so the
sample ends where the value did. The copy reads the lanes directly rather than
through the journey's own read: a reading is not a view depending on the
value, and a read recorded mid-render would make whatever element is being
built a reader of a state it never mentions. Several views may read one source
into several states at several rates; each reading has its own window.

## A finger takes a moving thumb

A slider or a stepper carries its `Double` as a journey. An assignment
(`volume = 1`) sends the thumb there under the element's motion, and
`.motion(.none)` on the slider lands it at once. A drag is written onto the
journey's value and destination together, so nothing aims the thumb out from
under the hand holding it; a report raised inside the host's own write is the
host hearing itself, and is dropped. A finger that takes a thumb already moving
ends the old animation where the user put it: its first report zeroes the
velocity and resumes an awaiting move with `false`.

A reading that keeps up with every report is a text an engine following
`$volume` writes, or `$volume.convert { … }`; a body that prints `volume`
renders once per report.
