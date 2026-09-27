# Styles and drawing

StateUI resolves styles, theme variants, and visual-state setters in Swift
before a host receives a control patch. The host sees the effective semantic
properties it must apply; it does not run a second style cascade.

## Style sheets

A `StyleSheet` contains typed styles. An unkeyed style applies implicitly to
every control of its target type. A keyed style is selected with `.style(...)`:

```swift
enum HandbookStyles {
    static var sheet: StyleSheet {
        StyleSheet {
            Style<Label>()
                .fontSize(15)
                .textColor(Color(light: .black, dark: .white))

            Style<Button>("Primary")
                .textColor(.white)
                .background(.cornflowerBlue)
                .shape(.roundedRectangle(8))

            Style<Button>("Danger")
                .basedOn("Primary")
                .background(.firebrick)
        }
    }
}
```

Install the sheet on `ApplicationSession` when the application is made:

```swift quote
struct NotesApp: Application {
    @Environment private var application: ApplicationSession

    init() {
        application.styles = HandbookStyles.sheet
    }

    var scene: any Scene { MainWindow() }
}
```

Use a keyed style by name:

```swift
Button("Delete")
    .style("Danger")
```

`basedOn` is flattened when the sheet is resolved. A derived style inherits
only properties it does not replace, and resolving the style for a control
does not walk the chain again. The referenced style may appear later in the
same sheet. A missing base contributes nothing. If a chain contains a cycle,
resolution stops at the first key it would visit again; the values accumulated
before that cut remain, with each derived style still winning over its base.
This makes a malformed cycle finite and deterministic, but a cycle does not
express a useful precedence and should be removed.

A property written directly on a control wins over a style. A recognized keyed
style for the same target replaces that target's implicit style, so it must
inherit from or state every value it requires. A key that is absent, or belongs
to another target type, is unresolved and falls through to the implicit style
for the control's own type. If no implicit style exists, only the control's own
values remain. The differ consumes the key in every case; hosts never resolve
style names.

The style's generic target is a compile-time boundary. It offers only the
property modifiers valid for that control; events, gestures, identity, and
driven bindings are not style values.

## Theme values

`Color` stores exact sRGB channels and optionally a light and dark variant:

```swift
let surface = Color(light: .white, dark: Color("#18181B"))
let accent = Color("#5B5BD6")
let translucent = Color("#805B5BD6")
let sameTranslucent = Color(red: 91, green: 91, blue: 214, alpha: 128)
```

Hex input accepts `#RGB`, `#ARGB`, `#RRGGBB`, or `#AARRGGBB`, the alpha first
when it is written. Named colors are static members checked by the compiler.
`Color(red:green:blue:alpha:)` takes whole-number channels from 0 through 255;
the alpha is 255, opaque, unless it is given.

`ImageSource` follows the same theme rule:

```swift
let icon = ImageSource(light: "edit.png", dark: "edit-dark.png")
Image(icon)
```

The differ resolves the theme variant for the element wearing it. A system
theme change invalidates those resolved uses. The host therefore receives one
concrete color or resource name and needs no parallel theme binding model.

Use `@Environment var app: AppInfo` only when application logic needs the
theme as a value. A themed color or image follows the theme without an
application branch.

## Visual states

A visual state is a set of values a control shows while it is in a state:
disabled, held down, under the pointer, holding the keyboard, on or off. Two
modifiers work with it, one for each half of a control: `.visualState` says
what the control looks like in a state, in a style or on the control, and
`.onVisualStateChanged` says what happens when it enters one.

```swift
Style<Button>()
    .background(.cornflowerBlue)
    .visualState(.disabled) { state in
        state
            .background(.gray)
            .textColor(.darkGray)
    }
    .visualState(.pressed) { state in
        state.opacity(0.75)
    }
```

The states offered after the dot are the ones that control enters. Every
view has normal, disabled, focused and pointer-over; a button adds pressed, a
switch on and off, a check box on, a radio button checked and unchecked. A
state the control never enters does not compile.

StateUI decides which state a control is in, the same way on every platform:
the first that holds of disabled, pressed, pointer-over, focused, on or
checked, off or unchecked - and normal when none does. What the control shows
is every state that holds at once, the earlier in that order winning a value
two of them set. A disabled switch that is on is dimmed, and green:

```swift
@State var isOn = true

Switch($isOn)
    .isEnabled(false)
    .visualState(.disabled) { $0.opacity(0.5) }
    .visualState(.on) { $0.background(.green) }
```

Normal's values show only when no other state holds.

Leaving a state gives the control its own values back. A state's values are
ordinary property changes: they move under the control's `.motion(_:)` like
any other value, and `.motion(.none)` makes them change at once.

A control can override or add states locally. Its values merge with its
style's by state and property, so a local change does not erase the
style's other values:

```swift
Button("Save")
    .visualState(.pressed) { state in
        state.background(.steelBlue)
    }
```

`onVisualStateChanged` runs after the control entered a state - never for the
state it starts in - and receives the typed state. Naming states declares
them without changing how the control looks and hears only them; naming none
hears every state the control declares, normal included:

```swift quote
@State private var scale = 1.0

Button("Hold")
    .scale($scale)
    .onVisualStateChanged(.pressed, .normal) { state in
        try await $scale.journey.move(
            to: state == .pressed ? 0.96 : 1,
            .eased(90))
}
```

Use the handler when entering a state starts or sequences another `Journey`,
as the scale does here, or when the application acts on it. A look belongs
in `.visualState`: a style can carry it for every control of a type, and a
style carries no handlers.

## Flat colors and brushes

`background` takes one colour or a brush, and it is one property whichever
it carries. A brush can be solid, linear, or radial:

```swift
let wash = Brush.linearGradient(
    [
        GradientStop(.cornflowerBlue, 0),
        GradientStop(.indigo, 1),
    ],
    startPoint: Point(0, 0),
    endPoint: Point(1, 1))

VStack {
    Label("Gradient")
        .textColor(.white)
}
.background(wash)
```

Gradient points are fractions of the painted bounds. Offsets run from zero at
the start to one at the end. A radial gradient supplies a fractional center
and radius. Theme-aware colors inside gradient stops resolve with the element
that uses the brush.

Brush interpolation is valid only when the standing and destination values
have the same semantic shape: the same brush kind and compatible stop
structure. Otherwise the host snaps to the destination.

## Shapes

Shape controls are retained native drawing surfaces with a shared shape
vocabulary:

- `Rectangle` and `Ellipse`;
- `Line`;
- `Path` with path data;
- `Polygon` and `Polyline` with `Point` values.

Common shape modifiers include fill, stroke, stroke width and dash
settings, aspect, and `renderTransform`. Geometry-specific modifiers such as a
rectangle's corner radius or line endpoints remain on the matching shape.

```swift
Rectangle()
    .cornerRadius(14)
    .fill(.linearGradient(
        [GradientStop(.cornflowerBlue, 0), GradientStop(.indigo, 1)],
        startPoint: Point(0, 0),
        endPoint: Point(1, 0)))
    .stroke(.solidColor(.white))
    .strokeWidth(2)
    .height(80)
```

The host maps this description to its native path and paint types. Path data
and fill rules are StateUI values; platform path objects do not cross the
boundary.

## Canvas

`Canvas` is the escape hatch for retained, command-based 2D drawing. Its
drawing closure produces a deterministic list of `DrawCommand` values:

```swift
Canvas {
    Draw.fillColor(.cornflowerBlue)
    Draw.fillRoundedRectangle(
        x: 0,
        y: 0,
        width: 160,
        height: 48,
        cornerRadius: 8)

    Draw.textColor(.white)
    Draw.fontSize(15)
    Draw.drawText(
        "Ready",
        x: 0,
        y: 0,
        width: 160,
        height: 48,
        horizontalAlignment: .center,
        verticalAlignment: .center)
}
.height(48)
```

Commands execute in order. Color, stroke, font, alpha, and transform commands
change the state used by later drawing commands. `saveState` and
`restoreState` bound temporary transform or paint changes.

The interaction handlers report points in the canvas's own coordinate space:
`onPressed`, `onDragged`, and `onReleased`. A state
change that alters the command list rebuilds the drawing description; a host
may animate compatible command values without rebuilding the application tree.

`Canvas` is for drawing content, not for recreating standard controls.
Use accepted controls whenever native input, focus, selection, or accessibility
semantics already exist.

Verified shape, brush, visual-state, and drawing coverage is recorded in
[Platform contract](platform-contract.md).
