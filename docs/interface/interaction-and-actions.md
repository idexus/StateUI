# Interaction and actions

StateUI distinguishes three things:

- state says what the interface currently means;
- an event reports something the user or platform committed;
- an action asks the host to do something that cannot be represented as a
  standing value.

Keeping those roles separate prevents application writes from masquerading as
input and keeps native methods out of the description tree.

## Event handlers

Typed handlers are modifiers on the element that reports them:

```swift
@State var count = 0
@State var value = 0.0
@State var lastChange = ""

VStack {
    Button("Count").onClicked { count += 1 }

    Slider($value)
        .onValueChanged { newValue in
            lastChange = "User chose \(newValue)"
        }

    Text(lastChange)
}
```

Handlers run in writing order. A control's two-way binding is committed before
its handler starts, so the handler observes the new state. Programmatic writes
do not dispatch user events.

A handler may throw. One that awaits says what its event does when it comes
again while it runs - `.onClicked(gate: .ignoreWhileRunning) { … }` - and continues on
StateUI's UI isolation domain after each suspension. An uncaught error is
reported through the host rather than being discarded.
[Concurrency](concurrency.md#when-the-event-comes-again) defines the execution
model.

## Gestures

Gestures attach to any `View`, including a container used as one interactive
row. Configuration belongs to the same modifier as its handler, so no
half-configured recognizer remains in the tree.

### Tap and swipe

```swift quote
HStack {
    Text("Open details")
}
.padding(12)
.onTapped { path.append(.details) }
.onSwiped(direction: [.left, .right], threshold: 40) { direction in
    if direction == .left {
        path.append(.next)
    }
}
```

Use `onTapped(count:_:)` for a double or higher tap. A swipe
handler receives one dominant `SwipeDirection`; the option set on the modifier
defines which directions are recognized.

A view that answers a tap is a button to assistive technology. The platform's
accessibility press runs the same handler a tap runs, so a screen reader or an
automation script activates the row without a pointer. Give such a view a
`accessibilityLabel` so the button has a name.

### Pan and pinch

`PanUpdate` reports its phase and total displacement from the gesture's start.
`PinchUpdate.scale` is relative to the previous report:

```swift quote
@State private var x = 0.0
@State private var scale = 1.0

ColorBox(.cornflowerBlue)
    .translationX(x)
    .scale(scale)
    .onPanUpdated { update in
        if update.phase == .changed { x = update.totalX }
    }
    .onPinchUpdated { update in
        if update.phase == .changed { scale *= update.scale }
    }
```

For frame-rate gesture data that should not rebuild a body, `panX($state)` and
`panY($state)` feed host-carried state directly. An engine or driven property
can consume that channel without creating a description loop.

### Pointer

Pointer handlers cover enter, exit, move, press, and release. Coordinate
payloads are in the view's own space. A touch-only host may never report a
pointer hover; application behavior must not depend on hover as its sole route.

### Drag and drop

Text is the portable drag payload:

```swift quote
Text(item.title)
    .draggable(text: item.id)
    .onDragEnded { dragging = nil }

ZStack { Text("Drop here") }
    .onDrop { text in receive(text) }
    .onDragOver { highlighted = true }
    .onDragLeave { highlighted = false }
```

The payload is declared before the native drag starts. A start handler may
react to the drag but cannot asynchronously replace what the current drag
carries. On a touch screen the drag begins once the finger has held the view a
moment, as the platform's own drags do.

Files dragged from the system - from a file manager, another application, the
desktop - land on a view through `onDrop(files:)`, as `ChosenFile`s of the
kinds it lists:

```swift quote
ZStack { Text("Drop a report here") }
    .onDrop(files: [FileType("Text", extensions: ["txt", "md"])], gate: .waitForPrevious) { files in
        report = String(decoding: try await files[0].read(), as: UTF8.self)
    }
```

A view may take words and files both; `onDragOver` and `onDragLeave` serve
either. Files of other kinds are not taken, and a drop holding none of the
view's kinds is heard by nobody. A dropped file reads and launches as one the
user opened ([Files and links](#files-and-links)).

Gesture availability and host tests are tracked in
[Platform contract](../platform-contract.md).

## Aims and control methods

An `Aim<Target>` identifies one rendered control for a method call. It is not
state and does not participate in tree identity:

```swift
struct FocusForm: View {
    @Aim(TextField.self) private var field
    @State private var text = ""

    var body: some View {
        VStack {
            TextField($text).aim(field)
            Button("Edit").onClicked(gate: .ignoreWhileRunning) { try await field.focus() }
            Button("Done").onClicked(gate: .ignoreWhileRunning) { try await field.unfocus() }
        }
    }
}
```

The differ fills the aim with the element identity after the view has rendered.
One aim names one view. Calling through an aim that reached no view, was placed
on two views, or refers to a view that has left fails explicitly.

The type parameter limits methods to the controls that support them. Common
focus methods exist on every aim; specialized surfaces add methods such as
history navigation or map movement. `.id(...)` and `.aim(...)` can be used
together because they answer different questions: identity says which element
continues, while the aim says where an action goes.

`OnScreenKeyboard.hide()` dismisses whichever text input currently owns the on-screen
keyboard when the application does not hold that control's aim.

## Dialogs

Dialogs are sequential host actions rather than tree nodes:

```swift quote
Button("Delete").onClicked(gate: .ignoreWhileRunning) {
    let confirmed = try await Dialogs.confirm(
        "Delete draft?",
        message: "This cannot be undone",
        accept: "Delete",
        cancel: "Keep")

    if confirmed { drafts.removeAll() }
}
```

StateUI also provides a one-button `alert`, a `chooseAction` that returns the
chosen caption, and a prompt that returns typed text or `nil` on cancellation.
An accepted empty prompt is `""`, distinct from cancellation.

The host presents a dialog from the page currently visible, including the top
modal page. Dialogs show one at a time, in the order asked; one asked while
another is up waits until that one is answered.

## Files and links

The dialogs that open and save files are dialogs too, awaited the same way:

```swift
struct ReportPage: View {
    @State private var report = "<h1>Report</h1>"
    @State private var opened = ""

    var body: some View {
        VStack {
            Button("Save report…").onClicked(gate: .ignoreWhileRunning) {
                let page = FileType("HTML page", extensions: ["html"])
                let saved = try await Dialogs.saveFile(
                    Array(report.utf8), name: "Report", types: [page])
                if let saved { try await saved.launch() }
            }
            Button("Open…").onClicked(gate: .ignoreWhileRunning) {
                guard let file = try await Dialogs.openFile() else { return }
                opened = String(decoding: try await file.read(), as: UTF8.self)
            }
            Button("Help").onClicked(gate: .ignoreWhileRunning) {
                try await Links.launch("https://www.swift.org")
            }
        }
    }
}
```

`Dialogs.openFile` answers the `ChosenFile` the user picked, or `nil` on
cancellation; `Dialogs.openFiles` answers as many as they pick, none on
cancellation. A `FileType` gives a kind of file its caption and extensions;
the dialog that opens shows only those kinds, the one that saves offers them
with the first chosen. No kind means any file.

`Dialogs.saveFile` takes the contents first and writes them where the user
says, answering the file saved or `nil`. Its name gains the first kind's
extension where it ends in none of theirs. A browser with no save dialog
downloads the file instead, and the call answers it at once.

A `ChosenFile` shows only its `name`. Where it stands belongs to the platform -
a path, a document's address, a browser's file - so the application reads it
with `read()` and hands it to the system with `launch()`, which opens it in
the application the system gives its kind. `Links.launch` does the same for an
address. Both answer whether an application took it. A chosen file stays good
while the application runs.

`read(atMost:)` reads no more than so many bytes from the file's start, so a
file longer than the application takes is never read whole - one byte past
the limit is enough to tell it is too long:

```swift
struct NotePage: View {
    @State private var note = ""

    var body: some View {
        Button("Open a note…").onClicked(gate: .ignoreWhileRunning) {
            guard let file = try await Dialogs.openFile() else { return }
            let start = try await file.read(atMost: 1025)
            note = start.count > 1024
                ? "\(file.name) is longer than 1 KB"
                : String(decoding: start, as: UTF8.self)
        }
    }
}
```

## Host-extension actions

An application reaches its own host code through acts it declares in a tier
the application wears - an `ApplicationTier` - each with the types of its
arguments and its answer:

```swift
enum NotesContract: ApplicationTier {
    static let name = "Notes"

    static let exportDocument = ElementAct<Self, String, String>("Notes.ExportDocument")

    static let members: [any ContractMember] = [exportDocument]
}

@State var location = ""

Button("Export").onClicked(gate: .ignoreWhileRunning) {
    location = try await stateUICall(NotesContract.exportDocument, "draft-7")
}
```

`stateUICall` hands the act the arguments its contract declares, waits for the
answer it declares, and throws `StateUIError` on a host failure or an answer
of another shape. `stateUISend` is fire-and-forget and therefore has no error
result; use it only when no later decision depends on success.

A batch of actions is not a transaction. Use ordinary Swift control flow and
`await` for ordering.

Both halves are always needed: a declaration alone reaches nothing, and a host
refuses by name an act nobody registered.

The AppKit host registers them in Swift, typed by the same contract the call
is written against:

```swift quote
StateUIActs.add(NotesContract.exportDocument) { draft in
    "~/Documents/\(draft).pdf"
}
```

An act aimed at a control names that control at argument 0, and the host turns
the identity back into the view its registration made - so the performer is
handed the view itself:

```swift quote
StateUIActs.add(RatingBarContract.flash, on: RatingBarView.self) { bar in
    bar.flash()
}
```

## Host-extension events

`HostEvents` represents a provider notification with no tree element. The
application declares it in its contract with the types of the values it
carries. `HostEvents.on` answers the subscription, which is kept - dropping it
is a compiler warning - and cancelled with `cancel()` when its owner leaves,
since nothing else ends it; a view keeps it in its own state:

```swift
enum NotesContract: ApplicationTier {
    static let name = "Notes"

    static let importFinished = ElementEvent<Self, String>("Notes.ImportFinished")

    static let members: [any ContractMember] = [importFinished]
}

struct ImportStatus: View {
    @State private var imported = ""
    @State private var heard: [HostEventSubscription] = []

    var body: some View {
        Text(imported)
            .onCreated {
                heard = [
                    HostEvents.on(NotesContract.importFinished) { location in
                        imported = location
                    },
                ]
            }
            .onDestroying {
                heard.forEach { $0.cancel() }
                heard = []
            }
    }
}
```

A handler that awaits names what a raise does while it runs, as an element's
event does: `HostEvents.on(NotesContract.importFinished, gate: .waitForPrevious) {
location in … }`.

A raise carrying values of another shape is reported once and reaches no
handler. An ordinary control or gesture event always belongs on its element
instead. Use an application's events only for provider-owned notifications
that genuinely have no element identity.

The AppKit host raises such an event in Swift, typed by the same contract the
subscription is written against, from whatever thread the platform reports
on; the subscriptions hear it on the UI thread soon after, in the order
raised:

```swift quote
StateUIEvents.raise(NotesContract.importFinished, location)
```

A raise nobody hears is an ordinary one rather than a failure, so a host
wires its sources unconditionally. The head declares what it raises,
`StateUIEvents.raises(NotesContract.importFinished)`, and a subscription to an
event no head declared is said once, as a misspelled name would be.

## Accessibility and automation

Accessibility modifiers describe meaning, not test-only metadata:

```swift
Text("Order total")
    .accessibilityLabel("Order total: 42 euros")
    .accessibilityHint("Updates after the cart changes")
    .accessibilityHeading(.h1)
    .accessibilityIdentifier("checkout.total")
```

`accessibilityLabel` states what the element is, `accessibilityHint` explains the
result of interacting with it, and heading level describes document structure.
Use `isAccessibilityHidden` and
`automationExcludedWithChildren` to control exposure only when the composed
semantics require it.

`accessibilityIdentifier` is an external stable identifier for UI automation. It is not
the tree's `.id`, and assigning one does not change StateUI identity.

Announce an important asynchronous change that has no visible focused element:

```swift quote
try await ScreenReader.announce("Import complete")
```

Do not announce a tap result the user's focused control already expresses;
screen-reader output is a scarce, interrupting channel.

Every semantic value and action still requires a native mapping. The platform
matrix distinguishes declared API from verified accessibility and interaction
behavior.
