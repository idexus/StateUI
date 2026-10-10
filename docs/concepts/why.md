# Why StateUI is shaped this way

A few decisions shape every API StateUI offers. Each section below states one:
what StateUI does, why, and what was deliberately rejected. The rejected shapes
are not missing features waiting for a contribution. They were weighed and left
out on purpose, because each would cost one of the properties the section
names.

Read this page before contributing. A change follows these decisions; a
proposal to change one starts as a Proposal issue that answers the reason given
here ([Contributing](../../CONTRIBUTING.md)).

## A property is one modifier: a value or a state

Every property of a control is one member of its element's contract, set by
one modifier named for the property. A property the host can carry takes the
value itself, or a state that carries it; one whose value no host carries - a
font family, an icon - takes its value, which a body that reads a state
changes:

```swift
struct Total: View {
    @State private var weight: FontAttributes = .bold
    @State private var alignment: Alignment = .center
    @State private var fade = 1.0

    var body: some View {
        VStack {
            Text("Total").fontAttributes(.bold)
            Text("Total").fontAttributes($weight)
            Text("Total").horizontalAlignment($alignment)
            Text("Total").opacity($fade)
        }
    }
}
```

These are StateUI's two reactive paths ([Architecture](architecture.md)). A
value belongs to the description: when a state the body read changes it, the
body is built again, compared, and the host is sent the difference. A state
handed as `$weight` is carried by the host: a write reaches the native control
on the host's own cycle and no body is built again; a value that can move
travels to each new one ([Motion and journeys](motion-and-journeys.md)); and
what the platform reports lands on the same state. Every property the host can
carry offers both paths, because each has the same shape.

**Deliberately rejected:** a modifier without an argument that sets one value
of a property - `.bold()`, `.italic()`, `.center()`, `.leading()` and their
like.

- It has no state form. `.bold()` cannot be handed `$weight`; the only way to
  change it is an `if` in a body that reads a state, so the second path is gone
  for that property.
- An `if` around a modifier changes which element stands there. The `if` and
  `else` branches are distinct identities, and switching them replaces the
  element ([Builders and conditional identity](../interface/composition-and-identity.md#builders-and-conditional-identity)):
  the native control is made again, its focus, caret and selection go with
  it, and nothing moves from one look to the other.
- It cannot say no. Removing `.bold()` is the only way back, while
  `.fontAttributes(.none)` is one more value of the same member.
- It is a second spelling of one member. The contract, the hosts, the
  conformance cases and the [platform matrix](../platform-contract.md) all
  speak member by member; one member reached by several modifiers, each
  setting one of its values, has no one place where its support is proved.

## A model's properties are `@State`

StateUI has one state declaration, `@State`, and a class you own declares with
it the properties an interface uses
([State in a class](state-and-reactivity.md#state-in-a-class)):

```swift
final class Profile {
    @State var name = "Guest"
    @State var visits = 0
}

struct ProfileCard: View {
    @State private var profile = Profile()

    var body: some View {
        VStack {
            TextField(profile.$name)
            Text("\(profile.visits) visit(s)")
            Button("Visit").onClicked { profile.visits += 1 }
        }
    }
}
```

- **One declaration, its role decided by where it is used.** A model's
  `@State` is a view's `@State`: read in a body, a write builds that body
  again; handed to a control as `profile.$name`, it is carried by the host;
  named in an engine's `following:`, a write wakes the engine; and its journey
  is part of it. A model needs no second kind of state, and an author learns
  one.
- **Precision.** The core records which state each body read while it was
  built, so `profile.visits += 1` builds again the bodies that read `visits`
  and none that read only `name`.

**Deliberately rejected:** tracking Swift's `@Observable` models. An
`@Observable` property notifies whoever armed an observation scope around its
read, and StateUI arms none: its own record of what each body read already
says which body to build again, property by property, so observation would be
a second way to do one thing. An `@Observable` property also has no `$`
binding a host could carry, and so no host channel, no journey and no engine
wake. Holding an `@Observable` model in a `@State` compiles with a deprecation
warning on that line, because its writes would leave the interface showing
old values. A model another package owns is bridged by the application
([Swift Observation](state-and-reactivity.md#swift-observation)).

## One kind of state, and its journey is part of it

A state is discrete: `fade` is where the value is going. Where it is now, how
fast it moves and under what law is `$fade.journey`, the same state seen in
motion ([Motion and journeys](motion-and-journeys.md)). A state named in an
engine's `following:` wakes the engine when it is written, whoever writes it;
reading a state wakes nothing.

**Deliberately rejected:** a second declaration for a value that moves, a
declared journey type, and an engine woken by what it reads. Each would double
every API that takes a state, and where a state is used already says what it
is.

## Native controls, through what they expose

Each host renders with its platform's own controls, so an application looks
and behaves as that platform's own applications do: its keyboard, its
accessibility, its input methods and its theme come with the control. A control
is used through what it exposes publicly - its properties, events, styles and
the named theme resources its style reads. What every host must match is the
effect of the contract - the state written, the event heard once, the choice
shown - never the pixels.

**Deliberately rejected:** controls StateUI draws itself on every platform, and
reaching into a native control's template to make it look like another
platform's. The first would rebuild each platform's accessibility and input by
hand; the second breaks with the platform's next version. What a native control
cannot do stands in the [platform matrix](../platform-contract.md) as `–` with
its reason, or `☑️` with what is missing.

## Every host is Swift, and decides little

Every host is Swift in the application's process and reads the renderer's
typed patch directly; Java on Android and C++/WinRT on Windows are only relays
beneath it. What two hosts would decide alike - layout arithmetic, gestures,
text rules, a list's cells, where a view stands - lives once in the host layer,
in Swift, with its own tests ([Host layer](../internals/host-layer.md)). A host
is a thin layer of its toolkit's calls.

**Deliberately rejected:** a serialized wire between the core and a host, a
host written in its platform's own language, and a rule kept in one host that
another decides too. One copy of a rule is one behaviour on every platform, and
every host's suite proves it through the same conformance cases.

## Navigation and presentation are state

A navigation stack shows its path, an array of values; a modal page is an
element of an array; the tab shown is a state
([Navigation and presentation](../interface/navigation-and-presentation.md)).
Going somewhere is writing a state, and the user's own way back writes it too.

**Deliberately rejected:** routers, navigation commands and command strings. A
state can be kept, restored, tested and read by any view; a command is gone the
moment it runs.

## A control's method goes through an aim

An action on one control - focusing a field, scrolling a list to an item,
moving a map - goes through an `@Aim`, which identifies the control the tree
rendered ([Aims and control methods](../interface/interaction-and-actions.md#aims-and-control-methods)).
An aim is not state and holds no control.

**Deliberately rejected:** references to native controls in application code.
A host makes, reuses and lets go of its controls; an application holding one
would keep a control the tree has dropped, and would be tied to one platform's
type.

## `some View`, never `any View`

The public API takes `some View`, and a builder keeps the type it was given.
The type stays known to the compiler and to the core: a view without a `body`
does not compile, and the core tells a navigation stack, a split view or a tab
view from other views by its type.

**Deliberately rejected:** `any View` and type-erased wrappers in the public
API, which would turn those compile errors into failures at run time.

## A state belongs to the UI thread

A `@State`, its bindings and its journey are read and written on `MainActor`,
with no lock: a handler's lines run with nothing between them, and a write is
what the next read sees. Another thread posts - `$x.post` - the one door in,
landing on the UI thread in the order posted. A handler that awaits says what
its event does when it comes again, and a run superseded changes nothing, so
an older answer never overwrites a newer one.

**Deliberately rejected:** state written from any thread under locks, where a
write costs a lock, two writers interleave inside one change and an author
reasons about threads in every handler; and a default for a repeated event,
which would hide the one question an awaiting handler has to answer.

## The library never imports Foundation

The StateUI library never imports Foundation; an application may. Handlers run
on `MainActor`, which every host drains on its own UI thread.

**Deliberately rejected:** Foundation in the library, and its timers, run loops
and main queue as the library's clock. The library runs on macOS, iOS, Android,
Windows, Linux and the Web, and nothing drains Foundation's timers and run
loops on Android or Windows
([Foundation boundary](environment.md#foundation-boundary)).

## The same session gives the same patch

Everything StateUI derives from a dictionary or a set is sorted before it
reaches a patch or an export, so one session rendered twice gives the same
patches. Two renders can be compared, a session can be replayed, and the
rendered documents change only where a verdict changed.

**Deliberately rejected:** any output in an order a hash or a memory address
decides.

## What the library offers is read by name

The library's own objects are read by name - `@Environment(\.application)`,
`\.scene`, `\.window`, `\.device`, `\.locale` - and an application's own object,
given with `.environment(model)`, by its type
([What the library offers](environment.md#what-the-library-offers)).

**Deliberately rejected:** a second spelling for the library's objects. Each
has one name, so a reader meets one spelling in every application.

## Names say what a thing is

A modifier is the noun of what it sets, given a value or a state; a Boolean
reads as a statement (`isOn`, `showsBackButton`); an event is `on` followed by
what happened (`onClicked`, `onItemActivated`); words are whole (`minimum`,
not `min`). One concept has one word across the whole library.

**Deliberately rejected:** a verb or a value as a modifier (`.center()`),
abbreviations, and names that say what something resembles rather than what it
is.
