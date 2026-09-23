# Builders

A result builder turns the statements of a closure into the list a container
holds. StateUI has one for views, and one each for menu entries, windows,
window groups and styles. The view builder also gives every view it collects
a key.

## Statements become a list

Every method of `ViewBuilder` works on `[Element]`, never on one `Element`: an
`if` or a `ForEach` produces a list, and working in lists lets either stand as
one statement among the others. `buildBlock` joins the statements in writing
order.

## Every statement records where it stood

Each method also writes down where a view was written: the statement's number,
then which branch of an `if` it came from, then the statement's number inside
that branch. The segments nest into a path, and `Node.key` carries that path to
the differ.

```text
  VStack {
      Label("Title")                  0
      if signedIn {
          Label("Welcome")            1.some.0
      }
      if editing {
          TextField($name)            2.if.0
      } else {
          TextField($nickname)        2.else.0
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
      if signedIn { Label("Welcome") }
      TextField($search)
  }

  signed out:  [TextField]           the field is child 0
  signed in:   [Label, TextField]    child 0 is the Label
```

Matched by index, signing in would match the new Label against the field: a
changed type, so a replaced control, and the search field would lose its
focus, its caret and its scroll on every sign-in and sign-out. With the path
the Label is `0.some.0` and the field is `1` in both states, so the field is
matched to itself and never moves.

## Two branches are two elements

`if editing { TextField($name) } else { TextField($nickname) }` builds the same
kind of control in both branches. Matched by position they would be one control
that only changes its text, and the caret would stay put across what the author
wrote as a switch between two fields. `2.if.0` and `2.else.0` are different
places, so switching branches replaces the control rather than editing it.

## No plain for loop

`ViewBuilder` and `MenuBuilder` have no `buildArray`, so a plain `for` does not
compile in them. A turn of a loop has no identity but its number, and its
number is its position: a collection that gains a row at the top renumbers
every turn below it, and every view would be rebuilt as though it had changed.
`ForEach` is where repetition is written, and it keys each view by its item.

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

A statement may produce several views: an array handed to `buildExpression`, or
a branch holding more than one statement. Such a statement's segment gets a
number of its own under it - `0.0`, `0.1` - so the views do not all share one
path. That inner number is a position like any other. It does not matter for a
`ForEach`, whose views carry their items' ids, and an id wins over the path; it
is why a hand-built `[Element]` whose length changes wants `ForEach` instead.

## The path rides a wrapper

The segment is added by a wrapper, `Keyed`, and an item's identity by another,
`Identified`, rather than by a property on the controls. The builder is handed
an `Element` and must not care which kind: a Label, a composed view and a
hand-written `Node` take a segment the same way. The wrapper writes onto
whatever node the element builds, a composed view's placeholder included,
which is where a key has to sit for the differ to see it.

`body` is where the segment lands, and `body` is also where the parent asks for
the node, so a wrapped element is built no earlier than an unwrapped one.

## Menus collect without keys

`MenuBuilder` is shaped like `ViewBuilder` over the same `[Element]`: `if`,
`if/else` and `ForEach` work in a menu, and a plain `for` does not. It records
no path. An entry is matched by its `.id()` and otherwise by its position, so
an `if` whose entry comes and goes re-matches every entry below it against a
different one. A hand-written entry standing beside a conditional wants an id;
`ForEach` gives each of its entries its item's identity.

## Windows and styles

`WindowBuilder` answers one window. An `if` may choose between two, which
changes what the one window shows while the platform's window stays where it
is. `WindowGroupBuilder` collects a scene's groups, one per statement.

`StyleBuilder` keeps `buildArray`: a style is filed by its target type or its
key, so there is no identity to lose in a loop, and a sheet may use `for` and
`if` to answer a platform or a form factor. It erases each `Style<Target>` to
an `AnyStyle` as it takes it, the last point at which the target type is
known.
