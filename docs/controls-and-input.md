# Controls and input

StateUI exposes a cross-platform semantic control vocabulary. A host maps each
accepted control to native behavior; it does not make the platform class part
of application code. The complete member inventory and verified coverage are
in [Platform contract](platform-contract.md).

## API shape

The value that gives a control its purpose belongs in its initializer:

```swift
Label("Account")
Button("Save")
Button(icon: "trash.png")
Image("avatar.png")
ColorBox(.cornflowerBlue)
```

Optional capabilities are modifiers:

```swift
Button("Save")
    .isEnabled(true)
    .padding(18, 10)
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
the contained branch.

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
storage identity for the host to carry. It still behaves correctly, but it
takes the described/event path: the getter supplies the property and the
native report calls the setter.

## Two-way input and event ordering

Controls with an editable purpose value accept either a value or a binding.
Examples include `TextField`, `TextEditor`, `SearchField`, `Switch`,
`CheckBox`, `RadioButton`, `Slider`, `Stepper`, `Picker`, `DatePicker`, and
`TimePicker`.

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

`Label` displays either one text value or a formatted sequence of runs:

```swift
Label()
    .spans {
        TextSpan("let ").textColor(.purple)
        TextSpan("count").fontAttributes(.bold)
        TextSpan(" = 0")
    }
```

`TextSpan` is structural text content, not a `View`. It can carry text, font,
decoration, line-height, foreground, and run background properties, but it has
no independent frame, margin, or gesture surface.

Plain text and formatted text are mutually exclusive descriptions of one
label. Do not rely on modifier order to keep both.

Text properties distinguish their semantic tier:

- text-bearing controls can transform authored text;
- text-styled controls can choose font family, size, attributes, color,
  alignment, and spacing where their host surface supports it;
- label-only properties control wrapping and maximum lines.

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

`cursorPosition` and `selectionLength` describe and report the native caret
and selection. The host remains responsible for valid positions after native
text normalization. `maximumLength` limits accepted content; read-only,
spell-check, prediction, password, return-key, and clear-button choices remain
separate semantic capabilities.

Focus is not a Boolean command hidden in the description. When state needs to
observe it, use the `isFocused` feed. When an action needs to move it, use an
`@Aim`; see [Interaction and actions](interaction-and-actions.md).

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
belongs in the application boundary; see [Environment](environment.md).

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
`aspect` for how its picture fills it. A picture alone gives it no name for a
screen reader, so it carries a `accessibilityLabel`.

## Provisional native surfaces

The following declarations express a candidate semantic contract but are not
part of the usable base surface until the platform matrix records a verified
host. Their presence in the Swift module is not a support claim:

| Surface | Semantic contract under evaluation |
| --- | --- |
| `WebView` | URL or inline-HTML source; back/forward capability feeds; navigation reports; aimed back, forward, reload, and script actions |
| `Map` | provider-owned native map; initial region in the declaration; pins and tap reports; later region changes through an aim |
| `PositionIndicator` | display-only count and current position with native indicator appearance |

`Map` is provider-owned because credentials, map engines, permissions, and
feature sets are not one base-platform primitive. The other candidates enter
the base contract only if the target native toolkits can preserve the stated
ownership, input, accessibility, and lifecycle semantics without growing a
second UI system in the host. A surface that cannot meet that bar is removed
vertically from API, vocabulary, tests, Gallery, and documentation.

The intended source/event/aim shapes above keep design review explicit; they do
not authorize production use on an unmarked host.

## Collections

`ForEach` is identified composition, not virtualization. The native
virtualized collection contract remains intentionally unadmitted until all
target hosts can share identity, reuse, selection, activation, accessibility,
and programmatic scrolling semantics. See [Layout](layout.md) for the current
boundary.

## Choosing a control

Prefer the smallest accepted native primitive that expresses the behavior.
Compose richer application controls as `ContentView`s. Add a base control only
when the capability has one coherent meaning across target toolkits or belongs
to a clearly optional provider package.
