# Styles

A style is the property values every control of a type wears. It is written
with the control's own modifiers and resolved on this side, before any patch
leaves.

## Styles are resolved before the patch

```text
  application.styles = StyleSheet {             a value in the application session
      Style<Text>().fontSize(14)               implicit: every Text
      Style<Text>(.headline).fontSize(32)     keyed: asked for with .style(.headline)
  }

  Text("Welcome").style(.headline)
        │
        ▼  the differ, for every element it builds: styled(_:with:)
  Text with the style's values under its own, and the states of both
        │
        ▼
  the patch: a control with every value already on it; no style crosses
```

Nothing about a style crosses to a host: the differ merges it into the control
it belongs to, so a host receives a control with every value already on it.
There is no style object, no resource lookup, and nothing in a host that has to
know what a style is, which keeps each host small enough to be written again
for another platform. The key a view asks for, `.style(.headline)`, is a
`StyleKey` typed by its control and declared once - one spelling, one style,
and a key of another control's or one misspelled does not compile - which is
written on the node as its name; the differ consumes it and takes it off the
node before the patch, the host having no dictionary to look one up in.

## A style wears the property half

A style is written with the modifiers its control has, chained on the style
itself. It conforms to the property half of its target's tiers and to nothing
else (tiers.md, two halves), so after the dot an author is offered exactly what
a style can carry: `Style<Text>().onTapped { }` and `Style<Text>().id("x")` do
not compile. The conformances are one line per tier and one per control's own
properties, and the modifiers themselves are written once for both.

The style takes its node type from its target's blank initializer, so the
target is named once, by the control itself. `StyleBag<Target, Context>` has a
phantom context - the style itself, or one of its states - whose one job is to
keep `visualState` and `basedOn`, which only the style itself says, out of its
states: a state cannot hold a state. `Style<Target>` is a typealias with the
context filled in, since Swift has no default generic arguments.

## Precedence

- A keyed style replaces the implicit one for the type, and a value written on
  the control beats both, one property at a time.
- A key naming no style of its own control falls through to the implicit
  style; two controls' keys spelled alike are two, since the sheet files a
  keyed style by its control's type and its key's name.
- Two styles under one key, or two implicit ones for one target, are one: the
  last wins, as a second assignment to one dictionary key does.
- `basedOn` is flattened when the sheet is built, against what was written -
  so a style may start from one written below it - and a chain costs a control
  nothing. A chain that comes back round to a style already being flattened
  stops there rather than looping over a mistake there is nowhere to report.

## Visual states

A visual state is a named state a control can be in - Normal, Disabled,
PointerOver, On - with the property values in force while it is there. A
control declares its states as data: each a name and its values. Nothing of a state crosses to a host; the differ resolves the
states into the values the control shows, as it resolves a style.

The two halves of a control meet a state as they meet everything else: a
state's look is the property half - `.visualState`, which a style carries -
and hearing a state is the event half - `.onVisualStateChanged`, which a
style cannot. A look set from a handler would reach no style and cost a
build of the body that holds it.

`VisualState<Target>` carries its control type as a phantom, which makes the
list after the dot the states that control actually enters:
`Style<Switch>().visualState(.on)` compiles and
`Style<Button>().visualState(.on)` does not, because nothing moves a Button
into On, and a state nothing enters is a style that silently does nothing.
For the same reason there is no state by a name of the author's own.

## Which state a control is in

A control's states come in one order: Disabled, Pressed, PointerOver,
Focused, On and Checked, Off and Unchecked. The control is in the first of
its declared states that holds, and in Normal, written or not, where none
does; that is the state `.onVisualStateChanged` hears. What each follows:

- Disabled: `isEnabled` false.
- Pressed: a button held down; PointerOver: a pointer over the control;
  Focused: the keyboard in it ([what the user does](#what-the-user-does)).
- On and Checked, Off and Unchecked: `isOn`, written or bound.

What the control shows lays the values of every state that holds over its
own, the first in that order winning a value two set: a disabled switch that
is on shows Disabled's values and On's where Disabled sets none. Normal's
values show only where no other state holds. Leaving a state is its values
stopping: the control's own come back, and a value only the state set is
cleared to the platform's. The values are ordinary
properties, so they cross under the control's motion: `.motion(.none)`
changes them at once.

A bound value is read as the element is described, which makes the element
that value's reader: the user turning a switch describes that switch again,
and no body.

## What the user does

What a state follows of the user is a contract event the control already
reports: a button's `pressed` and `released`, a view's `pointerEntered` and
`pointerExited`, the `isFocusedChanged` every visual element reports. The
differ hears them with handlers of its own beside the author's, and only
those a declared state follows. What they say is kept in the element's
`VisualInput` across its builds and read as a state, so a press describes that
element again from what its parent last wrote - the road a theme change takes
- and nothing else.

## Arranging states

`written(_:adding:)` is the one place a list of states is arranged, so a
style and a control put theirs in the same shape: a state written over one of
the same name stands where that one stood, with the second writing's values,
and a new one joins after the rest.

## States on a control over its style

A state written on a control is written over the state of the same name in its
style, one setter at a time, rather than replacing it - merging being what
every other value here already does. A control that declares `.pointerOver`
only to hear it keeps whatever its style paints there, and a state that sets
nothing changes nothing, which is why declaring one is safe. A state the
style does not have joins after the style's.

## Hearing a state

`onVisualStateChanged` runs after the render in which the control entered a
state, which is where a state can animate rather than only be set: a style's
values change with the render, and a handler can take as long as it likes. It
runs for a state entered, never for the one the control arrives in - first
described, or made again as another kind of control under the same identity -
as `.onChanged` does not. The states it names are declared without values,
merged into the style's without changing how the control looks, and only
they are heard; naming none hears every state the control declares, and
Normal.

## The sheet

`StyleSheet` keeps every style in writing order, each with what it is based on
already under it. The implicit and keyed maps are places in that one list, not
copies of it, which also lets a test see a style filed twice where a dictionary
would show only the winner. A sheet is a value: two sheets saying the same
thing are the same sheet. The differ compares sheets once per render, only to
decide whether a composed view may still be carried - a sheet is not among a
view's inputs - states included, which are values like the rest.

## Applying a style

`styled(_:with:)` is the one place a style is applied, called by the differ for
every element it builds: after a composed view is unwrapped, since the real
node's type and key decide which style it wears, and before anything is sent.
It runs even with no sheet, because `.style(…)` is consumed there whatever
happens. It asks before it writes: assigning nil to a key a dictionary does not
have still makes the storage unique, so an unguarded removal would copy the
properties of every node in the tree, styled or not.

## What can be styled

Every control in `Views/` but the ItemsView is a `StyleTarget`, the list
kept in one place - `StyleTarget.swift` - so it can be read at a glance and a
test can insist on it. A style target is any control that can be made with
nothing set, and each of them can: the initializer taking the value that
gives a control its purpose is one of several, never the only one.

An ItemsView is none. It exists only with its items, and it is generic: a
style would have to name one kind of list while it styled every list, and
its own layout is a method of the list rather than a property a style can
carry. A list's look is its own modifiers', shared across an application as
any Swift is - an extension or a composed view - and every host records its
`style` member unrealized, with that reason. Were lists ever styled, the one
spelling that keeps every control alike is a style naming a contract
(`Style<ItemsViewContract>`) rather than a view.
