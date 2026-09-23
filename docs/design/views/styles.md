# Styles

A style is the property values every control of a type wears. It is written
with the control's own modifiers and resolved on this side, before any patch
leaves.

## Styles are resolved before the patch

```text
  application.styles = StyleSheet {             a value in the application session
      Style<Label>().fontSize(14)               implicit: every Label
      Style<Label>("Headline").fontSize(32)     keyed: asked for with .style("Headline")
  }

  Label("Welcome").style("Headline")
        │
        ▼  the differ, for every element it builds: styled(_:with:)
  Label with the style's values under its own, and the states of both
        │
        ▼
  the patch: a control with every value already on it; no style crosses
```

Nothing about a style crosses to a host: the differ merges it into the control
it belongs to, so a host receives a control with every value already on it.
There is no style object, no resource lookup, and nothing in a host that has to
know what a style is, which keeps each host small enough to be written again
for another platform. The key a view asks for, `.style("Headline")`, is a name
- one spelling, one style - and the differ consumes it and takes it off the
node, the host having no dictionary to look one up in.

## A style wears the property half

A style is written with the modifiers its control has, chained on the style
itself. It conforms to the property half of its target's tiers and to nothing
else (tiers.md, two halves), so after the dot an author is offered exactly what
a style can carry: `Style<Label>().onTapped { }` and `Style<Label>().id("x")` do
not compile. The conformances are one line per tier and one per control's own
properties, and the modifiers themselves are written once for both.

The style takes its node type from its target's blank initializer, so the
target is named once, by the control itself. `StyleBag<Target, Context>` has a
phantom context - the style itself, or one of its states - whose one job is to
keep `visualState` from nesting: a state cannot hold a state. `Style<Target>`
is a typealias with the context filled in, since Swift has no default generic
arguments.

## Precedence

- A keyed style replaces the implicit one for the type, and a value written on
  the control beats both, one property at a time.
- A key naming nothing falls through to the implicit style, and so does a key
  naming a style declared for another control, whose values would be half
  applied and half dropped unread.
- Two styles under one key, or two implicit ones for one target, are one: the
  last wins, as a second assignment to one dictionary key does.
- `basedOn` is flattened when the sheet is built, against what was written -
  so a style may start from one written below it - and a chain costs a control
  nothing. A chain that comes back round to a style already being flattened
  stops there rather than looping over a mistake there is nowhere to report.

## Visual states

A visual state is a named state a control can be in - Normal, Disabled,
PointerOver, On - with the property values in force while it is there. Names
are spelled exactly as the host matches them: a state is matched by its name,
so unlike an enumeration member on the wire it is not camel-cased, and
"PointerOver" is the state while "pointerOver" is nothing. A state's name and
its group are names on the wire, not text: each repeats on every state sharing
it, and one spelling means one state wherever it is written.

`VisualState<Target>` carries its control type as a phantom, which makes the
list after the dot the states that control actually enters:
`Style<Switch>().visualState(.on)` compiles and
`Style<Button>().visualState(.on)` does not, because nothing moves a Button
into On, and a state nothing drives is a style that silently does nothing.

States ride as children of the control, appended after whatever it lays out,
where the host takes them out of the arrangement; a control's own states are
written into the same list the same way.

## The resting state

A control is in one state per group, and leaves a state only by entering
another in the same group. A group that names no resting state is therefore
given its target's, an empty state that changes nothing: a group whose only
state is Disabled would otherwise have no way back, and a control disabled once
would stay drawn that way for the rest of its life with nothing reporting it.

The resting state is `.normal` for every control but a RadioButton, which rests
in `.unchecked`. A RadioButton enters Checked or Unchecked first and Normal
after, so a group declaring Normal would end every transition there and the
pair would never be seen. A Switch and a CheckBox enter Normal first, so their
own states win over a Normal beside them. `StyleTests` pins the resting state a
group gets. `.unfocused` is entered straight after Normal, so a group declaring
both rests in Unfocused: it is a second spelling of Normal rather than the pair
of `.focused`.

## Arranging states

`visualStates(_:adding:resting:)` is the one place a list of states is
arranged, so a style and a control put theirs in the same shape:

- A state replaces one of the same name in the same group, where the first one
  was: a group holds one state of each name, so the second writing wins the
  values and not the position, and writing order is what the list reads as.
- A group that names no resting state is given its target's, empty.
- The resting state stands first, because a group opens in the state it
  declares first.

## States on a control over its style

A state written on a control is written over the state of the same name in its
style, one setter at a time, rather than replacing it - merging being what
every other value here already does. A control that declares `.pointerOver`
only to hear it keeps whatever its style paints there, and a state that sets
nothing changes nothing, which is why declaring one is safe. A state in a group
the style does not have is appended; both lists arrive arranged, so each
group's resting state already stands first among its own.

## Hearing a state

`onVisualStateChanged` runs when a control enters a state, which is where a
state can animate rather than only be set: a style's setters change at once,
and a handler can take as long as it likes. A control reports only the states
it declares - a host knows a state only from the list it is sent - so the
states named there are declared in `CommonStates`, merged into the style's
without changing how the control looks. Declaring a state can change which one
the control rests in, so only the states it should react to are named. A
report carries the state's name as text: an event payload is written without
a name dictionary, so a name arrives as text however it went out.

## The sheet

`StyleSheet` keeps every style in writing order, each with what it is based on
already under it. The implicit and keyed maps are places in that one list, not
copies of it, which also lets a test see a style filed twice where a dictionary
would show only the winner. A sheet is a value: two sheets saying the same
thing are the same sheet. The differ compares sheets once per render, only to
decide whether a composed view may still be carried - a sheet is not among a
view's inputs - and compares their states by hand, since a state is a node
carrying closures and cannot be `Equatable`.

## Applying a style

`styled(_:with:)` is the one place a style is applied, called by the differ for
every element it builds: after a composed view is unwrapped, since the real
node's type and key decide which style it wears, and before anything is sent.
It runs even with no sheet, because `.style("…")` is consumed there whatever
happens. It asks before it writes: assigning nil to a key a dictionary does not
have still makes the storage unique, so an unguarded removal would copy the
properties of every node in the tree, styled or not.

## What can be styled

Every control in `Views/` is a `StyleTarget`, the list kept in one place so it
can be read at a glance and a test can insist on it. A style target is any
control that can be made with nothing set, and each of them can: the
initializer taking the value that gives a control its purpose is one of
several, never the only one. A `SwipeAction` is not a target and cannot be: it
is a menu item rather than a view, with none of the properties a style would
set and no visual element to hang one on.
