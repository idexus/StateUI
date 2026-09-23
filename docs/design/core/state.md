# State

`@State` is the one declaration of mutable state (Core/State/State.swift).
Where it is used decides its role: read in a body, it rebuilds that body when
written; handed to a control or a driven modifier as `$x`, the host carries it
and no body is rebuilt for it. This note covers how a state is stored,
borrowed, carried, kept and provided.

## Storage and box

```text
  @State var count        a State box, rebuilt with its view every render
        |
        v  adopt(from:) - the differ hands a fresh box its predecessor's storage
  State.Storage           the value, its lock, its name, its image; the one
                          object that means "this state" across renders
        |
        v  once a host carries it
  HostStorage             the value as bytes both sides read (the image)
```

The value lives one level deeper than the box, and that is load-bearing. A
view is rebuilt every render, so its `@State` comes back as a new box holding
the initial value; the differ makes the new box adopt the old one's storage, so
every box that ever stood for this state points at one storage. A handler that
captured last render's box then writes where this render reads. Copying the
value instead of sharing the storage would lose the write of a handler
suspended across a render.

The lock lives on the storage, not the box, because two boxes sharing a storage
must share its lock. The storage is internal so tests can hold its invariants
directly; no public signature names it.

## The initial value waits

The expression beside a declaration is held as a closure until a storage nobody
adopted is first read. Evaluated eagerly, it would run on every render of every
view described and be thrown away by the adoption. The value is kept as an
optional one level deeper than `Value`, so a state holding `nil` is told apart
from a state with no value yet.

## Writes from any thread

A state may be read and written anywhere. The value sits behind the storage's
lock, a write marks the tree and wakes the host from whatever thread made it,
and a write that lands while a render runs is kept for the next one. A handler,
a `Task.detached` and an `async let` child can all write without hopping first.

What no two tasks may do is read a value, think, and write it back expecting
both to count: `counter += 1` is a read and a write, two holds of the lock.
That is right from a handler, where nothing runs between them, and wrong for
two tasks at once; `update(_:)` holds the lock across all three steps. On a
state the host carries, `update` is a read and then a write, because the host
rewrites the image on its own frames and nothing here can bracket that.

A write and the save it records happen under one hold. Two tasks writing a kept
state at once could otherwise settle the value in one order and reach the
store in the other, leaving the newer value in memory and the older one on
disk for the next launch.

## Bindings

A `Binding` is two closures - read and write - plus who it borrows from: the
storage behind a `@State` (`lender`) and which part of it (`lent`). `$counter`
builds a new binding every time it is written, so two spellings of one state
are two values; the lender is how they recognize each other. Only `described`
reads it, and it answers the storage behind a whole `@State` and nothing for a
part of one or a binding made from closures. The host's image, the journey and
an engine's following all hang off it.

`$` lends a capability: a borrower may write the whole value or one property of
it, and a model lent this way may be edited or replaced outright. Handing over
less is done by handing over less - the value to read it, the object to edit
what it holds, `$` to do everything the owner can. A class of `@State`
properties is lent the same way; there is no second wrapper for it.

A binding to a property of a value (`$profile.name`) reads the whole, writes
the property and puts the whole back. For a class, a `ReferenceWritableKeyPath`
writes straight into the object both sides hold; Swift prefers that overload
wherever both fit, which keeps a model's own binding from being rewritten on
every keystroke. A part of a state has no storage of its own: a control handed
one reads it at build and writes through the whole, and a driven modifier
refuses it - four bars the host animates are four states.

## Reading without recording

`Binding.standing` reads the value without recording a dependency. It is what
the machinery of a write uses - `move`, `stop`, `snap(to:)` and the journey's
setters read what they are about to change - because a write reading its target
is not a view depending on it. Recording would be worse than useless: a
completion answered while a render runs resumes the handler inside that build,
so the read would land in whatever element's scope is open and make it a reader
of a state it never mentions.

## Model state

A `@State` declared inside a class is reached through the wrapper's
enclosing-instance subscript: Swift routes the property through the wrapper's
type with the instance in hand. The value is the storage's, read and written as
`wrappedValue` would, so `profile.visits += 1` rebuilds the closures that read
`visits` and none that read `name`.

The instance buys the name. The reflection walk that names a view's states
stops at a reference, so the first access through any of a model's states
reflects the instance once and names every state it holds by its property;
every access after that is one nil check. The subscript is declared in the
class body, not in an extension: the compiler looks it up on the wrapper's own
declaration and silently passes over one in an extension, and the property then
goes through `wrappedValue` unnamed.

The model's own `$name` is the whole state - carried by the host when a control
is handed it. `$profile.name`, through a key path, is a part of the state
holding the model.

## Carried state

A state handed to a driven modifier, a feed or a two-way control is carried by
the host on an image (`HostStorage`, Core/Carried/HostStorage.swift). The image
is made the first time anything asks, from the value as it stands, and kept on
the storage - a box is remade every render, and the number the host quotes the
value by is issued against the image. From then on the value lives on the
image: reads decode its lanes, writes lay theirs, and the box's own hold is
empty, because two homes for one value would be two answers.

A carried state and one only read in bodies cost differently: handing `$x` on
reads nothing at build, so it makes no body a reader, and a value the host
moves sixty times a second costs a render only where a body prints it.

## A state has one shape

An image is either the value's own lanes (a feed, a text, a plain value) or a
journey's (`JourneyLanes`: a driven property, a slider, a scroller). One state
has one shape. A state handed to both is refused with a complaint: declare a
second state for the other role. The one exception is an image the host has not
been told the number of yet - made by a hand-over the differ has not
registered, in the same body that now hands the state to a slider. It is
reshaped rather than refused, because the host has no picture of it yet.

## What the host writes back

A host write is a write: it ends where this side's do, and the storage decides
by its readers. A host that writes back the value this side last wrote - a
switch reporting where it already stood, an animation landing on the
destination this side sent - asks for nothing. The storage keeps the bytes or
the destination it last knew and compares against them.

On a journey image the host's writes are told apart by lane. A moved
destination is the state's own value moving (a drag, a press): every reader is
asked. A frame of an animation moves only the value and velocity lanes: only
the journey's readers are asked (journeys.md).

## A state nobody wears

Until an element registers a state, the host has no number for it and nothing
animates it. A write then puts the value at the destination as well, standing
still, so a view described later shows it from its first frame. `.custom` is
the exception: its animator is an engine on this side.

## Themed colours on a carried state

A colour pair (`Color(light:dark:)`) written into a carried state keeps the
pair on the storage, and the image holds the half in force: lanes are one
colour. Every driven modifier that hands the state on reads the theme as it
does, which makes that element the theme's reader; a theme change builds it
again, and the host animates the colour to the other half. The pair is let go
when the host moves the value somewhere else.

## A write that lands

`Binding.land` writes a report - a value the platform measured or the user
moved - so that it lands where it is rather than animating there: value,
destination and a speed of nought together. The state's readers are asked as
for every write. A landed value is not saved: a measurement is not a setting.

## Kept state

`@State(persistentKey: .key)` is an ordinary state that is also kept. Reading
a state is synchronous, so the value has to be in memory before the first view
is built, and the host hydrates the whole store before the first render. It
reads a store key by key, each with its kind, so the application lists its keys:

```text
  1  the host asks for the keys and the store     stateui_persistent_keys
  2  it reads exactly those from the store
  3  it hands back what it found                  stateui_set_persistent
```

A key the store has nothing under is absent, and the state keeps the value
written beside its declaration - which is where the default can be seen.

A write lands in memory at once and marks the key. The saves go out as one act
per key per take, sorted by name, holding the last value: a key written five
times inside one handler is saved once. It is a collapse per drain, not a
delay. A write to a kept state wakes the host itself, and waiting saves count
as pending work, because a kept state nobody reads asks for no render and its
save must not wait for the next event.

One key is one piece of state: two views declaring a key share its storage, so
a write in one rebuilds the readers in the other. The first state to claim a key
decides the storage, under one hold of the store's lock; two holds would let two
tasks each see nothing standing and adopt their own. A storage claimed before
the host's read arrives - an application's own keyed state is built as the app
registers - takes the stored value when `hydrate` runs, still ahead of the
first view. The storage's lock comes before the store's everywhere: a save is
recorded from under the storage's lock, so `hydrate` lands values after
releasing its own.

The key's kind must match the value's type, checked when the state is made. The
label `persistentKey:` is the argument's own type, lowercased, as `motion:` and
`sceneKey:` are: there is one kind of state, and the brackets say only what else
is true of one. The unlabelled position already means the initial value.

## Scene-kept state

`@State(sceneKey: .key)` keeps a value per scene, handed back with the scene
when the system restores the application's windows. A view is a value made
before the walk decides where it stands, so the state is paired with its scene
by the build that finds it there; one made inside a scene's build - a model a
scene's state creates - claims at once. Each scene record keeps its own
storages, restored values and waiting saves, which go out as one act per key
per take (scenes.md).

## The environment

`.environment(object)` provides an object to a subtree, and
`@Environment var x: T` on any view below resolves the nearest object of that
type: the annotation is the key, so there is nothing to spell and nothing to
collide. Nothing about it crosses to the host.

```text
  .environment(obj)   stored on the node, outside the wire
  the differ          keeps a stack of provided objects as it walks, in both
                      walks, and fills each @Environment slot BEFORE the body
                      builds; refilled on every build, never adopted
  invalidation        untouched: reading a provided object's @State records the
                      read as for any object; the provider only passes a
                      reference, so only replacing the object rebuilds it
```

A carried view's inputs cannot see a provider above it replacing its object, so
the differ compares a snapshot of the visible providers too
(identity-and-diffing.md). The standard providers - battery, connectivity,
display, locale, device, application info and the four sessions - are there
without anybody writing `.environment()`; a slot nothing filled answers the
standard provider of its type, which is what lets the application itself
declare `@Environment`, its `init` and `scene` running outside the differ. A
type neither provided nor standard stops the program with its name: an
environment that silently answered nothing would be the failure this library
refuses everywhere. The projected binding lends the object's properties and
refuses to replace the object, which is the ancestor's to provide.

## Element sessions

An `ElementSession` is an object an element holds for its life: made the first
time the element is built, kept on its `RenderedNode`, handed back on every
build while the same kind of view stands there, and offered to everything under
it by its type. It is how a page has a session: the view a page shows is a
value its parent constructs afresh on every render, so nothing stored on the
view outlives a build - the page's element does.

## An observable model

`@Observable` and a class of `@State` properties read as two spellings of one
thing and are not. Both report writes, to different listeners. A `@State` calls
the renderer; `@Observable` notifies whoever armed an observation scope around
the read, and nothing here arms one. A write to such a model would leave the
interface showing the old value with nothing failing anywhere. Holding one in a
`@State` is therefore deprecated with a message naming the line - a warning, not
a refusal, because the model still works as an object and an application that
arms the tracking itself may hold one. A model declared elsewhere is bridged
in the application: read it inside `withObservationTracking` and call
`Renderer.shared.setNeedsRender()` from its change handler, arming again after
every change.

## Sendable promises

`State` is `@unchecked Sendable`, kept by its storage's lock: a box may be
written from a handler, read by a render and written by a detached task at
once, and every write is whole. `@unchecked` because `Value` need not be
`Sendable` - the lock guards the box's hold on the value, not the value's
insides - and without it even `let counter = State(0)` at file scope would be
rejected. `Binding` is `@unchecked Sendable` for the same reason, which is what
lets a handler's `async let` child write through one. `Journey` is `Sendable`
over the same storage.
