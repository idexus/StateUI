# Interaction and actions

StateUI distinguishes three things:

- state says what the interface currently means;
- an event reports something the reader or platform committed;
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
            lastChange = "Reader chose \(newValue)"
        }

    Label(lastChange)
}
```

Handlers run in writing order. A control's two-way binding is committed before
its handler starts, so the handler observes the new state. Programmatic writes
do not dispatch reader events.

Handlers are `async throws`. They may suspend and continue on StateUI's UI
isolation domain. An uncaught error is reported through the host rather than
being discarded. [Concurrency](concurrency.md) defines the execution model.

## Gestures

Gestures attach to any `View`, including a container used as one interactive
row. Configuration belongs to the same modifier as its handler, so no
half-configured recognizer remains in the tree.

### Tap and swipe

```swift quote
Border {
    Label("Open details")
        .padding(12)
}
.onTapped { path.append(.details) }
.onSwiped(direction: [.left, .right], threshold: 40) { direction in
    if direction == .left {
        path.append(.next)
    }
}
```

Use `onTapped(numberOfTapsRequired:_:)` for a double or higher tap. A swipe
handler receives one dominant `SwipeDirection`; the option set on the modifier
defines which directions are recognized.

A view that answers a tap is a button to assistive technology. The platform's
accessibility press runs the same handler a tap runs, so a screen reader or an
automation script activates the row without a pointer. Give such a view a
`semanticDescription` so the button has a name.

### Pan and pinch

`PanUpdate` reports status and total displacement from the gesture's start.
`PinchUpdate.scale` is relative to the previous report:

```swift quote
@State private var x = 0.0
@State private var scale = 1.0

BoxView(.cornflowerBlue)
    .translationX(x)
    .scale(scale)
    .onPanUpdated { update in
        if update.status == .running { x = update.totalX }
    }
    .onPinchUpdated { update in
        if update.status == .running { scale *= update.scale }
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
Label(item.title)
    .draggable(text: item.id)
    .onDropCompleted { dragging = nil }

Border { Label("Drop here") }
    .onDrop { text in receive(text) }
    .onDragOver { highlighted = true }
    .onDragLeave { highlighted = false }
```

The payload is declared before the native drag starts. A start handler may
react to the drag but cannot asynchronously replace what the current drag
carries.

Gesture availability and host tests are tracked in
[Platform contract](platform-contract.md).

## Aims and control methods

An `Aim<Target>` identifies one rendered control for a method call. It is not
state and does not participate in tree identity:

```swift
struct FocusForm: ContentView {
    @Aim(Entry.self) private var field
    @State private var text = ""

    var content: any View {
        VStack {
            Entry($text).aim(field)
            Button("Edit").onClicked { try await field.focus() }
            Button("Done").onClicked { try await field.unfocus() }
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

`SoftInput.hide()` dismisses whichever text input currently owns the on-screen
keyboard when the application does not hold that control's aim.

## Dialogs

Dialogs are sequential host actions rather than tree nodes:

```swift quote
Button("Delete").onClicked {
    let confirmed = try await Dialogs.displayAlert(
        "Delete draft?",
        message: "This cannot be undone",
        accept: "Delete",
        cancel: "Keep")

    if confirmed { drafts.removeAll() }
}
```

StateUI also provides a one-button alert, an action sheet that returns the
chosen caption, and a prompt that returns typed text or `nil` on cancellation.
An accepted empty prompt is `""`, distinct from cancellation.

The host presents a dialog from the page currently visible, including the top
modal page. `await` determines sequencing: two actions queued together start
in queue order but may finish independently; awaiting the first before issuing
the second makes the dependency explicit.

## Host-extension actions

Open `Act` values let a host package define an extension boundary and wrap its
low-level call in a typed function:

```swift quote
extension Act {
    static let exportDocument = Act("com.example.notes.export-document")
}

@MainThread
func export(_ id: String) async throws -> String {
    let result = try await stateUICall(.exportDocument, [.string(id)])
    guard let location = result.first?.string else {
        throw StateUIError(message: "The export returned no location")
    }
    return location
}
```

`stateUICall` waits for typed return values and throws `StateUIError` on a host
failure. `stateUISend` is fire-and-forget and therefore has no error result;
use it only when no later decision depends on success.

A batch of actions is not a transaction. Use ordinary Swift control flow and
`await` for ordering.

The active AppKit host does not expose a public action-handler registry.
Consequently, an application or provider cannot make the example above
operational merely by declaring the token; AppKit rejects an act it does not
own. This is a host-extension contract for a package that supplies a real
adapter hook, tests, and a checked matrix row, not a currently available AppKit
plug-in point.

## Host-extension events

`HostEvents` represents a provider notification with no tree element. The
subscription must be retained and cancelled when its owner leaves:

```swift quote
extension Event {
    static let importFinished = Event("com.example.notes.import-finished")
}

var subscription: HostEventSubscription?

subscription = HostEvents.on(.importFinished) { payload in
    imported = payload.first?.string
}

subscription?.cancel()
subscription = nil
```

An ordinary control or gesture event always belongs on its element instead.
Use open host events only for provider-owned notifications that genuinely have
no element identity.

The active typed AppKit SPI does not publicly expose emission of an arbitrary
host event. As with an open act, a declaration and subscription alone do not
make this a usable extension: the provider's host adapter must own a supported
emission route and its lifecycle. Wire hosts can implement that boundary, but
support still belongs in the platform matrix.

## Accessibility and automation

Accessibility modifiers describe meaning, not test-only metadata:

```swift
Label("Order total")
    .semanticDescription("Order total: 42 euros")
    .semanticHint("Updates after the cart changes")
    .semanticHeadingLevel(.level1)
    .automationId("checkout.total")
```

`semanticDescription` states what the element is, `semanticHint` explains the
result of interacting with it, and heading level describes document structure.
Use `automationIsInAccessibleTree` and
`automationExcludedWithChildren` to control exposure only when the composed
semantics require it.

`automationId` is an external stable identifier for UI automation. It is not
the tree's `.id`, and assigning one does not change StateUI identity.

Announce an important asynchronous change that has no visible focused element:

```swift quote
try await SemanticScreenReader.announce("Import complete")
```

Do not announce a tap result the reader's focused control already expresses;
screen-reader output is a scarce, interrupting channel.

Every semantic value and action still requires a native mapping. The platform
matrix distinguishes declared API from verified accessibility and interaction
behavior.
