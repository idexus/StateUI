# Composition

An application builds its interface out of composed views - `ContentView`s -
and the library builds several of its own the same way: `FrameReader`,
`PlacedLayout`, `ScrollReader`, `GalleryView`, `ItemsView`, the inspector. A
composed view is a value that says what it is made of; the differ decides when
that is read.

## A composed view is a placeholder

`ContentView.body` does not build the content. It answers a placeholder node
(`Node.composed`) carrying the view's value, its state boxes, its inputs and a
closure that builds the content:

```text
  Header("Settings")                   the author's value
    └─ body ─▶ Node(type: Composed)    placeholder: the view, its @State boxes,
                                       its inputs, and a closure for `content`
                 │
                 ▼  the differ, once it knows whether this view stood here
                    last render (by its key)
               hands the @State boxes the storage their predecessors held,
               then runs `content` - or carries the view whole when its
               inputs are unchanged and no state it read has moved
```

The differ builds the content only once it knows whether this view stood here
last render, because only identity can decide which storage a `@State` box
takes over. So a view's state survives every rebuild, and the content is read
the first time and again only when what the view was built with, or a state it
read, changes.

## A modifier on a composed view

A composed view has no node of its own to keep a change in: `content` is built
afresh every time it is read, so a change stored on the composed value would be
gone by the next render. A modifier written on one therefore gives back a
`ModifiedContent`, a wrapper holding the placeholder with the change written
into it, and the differ writes what accumulates there over the built content.
That is why `PropertyContainer.Modified` is an associated type rather than
`Self`.

`ModifiedContent` offers what every view has - margin, opacity, grid placement
- and nothing only some views have: what is inside might be a Label or a stack,
and `.fontSize()` on one would be a promise the library cannot keep. Because
those modifiers return a `ModifiedContent`, a composed view's own modifiers
come first in a chain, and an aim is written directly on the initializer's
result.

## What goes in the initializer

A control and a composed view are configured the same way. What it is - the
value that gives it its purpose - goes in the initializer and has no default.
Everything a caller may leave out is a modifier returning `Self`: one copy, one
assignment into a `private` field, which also keeps the memberwise initializer
from being a second way in. An optional purpose value is a second initializer
delegating to the first, never a defaulted parameter. Every control also has
an initializer that sets nothing, which is what a `Style` of it is written
against.

## Container content runs when the differ reaches it

A container keeps its content closure (`Node.producer`) and runs it only when
the differ describes that container, not when the author's line constructs it.
A closure written inside a carried view therefore never runs; an ancestor's
`.environment()` is in scope when it does; and the reads it makes land on this
container and no other. The reader of a state is the closure that read it -
the innermost container whose content did, or the body - and that is what is
built again when the state moves, while everything around it is carried.

## Reads an engine makes are recorded nowhere

An engine runs on the host's frames, outside any render, so a state it reads
makes nothing a reader. A value that decides what a view looks like must be
read in the body and handed to the engine's arithmetic. `GalleryView` reads its
shape and whether its cards are animating in its body for this reason: read
only inside the engine, a change of shape would move nothing, arm no engine,
and leave the cards in the shape they were last placed in.

## A watcher is a view of its own

`.onChanged(value)` compares the value it was described with, so whatever
writes the watcher reads the value at build - and whatever reads a value is
built again when it moves. A watcher written on a view that holds many others
makes that whole view rebuild for every change it watches.

The library's own composed views put such a watcher in a view of its own: an
empty view beside the ones it serves, reading the value so the read is its
own. `GalleryView`'s `Turning` watches the asked position and shape, and every
card crossed rebuilds that empty view rather than the deck. Handlers that need
the value when they fire ask it through a closure rather than reading it at
build.

## Items held behind a class

The differ finds a composed view's `@State` by walking its stored properties,
into structs, enums and collections, since a view may keep another view - and
that view's state - in a stored property. The walk stops at any class. A
composed view that holds data - a layout's items, a list's groups, a gallery's
cards and their face closure - keeps it behind a private class (`Source`), so
the walk does not visit every field of every item on every render to find
state that is never there. For a list of many thousand items that is the
difference the list exists for.

## State declared first

The library's composed views declare their `@State` first, above the stored
properties that may hold other views. A box is adopted next render by its path:
the stored property's name at every level, the branch a keyed child came from
and the type of any view stored along the way. A view stored below may carry
boxes of its own under paths through it, and the view's own state stays apart
from them at the top.

## Handlers capture locals

A composed view that holds a class builds its handler closures out of locals -
the state wrappers, the bindings, the values it needs - rather than capturing
`self`. A handler closure that captures such a view can leave the main actor,
where every handler runs.
