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
again while it runs - `.onClicked(.ignoreWhileRunning) { … }` - and continues on
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

Rectangle()
    .fill(.cornflowerBlue)
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
    .onDrop(files: [FileType("Text", extensions: ["txt", "md"])], policy: .waitForPrevious) { files in
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
            Button("Edit").onClicked(.ignoreWhileRunning) { try await field.focus() }
            Button("Done").onClicked(.ignoreWhileRunning) { try await field.unfocus() }
        }
    }
}
```

The differ fills the aim with the element identity after the view has rendered.
One aim names one view. Calling through an aim that reached no view, was placed
on two views, or refers to a view that has left fails explicitly.

The type parameter limits methods to the controls that support them. `focus()`
and `unfocus()` exist on the aim of a control that takes the focus - a field, a
button, a list - never on a text or a stack, which cannot; specialized surfaces
add methods such as history navigation or map movement. `.id(...)` and `.aim(...)` can be used
together because they answer different questions: identity says which element
continues, while the aim says where an action goes.

`window.hideOnScreenKeyboard()` dismisses whichever text input in the window
owns the on-screen keyboard when the application does not hold that control's
aim.

## Dialogs

Dialogs are sequential host actions rather than tree nodes, asked of the window
a view stands in - the session it reads with `@Environment(\.window)`:

```swift quote
Button("Delete").onClicked(.ignoreWhileRunning) {
    let confirmed = try await window.confirm(
        "Delete draft?",
        message: "This cannot be undone",
        accept: "Delete",
        cancel: "Keep")

    if confirmed { drafts.removeAll() }
}
```

StateUI also provides a one-button `alert`, a `chooseAction` that returns the
action chosen - one of the values it offers, or `nil` for its cancel - and a
prompt that returns typed text or `nil` on cancellation. An accepted empty
prompt is `""`, distinct from cancellation. A cancel left unnamed says the
system's own word, in the user's language:

```swift quote
let choice = try await window.chooseAction(
    "Share via", among: Share.allCases, caption: \.title, destructive: .delete)
if choice == .delete { drafts.removeAll() }
```

The host presents a dialog over the window that asked, on the page it shows,
including the top modal page; a view outside every window asks in the window
the user is in. Dialogs show one at a time, in the order asked; one asked while
another is up waits until that one is answered, and one whose window closed
meanwhile is answered as if the user dismissed it.

## Files and links

The dialogs that open and save files are dialogs too, a window's and awaited the
same way; launching an address is the application's:

```swift
struct ReportPage: View {
    @Environment(\.window) private var window
    @Environment(\.application) private var application
    @State private var report = "<h1>Report</h1>"
    @State private var opened = ""

    var body: some View {
        VStack {
            Button("Save report…").onClicked(.ignoreWhileRunning) {
                let page = FileType("HTML page", extensions: ["html"])
                let saved = try await window.saveFile(
                    Array(report.utf8), name: "Report", types: [page])
                if let saved { try await saved.launch() }
            }
            Button("Open…").onClicked(.ignoreWhileRunning) {
                guard let file = try await window.openFile() else { return }
                opened = String(decoding: try await file.read(), as: UTF8.self)
            }
            Button("Help").onClicked(.ignoreWhileRunning) {
                try await application.launch("https://www.swift.org")
            }
        }
    }
}
```

`window.openFile` answers the `ChosenFile` the user picked, or `nil` on
cancellation; `window.openFiles` answers as many as they pick, none on
cancellation. A `FileType` gives a kind of file its caption and extensions;
the dialog that opens shows only those kinds, the one that saves offers them
with the first chosen. No kind means any file.

`window.saveFile` takes the contents first and writes them where the user
says, answering the file saved or `nil`. Its name gains the first kind's
extension where it ends in none of theirs. A browser with no save dialog
downloads the file instead, and the call answers it at once.

A `ChosenFile` shows only its `name`. Where it stands belongs to the platform -
a path, a document's address, a browser's file - so the application reads it
with `read()` and hands it to the system with `launch()`, which opens it in
the application the system gives its kind. `application.launch` does the same for an
address. Both answer whether an application took it. A chosen file stays good
while the application runs.

`read(atMost:)` reads no more than so many bytes from the file's start, so a
file longer than the application takes is never read whole - one byte past
the limit is enough to tell it is too long:

```swift
struct NotePage: View {
    @Environment(\.window) private var window
    @State private var note = ""

    var body: some View {
        Button("Open a note…").onClicked(.ignoreWhileRunning) {
            guard let file = try await window.openFile() else { return }
            let start = try await file.read(atMost: 1025)
            note = start.count > 1024
                ? "\(file.name) is longer than 1 KB"
                : String(decoding: start, as: UTF8.self)
        }
    }
}
```

## The clipboard

The system's clipboard is the application's `clipboard`: `write(text:)` puts
words on it in place of what it held, and `text()` reads the words it holds,
`nil` where it holds none.

```swift
struct LinkRow: View {
    @Environment(\.application) private var application
    let link: String

    var body: some View {
        HStack {
            Text(link)
            Button("Copy").onClicked(.ignoreWhileRunning) {
                try await application.clipboard.write(text: link)
            }
        }
    }
}
```

A platform may ask the user before the application reads what another
application put there - iOS and a browser do. A browser's read throws where
the user refuses, and a page served over plain http has no clipboard.

## Sharing

A window offers what the user shares to the platform's share sheet:
`share(text:)`, `share(link:)`, or both together with `share(text:link:)`. The
call answers whether the user shared it, `false` where they cancelled.

```swift
struct TalkPage: View {
    @Environment(\.window) private var window
    let talk = "https://www.swift.org"

    var body: some View {
        Button("Share the talk").onClicked(.ignoreWhileRunning) {
            try await window.share(text: "The talk I mentioned", link: talk)
        }
    }
}
```

GNOME offers an application no share sheet, and a browser may have none:
there the call throws with that reason.

## Requests to a server

`application.send` sends an `HTTPRequest` through the platform's own
networking - its certificates, proxy and network rules hold - and answers
the server's `HTTPResponse`: its `status`, its `headers` by name and its
`body`, `text` reading the body as UTF-8.

```swift
struct WeatherPage: View {
    @Environment(\.application) private var application
    @State private var said = "Ask for the weather"

    var body: some View {
        VStack {
            Button("Weather").onClicked(.cancelPrevious) {
                let response = try await application.send(HTTPRequest(
                    "https://api.open-meteo.com/v1/forecast?latitude=50.06&longitude=19.94&current=temperature_2m"))
                said = response.status == 200 ? response.text : "The server answered \(response.status)"
            }
            Text(said)
        }
    }
}
```

Any status is an answer - a 404 is the server's word; what throws is no
answer at all: no connection, no server, an address the platform cannot
read. A request carries a method, headers and a body
(`HTTPRequest(address, method: .post, headers:, body:)`), and a header's
name is read in any case (`response.header("Content-Type")`). The platform
keeps the cookies a server sets, as a browser does, so a session a server
opens holds for the requests after it. A request ends with the run that sent
it: under `.cancelPrevious` the next tap stops the one under way, and a page
left stops its own
([Concurrency](concurrency.md#when-the-event-comes-again)).

An address names its scheme. On the Web an address with none stands on the
page's own, and the browser's rules for another site's answers hold. An
Android application declares
`<uses-permission android:name="android.permission.INTERNET" />` in its
manifest, and a plain `http:` address there needs its leave too.

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

Button("Export").onClicked(.ignoreWhileRunning) {
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
carries. A view hears it with `.onHostEvent`, which belongs to the view: it
is subscribed as the view is made and cancelled as it leaves, each raise run
by the handler the last render wrote:

```swift
enum NotesContract: ApplicationTier {
    static let name = "Notes"

    static let importFinished = ElementEvent<Self, String>("Notes.ImportFinished")

    static let members: [any ContractMember] = [importFinished]
}

struct ImportStatus: View {
    @State private var imported = ""

    var body: some View {
        Text(imported)
            .onHostEvent(NotesContract.importFinished) { location in
                imported = location
            }
    }
}
```

A handler that awaits names what a raise does while it runs, as an element's
event does: `.onHostEvent(NotesContract.importFinished, policy: .waitForPrevious) {
location in … }`. Code that no view stands for - an application's model -
subscribes with `HostEvents.on`, which answers the subscription: it is kept -
dropping it is a compiler warning - and cancelled with `cancel()` when its
owner is done, since nothing else ends it.

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

## Keyboard shortcuts

A button presses from the keyboard while its window is in front:

```swift
struct Editor: View {
    @State private var saved = 0

    var body: some View {
        HStack {
            Button("Save")
                .keyboardShortcut("s")
                .onClicked { saved += 1 }
            Button("Send")
                .keyboardShortcut(.return, modifiers: [])
                .onClicked { saved += 1 }
        }
    }
}
```

A shortcut is a `Key` - a character, `"s"`, or one of `.return`, `.escape`,
`.delete`, the arrows and `.f1` to `.f12` - with the keys held with it, or with
none: `keyboardShortcut("1", modifiers: [])` presses a button on the key `1`
alone, except while a field is being typed into, where the `1` is written -
and Return there ends what was typed.
`.primary` alone is held unless the shortcut says otherwise: Command on Apple's
platforms, Control on Windows, Linux and Android, so one `keyboardShortcut("s")`
is ⌘S on the Mac and Ctrl+S elsewhere; `.shift` and `.alt` add Shift and
Option or Alt. A disabled button's shortcut presses nothing, and a button on
a page out of sight - beneath a stack's top, behind another tab - takes none.
Two controls in one window stating the same shortcut is said in debug: which of
them acts is then not yours to choose.

A menu bar's entry and a bar's item take a shortcut the same way, and the
shortcut chooses them as a click does; a menu shows it beside the entry's
words:

```swift
struct Document: View {
    @State private var exported = 0

    var body: some View {
        Text("Exported \(exported) times")
            .contextMenu {
                MenuItem("Export…")
                    .keyboardShortcut("e", modifiers: [.primary, .shift])
                    .onClicked { exported += 1 }
            }
            .menuBar {
                Menu("File") {
                    MenuItem("Export…")
                        .keyboardShortcut("e", modifiers: [.primary, .shift])
                        .onClicked { exported += 1 }
                }
                .id(StandardMenu.file)
            }
            .toolbar {
                ToolbarButton("Mark")
                    .keyboardShortcut("m")
                    .onClicked { exported += 1 }
            }
    }
}
```

A context menu's entry only shows its shortcut, telling the user the keys of
the command it repeats; pressing them chooses the menu bar's entry, never the
context menu's.

### A button's role

A role says what a button stands for in its window, and gives it a key:

```swift
struct Rename: View {
    @State private var name = ""
    @State private var renamed = false

    var body: some View {
        VStack {
            TextField($name)
                .onSubmitted { renamed = true }
            HStack {
                Button("Cancel")
                    .role(.cancel)
                    .onClicked { name = "" }
                Button("Rename")
                    .role(.primary)
                    .onClicked { renamed = true }
            }
        }
    }
}
```

`.primary` is the window's main action: filled in the platform's accent and
pressed by Return. `.cancel` is the way out, pressed by Escape, and stands as
the platform's plain button. `.destructive` marks an action that destroys
something: its words stand in the platform's color for one - the red its
alerts and menus give such an action. A fill or a color of words the button
is given, by a style or itself, takes the place of its role's, and
`Style<Button>(role:)` styles a role in an application's own look. A
shortcut the button states takes the place of its role's key. Return belongs
to a field being typed into - it ends the words there, and `.onSubmitted`
hears it - so the main action takes Return while no field holds the keyboard.

### A button's menu

A button can hold a menu, written as a menu is. How it opens is one of three
kinds:

```swift
struct Document: View {
    @State private var last = ""

    var body: some View {
        HStack {
            Button("Share").menu {
                MenuItem("Mail").onClicked { last = "mail" }
                MenuItem("Message").onClicked { last = "message" }
            }
            Button("Save")
                .onClicked { last = "saved" }
                .menu { MenuItem("Save as…").onClicked { last = "saved as" } }
            Button("Open")
                .onClicked { last = "opened" }
                .menu(.held) { MenuItem("Open recent").onClicked { last = "recent" } }
        }
    }
}
```

- With no `.onClicked`, a click opens the menu, and an arrow pointing down
  after the words says so. `.showsMenuArrow(false)` takes the arrow away - an
  icon alone opening a menu.
- With one, the button splits: its click is its own action, and an arrow of
  its own beside it opens the menu. `.menu(.split) { }` splits a button with
  no action too.
- `.menu(.held) { }` keeps the click the button's own and opens the menu when
  the user holds the button - a mouse button or a finger held down; on Windows
  and in a browser, as the user asks for any menu there: a finger held still or
  the mouse's other button. It shows no arrow.

A button holding a menu offers no context menu of its own. A `ToolbarButton`
holds one the same way ([Toolbars](navigation-and-presentation.md#toolbars)).

### A view's keys

A control taking the focus, and a layout holding one, hears the keys it names
while it holds the keyboard:

```swift
struct Search: View {
    @State private var query = ""
    @State private var row = 0

    var body: some View {
        VStack {
            TextField($query)
            Text("Row \(row)")
        }
        .onKeyPressed(.upArrow, .downArrow, .tab, .escape) { press in
            switch press.key {
            case .escape: query = ""
            case .tab: row += press.modifiers.contains(.shift) ? -1 : 1
            default: row += press.key == .upArrow ? -1 : 1
            }
        }
    }
}
```

The nearest view naming a key takes it, out from the one holding the
keyboard; with nothing holding it, the page's content does. A taken key
reaches nothing else - the field above keeps its caret where it was - and
every other key goes on as before. A text, a picture or a shape never holds
the keyboard, so it offers no `onKeyPressed`. The handler is handed the key
and the keys held with it (`KeyPress`): Shift, where it was - Tab and
Shift-Tab are one key told apart by it. A key held with the platform's own key
or Alt belongs to shortcuts. Besides letters, digits, Return, Escape, Delete,
the arrows and F1 to F12, a view takes Tab, Space, Home, End, Page Up and Page
Down. `.onKeyPressed(.escape, policy:
.ignoreWhileRunning) { _ in try await close() }` takes a handler that awaits.

## Tooltips

`tooltip` gives any view words the platform shows beside it while the pointer
rests on it:

```swift
Button("Delete")
    .icon("trash.png")
    .showsText(false)
    .tooltip("Moves the file to the bin")
```

The Mac, Windows, Linux and the Web show it after their own delay, and Android
after a long press too. An iPhone and an iPad show none, so nothing a view
needs to be used is said only in its tooltip. A tooltip is no
accessible name: a button showing its picture alone is named by its words.

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
`hidesChildrenFromAccessibility` to control exposure only when the composed
semantics require it.

A view composed of parts says what it is and holds with `accessibilityRole`
and `accessibilityValue`, so a screen reader meets one thing where the screen
shows several:

```swift
struct Rating: View {
    @State private var stars = 3

    var body: some View {
        HStack {
            ForEach(1...5) { star in
                Text(star <= stars ? "★" : "☆").onTapped { stars = star }
            }
        }
        .accessibilityLabel("Rating")
        .accessibilityRole(.adjustable)
        .accessibilityValue("\(stars) of 5")
        .onAccessibilityAdjusted { step in
            stars = min(5, max(0, stars + (step == .increment ? 1 : -1)))
        }
        .accessibilityAction("Clear") { stars = 0 }
    }
}
```

A screen reader steps an adjustable view up and down, which
`onAccessibilityAdjusted` hears, and offers the view's actions by their words;
an action is what a user who sees the screen reaches by a gesture or a menu.

A control is its own kind and says its own value already, so the pair belongs
on a layout. VoiceOver and TalkBack offer the actions and the steps; the
platform matrix says where the other readers do. The kinds are those every platform's screen reader names alike:
`.button`, `.toggle`, `.adjustable`, `.link`, `.image` and `.text`.

`accessibilityIdentifier` is an external stable identifier for UI automation. It is not
the tree's `.id`, and assigning one does not change StateUI identity. A view, a
menu's entry, a bar's item and a page arrangement take one; a run of text and a
style do not, as automation never meets a run and a style dresses many controls.

Announce an important asynchronous change that has no visible focused element:

```swift quote
try await application.announce("Import complete")
```

Do not announce a tap result the user's focused control already expresses;
screen-reader output is a scarce, interrupting channel.

Every semantic value and action still requires a native mapping. The platform
matrix distinguishes declared API from verified accessibility and interaction
behavior.
