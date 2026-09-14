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
                .cornerRadius(8)

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
```

Hex input accepts `#RGB`, `#ARGB`, `#RRGGBB`, or `#AARRGGBB`. Named colors are
static members checked by the compiler. `Color.fromRgb` and `fromRgba` accept
integer channels from 0 through 255.

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

Visual states describe property overrides while a native control is in a
semantic state:

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

The state type is tied to the control target. Common states include normal,
disabled, focused, unfocused, pointer-over, and selected; controls add their
own states such as a button's pressed state or a switch's on and off states.
The compiler prevents a state that the target cannot declare through the typed
conveniences.

Each group contains at most one state with a given name. Writing the same state
again replaces its earlier declaration without changing its position. The
`group` argument defaults to `"CommonStates"`; states that exclude one another
belong in the same group because entering another state in that group is what
leaves the current one.

Every declared group begins with its target's `restingVisualState`. StateUI
inserts an empty resting state when the author did not write one, providing a
state to return to without changing any property. An explicitly written
resting state keeps its setters and is moved to the front. The default for a
`StyleTarget` is `.normal`; `RadioButton` declares `.unchecked`. A custom style
target is responsible for declaring the state in which its native control
rests.

A control can override or add states locally. Setters merge by state, group,
and property, so a local change does not erase unrelated style setters:

```swift
Button("Save")
    .visualState(.pressed) { state in
        state.background(.steelBlue)
    }
```

`onVisualStateChanged` is for behavior that must react to entering a state. It
declares the states it listens to and receives the typed state after the
native control enters it:

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

Visual-state setters are host-owned changes: a native control enters a state
outside a render, so there is no property patch on which StateUI could place a
`HostTransition`. The control's base `.motion(_:)` supplies the law for
compatible setter values instead. With no local override the host uses the
application motion; `.motion(.none)` makes state setters arrive immediately.
The state declaration remains the destination, while the host owns the frames
between the standing value and that destination.

The `onVisualStateChanged` handler is separate from that property motion. Use
it when entering a state must start or sequence another `Journey`, as in the
scale example, rather than to reassign the state's own setters.

Visual-state setters and their motion still require host evidence. Check the
matrix before relying on a state on a target.

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

- `Rectangle`, `RoundRectangle`, and `Ellipse`;
- `Line`;
- `Path` with path data;
- `Polygon` and `Polyline` with `Point` values.

Common shape modifiers include fill, stroke, stroke thickness and dash
settings, aspect, and `renderTransform`. Geometry-specific modifiers such as a
rectangle radius or line endpoints remain on the matching shape.

```swift
RoundRectangle()
    .cornerRadius(14)
    .fill(.linearGradient(
        [GradientStop(.cornflowerBlue, 0), GradientStop(.indigo, 1)],
        startPoint: Point(0, 0),
        endPoint: Point(1, 0)))
    .stroke(.solidColor(.white))
    .strokeThickness(2)
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

    Draw.fontColor(.white)
    Draw.fontSize(15)
    Draw.drawString(
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
