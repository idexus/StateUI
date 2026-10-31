# State and reactivity

StateUI has one declaration for mutable application data: `@State`. The place
where a value is used decides how it reaches the interface:

- a value read while a body is built invalidates that description when it is
  written;
- a whole state handed on as a `Binding` can be carried by the host or followed
  by an engine without making the body a reader.

These are two paths over the same storage, not two kinds of state. The complete
ownership model and the host motion axis are introduced in
[Architecture](architecture.md). This chapter is the author-facing reference
for choosing and composing those paths.

Two words say how a view holds a state, and one type names a part of it:

- `@State` owns the value and manages its state;
- `@Binding` borrows a whole state, with the host's reactive channel;
- a `StatePart` - `$contact.name`, `$levels[1]` - is one property or element
  of a state, read and written through the whole, which nothing in the
  library takes.

Every member takes a value, which a body reads, or a `Binding`, which the host
carries: `Text(contact.name)` reads, `Text(contact.$name)` is the channel.

## Owning a value with `@State`

A state belongs where its lifetime belongs:

```swift
struct Counter: View {
    @State private var count = 0

    var body: some View {
        HStack {
            Text("Count: \(count)")
            Button("Add").onClicked { count += 1 }
        }
    }
}
```

Reading `count` while `Counter.body` is built records `Counter` as a reader.
Writing it schedules another build of that reader. A read performed later by a
button handler is not a build-time read and creates no dependency.

StateUI keeps the state's storage while all of these remain true:

- the composed view still has a place in the retained tree;
- its identity still resolves to the same element;
- its composed view type has not changed.

Rebuilding a view creates another Swift value, but StateUI hands its state boxes
the storage held by the preceding value. A handler captured by an earlier build
therefore continues to write the storage read by the current build. Removing
the element ends that lifetime. See the ownership rules in
[Architecture](architecture.md#deterministic-ownership).

The expression beside a state declaration is evaluated lazily. A newly built
box that adopts existing storage does not evaluate and discard its proposed
initial value. State declared on the `Application` instead lives for the
application process because the application value itself is retained.

### Writes from other threads

A state belongs to the UI thread: a body reads it and a handler writes it on
`MainActor`, and a write from any other thread does not compile. On the UI
thread a handler's lines run with nothing between them, so `count += 1` is one
step. A task off the UI thread posts instead - `$state.post(value)` to replace
the value, `$state.post { … }` to change it - and each post lands in one job on
the UI thread soon after, in the order posted, so tasks counting at once all
count:

```swift
struct DownloadCount: View {
    @State private var completed = 0

    var body: some View {
        Text("Completed: \(completed)")
            .onCreated {
                let completed = $completed
                await withTaskGroup(of: Void.self) { group in
                    for _ in 0..<4 {
                        group.addTask {
                            completed.post { $0 + 1 }
                        }
                    }
                }
            }
    }
}
```

A post is never written at once, on the UI thread neither: it is a message,
and nothing reads it before its job runs. A value posted replaces the changes
waiting before it, so a loop posting ten thousand values costs one write and
one render. What it carries crosses threads, so the value is `Sendable`.

Swift does not allow a property wrapper at file scope. A value with that
lifetime can use the box directly, on the UI thread's actor:

```swift
@MainActor let launchCount = State(0)

@MainActor func countLaunch() -> Int {
    launchCount.wrappedValue += 1
    return launchCount.get()
}
```

## State in a class

A shared model declares every property that participates in StateUI as
`@State`. A plain stored property is ordinary Swift storage: changing it does
not invalidate a body, wake an engine, or update a host channel.

```swift
final class Profile {
    @State var name = "Guest"
    @State var visits = 0

    var cachedInitials = "G"
}

struct ProfileCard: View {
    @State private var profile = Profile()

    var body: some View {
        VStack {
            TextField(profile.$name)
            Text("\(profile.name) · \(profile.visits) visit(s)")
            Button("Visit").onClicked { profile.visits += 1 }
        }
    }
}
```

The view's state keeps the `Profile` instance across rebuilds. The properties'
states make their individual writes visible. Two views holding the same model
read the same property storages; two model instances have independent
storages. Computed properties follow the state they read.

Give a wrapped class property its initial value at the declaration, or make
its state in `init` - `_name = State(wrappedValue: name)`, as
[Editing a record](#editing-a-record-two-ways) shows: assigning the wrapped
property there does not compile. A weak or unowned back-reference is a plain
property because Swift does not combine those ownership modifiers with a
property wrapper.

### Swift Observation

Swift's `@Observable` and StateUI's `@State` notify different readers. StateUI
does not open an Observation tracking scope around a view description, so a
write to an `@Observable` property alone does not request a render. Holding an
`@Observable` model in `@State` is deprecated because it looks reactive while
its member writes leave the interface unchanged.

Declare properties on a model you own with `@State`. When another package owns
an `@Observable` type, bridge it with an adapter whose properties are `@State`:
copy what the interface reads inside `withObservationTracking`, and in
`onChange` copy again, which arms the one-shot tracking anew. Each copy is a
write to a state, so only the views that read that property are built again.

```swift
import Observation
import StateUI

/// Another package's model.
@MainActor @Observable
final class ExternalModel {
    var title = ""
    var progress = 0.0
}

@MainActor
final class PlayerAdapter {
    @State var title = ""
    @State var progress = 0.0

    func follow(_ model: ExternalModel) {
        withObservationTracking {
            title = model.title
            progress = model.progress
        } onChange: { [weak self] in
            Task { @MainActor in self?.follow(model) } // Observation tracking is one-shot.
        }
    }
}
```

The views read the adapter, never the model. Start following from the lifetime
owner - an action or `.onAppearing` - and let the adapter go when its element
leaves; the weak reference ends the following with it.

## Borrowing with `@Binding`

`@Binding` borrows another owner's value. It does not copy the value or create
another source of truth:

```swift
struct NameEditor: View {
    @Binding var name: String

    var body: some View {
        TextField($name)
    }
}

struct AccountForm: View {
    @State private var name = ""

    var body: some View {
        VStack {
            NameEditor(name: $name)
            Text(name.isEmpty ? "Choose a name" : "Hello, \(name)")
        }
    }
}
```

The projection `$name` is a `Binding<String>`. A borrowed binding projects
itself again, so it can be handed through several composed views without a new
wrapper or adapter.

### Editing a record: two ways

A control takes a whole state, `$x`, which the host carries. A record edited
field by field is written one of two ways.

**A class whose fields are states.** Each field is a `@State` of its own, so a
control is handed it whole - `contact.$name` - and the host carries it: typing
writes that field alone, and no body is built for it.

```swift
final class Contact {
    @State var name = ""
    @State var subscribed = false
}

struct ContactForm: View {
    @State private var contact = Contact()

    var body: some View {
        VStack {
            TextField(contact.$name)
            Switch(contact.$subscribed)
            Text("Hello, \(contact.name)")
        }
    }
}
```

An array of such objects edits its rows the same way: a row borrows its fields
with `@Binding`, and a keystroke writes that row's state alone. A field given
its first value in `init` is made there, `_title = State(wrappedValue: title)`:
assigning a wrapped property in `init` does not compile.

```swift
final class Todo {
    let id: Int
    @State var title: String
    @State var done = false

    init(id: Int, title: String) {
        self.id = id
        _title = State(wrappedValue: title)
    }
}

struct TodoRow: View {
    @Binding var title: String
    @Binding var done: Bool

    var body: some View {
        HStack {
            CheckBox($done)
            TextField($title)
        }
    }
}

struct Checklist: View {
    @State private var todos = [Todo(id: 1, title: "Milk"), Todo(id: 2, title: "Bread")]

    var body: some View {
        VStack {
            ForEach(todos, id: \.id) { todo in
                TodoRow(title: todo.$title, done: todo.$done)
            }
        }
    }
}
```

**A value and its event.** A record that stays a value - written to a file,
compared, kept by a scene - hands each control its value, and the control's
event writes the user's change:

```swift
struct Chore {
    let id: Int
    var title: String
    var done = false
}

struct Chores: View {
    @State private var chores = [Chore(id: 1, title: "Milk"), Chore(id: 2, title: "Bread")]

    var body: some View {
        VStack {
            ForEach(chores, id: \.id) { chore in
                HStack {
                    CheckBox(chore.done)
                        .onToggled { done in edit(chore.id) { $0.done = done } }
                    TextField(chore.title)
                        .onTextChanged { title in edit(chore.id) { $0.title = title } }
                }
            }
        }
    }

    private func edit(_ id: Int, _ change: (inout Chore) -> Void) {
        if let row = chores.firstIndex(where: { $0.id == id }) { change(&chores[row]) }
    }
}
```

Each change writes the whole array, so the body that read it is built again
and describes the new values; the write stands where it can be seen, and finds
its row by identity, not by place.

| | A class of states | A value and its event |
| --- | --- | --- |
| The record | a class: shared, never copied | a value: `Codable` and `Equatable` come with it |
| One keystroke | writes that field's state, builds nothing | writes the whole value, builds its readers |
| The control's value | carried by the host | described by the body |
| A journey, an animation, an engine on a field | yes | no |
| Suits | live editing, values that move | lists and records saved or compared |

A value that crosses to the host as it is - text, on or off, a number, a day,
a time, a color - takes either form: `TextField($name)` or
`TextField(name).onTextChanged { … }`. A choice the library translates for the
host - a picker's place in its list, a list's chosen items, a tab - takes the
state alone, `Picker(sizes, selection: $size)`: a choice kept in a value is a
field made a state of its own.

### A part of a state: `StatePart`

`$contact.name` and `$levels[1]` are one property or one element of a state - a
`StatePart`, which reads the whole value and writes the member back. Nothing
in the library takes one: a control, a driven modifier, a conversion and an
engine take a whole state, so a part handed to one does not compile, and the
error names a `StatePart` where a `Binding` is asked. A part is read and
written - `$levels[1].wrappedValue` - and posted to from another thread,
`$levels[1].post(0.5)`; a write or a post to an element its collection no
longer has is dropped and said once.

For a model held in state, the two spellings have different owners:

- `profile.$name` is the model property's whole state, a `Binding`;
- `$profile.name` is the `name` part reached through the state that holds the
  model, a `StatePart`.

A value StateUI does not own reaches a control through a class of `@State`
fields that follows it, as [State in a class](#state-in-a-class) shows.

### A state an element reads itself

Handing a state to a member never makes the body a reader. A member whose
value the library translates for its host - a picker's place in its list, a
tab, a list's chosen items, a stack's pages, a sheet - reads the state as its
element is described, and a write describes that element alone again: the
body that wrote `Picker(sizes, selection: $size)` is not built for a choice. A
registered control of the application's own does the same through its member,
`setValue(TrafficLightContract.signal, whenDescribed: { state.wrappedValue })`.

## Selecting a reactive path

Use the consequence you need as the selection rule:

| Need | StateUI expression | Cost when written |
| --- | --- | --- |
| Change which views exist or how authored values are composed | read the state in a body | rebuild current readers, then diff |
| Give a child access to the same value | pass `$value` to `@Binding` | determined by what the child does with it |
| Give a child one field of a record | the field's own state, `record.$field`, to `@Binding`; or its value | as for a whole state; or rebuild the child, which reads it |
| Keep a native property synchronized continuously | hand the whole state to a binding-taking control or modifier | host-cycle update, no body read |
| Wake arithmetic on a display frame | name the state in `engine(following:)` or `engine(tracking:)` | wake that engine |
| Turn one or more carried states into another carried value | `convert`, or `multi` for several | conversion engine, no body read |
| Let a continuous value make an occasional structural decision | `samples` into ordinary state, or an engine that writes only when a threshold changes | rebuild only for sampled or changed decisions |

A state may use both paths. For example, a slider can carry `$volume` while a
caption reads `volume`. Dragging then updates the native control continuously
and rebuilds only the caption's description. Handing a binding to a control,
modifier, conversion, sample, or engine does not itself record a body read.

The host commits a native input report to the binding before invoking the
control's handler, so that handler observes the new value. A program write does
not return as a user event.

## Persistent state

Persistent state is ordinary state with a stable application key. The host's
store is read as the first state under the key is made, so the kept value is
there for the state's first description, and every change is written back.

```swift
enum Appearance: String, PersistentValue {
    case light
    case dark
    case system
}

extension PersistentKey where Value == Appearance {
    static let appearance = PersistentKey("com.example.notes.appearance")
}

struct SettingsPage: View {
    @State(persistentKey: .appearance) private var appearance = Appearance.system

    var body: some View {
        Button("Appearance: \(appearance.rawValue)").onClicked {
            appearance = appearance == .system ? .dark : .system
        }
    }
}
```

The declared value is the default when the store has no entry. Nothing lists
the keys in advance: a key is typed by the value it keeps, and the store is
read by its name and that type's kind.

`Bool`, `Int`, `Double`, and `String` conform to `PersistentValue`. An enum
whose raw value conforms gains the same representation. Larger records belong
in an application-owned, explicitly versioned model rather than being hidden
inside an unversioned settings string.

One key names one storage for the application. Separate declarations of the
same key share the value and invalidate all of its readers. A state of another
type than its key's does not compile; two keys giving one name to different
types stop the application when the second is used.

Several writes to one key before the host drains pending work produce one save
holding the last value. A persistent write is still drained when no body reads
the state; persistence does not depend on description invalidation. Writing the
same value also schedules a save because the host store may not hold it yet.

Kept state lives in the platform's own settings store - `UserDefaults` on
AppKit and UIKit, `SharedPreferences` on Android - on WinUI and GTK, whose
platforms keep no store an application can use, in a file of the host's own,
and on the Web in the browser's storage for the page's site, under the
application's name. An application that keeps something in a file or a
database of its own reads and writes it in its own code and hands the values
to ordinary `@State`.

## State kept with a scene

A `SceneKey` keeps a separate value for each scene session. A restoring host
returns that value with the scene before the scene's first build:

```swift
extension SceneKey where Value == Int {
    static let selectedSection = SceneKey("com.example.notes.selectedSection")
}

struct SceneSidebar: View {
    @State(sceneKey: .selectedSection) private var selectedSection = 0

    var body: some View {
        HStack {
            Button("Previous").onClicked {
                selectedSection = max(0, selectedSection - 1)
            }
            Text("Section \(selectedSection)")
            Button("Next").onClicked { selectedSection += 1 }
        }
    }
}
```

A scene keeps any `Codable` value, as its JSON text; a kept text that no
longer reads as the key's type - the type changed since - leaves the declared
default. Two declarations of one key inside one scene share its storage. The
same key in another scene names that scene's independent storage. A `sceneKey` state
declared outside a scene is ordinary state because there is no scene session to
claim it. On a host without scene restoration, the state still lasts for the
open scene but is not promised across launches.

Use a `PersistentKey` for one setting shared by the whole application and a
`SceneKey` for state that belongs to a particular restored workspace or
window group.

## Host-cycle conversions

A conversion derives another carried state without rebuilding a body. The
forward closure runs on host cycles when its source changes:

```swift
@State var volume = 0.2
@State var width = 120.0
@State var height = 80.0

VStack {
    Slider($volume.convert { $0 * 100 }
        .convertBack { $0 / 100 })
        .maximum(100)

    Text($volume.convert { "\(Int($0 * 100))%" })

    Text(.multi($width, $height).convert { width, height in
        "\(Int(width)) × \(Int(height))"
    })
}
```

`convertBack` is needed when a reporting control edits the derived value. It
maps that report back into the source's units. Without it, reports into the
derived binding have no source-side destination. Only the user's change comes
back: a value the application writes goes forward as written, however the
conversion rounds it on the way.

Use `.multi` for a forward conversion of two through ten states:

```swift
@State var name = "Panel"
@State var width = 120.0
@State var height = 80.0

Text(.multi($name, $width, $height).convert { name, width, height in
    "\(name): \(Int(width)) × \(Int(height))"
})
```

Each view writing a conversion keeps its own derived state, even where two
views convert one source on one line, and lets it go when it leaves.

Conversions take whole StateUI states as sources, which keeps them on the
host-cycle path: `convert` and `multi` are offered on `Binding` alone, so a
`StatePart` cannot be converted.

### Destination conversion and journey conversion

For a walked state, an ordinary binding conversion reads the destination. A
journey conversion receives the live `Journey` lanes and is evaluated as the
value travels:

```swift
@State var width = 80.0

VStack {
    Rectangle()
        .fill(.cornflowerBlue)
        .width($width)
        .height(24)

    Text($width.convert { "Target: \(Int($0))" })
    Text($width.journey.convert { journey in
        "Now: \(Int(journey.value))"
    })
}
```

Use `.multi($a.journey, $b.journey).convert { … }` when the live presentation
depends on two moving states - `.multi` is the one road for a conversion of
several sources, states or journeys. One host-carried state is one shared motion channel; use separate
states when the values need independent animations.

## Journey and sampled readings

Every state whose value conforms to `Walked` exposes `$value.journey`. The
state itself remains discrete and immediately holds the destination:

| Member | Meaning |
| --- | --- |
| `journey.value` | presentation value on the current host frame |
| `journey.destination` | target; the same value as a plain state read |
| `journey.velocity` | per-second velocity in the value's lanes |
| `journey.motion` | law used wherever this state is carried |
| `move(to:_:)` | set a destination; `arrived()` awaits whether it was reached |
| `stop()` | settle an active animation at its current presentation |
| `snap(to:)` | set presentation, destination, and zero velocity together |

Reading `journey.value` in a body explicitly requests a rebuild for every
reported frame. Prefer a journey conversion when only a native property or
caption needs the live value.

When a continuous value must occasionally feed description logic, sample its
journey into another state:

```swift
struct SampledProgress: View {
    @State private var progress = 0.0
    @State private var shown = 0.0

    var body: some View {
        VStack {
            ProgressBar().progress($progress)
            Text("Shown: \(Int(shown * 100))%")
            Button("Run").onClicked {
                $progress.journey.move(to: 1, .eased(.seconds(1), .cubicOut))
            }
        }
        .samples($progress, into: $shown, .every(.milliseconds(100)))
    }
}
```

The target is ordinary state, so each changed sample rebuilds its readers. The
sample keeps its cadence across those rebuilds, writes only when the value
differs, and delivers the final value. `.always` takes every changed frame.

## Custom engines

Write a custom engine for frame arithmetic that needs memory or sequencing and
cannot be expressed as a pure conversion. An engine is attached to an element
and runs inside the host's display cycle. It comes two ways:
`.engine(following:)` runs on the display cycle after a state it follows is
written - once, however many writes came - and once after each render that
describes its view; `.engine(tracking:)` keeps tracking, answering on each
cycle whether it has more to do - a spring, a stopwatch:

```swift
struct SpringDot: View {
    @State(motion: .custom) private var y = 0.0

    var body: some View {
        VStack {
            Rectangle()
                .fill(.cornflowerBlue)
                .width(28)
                .height(28)
                .translationY($y)
                .engine(tracking: $y) { cycle in
                    let journey = $y.journey

                    if cycle.reducesMotion {
                        journey.snap(to: journey.destination)
                        return .wait
                    }

                    let seconds = cycle.elapsed / 1_000
                    let displacement = journey.destination - journey.value
                    journey.velocity += (
                        displacement * 40 - journey.velocity * 10
                    ) * seconds
                    journey.value += journey.velocity * seconds

                    if abs(displacement) < 0.01 && abs(journey.velocity) < 0.01 {
                        journey.snap(to: journey.destination)
                        return .wait
                    }

                    return .again
                }

            Button("Move").onClicked { y = y == 0 ? 180 : 0 }
        }
    }
}
```

The engine contract is deliberately narrow:

- `following:` and `tracking:` name the writes that wake it; they do not limit
  which values the closure may read;
- a time-driven engine may omit `tracking:`: its answer controls whether it
  receives another cycle;
- an engine runs once after every render that describes its view;
- a write made by the engine itself does not wake that same engine;
- `.again` requests the next display cycle, while `.wait` sleeps until a
  tracked state is written or a render rearms the declaration;
- `EngineCycle.elapsed` is milliseconds since this engine last ran, capped at
  `EngineCycle.mostElapsed`; `now`, `count`, `sync`, and `reducesMotion`
  describe the same display board;
- engines run by ascending `priority`, with stable registration order breaking
  ties;
- anything remembered between runs belongs in `@State` that the engine reads
  or writes;
- an engine does not await, ask the host for anything, or touch a control: it
  runs inside the frame the platform draws.

Like every attachment owned by an element, an engine is removed when that
element leaves the tree.

An engine that always returns `.again` keeps the display clock active. Return
`.wait` as soon as no visible work remains. Every engine that draws movement
must make an explicit reduced-motion decision.

Use `@State(motion: .custom)` only when the engine owns the journey. Ordinary
motion laws remain the host's responsibility and need no custom engine.

## Related contracts

- [Architecture](architecture.md) defines the two reactive paths, motion axis,
  sessions, and ownership boundaries.
- [Motion and journeys](motion-and-journeys.md) defines motion precedence,
  interruption, visibility, and layout motion.
- [Environment](environment.md) covers provided objects, standard host facts,
  sessions, dates, clocks, and time zones.
- [Host contract](../internals/host-contract.md) defines the sparse typed patch and state
  channel semantics.
- [Platform contract](../platform-contract.md) records which native hosts have
  implemented and tested each public surface.
