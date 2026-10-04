# Builders

A result builder turns the statements of a closure into what a container
holds, or into one view. StateUI has one for views - a page position takes one
view through it, an `if`/`else` or `switch` keying each branch - one each for
an application's scenes and a scene's windows (`ApplicationBuilder`,
`SceneBuilder`), and one each for
a menu bar's menus, menu entries, toolbar items, text runs, markers, styles
and a canvas's drawing. The view builder also gives every view it collects a
key.

## The result says what was written

The view builder keeps the type of what it was given. One statement stays what
it is, so one view is one view. An `if`/`else` is an `Either` of its two
branches - a view where both branches are views - an `if` with no `else` an
optional, several statements `Statements`, repetition a `ForEach`, and a list
of `any View` an array. Everything a container holds is `Views`: every view is
one, and so is each of these. A composed view's `body` and a one-view slot
take a `View`, so two statements or an `if` with no `else` there do not compile,
and neither does `VStack { ToolbarItem("Save") }`: an action, a run of text, a
marker and an arrangement of pages each go where they belong. A modifier on a view
gives back a view (`View where Modified: View`), so a chain goes on on
`any View` as on a view of a known type.

The builder has no `buildExpression`. An overload taking `any View` is chosen
for every view and erases it while type-checking stays green, so a value held
as `any View` goes in explicitly, as `ModifiedContent(node: view.node)`. A
function returning views is `@ViewBuilder` and `some View`: several `return`s of
different types become an `if`/`else`.

## Every statement records where it stood

Each piece also writes down where a view was written, as its nodes are made
(`Views.nodes`): the statement's number among several, then which branch of an
`if` it came from, then the statement's number inside that branch. A lone
statement adds no number. The segments nest into a path, and `Node.key` carries
that path to the differ.

```text
  VStack {
      Text("Title")                  0
      if signedIn {
          Text("Welcome")            1.some
      }
      if editing {
          TextField($name)            2.if
      } else {
          TextField($nickname)        2.else
      }
  }
```

The differ keys a child by its explicit `.id()` first, then by this path, then
by its position. The path never crosses to a host; it only decides which
element a view is.

## Why position is not identity

Flattening loses the shape of the closure. Without the path the differ would
have only the index to go on:

```text
  VStack {
      if signedIn { Text("Welcome") }
      TextField($search)
  }

  signed out:  [TextField]           the field is child 0
  signed in:   [Text, TextField]    child 0 is the Text
```

Matched by index, signing in would match the new Text against the field: a
changed type, so a replaced control, and the search field would lose its
focus, its caret and its scroll on every sign-in and sign-out. With the path
the Text is `0.some` and the field is `1` in both states, so the field is
matched to itself and never moves.

## Two branches are two elements

`if editing { TextField($name) } else { TextField($nickname) }` builds the same
kind of control in both branches. Matched by position they would be one control
that only changes its text, and the caret would stay put across what the author
wrote as a switch between two fields. `2.if` and `2.else` are different
places, so switching branches replaces the control rather than editing it. The
same holds where the branch is a composed view's whole content: the content
root's branch is part of what the element is
([another kind of view](../core/identity-and-diffing.md#another-kind-of-view)),
and so is a `ForEach` row's, whose builder takes an `if`/`else` too.

## No plain for loop

The builders but `StyleBuilder` and `DrawingBuilder` have no `buildArray`, so a plain `for` does not compile in them. A turn of a loop has no identity but its number, and its
number is its position: a collection that gains a row at the top renumbers
every turn below it, and every view would be rebuilt as though it had changed.
`ForEach` is where repetition is written, and it keys each view by its item;
where views are not what is repeated - menu entries, toolbar items, runs, markers -
an array of them stands for the loop, each matched by its `.id()`.

## ForEach keys are text

`ForEach` writes each item's identity - `String(describing:)` of the item, or
of the part `id:` names - into the view's `id`. Identity is text wherever a
value names an element: `.id(_:)`, a navigation route, a tab, a modal sheet, a
menu entry. One value therefore means one thing wherever it is given.

The trap is a type that describes itself with less than it holds. A
`CustomStringConvertible` printing one field of a compound key gives two values
one identity, and the differ then tells those views apart by where they stand
rather than by what they are. A synthesized description of an enum or a struct
carries every field and is safe. A class prints its type's name for every
instance, so a class is identified by something it holds.

An author's own `.id()` on the view wins over the item's.

## Several views from one statement

A statement may produce several views: an array, or a branch holding more than
one statement. Such a statement's segment gets a number of its own under it -
`0.0`, `0.1` - so the views do not all share one path. That inner number is a
position like any other. It does not matter for a `ForEach`, whose views carry
their items' ids, and an id wins over the path; it is why a hand-built array
whose length changes wants `ForEach` instead.

## The path lands on the node

A piece writes its segment onto the nodes its views build (`BuilderPath`), a
composed view's placeholder included, which is where a key has to sit for the
differ to see it; a `ForEach` writes its item's identity as the node's `id`. A
Text, a composed view and a hand-written `Node` in `ModifiedContent(node:)`
take a segment the same way. A container asks for the nodes in its producer,
so its views are built no earlier than before.

## Menus collect without keys

`MenuBuilder` collects `[Element]`, and its expressions are a menu's entries
alone - a `MenuItem`, a `Menu`, a `Divider`, a list of items - so a view
in a menu does not compile. `if` and `if/else` work in a menu, and a plain `for`
does not. It records no path. An entry is matched by its `.id()` and otherwise
by its position, so an `if` whose entry comes and goes re-matches every entry
below it against a different one. An entry standing beside a conditional, and
each of a list of entries that changes, wants an id. `MenuBarBuilder`, `ToolbarBuilder`, `TextSpanBuilder` and `MarkerBuilder`
collect one type each - a `Menu`, a `ToolbarItem`, a `TextSpan`, a `Marker` - the
same way, an array of them standing for a loop.

## Scenes and styles

`SceneBuilder` collects a scene's windows - a `WindowGroup` or a `Window`, in
any number and order, and an `if` for a window only some builds declare; an
unavailable overload with a message of its own refuses a view written where a
window belongs and a scene inside a scene. What a window shows is chosen
inside its view, where an `if` changes what the one window shows while the
platform's window stays where it is. `ApplicationBuilder` collects the
application's scenes the same way, a window written there being a scene of its
own, and refuses a view.

`StyleBuilder` keeps `buildArray`: a style is filed by its target type or its
key, so there is no identity to lose in a loop, and a sheet may use `for` and
`if` to answer a platform or a form factor. It erases each `Style<Target>` to
an `AnyStyle` as it takes it, the last point at which the target type is
known.
