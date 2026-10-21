# Styles and drawing

StateUI resolves styles, theme variants, and visual-state setters in Swift
before a host receives a control patch. The host sees the effective semantic
properties it must apply; it does not run a second style cascade.

## Style sheets

A `StyleSheet` contains typed styles. An unkeyed style applies implicitly to
every control of its target type. A keyed style is selected with `.style(...)`
and its key: a `StyleKey` typed by the control it is for and declared once, so
a key misspelled, or asked of another kind of control, does not compile. A
sheet describes the interface, so it is built on `MainActor`, as a body is:

```swift
extension StyleKey where Target == Button {
    static let primary = StyleKey("Primary")
    static let danger = StyleKey("Danger")
}

@MainActor
enum HandbookStyles {
    static var sheet: StyleSheet {
        StyleSheet {
            Style<Text>()
                .fontSize(15)
                .textColor(Color(light: .black, dark: .white))

            Style<Button>(.primary)
                .textColor(.white)
                .background(.cornflowerBlue)
                .shape(.roundedRectangle(8))

            Style<Button>(.danger)
                .basedOn(.primary)
                .background(.firebrick)
        }
    }
}
```

Install the sheet on `ApplicationSession` when the application is made:

```swift quote
struct NotesApp: Application {
    @Environment(\.application) private var application

    init() {
        application.styles = HandbookStyles.sheet
    }

    var body: some Scene { WindowGroup { MainPage() } }
}
```

Use a keyed style by its key:

```swift
extension StyleKey where Target == Button {
    static let danger = StyleKey("Danger")
}

struct DeleteButton: View {
    var body: some View {
        Button("Delete")
            .style(.danger)
    }
}
```

`basedOn` is flattened when the sheet is resolved. A derived style inherits
only properties it does not replace, and resolving the style for a control
does not walk the chain again. The referenced style may appear later in the
same sheet. A missing base contributes nothing. If a chain contains a cycle,
resolution stops at the first key it would visit again; the values accumulated
before that cut remain, with each derived style still winning over its base.
This makes a malformed cycle finite and deterministic, but a cycle does not
express a useful precedence and should be removed.

A button's role chooses a style too. `Style<Button>(role:)` is the style every
button of that role wears, standing over the implicit button style: it states
only what the role changes, and everything else comes from the style every
button wears.

```swift
@MainActor
enum RoleStyles {
    static var sheet: StyleSheet {
        StyleSheet {
            Style<Button>()
                .textColor(.white)
                .background(.cornflowerBlue)
                .shape(.roundedRectangle(8))

            Style<Button>(role: .destructive)
                .background(.firebrick)

            Style<Button>(role: .cancel)
                .textColor(.cornflowerBlue)
                .background(.transparent)
        }
    }
}

struct DeleteOrKeep: View {
    var body: some View {
        HStack {
            Button("Keep").role(.cancel)
            Button("Delete").role(.destructive)
        }
    }
}
```

A button asking for a keyed style, or for the platform's own look, wears none
of its role's style.

Every control also has the key `.platform`: the platform's own look, wearing
no style of the sheet - neither the implicit one nor any other. A control
chooses its style as it is built, and `nil` wears the implicit one, so
`.style(plain ? .platform : nil)` switches between the platform's look and the
application's.

A property written directly on a control wins over a style. A recognized keyed
style for the same target replaces that target's implicit style, so it must
inherit from or state every value it requires. A key under which no style of
the control's own type is written is unresolved, and falls through to the
implicit style for that type. If no implicit style exists, only the control's
own values remain. The differ consumes the key in every case; hosts never
resolve style names.

The style's generic target is a compile-time boundary. It offers only the
property modifiers valid for that control; events, gestures, identity, and
driven bindings are not style values.

## Theme values

`Color` stores exact sRGB channels and optionally a light and dark variant:

```swift
let surface = Color(light: .white, dark: Color(hex: 0x18181B))
let accent = Color(hex: 0x5B5BD6)
let translucent = Color(hex: 0x5B5BD6, opacity: 0.5)
let sameTranslucent = Color(red: 91, green: 91, blue: 214, alpha: 128)
```

A hex number has six digits, `0xRRGGBB`, and `opacity:` says how opaque the
color is, from 0 to 1. A color that data holds as text - a theme file, a
server's answer - is read with `Color(parsing:)`, which takes `#RGB`, `#ARGB`,
`#RRGGBB` or `#AARRGGBB`, the alpha first when it is written, and answers nil
for anything else:

```swift
let brand = Color(parsing: "#5B5BD6") ?? .accent
```

Named colors are static members checked by the compiler.
`Color(red:green:blue:alpha:)` takes whole-number channels from 0 through 255;
the alpha is 255, opaque, unless it is given. `opacity(_:)` lets a color
through - its alpha scaled, in both halves of a pair:

```swift
let wash = Color(hex: 0x5B5BD6).opacity(0.15)
```

`ImageSource` follows the same theme rule:

```swift
let icon = ImageSource(light: "edit.png", dark: "edit-dark.png")
Image(icon)
```

The differ resolves the theme variant for the element wearing it. A system
theme change invalidates those resolved uses. The host therefore receives one
concrete color or resource name and needs no parallel theme binding model.

Read `app.info.colorScheme`, with `@Environment(\.application) private var
app`, only when application logic needs the theme as a value. A themed color or image follows the theme without an
application branch.

`Color.accent` is the accent in force - the one the user chose for the
system, or, on a platform with none, the application's own tint - resolved
as the view wearing it is built, as a pair is, so a change in the system's
settings builds again exactly the views wearing it, in a style too:

```swift
let marked = Color.accent.opacity(0.7)
```

## Materials

A background is a material: what the surface behind the view's content is
made of. A color and a gradient are materials; so is a blur of what lies
behind the view, in the platform's own look - from `.ultraThin`, which lets
the most through, to `.ultraThick` - and so is the platform's glass, regular
or clear, tinted, answering the user's touch where it is interactive. Every
kind is cut to the view's shape:

```swift
let washed = VStack { Text("Saved") }
    .background(.blur(.thin.tint(.indigo.opacity(0.15))))
    .shape(.roundedRectangle(12))

let glass = VStack { Text("Saved") }
    .background(.glass(.regular.tint(.indigo).isInteractive(true)))
    .shape(.roundedRectangle(16))
```

A blur's tint lies over it, so a color with an alpha tints the blur. A
material may differ by theme - `Material(light:dark:)`, a nil half for no
background - and one with no pair is the same choice in both themes, the blur
and glass following the theme as the platform draws them:

```swift
let panel = VStack { Text("Saved") }
    .background(Material(light: .color(.white), dark: .blur(.regular)))
```

A platform with no glass draws the blur as clear as the glass; one that blurs
nothing, a color of the theme let through as the blur is, the tint over it.
A state holding a material is a channel: `.background($material)` -
`.pageBackground($material)`, a split view's `.sidebarBackground($material)`
and `.flyoutBackground($material)` alike - shows each material written into
the state as it stands, and no body is built again for it; a pair in it
follows the theme. A color's channel walks the color instead:
`.background($color)` animates it as the state moves. A window's background
is a material too (`window.background`, in *Application and sessions*).

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
view has normal, disabled and pointer-over; a control taking the focus adds
focused, a button pressed, a switch on and off, a check box on. A state the
control never enters does not compile.

StateUI decides which state a control is in, the same way on every platform:
the first that holds of disabled, pressed, pointer-over, focused, on, off -
and normal when none does. What the control shows
is every state that holds at once, the earlier in that order winning a value
two of them set. A disabled switch that is on is dimmed, and green where its
host paints a switch's background - GTK paints none, its switch's box being its
track:

```swift
@State var isOn = true

Switch($isOn)
    .isEnabled(false)
    .visualState(.disabled) { $0.opacity(0.5) }
    .visualState(.on) { $0.background(.green) }
```

Normal's values show only while no other state the control declares holds.

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
        $scale.journey.move(to: state == .pressed ? 0.96 : 1, .eased(.milliseconds(90)))
    }
```

Use the handler when entering a state starts or sequences another `Journey`,
as the scale does here, or when the application acts on it. A look belongs
in `.visualState`: a style can carry it for every control of a type, and a
style carries no handlers.

## Flat colors and brushes

`background` takes one color or a brush, and it is one property whichever
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
    Text("Gradient")
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

- `Rectangle`, `Capsule` and `Ellipse`;
- `Line`;
- `Path` with path data;
- `Polygon` and `Polyline` with `Point` values.

Every shape takes `stroke`, `lineWidth`, the dash settings and `lineCap`,
`contentMode`, and `geometryTransform`. A shape enclosing an area - every
shape but `Line` - takes `fill`, and a shape whose outline turns corners -
`Rectangle`, `Polygon`, `Polyline`, `Path` - takes `lineJoin` and
`miterLimit`. Neither is offered where it would draw nothing: a line's
`fill` does not compile. Geometry-specific modifiers such as a rectangle's
corner radius or line endpoints remain on the matching shape. A `Rectangle`,
a `Capsule` and an `Ellipse` are drawn for their fill, so they take it first,
`Rectangle().fill(.cornflowerBlue)` - a color, a brush or a color's state;
`.fill` says the same where a style or a later change does.

```swift
Rectangle().fill(.linearGradient(
    [GradientStop(.cornflowerBlue, 0), GradientStop(.indigo, 1)],
    startPoint: Point(0, 0),
    endPoint: Point(1, 0)))
    .cornerRadius(14)
    .stroke(.solidColor(.white))
    .lineWidth(2)
    .height(80)
```

The host maps this description to its native path and paint types. Path data
and fill rules are StateUI values; platform path objects do not cross the
boundary.

A `Capsule` is a rectangle whose shorter sides round whole: its ends are half
its shorter side at every size, so it stays a pill however wide or tall its
room - and a circle in a square one.

```swift
Capsule().fill(.teal)
    .width(120)
    .height(32)
```

A rectangle is also the plain block of color - a bar of a chart, a swatch, a
placeholder. Its fill and outline take a color's state, `$x`, as other color
properties do: the host moves the color to each new value and no view is
rebuilt for it.

```swift
struct Level: View {
    @State var tint = Color.cornflowerBlue

    var body: some View {
        VStack {
            Rectangle().fill($tint).cornerRadius(6).height(12)
            Button("Warn").onClicked { tint = .orange }
        }
    }
}
```

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
    Draw.text(
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

Commands execute in order. The color commands, `lineWidth`, `fontSize`,
`opacity` and the transform commands (`translateBy`, `rotate(by:)`,
`scaleBy`) change the state used by later drawing commands. `saveState` and
`restoreState` bound temporary transform or paint changes.

The interaction handlers report points in the canvas's own coordinate space:
`onPressed`, `onDragged`, and `onReleased`. A state change that alters the
command list describes the drawing again, and the host replays the new list
whole; nothing in a drawing animates.

`Canvas` is for drawing content, not for recreating standard controls.
Use accepted controls whenever native input, focus, selection, or accessibility
semantics already exist.

Verified shape, brush, visual-state, and drawing coverage is recorded in
[Platform contract](../platform-contract.md).
