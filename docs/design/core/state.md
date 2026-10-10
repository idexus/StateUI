# State

`@State` is the one declaration of mutable state (State.swift).
Where it is used decides its role: read in a body, it rebuilds that body when
written; handed to a control or a driven modifier as `$x`, the host carries it
and no body is rebuilt for it. This note covers how a state is stored,
borrowed, carried, kept and provided.

## Storage and box

```text
  @State var count        a State box, rebuilt with its view every render
        |
        v  adopt(from:) - the differ hands a fresh box its predecessor's storage
  State.Storage           the value, its name, its image, its posts; the one
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

The posts waiting for the UI thread live on the storage, not the box, because
two boxes sharing a storage must share them: posts through either land in one
order. The storage is internal so tests can hold its invariants directly; no
public signature names it.

A read and a write of a value the host does not carry are `@inlinable`, down
to the storage's fields: the application's module, which knows `Value`,
compiles them for its own type. Called unspecialized across the module
boundary, a read pays for the generic machinery - the value's metadata, its
copies - several times over the read itself; the storage's fields that path
touches are `@usableFromInline` for that reason alone. A carried value's road
stays a call.

## The initial value waits

The expression beside a declaration is held as a closure until a storage nobody
adopted is first read. Evaluated eagerly, it would run on every render of every
view described and be thrown away by the adoption. The value is kept as an
optional one level deeper than `Value`, so a state holding `nil` is told apart
from a state with no value yet.

## The UI thread's state

A state belongs to the UI thread: `State`, `Binding`, `Journey` and everything
that reads or writes them are `MainActor`'s, so a write from another thread
does not compile. On the UI thread a handler's lines run with nothing between
them - `counter += 1` is one step - and a write made while a render runs, by
what it builds, is kept for the next one. A write and the save it records happen together, so
the newer value of a kept state is the one that reaches the store.

## Posting

`$x.post(v)` and `$x.post { … }` are the one door in from another thread. A
post records itself in the state's mailroom and books one job on `MainActor`
for the whole state unless one is booked already; the job takes what waits and
writes it entry by entry, in the order posted, each through a binding to its
part. A value posted to a part drops what waits for that part and for every
part of it, and goes last: the last one posted stands, whenever the job runs -
a title posted after the whole lands over it, the whole posted after a title
replaces it. A change goes on the last entry when that is its own part's, and
runs over what the one before it left, so a hundred tasks counting with
`post { $0 + 1 }` count every one, in one write. A post is deferred on every
thread, the UI thread too: it is a message rather than a write, and nothing
reads it before its job runs. Its value crosses threads, so it is `Sendable`.

The mailroom is made on `MainActor` the first time the state is lent, and
every binding to the state carries it; its entries wait under its lock.
Coalescing is what makes a value posted ten thousand times from a loop cost one
write and one render.

An entry holds the binding it writes through until the job takes it: kept in
the state's own mailroom, it is a ring only while it waits, and the state is
freed once the job has run. The job is the library's own task, so it belongs to
no handler's run: what it writes may have been posted by several runs, and the
run that booked it being superseded refuses none of it - a superseded run's own
post is refused as it is posted.

## Bindings

A `Binding` is two closures - read and write - plus who it borrows from: the
storage behind a `@State` (`lender`) and which part of it (`lent`). A part is
the whole road from the state (`StatePart`): `$rows[0].title` and
`$rows[1].title` are two parts, so a post to one lands in its own entry, and a
child lent the second is described again rather than carried with the first.
A binding to an element knows whether its collection still has it (`reaches`),
and so does every binding to a property of it: a write, or a post's job, to an
element the list no longer has - it shrank under the binding - is dropped and
said once, rather than writing past the end. `$counter`
builds a new binding every time it is written, so two spellings of one state
are two values; the lender is how they recognize each other. `described`
reads it and answers the storage behind a whole `@State` and nothing for a
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
the host on an image (`HostStorage`, HostStorage.swift). The image
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

## What a host reads lanes as

A value that lies as numbers is a `LaneValue`, and its type says what a host
reads its lanes as: numbers, a Boolean, a choice or a colour (`LaneKind`). A
registration takes the kind from the value it is handed and the patch carries
it beside the state's door, so a value said from a state reaches the control
as the same value said directly - `.isOn($x)` a Boolean,
`.horizontalAlignment($side)` a case, an application's own `Bool` member a
Boolean too. A host reading lanes by the property's name would know only the
names it lists, and any other member would arrive as a number.

Text is no `LaneValue`: it has no lanes, and it goes through the text door
alone. `plain` and the lane form of `setValue(_:on:mode:kind:)` refuse it by
type; its own form takes the mode alone.

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

A colour pair (`Color(light:dark:)`) - or any value wearing the theme, a
material holding one - written into a carried state keeps the
pair on the storage, and the image holds the half in force: lanes are one
colour. The state lays the value in the theme in force (`ThemeInForce`),
handed to the value rather than read by it, so a value's conversion depends
on nothing but its arguments; a value's own `carried` is its lanes in the
standard theme - the light half, the application's first accent. Every driven modifier that hands the state on reads the theme as it
does, which makes that element the theme's reader; a theme change builds it
again, and the host animates the colour to the other half. A movement sent to
a pair keeps that pair, as a write does; one sent to a single colour lets it
go, and so do a stop and the host moving the value somewhere else.

## A material on a carried state

A `Material` lies as lanes of its own width (`LaneKind.material`): its kind -
none, a colour, a gradient, a blur, glass - then what that kind is made of,
every colour four lanes in the theme it is laid in. A pair lies as its half in force, a
half that is none as nothing; a blur and glass lay the stand-in colour of the
theme in force too, so a theme turning changes the bytes and the host shows
the other half. A material, a colour pair and the accent are each a value
wearing the theme (`ThemeWearing`): the storage keeps it whole and the
element handing it on reads the theme, as for a colour pair above. A material
is shown as it stands, never walked: `.background($material)` is a plain
channel, while `.background($colour)` stays a journey the host animates.

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
  1  the host asks for the keys and the store     HostBoundary.persistentKeys
  2  it reads exactly those from the store
  3  it hands back what it found                  HostBoundary.restorePersistent
```

A key the store has nothing under is absent, and the state keeps the value
written beside its declaration - which is where the default can be seen.

A key a state keeps that the application's `persistentKeys` leaves out is said
once, when the host reads the list or when a state claims the key after it:
the host never reads that key at launch, so its value would come back one
launch late.

A write lands in memory at once and marks the key, whoever makes it: the
program, a control through the state's binding, or the host reporting what the
user typed or moved into the control carrying the state - the key is marked by
the storage itself, on every road a value comes in by, a moving value by where
it is going. The saves go out as one act
per key per take, sorted by name, holding the last value: a key written five
times inside one handler is saved once. It is a collapse per drain, not a
delay. A write to a kept state asks the host for a turn itself, and waiting
saves count as pending work, because a kept state nobody reads asks for no
render and its save must not wait for the next event.

One key is one piece of state: two views declaring a key share its storage, so
a write in one rebuilds the readers in the other. The first state to claim a key
decides the storage. A storage claimed before the host's read arrives - an
application's own keyed state, made when the host reads `persistentKeys` -
takes the stored value when `hydrate` runs, still ahead of the first view.

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
collide. What the library offers is read by its name, `@Environment(\.window)`,
a name for its object's type, so both resolve through the same stack. Nothing
about it crosses to the host.

```text
  .environment(obj)   stored on the node, outside the patch
  the differ          keeps a stack of provided objects as it walks, in both
                      walks, and fills each @Environment slot BEFORE the body
                      builds; refilled on every build, never adopted
  invalidation        untouched: reading a provided object's @State records the
                      read as for any object; the provider only passes a
                      reference, so only replacing the object rebuilds it
```

A carried view's inputs cannot see a provider above it replacing its object, so
the differ compares a snapshot of the visible providers too
(identity-and-diffing.md). What the library offers - the device, the locale
and the three sessions - is there
without anybody writing `.environment()`; a slot nothing filled answers the
standard provider of its type, which is what lets the application itself
declare `@Environment`, its `init` and `body` running outside the differ. A
type neither provided nor standard stops the program with its name: an
environment that silently answered nothing would be the failure this library
refuses everywhere. `$context` is a lender (`EnvironmentLender`): it lends the
object's properties, each a binding that writes through the object, and has no
road to replace the object, which is the ancestor's to provide - replacing it
from below does not compile.

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

## Sendable

`State`, `Binding` and `Journey` are `MainActor`'s, which makes each
`Sendable` by its type: a binding handed to a task can be posted to, and
nothing else. Nothing promises more than the compiler checks: what other
threads share - a mailroom's waiting entries, the executor's queue, the
application's events raised and waiting, the complaints said - stands inside a
`Mutex`, and a run's superseded flag is an atomic
(concurrency.md#what-stands-behind-a-lock).
