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

## Owning a value with `@State`

A state belongs where its lifetime belongs:

```swift
struct Counter: ContentView {
    @State private var count = 0

    var content: any View {
        HStack {
            Label("Count: \(count)")
            Button("Add").onClicked { count += 1 }
        }
    }
}
```

Reading `count` while `Counter.content` is built records `Counter` as a reader.
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

### Writes and concurrent updates

A state read or write is protected as one operation and may be performed from
any thread. A read followed by a write is still two operations. When concurrent
tasks must derive a new value from the same old value, use `update` on the state
box so the transform runs under one hold:

```swift
struct DownloadCount: ContentView {
    @State private var completed = 0

    var content: any View {
        Label("Completed: \(completed)")
            .onCreated {
                await withTaskGroup(of: Void.self) { group in
                    for _ in 0..<4 {
                        group.addTask {
                            _completed.update { $0 + 1 }
                        }
                    }
                }
            }
    }
}
```

The transform must not read or write the same state again while it runs. In a
single handler, ordinary operations such as `count += 1` remain the clear
spelling.

Swift does not allow a property wrapper at file scope. A value with that
lifetime can use the box directly:

```swift
let launchCount = State(0)

launchCount.update { $0 + 1 }
let current = launchCount.get()
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

struct ProfileCard: ContentView {
    @State private var profile = Profile()

    var content: any View {
        VStack {
            Entry(profile.$name)
            Label("\(profile.name) · \(profile.visits) visit(s)")
            Button("Visit").onClicked { profile.visits += 1 }
        }
    }
}
```

The view's state keeps the `Profile` instance across rebuilds. The properties'
states make their individual writes visible. Two views holding the same model
read the same property storages; two model instances have independent
storages. Computed properties follow the state they read.

Give a wrapped class property its initial value at the declaration. This
wrapper cannot be used as uninitialized stored storage assigned for the first
time in `init`. A weak or unowned back-reference is a plain property because
Swift does not combine those ownership modifiers with a property wrapper.

### Swift Observation

Swift's `@Observable` and StateUI's `@State` notify different readers. StateUI
does not open an Observation tracking scope around a view description, so a
write to an `@Observable` property alone does not request a render. Holding an
`@Observable` model in `@State` is deprecated because it looks reactive while
its member writes leave the interface unchanged.

Declare properties on a model you own with `@State`. When another package owns
an `@Observable` type, bridge it explicitly: read the properties the interface
uses inside `withObservationTracking`, and in `onChange` re-arm that one-shot
tracking before calling `Renderer.shared.setNeedsRender()`.

```swift quote
import Observation

@MainThread
func observe(_ model: ExternalModel) {
    withObservationTracking {
        _ = model.title
        _ = model.progress
    } onChange: {
        Task { @MainThread in
            observe(model) // Observation tracking is one-shot.
            Renderer.shared.setNeedsRender()
        }
    }
}
```

Call the bridge from the lifetime owner and stop retaining that owner when its
element leaves. `setNeedsRender()` is a full, unnamed invalidation: it cannot
identify which composed body read which external property. For selective
StateUI invalidation, copy the external values needed by the interface into an
adapter whose properties are `@State`.

## Borrowing with `@Binding`

`@Binding` borrows another owner's value. It does not copy the value or create
another source of truth:

```swift
struct NameEditor: ContentView {
    @Binding var name: String

    var content: any View {
        Entry($name)
    }
}

struct AccountForm: ContentView {
    @State private var name = ""

    var content: any View {
        VStack {
            NameEditor(name: $name)
            Label(name.isEmpty ? "Choose a name" : "Hello, \(name)")
        }
    }
}
```

The projection `$name` is a `Binding<String>`. A borrowed binding projects
itself again, so it can be handed through several composed views without a new
wrapper or adapter.

### Binding to a part

Bindings use dynamic-member lookup for writable key paths. A value member is
updated by reading the whole value, changing the member, and writing the whole
value back:

```swift
struct Contact {
    var name = ""
    var subscribed = false
}

struct ContactForm: ContentView {
    @State private var contact = Contact()

    var content: any View {
        VStack {
            Entry($contact.name)
            Switch($contact.subscribed)
        }
    }
}
```

A mutable collection can be borrowed by index in the same way:

```swift
@State var levels = [0.2, 0.5, 0.8]

Stepper($levels[1])
```

For a model held in state, the two useful spellings have different owners:

- `profile.$name` is the model property's whole state;
- `$profile.name` is the `name` part reached through the state that holds the
  model.

A part has no independent state storage. It works for described values and
write-back, but it cannot be a host motion channel, a journey, or an engine's
followed state. Give independently carried values their own `@State` storage.

### A custom binding

Use `Binding(get:set:)` at an integration boundary that StateUI does not own:

```swift
final class ExternalSettings {
    var name = ""

    var nameBinding: Binding<String> {
        Binding(
            get: { self.name },
            set: { self.name = $0 })
    }
}
```

The setter decides whether anything is invalidated. A closure binding has no
StateUI storage for the host to carry or for an engine to follow, so controls
read it while describing and report changes through its setter. Prefer a real
`@State` whenever StateUI owns the value.

## Selecting a reactive path

Use the consequence you need as the selection rule:

| Need | StateUI expression | Cost when written |
| --- | --- | --- |
| Change which views exist or how authored values are composed | read the state in a body | rebuild current readers, then diff |
| Give a child access to the same value | pass `$value` to `@Binding` | determined by what the child does with it |
| Keep a native property synchronized continuously | hand the whole state to a binding-taking control or modifier | host-cycle update, no body read |
| Wake arithmetic on a display frame | name the state in `engine(following:)` | wake that engine |
| Turn one or more carried states into another carried value | `convert`, `convert(with:)`, or `multi` | conversion engine, no body read |
| Let a continuous value make an occasional structural decision | `samples` into ordinary state, or an engine that writes only when a threshold changes | rebuild only for sampled or changed decisions |

A state may use both paths. For example, a slider can carry `$volume` while a
caption reads `volume`. Dragging then updates the native control continuously
and rebuilds only the caption's description. Handing a binding to a control,
modifier, conversion, sample, or engine does not itself record a body read.

The host commits a native input report to the binding before invoking the
control's handler, so that handler observes the new value. A program write does
not return as a user event.

## Persistent state

Persistent state is ordinary state with a stable application key. It is
hydrated before the first description is built and written to the selected
host store after changes.

```swift
enum Appearance: String, PersistentValue {
    case light
    case dark
    case system
}

extension PersistentKey {
    static let appearance = PersistentKey(
        "com.example.notes.appearance",
        of: Appearance.self)
}

struct NotesApp: Application {
    @Environment private var application: ApplicationSession

    init() {
        application.persistentKeys = [.appearance]
    }

    var scene: any Scene { NotesWindow() }
}

struct NotesWindow: Window {
    var page: any Page { SettingsPage() }
}

struct SettingsPage: ContentPage {
    @State(persistentKey: .appearance) private var appearance = Appearance.system

    var content: any View {
        Button("Appearance: \(appearance.rawValue)").onClicked {
            appearance = appearance == .system ? .dark : .system
        }
    }
}
```

The declared value is the default when the store has no entry. The application
must list every key in `ApplicationSession.persistentKeys` during its
initialization; otherwise the host has no key to hydrate before the first
build. A write still has its key, so omitting it can look like restoration is
one launch late.

`Bool`, `Int`, `Double`, and `String` conform to `PersistentValue`. An enum
whose raw value conforms gains the same representation. Larger records belong
in an application-owned, explicitly versioned model rather than being hidden
inside an unversioned settings string.

One key names one storage for the application. Separate declarations of the
same key share the value and invalidate all of its readers. A type mismatch
between a key and its state is rejected when the state is built.

Several writes to one key before the host drains pending work produce one save
holding the last value. A persistent write is still drained when no body reads
the state; persistence does not depend on description invalidation. Writing the
same value also schedules a save because the host store may not hold it yet.

`ApplicationSession.persistentStorage` defaults to `.preferences`, the host's
native settings store. `PersistentStorage("name")` selects a host extension
point with that name; it is usable only when the active host explicitly
provides it.

## State kept with a scene

A `SceneKey` keeps a separate value for each scene session. A restoring host
returns that value with the scene before the scene's first build:

```swift
extension SceneKey {
    static let selectedSection = SceneKey(
        "com.example.notes.selectedSection",
        of: Int.self)
}

struct SceneSidebar: ContentView {
    @State(sceneKey: .selectedSection) private var selectedSection = 0

    var content: any View {
        HStack {
            Button("Previous").onClicked {
                selectedSection = max(0, selectedSection - 1)
            }
            Label("Section \(selectedSection)")
            Button("Next").onClicked { selectedSection += 1 }
        }
    }
}
```

Two declarations of one key inside one scene share its storage. The same key
in another scene names that scene's independent storage. A `sceneKey` state
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

    Label($volume.convert { "\(Int($0 * 100))%" })

    Label($width.convert(with: $height) { width, height in
        "\(Int(width)) × \(Int(height))"
    })
}
```

`convertBack` is needed when a reporting control edits the derived value. It
maps that report back into the source's units. Without it, reports into the
derived binding have no source-side destination.

Use `.multi` for a forward conversion of two through ten states:

```swift
@State var name = "Panel"
@State var width = 120.0
@State var height = 80.0

Label(.multi($name, $width, $height).convert { name, width, height in
    "\(name): \(Int(width)) × \(Int(height))"
})
```

Conversions require whole StateUI states as sources to remain on the host-cycle
path. A binding to a member or one made from closures is evaluated as described
data instead and cannot receive a host-carried reverse conversion.

### Destination conversion and journey conversion

For a walked state, an ordinary binding conversion reads the destination. A
journey conversion receives the live `Journey` lanes and is evaluated as the
value travels:

```swift
@State var width = 80.0

VStack {
    BoxView(.cornflowerBlue)
        .widthRequest($width)
        .heightRequest(24)

    Label($width.convert { "Target: \(Int($0))" })
    Label($width.journey.convert { journey in
        "Now: \(Int(journey.value))"
    })
}
```

Use `journey.convert(with:)` when the live presentation depends on two moving
states. One host-carried state is one shared motion channel; use separate
states when the values need independent trips.

## Journey and sampled readings

Every state whose value conforms to `Walked` exposes `$value.journey`. The
state itself remains discrete and immediately holds the destination:

| Member | Meaning |
| --- | --- |
| `journey.value` | presentation value on the current host frame |
| `journey.destination` | target; the same value as a plain state read |
| `journey.velocity` | per-second velocity in the value's lanes |
| `journey.motion` | law used wherever this state is carried |
| `move(to:_:)` | set a destination and await whether it was reached |
| `stop()` | settle an active trip at its current presentation |
| `snap(to:)` | set presentation, destination, and zero velocity together |

Reading `journey.value` in a body explicitly requests a rebuild for every
reported frame. Prefer a journey conversion when only a native property or
caption needs the live value.

When a continuous value must occasionally feed description logic, sample its
journey into another state:

```swift
struct SampledProgress: ContentView {
    @State private var progress = 0.0
    @State private var shown = 0.0

    var content: any View {
        VStack {
            ProgressBar().progress($progress)
            Label("Shown: \(Int(shown * 100))%")
            Button("Run").onClicked {
                try await $progress.journey.move(
                    to: 1,
                    .eased(1_000, .cubicOut))
            }
        }
        .samples($progress, into: $shown, .every(100))
    }
}
```

The target is ordinary state, so each changed sample rebuilds its readers. The
sample keeps its cadence across those rebuilds, writes only when the value
differs, and delivers the final value. `.always` takes every changed frame.

## Custom engines

Write a custom engine for frame arithmetic that needs memory or sequencing and
cannot be expressed as a pure conversion. An engine is attached to an element
and runs inside the host's display cycle.

```swift
struct SpringDot: ContentView {
    @State(motion: .custom) private var y = 0.0

    var content: any View {
        VStack {
            BoxView(.cornflowerBlue)
                .widthRequest(28)
                .heightRequest(28)
                .translationY($y)
                .engine(following: $y) { cycle in
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

- `following:` names the writes that wake it; it does not limit which values
  the closure may read;
- a time-driven engine may omit `following:` when its answer controls whether
  it receives another cycle;
- an engine runs once after the render that declares it;
- a write made by the engine itself does not wake that same engine;
- `.again` requests the next display cycle, while `.wait` sleeps until a
  followed state is written or a render rearms the declaration;
- `EngineCycle.elapsed` is milliseconds since this engine last ran, capped at
  `EngineCycle.mostElapsed`; `now`, `count`, `sync`, and `reducesMotion`
  describe the same display board;
- engines run by ascending `priority`, with stable registration order breaking
  ties;
- anything remembered between runs belongs in `@State` that the engine reads
  or writes;
- an engine does not suspend, invoke an aimed control, perform host acts, or
  create another UI-thread model.

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
- [Host contract](host-contract.md) defines the sparse typed patch and state
  channel semantics.
- [Platform contract](platform-contract.md) records which native hosts have
  implemented and tested each public surface.
