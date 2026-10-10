# Controls and input

StateUI exposes a cross-platform semantic control vocabulary. A host maps each
accepted control to native behavior; it does not make the platform class part
of application code. The complete member inventory and verified coverage are
in [Platform contract](../platform-contract.md).

## API shape

The value that gives a control its purpose belongs in its initializer:

```swift
Text("Account")
Button("Save")
Button(icon: "trash.png")
Image("avatar.png")
ColorBox(.cornflowerBlue)
```

Optional capabilities are modifiers:

```swift
Button("Save")
    .isEnabled(true)
    .padding(horizontal: 18, vertical: 10)
    .shape(.roundedRectangle(8))
    .onClicked { }
```

This keeps one spelling for a property whether it is authored inline, driven
by a binding, supplied by a style, or animated by the host. A control-specific
modifier appears only on controls for which the semantic capability is honest.

Common view modifiers are grouped by meaning:

- identity and aiming;
- visibility, enabled state, opacity, and hit testing;
- size, margin, alignment, clipping, and drawing order;
- planar transform;
- accessibility and automation;
- gestures, frame feeds, focus feeds, and motion.

The matrix is authoritative for the exact members and host evidence.

## Enabled state and hit testing

`isEnabled(false)` keeps a view in layout and in the hit-test path, but the
view does not perform its action. On a container it disables interaction in
the contained branch, the bar's actions and menu items declared in it
included.

`ignoresInput(true)` instead takes the view and everything in it out of hit
testing, so input reaches what is behind it. A layout's `letsInputThrough(true)`
takes only its own empty area out: input passes through an overlay's background
while the controls placed inside it still answer. These are distinct
accessibility and interaction semantics; consult the platform matrix before
relying on their native mapping.

## Described and carried values

A plain value is described when the body builds:

```swift
@State var enabled = true

Button(enabled ? "Enabled" : "Disabled")
    .isEnabled(enabled)
```

The two reads make this description depend on `enabled`. A binding overload
hands the state channel to the host instead:

```swift
@State var volume = 0.5

Slider($volume)
ColorBox(.cornflowerBlue).scaleX($volume)
```

Passing `$volume` does not make the body a reader. Native input and program
writes update the attached controls through the host-carried path. Read
`volume` elsewhere only when the tree actually needs its discrete destination.

A binding derived from arbitrary `get` and `set` closures has no StateUI
storage identity for the host to carry. A switch, check box, radio button,
picker, date and time pickers, text field, text editor and search field then
take the described/event path: the getter supplies the property and the
native report calls the setter. A slider, a stepper and every driven modifier
refuse it, say so once, and set nothing.

## Two-way input and event ordering

Controls with an editable purpose value accept either a value or a binding.
Examples include `TextField`, `TextEditor`, `SearchField`, `Switch`,
`CheckBox`, `RadioButton`, `Slider`, `Stepper`, `Picker`, `DatePicker`, and
`TimePicker`. Every property is one modifier named for it, which takes the
value itself or, where the host can carry the value, a state, `$x`
([A property is one modifier](../concepts/why.md#a-property-is-one-modifier-a-value-or-a-state)).

```swift
@State var enabled = false

Switch($enabled)
    .onToggled { value in
        // `enabled` already equals `value` here.
    }
```

For native input, the host commits the new value to the binding before it
dispatches the handler. An application write updates the control but does not
raise a user event. Same-value guards on both sides prevent native echoes from
forming a render loop.

Use a binding for state synchronization and a handler for the additional act
caused by the user. Do not duplicate the assignment in the handler.

## Text display

`Text` displays either one text value or a formatted sequence of runs:

```swift
Text()
    .spans {
        TextSpan("let ").textColor(.purple)
        TextSpan("count").fontAttributes(.bold)
        TextSpan(" = 0")
    }
```

`TextSpan` is structural text content, not a `View`: it stands among a label's
runs and nowhere else. It can carry text, font, decoration, line-height,
foreground, and run background properties, but it has no independent frame,
margin, or gesture surface. Runs made from a list go in as an array, each
matched by where it sits:

```swift quote
Text().spans {
    tokens.map { TextSpan($0.text).textColor($0.colour) }
}
```

Plain text and formatted text are mutually exclusive descriptions of one
label. A label given both a `text` and runs shows the runs.

Text properties distinguish their semantic tier; [Text](../controls/Text.md)
and the tier pages it links list each with its mark per host:

- text-bearing controls - a label, a button, a radio button, the fields, a
  span - take `textCase`, which draws the words `.uppercase` or `.lowercase`
  while the text stays as written; a field turns what is typed into the case
  and reports it so;
- text-styled controls take `textColor` and `tracking`, the space between
  letters; those in a font take `fontSize`, `fontFamily` - the name the
  application registered the font under - `fontAttributes`, which is `.bold`,
  `.italic`, `[.bold, .italic]` or `.none`, and `isFontAutoScalingEnabled`,
  on unless said, which makes the text follow the user's text-size setting;
- aligned controls take `horizontalTextAlignment` and
  `verticalTextAlignment`: `.start`, `.center` or `.end`;
- a label and a span take `textDecorations` - `.underline`, `.strikethrough`,
  or both - and `lineHeight`, a multiple of the font's own;
- a label's own properties control wrapping and maximum lines. `lineBreak` is
  `.wordWrap`, the default, `.characterWrap`, which breaks inside a word, or
  `.noWrap`; `.headTruncation`, `.tailTruncation` and `.middleTruncation` keep
  one line and cut it with an ellipsis at that place, which shows only where
  the label's width is bounded. `maximumLines` caps a wrapping label, `-1`,
  the default, meaning no limit. A button's caption takes `lineBreak` too.

```swift
VStack {
    Text("Underlined and struck through")
        .textDecorations([.underline, .strikethrough])

    Text("A long line that has nowhere left to go, so it is cut short with an ellipsis")
        .lineBreak(.tailTruncation)
        .maximumLines(1)

    Text("Letters spaced out")
        .tracking(3)

    Text("Two lines,\nlineHeight 2")
        .lineHeight(2)

    Text("One string, drawn in Two Ways")
        .textCase(.uppercase)

    Text("Stays at 16 whatever the system says")
        .fontSize(16)
        .isFontAutoScalingEnabled(false)
}
```

## Text entry, caret, and selection

`TextField` is single-line, `TextEditor` is multiline, and `SearchField`
expresses search intent. All three share two-way text and `onTextChanged`. A
`TextField` and a `SearchField` report the return key as `onSubmitted`; a
`TextEditor` takes a Return as text, and `isFocused` says when its editing
ends.

```swift
@State var query = ""

SearchField($query)
    .placeholder("Search notes")
    .onSubmitted {
        if query.isEmpty { query = "All notes" }
    }
```

`cursorPosition` and `selectionLength` place the native caret and selection;
the host does not report them back. The host remains responsible for valid
positions after native text normalization. `maximumLength` limits accepted
content; the other choices are separate semantic capabilities, each a property
of its own:

| Modifier | On | Meaning |
| --- | --- | --- |
| `placeholder`, `placeholderColor` | every field | what an empty field says, and its colour |
| `inputPurpose` | every field | what the text is for - `.plain`, `.text`, `.chat`, `.email`, `.numeric`, `.telephone`, `.url` - which picks the keyboard the platform offers |
| `isReadOnly` | every field | the text can be selected and copied but not changed, which is not the same as disabled |
| `isSpellCheckEnabled` | every field | whether the platform marks what it takes to be misspelt |
| `isTextPredictionEnabled` | every field | whether the platform offers the next word |
| `isPassword` | `TextField` | what is typed hides behind the platform's secure-entry marks |
| `submitLabel` | `TextField`, `SearchField` | the return key's caption - `.done`, `.go`, `.next`, `.search`, `.send`; what the key does is `.onSubmitted`, whatever it says |
| `showsClearButton` | `TextField` | whether the native button that empties the field shows, where the platform's field has one; it does unless told otherwise |

```swift
@State var code = ""
@State var email = ""
@State var hidden = true
@State var done = 0

VStack {
    TextField($code)
        .placeholder("a serial number")
        .textCase(.uppercase)
        .isSpellCheckEnabled(false)
        .isTextPredictionEnabled(false)

    TextField()
        .placeholder("a password")
        .isPassword(hidden)
        .submitLabel(.done)

    TextField($email)
        .placeholder("an address, capped at 20")
        .inputPurpose(.email)
        .maximumLength(20)
        .onSubmitted { done += 1 }
}
```

Focus is not a Boolean command hidden in the description. When state needs to
observe it, use the `isFocused` feed. When an action needs to move it, use an
`@Aim`; see [Interaction and actions](interaction-and-actions.md). Where the
field holding the keyboard is not known - a Done button above a form of
several fields - `OnScreenKeyboard.hide()` takes the focus off whatever has it
on the page showing. It answers a `Bool`: `true` when something was focused
and is not any more, `false` when the keyboard was already down, which is an
answer and not a failure:

```swift
@State var said = ""

Button("Close keyboard")
    .onClicked(gate: .ignoreWhileRunning) {
        said = try await OnScreenKeyboard.hide()
            ? "Focus released"
            : "Nothing was focused"
    }
```

## Choices and ranges

Choice controls follow the same binding rule:

```swift
@State var accepted = false
@State var level = 0.25
@State var index = 0

VStack {
    CheckBox($accepted)

    Slider($level)
        .minimum(0)
        .maximum(1)

    Picker(["Small", "Medium", "Large"])
        .selectedIndex($index)
}
```

The application owns the selected value. A group name on radio buttons defines
mutual exclusion in the native control surface; the bindings remain the source
of application truth. Range bounds are semantic constraints and are not
animated presentation values.

## Activity and progress

`ActivityIndicator` is the spinner for work with no measurable length;
`ProgressBar` says how far along measurable work is:

```swift
@State var loading = true
@State var done = 3.0

VStack {
    ActivityIndicator(loading)
        .height(48)

    Switch($loading)

    ProgressBar(done / 5)
        .height(8)

    Stepper($done)
        .minimum(0)
        .maximum(5)
        .step(1)
}
```

`isAnimating`, the indicator's one property, says whether it spins. A still
indicator is invisible on most platforms, so `ActivityIndicator(loading)` shows
it only while the work runs. `progress` is a fraction from 0 to 1, not a
percentage or a count: work counted in steps divides by their total itself, and
the host clamps a value outside that range. The initializer's argument is the
same property as the modifier: `ProgressBar().progress(0.4)` sets what
`ProgressBar(0.4)` sets, `.progress($done)` carries a state the host animates
to each new value, and `.isAnimating($loading)` one it sets as it stands. Both
take `.tint`. Nothing about either is the user's to change, so neither reports
anything back.

## Dates and times

Date and time controls use StateUI value types rather than Foundation types:

```swift
@State var date = CalendarDate(year: 2026, month: 9, day: 13)
@State var time = ClockTime(hour: 9, minute: 30)

VStack {
    DatePicker($date)
    TimePicker($time)
}
```

`CalendarDate` is a calendar day and `ClockTime` is a wall-clock time. Neither
pretends to be an instant. Conversion to Foundation or another date library
belongs in the application boundary; see [Environment](../concepts/environment.md).

## Images and media providers

`ImageSource` names an application resource and can choose light and dark
variants. `Image` and a button's `icon` consume it without exposing a platform
image type.

A button carries a picture in one of two ways. When the picture is its whole
purpose, it goes in the initializer: `Button(icon:)`. Beside a caption it is the
`icon` modifier, placed by `iconPosition` and set apart by `iconSpacing`:

```swift
Button(icon: "trash.png")
    .accessibilityLabel("Delete")

Button("Surprise me")
    .icon("nav_surprise.png")
    .iconPosition(.leading)
    .iconSpacing(8)
```

`.leading`, the default, is the side a line of text starts from, so the icon
follows the layout direction. A button with only an icon is the same control as
one with a caption - the same outline, shape and pressed state - with
`contentMode` for how its picture fills it. A picture alone gives it no name for a
screen reader, so it carries a `accessibilityLabel`.

## A place in a sequence

`PositionIndicator` is a row of dots saying how many there are and which one
is current - the dots under a run of cards, the steps of a short sequence:

```swift
@State var step = 0

VStack {
    PositionIndicator()
        .count(4)
        .position(step)
        .currentIndicatorColor(.cornflowerBlue)

    Button("Next")
        .onClicked { step = (step + 1) % 4 }
}
```

StateUI composes it of colour boxes in a row, so it looks and behaves the same
on every platform. `maximumVisible` caps the dots, the current one kept among
them; one lone dot is hidden unless `hidesForSinglePage(false)` asks for it;
`indicatorShape(.square)` draws squares. Given items,
`PositionIndicator(items) { … }` shows each item's own mark, the current one
whole and the others faded. Its look is written on it: being StateUI's own
composition, it takes no `Style`.

## Web content

`WebView` puts a page of the web in the tree: one fetched from an address, or
a document written in place:

```swift
WebView("https://example.com")
```

A document written in place shows without the network. Its relative links
resolve against the address given beside it, where one is:

```swift
WebView().source(html: "<h1>Offline</h1><p>Written in place.</p>")
```

A document given no address travels as an address of its own, which on
Android holds at most 2 MB: give a larger document an address beside it.

The web content scrolls itself, so give it room of its own - a Grid row, or a
page without a scroller - rather than a place inside a ScrollView.

What the view is told to do is an act called through its aim; whether there
is a page behind and ahead arrives in a binding:

```swift
@Aim(WebView.self) var browser
@State var canGoBack = false
@State var title = ""

Grid {
    HStack {
        Button("Back")
            .isEnabled(canGoBack)
            .onClicked(gate: .ignoreWhileRunning) { try await browser.goBack() }
        Button("Reload")
            .onClicked(gate: .ignoreWhileRunning) { try await browser.reload() }
        Button("Title?")
            .onClicked(gate: .ignoreWhileRunning) { title = try await browser.evaluateJavaScript("document.title") }
    }
    WebView("https://example.com")
        .canGoBack($canGoBack)
        .aim(browser)
        .gridRow(1)
}
.rows(.auto, .fill)
```

A script answers what it evaluated to as text: words as they are, a number as
it is written, anything else as JSON, and an empty string for no value. A
navigation is heard as it starts, with why - a new page, back, forward, the
page again - and as it ends, with how; the web process ending under the view
is heard too, and `reload()` brings the page back:

```swift
@State var status = "nothing has loaded yet"

WebView("https://example.com")
    .onNavigating { navigation in status = "going to \(navigation.url)" }
    .onNavigated { navigated in status = "\(navigated.result): \(navigated.url)" }
    .onProcessTerminated { status = "the page's process ended" }
```

| Host | The web view |
| --- | --- |
| AppKit | WebKit's `WKWebView` |
| UIKit | WebKit's `WKWebView` |
| Android Views | Android's `WebView` |
| WinUI 3 | WinUI's `WebView2`, over the system's WebView2 runtime - a backend |
| GTK 4 | WebKitGTK 6.0's `WebKitWebView` - a backend |
| Web | the browser's own `<iframe>`, which cannot observe a cross-origin page's navigation or set a user agent |

Where the web engine is a library the platform does not ship with its
toolkit - WebKitGTK, WebView2's runtime - the web view's realization is a
backend, a package of its own in `lib/Backends`, so an application that
shows no web page links no engine. An application showing one depends on it
from that head and registers it before the host runs. A package reached by its
path is known by its folder's name, `WebView.<Host>`, so the dependency gives it
the name the head's product refers to, as the Gallery's manifest does:

```text
Package.swift
  dependencies:  .package(name: "StateUIWebView<Host>", path: "<StateUI>/lib/Backends/WebView.<Host>")   for GTK or WinUI
  the head:      .product(name: "StateUIWebView<Host>", package: "StateUIWebView<Host>")

Platforms/<Host>/main.swift
  StateUIWebView<Host>.register()         before the host runs
```

## Maps

`Map` shows the platform's own map of the world: MapKit's on macOS, iOS and
iPadOS. Where the platform has no map of its own - Android, Windows, Linux -
the application registers the one it chooses with the host, with the
provider and the key that map needs ([Children a control
draws](../hosts/gtk.md#children-a-control-draws), on each host's page); the
platform matrix marks it 🧩 there.

A map opens on the region its initializer gives: a centre and a radius in
meters, the circle the map shows whole whatever its proportions. Its markers are
its children, and a tap is heard where it fell - on the map itself, on a marker,
or on a marker's details:

```swift
@State var said = "tap the map or a marker"

Map(latitude: 50.0617, longitude: 19.9373, radiusMeters: 1500)
    .mapType(.hybrid)
    .markers {
        Marker("Wawel Castle")
            .subtitle("Wawel 5")
            .type(.place)
            .location(latitude: 50.0540, longitude: 19.9354)
            .onSelected { said = "the castle" }
            .onDetailsClicked { said = "the castle's details" }
    }
    .onMapClicked { place in said = "\(place.latitude), \(place.longitude)" }
    .height(300)
```

Markers drawn from data are each given an id - `places.map { Marker($0.name).id($0.name) }`
- so a marker put before them leaves the others themselves, each pin and its
open callout where it stood; without one a marker is matched by its position.

The user pans and zooms the map as the platform lets them, and
`isScrollEnabled` and `isZoomEnabled` say whether they may. The region in the
initializer is where the map opens; moving it later is an act through its
aim, which slides the map there:

```swift
@Aim(Map.self) var map

Button("Kraków")
    .onClicked(gate: .cancelPrevious) { try await map.moveToRegion(latitude: 50.06, longitude: 19.94, radiusMeters: 2000) }
```

`showsUserLocation(true)` draws the user's own position. The platform asks
the user, once, for leave to know it, in words the application gives in its
head's property list: `NSLocationWhenInUseUsageDescription` in
`Platforms/UIKit/Info.plist` on iOS and iPadOS, `NSLocationUsageDescription`
in the Mac application's. Without them the position is never drawn.

## Collections

`ItemsView` shows items with the platform's own collection. StateUI says
which items there are and builds an item only when the platform shows it;
the platform scrolls, reuses its cells, shows the user's choice and tells
assistive technology about the items:

```swift
struct Contact: Hashable {
    let name: String
    let phone: String
}

struct ContactsPage: View {
    @State private var chosen: String?
    @Aim(ItemsView<String>.self) private var list

    let contacts: [Contact]

    var body: some View {
        Grid {
            ItemsView(contacts, id: \.name) { contact in
                VStack {
                    Text(contact.name).fontAttributes(.bold)
                    Text(contact.phone)
                }
                .padding(horizontal: 14, vertical: 10)
            }
            .selection($chosen)
            .onItemActivated { name in chosen = name }
            .aim(list)
            .gridRow(0)

            Button("Back to the top")
                .onClicked(gate: .cancelPrevious) { try await list.scrollTo(contacts[0].name, anchor: .start) }
                .gridRow(1)
        }
        .rows(.fill, .auto)
    }
}
```

An item names itself by its identity described as text, so two items must
describe differently. Each item is a view of its own: a state it reads
builds that item alone, and a state it declares lives while the platform
holds it on screen. The binding given to `.selection` says how many the
user may choose - an optional for one, a `Set` for many - and the user's
choice lands on it, while a value the application writes is shown and
reported to nobody. `.onItemActivated` hears an item opened: a tap on a
phone, a double-click or Return on a desktop. An aim at the list,
`Aim<ItemsView<ID>>`, scrolls it to an item by an identity of the list's
own type.

`.itemsLayout` lays the items `.list(spacing:)` one under another,
`.row(spacing:)` one beside another, scrolled across, or
`.grid(minimumItemWidth:spacing:)` in as many columns as the width holds.
An item is as tall as it asks in a list and as wide as it asks in a row; a
size written on its view is kept. A list has no height of its own: give it
one, or a row of a grid that fills.

`ItemsView(groups:)` takes `Section`s, each named with `.id` - so two
groups may hold equal items - and each with a `.header` and a `.footer`;
`.header` and `.footer` on the list stand before and after everything.
`.onEndReached(within:)` hears the user come within so many items of the
end - once, until they scroll away or the number of items changes - and
`.emptyView` stands in the list's place while it has no items.

## Choosing a control

Prefer the smallest accepted native primitive that expresses the behavior.
Compose richer application controls as `View`s. Add a base control only
when the capability has one coherent meaning across target toolkits or belongs
to a clearly optional provider package.
