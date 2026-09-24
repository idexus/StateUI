# Tiers

A tier is a set of members several elements share, and in Swift it is a
protocol. Each property is declared once, on the tier whose controls all carry
it, and every control wearing that tier inherits the modifier: opacity from
`VisualElementProperties`, margin from `ViewProperties`, padding from
`PaddingElement`, the font size from `FontElement`. A modifier is therefore
offered on exactly the controls that carry the property - `.spacing()` on a
stack, `.placeholder()` on a text field, and nothing on a Label that a Label
does not carry. Each Swift tier has a tier contract under `Contracts/Tiers`
or `Contracts/Mixins`, which declares its members for the hosts.

## Two halves

The hierarchy is two parallel halves. The split is what makes "only what is
allowed can be written" a compiler rule rather than a convention.

```text
  property side: holds values              element side: is in the tree
  (a control, a Style, a TextSpan)         (a control)

  PropertyContainer                        Element
  ├── VisualElementProperties              └── ModifiableElement      events, lifetime
  │   └── ViewProperties                       └── VisualElement      key, aim, samples,
  │       ├── LayoutProperties                     │                  environment, style
  │       │   └── StackBaseProperties              └── View           gestures, pan, frame,
  │       ├── ShapeProperties                          │              context menu
  │       └── InputViewProperties                      ├── Layout
  └── the mixins, one file each:                       │   └── StackBase
      TextStyleElement  TextElement  FontElement       ├── Shape
      TextAlignmentElement  PaddingElement             └── InputView
      LineHeightElement  DecorableTextElement
      BorderElement  ImageElement  TintElement
      BarElement  PageElement  MenuItemElement
```

A control conforms on the element side - `View`, `Layout`, `Shape`,
`InputView` - which brings the matching property side with it, plus the mixins
it carries and its own `…Properties` protocol. A `Style<Target>` conforms to
the property side alone, one conditional conformance per tier its target wears,
so a style offers exactly the setters its target can carry, and an event, a
gesture or an `.id()` written on a style does not compile.

Every modifier returns a modified copy. Nothing mutates in place, so a view is
a value all the way down and a chain reads in one direction:
`Label("Total").fontSize(20).textColor(.gray).margin(0, 8)`.

## Why events live on the element side

Events are declared on `ModifiableElement`, a `PropertyContainer` that is also
an `Element`: what can hold a handler is something that exists on screen,
never a bag of values. `addHandler` lives on this tier and not on
`PropertyContainer`, so nothing reachable from a `Style` - the library's own
code included - can put a handler into a bag that cannot carry one. The key,
the aim and the read-only bindings live on `VisualElement`, and lifetime on
`ModifiableElement`, where only a control can reach them.

## The shared view tier

The shared tier, in `Tiers`, is the hierarchy every view wears - property
container, modifiable element, visual element, view, layout, stack, shape and
input view - a file for each, and one more for a larger group of a tier's
modifiers: a view's gestures, where it sits, what it says about itself.
`testTheSharedTierIsCoveredOnce` checks the properties declared in those files
against one fixture, built from a stack and a label, so those properties are
covered once rather than in every control's case.

## One file per mixin tier

A tier worn by some controls and not others - text, font, alignment, padding,
line height, decoration, border, image, tint, bar, page and menu item - has a
file of its own in `Mixins` rather than a block in a shared tier's file. Its
properties are then not part of the shared tier the fixture checks, and a
control that does not wear the tier is never offered its modifiers.

## Tiers a text run wears

`PropertyContainer` sits below `VisualElement` because not everything that
carries properties is a view. A `TextSpan`, one run of text inside a Label,
carries a text colour, a font size and a background colour, and has no
opacity, margin or size. The text and font mixins are therefore written against
`PropertyContainer`, where a `TextSpan` and a `Style` - which is not in the
tree at all - can both wear them.

There are two text tiers because some controls colour text they do not own. A
Picker shows the chosen item, and a DatePicker and a TimePicker format a value:
each carries `textColor` and `characterSpacing` through `TextStyleElement`, and
only a control that says something of its own wears `TextElement`, which adds
the text and its case. Changing the case of a formatted picker value would be
a different, platform-specific promise, so `textCase` is on `TextElement`.

`PaddingElement` and `TextAlignmentElement` stop at `VisualElementProperties`:
each names a set of properties rather than a kind of control, and asks for
nothing a positioned view adds.

## The properties of each control

A control's own properties are a protocol beside it, such as
`ButtonProperties`. The control conforms on the element side and its style on
the property side (`extension StyleBag: ButtonProperties where Target ==
Button`), which is what makes the same modifiers compile on both. The modifiers
are written once and serve the control and the style alike.

## Input views

`InputViewProperties` is a `ViewProperties`: it stands for a kind of control, a
positioned view the user types into. `InputView` is its element half, as
`Layout` and `Shape` are theirs, and the element half is what a style is told
apart by: the conditional conformances in `StyleBag+Properties.swift` name the
element protocol, so a tier with only a property half could not be given to a
style without also giving it the modifiers of `View`.

## Shapes

Rectangle, Ellipse, Line, Path, Polygon and Polyline share one drawing
vocabulary, the shape tier, checked once by the shared fixture rather than once
per shape. `renderTransform` transforms the path each shape makes, so one
modifier means one thing on all of them and the stroke follows the transformed
path; `.transform` moves what was drawn, after layout.

A `Border` carries the same stroke properties on `BorderProperties` rather than
sharing the shape tier, because that tier also carries `fill`,
`renderTransform` and `aspect`, a drawn figure's properties and none of them a
border's. On the wire they are the same properties.

## Borders

`BorderElement` is the outline a Button or a RadioButton draws around itself:
three flat properties declared once, so one binding twin such as
`.borderWidth($thickness)` serves both controls. Its `cornerRadius` is a whole
number, so its twin sets it as it stands. A `Border` is a different thing: a
view of its own that strokes whatever it holds, with a brush, a shape and a
dash pattern.

## Menu items

A toolbar item and a menu entry share `MenuItemElement`: text, icon,
destructive look, enabled, and `onClicked`. They are not views - none of
the view tiers applies to them, and none of this tier applies to a view.
`Menu` stays outside the tier: a menu has a caption and entries and is never
clicked, so its `isEnabled` is its own property, and an icon or a destructive
look on it would describe a capability the host contract does not apply.
