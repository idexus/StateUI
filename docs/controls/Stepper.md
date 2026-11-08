<!-- Rendered by ControlDictionaryTests from the contracts and the verdicts each host's runs of its tests wrote under lib/StateUI/exports/marks: STATEUI_UPDATE_DOCS=1 swift test --filter ControlDictionaryTests writes it again. -->

# Stepper

A number changed one step at a time, by two buttons.

```swift
@State var servings = 4.0

Stepper($servings)
    .minimum(1)
    .maximum(12)
    .step(1)
```

Layer: `native`. Every base host presents it with its native toolkit.

Inherits: [AutomationElement](tiers/AutomationElement.md) · [VisualElement](tiers/VisualElement.md) · [View](tiers/View.md) · [BackgroundElement](tiers/BackgroundElement.md) · [EnabledElement](tiers/EnabledElement.md) · [RangeElement](tiers/RangeElement.md) · [HoverElement](tiers/HoverElement.md) · [KeyboardElement](tiers/KeyboardElement.md) · [FocusElement](tiers/FocusElement.md)

| Mark | Meaning |
| :---: | --- |
| ✅ | Proven by every test of it that ran on that host. |
| ☑️ | Proven, the host recording what is missing. |
| ✓ | Proven only through the host's own entry or record, not the toolkit's; it counts as met. |
| – | Never on that host's family, which meets the contract there. |
| 🧩 | Left to the application, which registers its own control for it with that host. |
| ❌ | A test of it failed. |
| ◐ | Some of its tests proved it, another could not run or read. |
| · | The driver cannot yet do or read what its test needs. |
| ⏸ | Its test waits on a member the host does not realize. |
| ⌛ | Said at another revision of its family than it stands at. |
| empty | Not realized, or no run - the note says which. |

See [the dictionary](README.md) for how a mark is given.

<table>
<thead><tr><th>Host</th><th>Created</th><th>Members (84)</th><th>Realization</th></tr></thead>
<tbody><tr></tr><tr><td>AppKit</td><td align="center">✅</td><td>44 ✅ · 3 ☑️ · 31 ✓ · 3 –</td><td><code>NSStepper</code></td></tr></tbody>
<tbody><tr></tr><tr><td>UIKit</td><td align="center">⌛</td><td>1 ✅ · 2 ✓ · 3 –</td><td><code>UIStepper</code></td></tr></tbody>
<tbody><tr></tr><tr><td>Android Views</td><td align="center">⌛</td><td>1 ✅ · 2 ✓ · 3 –</td><td>custom <code>LinearLayout</code> of two <code>Button</code>s</td></tr></tbody>
<tbody><tr></tr><tr><td>WinUI 3</td><td align="center">⌛</td><td>6 ✅</td><td><code>NumberBox</code></td></tr></tbody>
<tbody><tr></tr><tr><td>GTK 4</td><td align="center">⌛</td><td>3 ✅ · 2 ✓ · 1 –</td><td><code>GtkSpinButton</code></td></tr></tbody>
<tbody><tr></tr><tr><td>Web</td><td align="center">⌛</td><td>6 ✅</td><td><code>&lt;input role=spinbutton&gt;</code> between two <code>&lt;button&gt;</code>s</td></tr></tbody>
</table>

Declared in `lib/StateUI/Core/Sources/Contracts/Elements/Controls/StepperContract.swift`.

## Stepper's own members

<table>
<thead><tr><th>Member</th><th>Kind</th><th>Value</th><th>Layer</th><th>AppKit</th><th>UIKit</th><th>Android Views</th><th>WinUI 3</th><th>GTK 4</th><th>Web</th></tr></thead>
<tbody><tr></tr><tr><td><code>step</code></td><td>property</td><td><code>Double</code></td><td>native</td><td align="center">✅</td><td align="center">⌛</td><td align="center">⌛</td><td align="center">⌛</td><td align="center">⌛</td><td align="center">⌛</td></tr></tbody>
</table>

## From [AutomationElement](tiers/AutomationElement.md)

What an element the platform's automation meets has - a drawn element, a menu's entry or a bar's item, an arrangement of pages: the name automation finds it by.

<table>
<thead><tr><th>Member</th><th>Kind</th><th>Value</th><th>Layer</th><th>AppKit</th><th>UIKit</th><th>Android Views</th><th>WinUI 3</th><th>GTK 4</th><th>Web</th></tr></thead>
<tbody><tr></tr><tr><td rowspan="2"><code>accessibilityIdentifier</code></td><td>property</td><td><code>String</code></td><td>native</td><td align="center">✅</td><td align="center">✅</td><td align="center">✅</td><td align="center">✅</td><td align="center">–</td><td align="center">✅</td></tr>
<tr><td colspan="9">GTK 4: GTK 4 tells assistive technology no identifier before 4.22, and from 4.22 only a GtkBuilder file's id, which no public call sets on a widget made in code.</td></tr></tbody>
</table>

## From [VisualElement](tiers/VisualElement.md)

What every drawn element has: its size and its bounds, how it is shown and turned, whether it answers input and holds the keyboard focus, the visual states it enters, and what a screen reader says about it.

<table>
<thead><tr><th>Member</th><th>Kind</th><th>Value</th><th>Layer</th><th>AppKit</th><th>UIKit</th><th>Android Views</th><th>WinUI 3</th><th>GTK 4</th><th>Web</th></tr></thead>
<tbody><tr></tr><tr><td><code>accessibilityActionPerformed</code></td><td>event</td><td><code>String</code></td><td>native</td><td align="center">✅</td><td align="center">⌛</td><td align="center">⌛</td><td align="center">⌛</td><td align="center">⌛</td><td align="center">⌛</td></tr></tbody>
<tbody><tr></tr><tr><td><code>accessibilityActions</code></td><td>property</td><td><code>[String]</code></td><td>structure</td><td align="center">✅</td><td align="center">⌛</td><td align="center">⌛</td><td align="center">⌛</td><td align="center">⌛</td><td align="center">⌛</td></tr></tbody>
<tbody><tr></tr><tr><td rowspan="2"><code>onAccessibilityAdjusted</code> (<code>accessibilityAdjusted</code>)</td><td>event</td><td><code>AccessibilityAdjustment</code></td><td>native</td><td align="center">–</td><td align="center">⌛</td><td align="center">⌛</td><td align="center">⌛</td><td align="center">⌛</td><td align="center">⌛</td></tr>
<tr><td colspan="9">AppKit: VoiceOver meets AppKit's own view here - a control, a box, a scroller, a map, a page - which steps as its own kind does, or not at all; a view StateUI draws takes a reader's steps.</td></tr></tbody>
<tbody><tr></tr><tr><td rowspan="2"><code>accessibilityHeading</code></td><td>property</td><td><code>AccessibilityHeadingLevel</code></td><td>native</td><td align="center">☑️</td><td align="center">⌛</td><td align="center">⌛</td><td align="center">⌛</td><td align="center">⌛</td><td align="center">⌛</td></tr>
<tr><td colspan="9">AppKit: AppKit marks a heading, not its level: every level is a heading.</td></tr></tbody>
<tbody><tr></tr><tr><td><code>accessibilityHint</code></td><td>property</td><td><code>String</code></td><td>native</td><td align="center">✅</td><td align="center">⌛</td><td align="center">⌛</td><td align="center">⌛</td><td align="center">⌛</td><td align="center">⌛</td></tr></tbody>
<tbody><tr></tr><tr><td><code>accessibilityLabel</code></td><td>property</td><td><code>String</code></td><td>native</td><td align="center">✅</td><td align="center">⌛</td><td align="center">⌛</td><td align="center">⌛</td><td align="center">⌛</td><td align="center">⌛</td></tr></tbody>
<tbody><tr></tr><tr><td><code>accessibilityPresence</code></td><td>property</td><td><code>AccessibilityPresence</code></td><td>native</td><td align="center">✅</td><td align="center">⌛</td><td align="center">⌛</td><td align="center">⌛</td><td align="center">⌛</td><td align="center">⌛</td></tr></tbody>
<tbody><tr></tr><tr><td><code>accessibilityRole</code></td><td>property</td><td><code>AccessibilityRole</code></td><td>native</td><td align="center">✅</td><td align="center">⌛</td><td align="center">⌛</td><td align="center">⌛</td><td align="center">⌛</td><td align="center">⌛</td></tr></tbody>
<tbody><tr></tr><tr><td><code>accessibilityValue</code></td><td>property</td><td><code>String</code></td><td>native</td><td align="center">✅</td><td align="center">⌛</td><td align="center">⌛</td><td align="center">⌛</td><td align="center">⌛</td><td align="center">⌛</td></tr></tbody>
<tbody><tr></tr><tr><td><code>frame</code></td><td>property</td><td><code>Rect</code></td><td>structure</td><td align="center">✅</td><td align="center">⌛</td><td align="center">⌛</td><td align="center">⌛</td><td align="center">⌛</td><td align="center">⌛</td></tr></tbody>
<tbody><tr></tr><tr><td><code>height</code></td><td>property</td><td><code>Double</code></td><td>native</td><td align="center">✅</td><td align="center">⌛</td><td align="center">⌛</td><td align="center">⌛</td><td align="center">⌛</td><td align="center">⌛</td></tr></tbody>
<tbody><tr></tr><tr><td><code>ignoresInput</code></td><td>property</td><td><code>Bool</code></td><td>native</td><td align="center">✅</td><td align="center">⌛</td><td align="center">⌛</td><td align="center">⌛</td><td align="center">⌛</td><td align="center">⌛</td></tr></tbody>
<tbody><tr></tr><tr><td><code>isVisible</code></td><td>property</td><td><code>Bool</code></td><td>native</td><td align="center">✅</td><td align="center">⌛</td><td align="center">⌛</td><td align="center">⌛</td><td align="center">⌛</td><td align="center">⌛</td></tr></tbody>
<tbody><tr></tr><tr><td><code>layoutDirection</code></td><td>property</td><td><code>LayoutDirection</code></td><td>native</td><td align="center">✅</td><td align="center">⌛</td><td align="center">⌛</td><td align="center">⌛</td><td align="center">⌛</td><td align="center">⌛</td></tr></tbody>
<tbody><tr></tr><tr><td><code>maximumHeight</code></td><td>property</td><td><code>Double</code></td><td>native</td><td align="center">✅</td><td align="center">⌛</td><td align="center">⌛</td><td align="center">⌛</td><td align="center">⌛</td><td align="center">⌛</td></tr></tbody>
<tbody><tr></tr><tr><td><code>maximumWidth</code></td><td>property</td><td><code>Double</code></td><td>native</td><td align="center">✅</td><td align="center">⌛</td><td align="center">⌛</td><td align="center">⌛</td><td align="center">⌛</td><td align="center">⌛</td></tr></tbody>
<tbody><tr></tr><tr><td><code>minimumHeight</code></td><td>property</td><td><code>Double</code></td><td>native</td><td align="center">✅</td><td align="center">⌛</td><td align="center">⌛</td><td align="center">⌛</td><td align="center">⌛</td><td align="center">⌛</td></tr></tbody>
<tbody><tr></tr><tr><td><code>minimumWidth</code></td><td>property</td><td><code>Double</code></td><td>native</td><td align="center">✅</td><td align="center">⌛</td><td align="center">⌛</td><td align="center">⌛</td><td align="center">⌛</td><td align="center">⌛</td></tr></tbody>
<tbody><tr></tr><tr><td><code>opacity</code></td><td>property</td><td><code>Double</code></td><td>native</td><td align="center">✅</td><td align="center">⌛</td><td align="center">⌛</td><td align="center">⌛</td><td align="center">⌛</td><td align="center">⌛</td></tr></tbody>
<tbody><tr></tr><tr><td rowspan="2"><code>pivotX</code></td><td>property</td><td><code>Double</code></td><td>native</td><td align="center">✓</td><td align="center">⌛</td><td align="center">⌛</td><td align="center">⌛</td><td align="center">⌛</td><td align="center">⌛</td></tr>
<tr><td colspan="9">AppKit: only through the host's own: read pivotX of Stepper: the host's own transform, checked against the layer it composed itself</td></tr></tbody>
<tbody><tr></tr><tr><td rowspan="2"><code>pivotY</code></td><td>property</td><td><code>Double</code></td><td>native</td><td align="center">✓</td><td align="center">⌛</td><td align="center">⌛</td><td align="center">⌛</td><td align="center">⌛</td><td align="center">⌛</td></tr>
<tr><td colspan="9">AppKit: only through the host's own: read pivotY of Stepper: the host's own transform, checked against the layer it composed itself</td></tr></tbody>
<tbody><tr></tr><tr><td rowspan="2"><code>rotation</code></td><td>property</td><td><code>Double</code></td><td>native</td><td align="center">✓</td><td align="center">⌛</td><td align="center">⌛</td><td align="center">⌛</td><td align="center">⌛</td><td align="center">⌛</td></tr>
<tr><td colspan="9">AppKit: only through the host's own: read rotation of Stepper: the host's own transform, checked against the layer it composed itself</td></tr></tbody>
<tbody><tr></tr><tr><td rowspan="2"><code>rotationX</code></td><td>property</td><td><code>Double</code></td><td>native</td><td align="center">✓</td><td align="center">⌛</td><td align="center">⌛</td><td align="center">⌛</td><td align="center">⌛</td><td align="center">⌛</td></tr>
<tr><td colspan="9">AppKit: only through the host's own: read rotationX of Stepper: the host's own transform, checked against the layer it composed itself</td></tr></tbody>
<tbody><tr></tr><tr><td rowspan="2"><code>rotationY</code></td><td>property</td><td><code>Double</code></td><td>native</td><td align="center">✓</td><td align="center">⌛</td><td align="center">⌛</td><td align="center">⌛</td><td align="center">⌛</td><td align="center">⌛</td></tr>
<tr><td colspan="9">AppKit: only through the host's own: read rotationY of Stepper: the host's own transform, checked against the layer it composed itself</td></tr></tbody>
<tbody><tr></tr><tr><td rowspan="2"><code>scale</code></td><td>property</td><td><code>Double</code></td><td>native</td><td align="center">✓</td><td align="center">⌛</td><td align="center">⌛</td><td align="center">⌛</td><td align="center">⌛</td><td align="center">⌛</td></tr>
<tr><td colspan="9">AppKit: only through the host's own: read scale of Stepper: the host's own transform, checked against the layer it composed itself</td></tr></tbody>
<tbody><tr></tr><tr><td rowspan="2"><code>scaleX</code></td><td>property</td><td><code>Double</code></td><td>native</td><td align="center">✓</td><td align="center">⌛</td><td align="center">⌛</td><td align="center">⌛</td><td align="center">⌛</td><td align="center">⌛</td></tr>
<tr><td colspan="9">AppKit: only through the host's own: read scaleX of Stepper: the host's own transform, checked against the layer it composed itself</td></tr></tbody>
<tbody><tr></tr><tr><td rowspan="2"><code>scaleY</code></td><td>property</td><td><code>Double</code></td><td>native</td><td align="center">✓</td><td align="center">⌛</td><td align="center">⌛</td><td align="center">⌛</td><td align="center">⌛</td><td align="center">⌛</td></tr>
<tr><td colspan="9">AppKit: only through the host's own: read scaleY of Stepper: the host's own transform, checked against the layer it composed itself</td></tr></tbody>
<tbody><tr></tr><tr><td><code>style</code></td><td>property</td><td><code>Name</code></td><td>structure</td><td align="center">✅</td><td align="center">⌛</td><td align="center">⌛</td><td align="center">⌛</td><td align="center">⌛</td><td align="center">⌛</td></tr></tbody>
<tbody><tr></tr><tr><td><code>tooltip</code></td><td>property</td><td><code>String</code></td><td>native</td><td align="center">✅</td><td align="center">⌛</td><td align="center">⌛</td><td align="center">⌛</td><td align="center">⌛</td><td align="center">⌛</td></tr></tbody>
<tbody><tr></tr><tr><td rowspan="2"><code>translationX</code></td><td>property</td><td><code>Double</code></td><td>native</td><td align="center">✓</td><td align="center">⌛</td><td align="center">⌛</td><td align="center">⌛</td><td align="center">⌛</td><td align="center">⌛</td></tr>
<tr><td colspan="9">AppKit: only through the host's own: read translationX of Stepper: the host's own transform, checked against the layer it composed itself</td></tr></tbody>
<tbody><tr></tr><tr><td rowspan="2"><code>translationY</code></td><td>property</td><td><code>Double</code></td><td>native</td><td align="center">✓</td><td align="center">⌛</td><td align="center">⌛</td><td align="center">⌛</td><td align="center">⌛</td><td align="center">⌛</td></tr>
<tr><td colspan="9">AppKit: only through the host's own: read translationY of Stepper: the host's own transform, checked against the layer it composed itself</td></tr></tbody>
<tbody><tr></tr><tr><td><code>width</code></td><td>property</td><td><code>Double</code></td><td>native</td><td align="center">✅</td><td align="center">⌛</td><td align="center">⌛</td><td align="center">⌛</td><td align="center">⌛</td><td align="center">⌛</td></tr></tbody>
<tbody><tr></tr><tr><td><code>zIndex</code></td><td>property</td><td><code>Int</code></td><td>native</td><td align="center">✅</td><td align="center">⌛</td><td align="center">⌛</td><td align="center">⌛</td><td align="center">⌛</td><td align="center">⌛</td></tr></tbody>
</table>

## From [View](tiers/View.md)

What every view a layout positions has: where it sits in its layout, the space kept around it, and the gestures, drags and frame reports it answers.

<table>
<thead><tr><th>Member</th><th>Kind</th><th>Value</th><th>Layer</th><th>AppKit</th><th>UIKit</th><th>Android Views</th><th>WinUI 3</th><th>GTK 4</th><th>Web</th></tr></thead>
<tbody><tr></tr><tr><td rowspan="2"><code>allowsDrop</code></td><td>property</td><td><code>Bool</code></td><td>native</td><td align="center">✓</td><td align="center">⌛</td><td align="center">⌛</td><td align="center">⌛</td><td align="center">⌛</td><td align="center">⌛</td></tr>
<tr><td colspan="9">AppKit: only through the host's own: dragAndDrop on Rectangle: the drag source and the window's drop routing told by the driver, no dragging session</td></tr></tbody>
<tbody><tr></tr><tr><td><code>area</code></td><td>property</td><td><code>Area</code></td><td>structure</td><td align="center">✅</td><td align="center">⌛</td><td align="center">⌛</td><td align="center">⌛</td><td align="center">⌛</td><td align="center">⌛</td></tr></tbody>
<tbody><tr></tr><tr><td rowspan="2"><code>onDragEntered</code> (<code>dragEntered</code>)</td><td>event</td><td></td><td>native</td><td align="center">✓</td><td align="center">⌛</td><td align="center">⌛</td><td align="center">⌛</td><td align="center">⌛</td><td align="center">⌛</td></tr>
<tr><td colspan="9">AppKit: only through the host's own: dragAndDrop on Rectangle: the drag source and the window's drop routing told by the driver, no dragging session</td></tr></tbody>
<tbody><tr></tr><tr><td rowspan="2"><code>onDragExited</code> (<code>dragExited</code>)</td><td>event</td><td></td><td>native</td><td align="center">✓</td><td align="center">⌛</td><td align="center">⌛</td><td align="center">⌛</td><td align="center">⌛</td><td align="center">⌛</td></tr>
<tr><td colspan="9">AppKit: only through the host's own: dragAndDrop on Rectangle: the drag source and the window's drop routing told by the driver, no dragging session</td></tr></tbody>
<tbody><tr></tr><tr><td rowspan="2"><code>onDragStarting</code> (<code>dragStarting</code>)</td><td>event</td><td></td><td>native</td><td align="center">✓</td><td align="center">⌛</td><td align="center">⌛</td><td align="center">⌛</td><td align="center">⌛</td><td align="center">⌛</td></tr>
<tr><td colspan="9">AppKit: only through the host's own: dragAndDrop on Stepper: the drag source and the window's drop routing told by the driver, no dragging session</td></tr></tbody>
<tbody><tr></tr><tr><td rowspan="2"><code>dragText</code></td><td>property</td><td><code>String</code></td><td>native</td><td align="center">✓</td><td align="center">⌛</td><td align="center">⌛</td><td align="center">⌛</td><td align="center">⌛</td><td align="center">⌛</td></tr>
<tr><td colspan="9">AppKit: only through the host's own: dragAndDrop on Stepper: the drag source and the window's drop routing told by the driver, no dragging session</td></tr></tbody>
<tbody><tr></tr><tr><td rowspan="2"><code>onDropped</code> (<code>dropped</code>)</td><td>event</td><td><code>String</code></td><td>native</td><td align="center">✓</td><td align="center">⌛</td><td align="center">⌛</td><td align="center">⌛</td><td align="center">⌛</td><td align="center">⌛</td></tr>
<tr><td colspan="9">AppKit: only through the host's own: dragAndDrop on Rectangle: the drag source and the window's drop routing told by the driver, no dragging session</td></tr></tbody>
<tbody><tr></tr><tr><td rowspan="2"><code>droppedFileTypes</code></td><td>property</td><td><code>[FileType]</code></td><td>native</td><td align="center">✓</td><td align="center">⌛</td><td align="center">⌛</td><td align="center">⌛</td><td align="center">⌛</td><td align="center">⌛</td></tr>
<tr><td colspan="9">AppKit: only through the host's own: dropFiles on Stepper: the window's drop routing told the driver's files, no dragging session</td></tr></tbody>
<tbody><tr></tr><tr><td rowspan="2"><code>onDragEnded</code> (<code>dragEnded</code>)</td><td>event</td><td></td><td>native</td><td align="center">✓</td><td align="center">⌛</td><td align="center">⌛</td><td align="center">⌛</td><td align="center">⌛</td><td align="center">⌛</td></tr>
<tr><td colspan="9">AppKit: only through the host's own: dragAndDrop on Stepper: the drag source and the window's drop routing told by the driver, no dragging session</td></tr></tbody>
<tbody><tr></tr><tr><td rowspan="2"><code>onDropped</code> (<code>filesDropped</code>)</td><td>event</td><td><code>[ChosenFile]</code></td><td>native</td><td align="center">✓</td><td align="center">⌛</td><td align="center">⌛</td><td align="center">⌛</td><td align="center">⌛</td><td align="center">⌛</td></tr>
<tr><td colspan="9">AppKit: only through the host's own: dropFiles on Stepper: the window's drop routing told the driver's files, no dragging session</td></tr></tbody>
<tbody><tr></tr><tr><td><code>onFrameChanged</code> (<code>frameChanged</code>)</td><td>event</td><td><code>[Double]</code></td><td>native</td><td align="center">✅</td><td align="center">⌛</td><td align="center">⌛</td><td align="center">⌛</td><td align="center">⌛</td><td align="center">⌛</td></tr></tbody>
<tbody><tr></tr><tr><td><code>gridColumn</code></td><td>property</td><td><code>Int</code></td><td>stateUI</td><td align="center">✅</td><td align="center">⌛</td><td align="center">⌛</td><td align="center">⌛</td><td align="center">⌛</td><td align="center">⌛</td></tr></tbody>
<tbody><tr></tr><tr><td><code>gridColumnSpan</code></td><td>property</td><td><code>Int</code></td><td>stateUI</td><td align="center">✅</td><td align="center">⌛</td><td align="center">⌛</td><td align="center">⌛</td><td align="center">⌛</td><td align="center">⌛</td></tr></tbody>
<tbody><tr></tr><tr><td><code>gridRow</code></td><td>property</td><td><code>Int</code></td><td>stateUI</td><td align="center">✅</td><td align="center">⌛</td><td align="center">⌛</td><td align="center">⌛</td><td align="center">⌛</td><td align="center">⌛</td></tr></tbody>
<tbody><tr></tr><tr><td><code>gridRowSpan</code></td><td>property</td><td><code>Int</code></td><td>stateUI</td><td align="center">✅</td><td align="center">⌛</td><td align="center">⌛</td><td align="center">⌛</td><td align="center">⌛</td><td align="center">⌛</td></tr></tbody>
<tbody><tr></tr><tr><td rowspan="2"><code>onHeld</code> (<code>held</code>)</td><td>event</td><td></td><td>native</td><td align="center">✓</td><td align="center">⌛</td><td align="center">⌛</td><td align="center">⌛</td><td align="center">⌛</td><td align="center">⌛</td></tr>
<tr><td colspan="9">AppKit: only through the host's own: hold on Stepper: handed to the host's recognizer or handler, no NSEvent sent</td></tr></tbody>
<tbody><tr></tr><tr><td><code>holdDuration</code></td><td>property</td><td><code>Double</code></td><td>structure</td><td align="center">✅</td><td align="center">⌛</td><td align="center">⌛</td><td align="center">⌛</td><td align="center">⌛</td><td align="center">⌛</td></tr></tbody>
<tbody><tr></tr><tr><td><code>horizontalAlignment</code></td><td>property</td><td><code>Alignment</code></td><td>native</td><td align="center">✅</td><td align="center">⌛</td><td align="center">⌛</td><td align="center">⌛</td><td align="center">⌛</td><td align="center">⌛</td></tr></tbody>
<tbody><tr></tr><tr><td rowspan="2"><code>isDraggable</code></td><td>property</td><td><code>Bool</code></td><td>native</td><td align="center">✓</td><td align="center">⌛</td><td align="center">⌛</td><td align="center">⌛</td><td align="center">⌛</td><td align="center">⌛</td></tr>
<tr><td colspan="9">AppKit: only through the host's own: dragAndDrop on Stepper: the drag source and the window's drop routing told by the driver, no dragging session</td></tr></tbody>
<tbody><tr></tr><tr><td><code>margin</code></td><td>property</td><td><code>Insets</code></td><td>native</td><td align="center">✅</td><td align="center">⌛</td><td align="center">⌛</td><td align="center">⌛</td><td align="center">⌛</td><td align="center">⌛</td></tr></tbody>
<tbody><tr></tr><tr><td rowspan="2"><code>panTouchCount</code></td><td>property</td><td><code>Int</code></td><td>structure</td><td align="center">☑️</td><td align="center">⌛</td><td align="center">⌛</td><td align="center">⌛</td><td align="center">⌛</td><td align="center">⌛</td></tr>
<tr><td colspan="9">AppKit: The host layer hears a one-finger pan only; any other <code>panTouchCount</code> turns the pan off.</td></tr></tbody>
<tbody><tr></tr><tr><td rowspan="2"><code>onPanUpdated</code> (<code>panUpdated</code>)</td><td>event</td><td><code>(GesturePhase, Point, Point, Point)</code></td><td>native</td><td align="center">✓</td><td align="center">⌛</td><td align="center">⌛</td><td align="center">⌛</td><td align="center">⌛</td><td align="center">⌛</td></tr>
<tr><td colspan="9">AppKit: only through the host's own: pan on Stepper: handed to the host's recognizer or handler, no NSEvent sent</td></tr></tbody>
<tbody><tr></tr><tr><td rowspan="2"><code>panXChannel</code></td><td>property</td><td><code>Int</code></td><td>structure</td><td align="center">✓</td><td align="center">⌛</td><td align="center">⌛</td><td align="center">⌛</td><td align="center">⌛</td><td align="center">⌛</td></tr>
<tr><td colspan="9">AppKit: only through the host's own: pan on Stepper: handed to the host's recognizer or handler, no NSEvent sent</td></tr></tbody>
<tbody><tr></tr><tr><td rowspan="2"><code>panYChannel</code></td><td>property</td><td><code>Int</code></td><td>structure</td><td align="center">✓</td><td align="center">⌛</td><td align="center">⌛</td><td align="center">⌛</td><td align="center">⌛</td><td align="center">⌛</td></tr>
<tr><td colspan="9">AppKit: only through the host's own: pan on Stepper: handed to the host's recognizer or handler, no NSEvent sent</td></tr></tbody>
<tbody><tr></tr><tr><td><code>layoutBody</code></td><td>property</td><td><code>LayoutBody</code></td><td>stateUI</td><td align="center">✅</td><td align="center">⌛</td><td align="center">⌛</td><td align="center">⌛</td><td align="center">⌛</td><td align="center">⌛</td></tr></tbody>
<tbody><tr></tr><tr><td rowspan="2"><code>onPinchUpdated</code> (<code>pinchUpdated</code>)</td><td>event</td><td><code>(GesturePhase, Double, Point, Double)</code></td><td>native</td><td align="center">✓</td><td align="center">⌛</td><td align="center">⌛</td><td align="center">⌛</td><td align="center">⌛</td><td align="center">⌛</td></tr>
<tr><td colspan="9">AppKit: only through the host's own: pinch on Stepper: handed to the host's recognizer or handler, no NSEvent sent</td></tr></tbody>
<tbody><tr></tr><tr><td rowspan="2"><code>onPointerMoved</code> (<code>pointerMoved</code>)</td><td>event</td><td><code>Point?</code></td><td>native</td><td align="center">⏸</td><td align="center">⌛</td><td align="center">⌛</td><td align="center">⌛</td><td align="center">⌛</td><td align="center">⌛</td></tr>
<tr><td colspan="9">AppKit: waits on Stepper.pointerEntered, not realized yet</td></tr></tbody>
<tbody><tr></tr><tr><td rowspan="2"><code>onPointerPressed</code> (<code>pointerPressed</code>)</td><td>event</td><td><code>Point?</code></td><td>native</td><td align="center">⏸</td><td align="center">⌛</td><td align="center">⌛</td><td align="center">⌛</td><td align="center">⌛</td><td align="center">⌛</td></tr>
<tr><td colspan="9">AppKit: waits on Stepper.pointerEntered, not realized yet</td></tr></tbody>
<tbody><tr></tr><tr><td rowspan="2"><code>onPointerReleased</code> (<code>pointerReleased</code>)</td><td>event</td><td><code>Point?</code></td><td>native</td><td align="center">⏸</td><td align="center">⌛</td><td align="center">⌛</td><td align="center">⌛</td><td align="center">⌛</td><td align="center">⌛</td></tr>
<tr><td colspan="9">AppKit: waits on Stepper.pointerEntered, not realized yet</td></tr></tbody>
<tbody><tr></tr><tr><td rowspan="2"><code>onRotationUpdated</code> (<code>rotationUpdated</code>)</td><td>event</td><td><code>(GesturePhase, Double, Double)</code></td><td>native</td><td align="center">✓</td><td align="center">⌛</td><td align="center">⌛</td><td align="center">⌛</td><td align="center">⌛</td><td align="center">⌛</td></tr>
<tr><td colspan="9">AppKit: only through the host's own: rotate on Stepper: handed to the host's recognizer or handler, no NSEvent sent</td></tr></tbody>
<tbody><tr></tr><tr><td rowspan="2"><code>swipeDirections</code></td><td>property</td><td><code>SwipeDirections</code></td><td>structure</td><td align="center">✓</td><td align="center">⌛</td><td align="center">⌛</td><td align="center">⌛</td><td align="center">⌛</td><td align="center">⌛</td></tr>
<tr><td colspan="9">AppKit: only through the host's own: pan on Stepper: handed to the host's recognizer or handler, no NSEvent sent</td></tr></tbody>
<tbody><tr></tr><tr><td rowspan="2"><code>swipeThreshold</code></td><td>property</td><td><code>Double</code></td><td>structure</td><td align="center">✓</td><td align="center">⌛</td><td align="center">⌛</td><td align="center">⌛</td><td align="center">⌛</td><td align="center">⌛</td></tr>
<tr><td colspan="9">AppKit: only through the host's own: pan on Stepper: handed to the host's recognizer or handler, no NSEvent sent</td></tr></tbody>
<tbody><tr></tr><tr><td rowspan="2"><code>onSwiped</code> (<code>swiped</code>)</td><td>event</td><td><code>SwipeDirection</code></td><td>native</td><td align="center">✓</td><td align="center">⌛</td><td align="center">⌛</td><td align="center">⌛</td><td align="center">⌛</td><td align="center">⌛</td></tr>
<tr><td colspan="9">AppKit: only through the host's own: pan on Stepper: handed to the host's recognizer or handler, no NSEvent sent</td></tr></tbody>
<tbody><tr></tr><tr><td rowspan="2"><code>tapCount</code></td><td>property</td><td><code>Int</code></td><td>structure</td><td align="center">✓</td><td align="center">⌛</td><td align="center">⌛</td><td align="center">⌛</td><td align="center">⌛</td><td align="center">⌛</td></tr>
<tr><td colspan="9">AppKit: only through the host's own: tap on Stepper: handed to the host's recognizer or handler, no NSEvent sent</td></tr></tbody>
<tbody><tr></tr><tr><td rowspan="2"><code>onTapped</code> (<code>tapped</code>)</td><td>event</td><td></td><td>native</td><td align="center">✓</td><td align="center">⌛</td><td align="center">⌛</td><td align="center">⌛</td><td align="center">⌛</td><td align="center">⌛</td></tr>
<tr><td colspan="9">AppKit: only through the host's own: pressDown on Stepper: handed to the host's recognizer or handler, no NSEvent sent</td></tr></tbody>
<tbody><tr></tr><tr><td><code>verticalAlignment</code></td><td>property</td><td><code>Alignment</code></td><td>native</td><td align="center">✅</td><td align="center">⌛</td><td align="center">⌛</td><td align="center">⌛</td><td align="center">⌛</td><td align="center">⌛</td></tr></tbody>
</table>

## From [BackgroundElement](tiers/BackgroundElement.md)

What an element is painted on: a view's, a page's, a window's, a bar item's and a run of text's background.

<table>
<thead><tr><th>Member</th><th>Kind</th><th>Value</th><th>Layer</th><th>AppKit</th><th>UIKit</th><th>Android Views</th><th>WinUI 3</th><th>GTK 4</th><th>Web</th></tr></thead>
<tbody><tr></tr><tr><td rowspan="2"><code>background</code></td><td>property</td><td><code>Material</code></td><td>adaptive</td><td align="center">☑️</td><td align="center">⌛</td><td align="center">⌛</td><td align="center">⌛</td><td align="center">⌛</td><td align="center">⌛</td></tr>
<tr><td colspan="9">AppKit: AppKit paints a color on this view; a brush, a blur and glass are drawn only by a layout, and elsewhere a blur's color stands in.</td></tr></tbody>
</table>

## From [EnabledElement](tiers/EnabledElement.md)

Whether the user's hand reaches an element: a view, a menu, an entry in one, a toolbar's group.

<table>
<thead><tr><th>Member</th><th>Kind</th><th>Value</th><th>Layer</th><th>AppKit</th><th>UIKit</th><th>Android Views</th><th>WinUI 3</th><th>GTK 4</th><th>Web</th></tr></thead>
<tbody><tr></tr><tr><td><code>isEnabled</code></td><td>property</td><td><code>Bool</code></td><td>native</td><td align="center">✅</td><td align="center">⌛</td><td align="center">⌛</td><td align="center">⌛</td><td align="center">⌛</td><td align="center">⌛</td></tr></tbody>
</table>

## From [RangeElement](tiers/RangeElement.md)

What a control choosing a number in a range holds and reports: a slider, a stepper.

<table>
<thead><tr><th>Member</th><th>Kind</th><th>Value</th><th>Layer</th><th>AppKit</th><th>UIKit</th><th>Android Views</th><th>WinUI 3</th><th>GTK 4</th><th>Web</th></tr></thead>
<tbody><tr></tr><tr><td><code>value</code></td><td>property</td><td><code>Double</code></td><td>native</td><td align="center">✅</td><td align="center">⌛</td><td align="center">⌛</td><td align="center">⌛</td><td align="center">⌛</td><td align="center">⌛</td></tr></tbody>
<tbody><tr></tr><tr><td><code>onValueChanged</code> (<code>valueChanged</code>)</td><td>event</td><td><code>Double</code></td><td>native</td><td align="center">✅</td><td align="center">⌛</td><td align="center">⌛</td><td align="center">⌛</td><td align="center">⌛</td><td align="center">⌛</td></tr></tbody>
<tbody><tr></tr><tr><td><code>minimum</code></td><td>property</td><td><code>Double</code></td><td>native</td><td align="center">✅</td><td align="center">⌛</td><td align="center">⌛</td><td align="center">⌛</td><td align="center">⌛</td><td align="center">⌛</td></tr></tbody>
<tbody><tr></tr><tr><td><code>maximum</code></td><td>property</td><td><code>Double</code></td><td>native</td><td align="center">✅</td><td align="center">⌛</td><td align="center">⌛</td><td align="center">⌛</td><td align="center">⌛</td><td align="center">⌛</td></tr></tbody>
</table>

## From [HoverElement](tiers/HoverElement.md)

What an element the pointer comes over and leaves reports: a view, an item on a bar.

<table>
<thead><tr><th>Member</th><th>Kind</th><th>Value</th><th>Layer</th><th>AppKit</th><th>UIKit</th><th>Android Views</th><th>WinUI 3</th><th>GTK 4</th><th>Web</th></tr></thead>
<tbody><tr></tr><tr><td rowspan="2"><code>onPointerEntered</code> (<code>pointerEntered</code>)</td><td>event</td><td></td><td>native</td><td align="center">–</td><td align="center">⌛</td><td align="center">⌛</td><td align="center">⌛</td><td align="center">⌛</td><td align="center">⌛</td></tr>
<tr><td colspan="9">AppKit: The Mac's toolbar draws its items in the Mac's own look.</td></tr></tbody>
<tbody><tr></tr><tr><td rowspan="2"><code>onPointerExited</code> (<code>pointerExited</code>)</td><td>event</td><td></td><td>native</td><td align="center">–</td><td align="center">⌛</td><td align="center">⌛</td><td align="center">⌛</td><td align="center">⌛</td><td align="center">⌛</td></tr>
<tr><td colspan="9">AppKit: The Mac's toolbar draws its items in the Mac's own look.</td></tr></tbody>
</table>

## From [KeyboardElement](tiers/KeyboardElement.md)

An element that can hold the keyboard - a control taking the focus, or a layout holding the view that does - and so hear the keys it takes.

<table>
<thead><tr><th>Member</th><th>Kind</th><th>Value</th><th>Layer</th><th>AppKit</th><th>UIKit</th><th>Android Views</th><th>WinUI 3</th><th>GTK 4</th><th>Web</th></tr></thead>
<tbody><tr></tr><tr><td rowspan="2"><code>keyPressed</code></td><td>event</td><td><code>(Key, KeyModifiers)</code></td><td>native</td><td align="center">✅</td><td align="center">✓</td><td align="center">✓</td><td align="center">✅</td><td align="center">✓</td><td align="center">✅</td></tr>
<tr><td colspan="9">UIKit: only through the host's own: pressKeys on Stepper: the window's or the main menu's key command performed, no key pressed<br>Android Views: only through the host's own: pressKeys on Stepper: the key event no view took handed to the host as the application's activity hands it<br>GTK 4: only through the host's own: pressKeys on Stepper: the shortcut controller's action run, no key event</td></tr></tbody>
<tbody><tr></tr><tr><td rowspan="2"><code>keysTaken</code></td><td>property</td><td><code>[Key]</code></td><td>structure</td><td align="center">✅</td><td align="center">✓</td><td align="center">✓</td><td align="center">✅</td><td align="center">✓</td><td align="center">✅</td></tr>
<tr><td colspan="9">UIKit: only through the host's own: pressKeys on Stepper: the window's or the main menu's key command performed, no key pressed<br>Android Views: only through the host's own: pressKeys on Stepper: the key event no view took handed to the host as the application's activity hands it<br>GTK 4: only through the host's own: pressKeys on Stepper: the shortcut controller's action run, no key event</td></tr></tbody>
</table>

## From [FocusElement](tiers/FocusElement.md)

An element that takes the keyboard focus itself - a field, a button, a list - and so holds the keyboard.

<table>
<thead><tr><th>Member</th><th>Kind</th><th>Value</th><th>Layer</th><th>AppKit</th><th>UIKit</th><th>Android Views</th><th>WinUI 3</th><th>GTK 4</th><th>Web</th></tr></thead>
<tbody><tr></tr><tr><td rowspan="2"><code>focus</code></td><td>act</td><td><code>() -&gt; Bool</code></td><td>native</td><td align="center">✅</td><td align="center">–</td><td align="center">–</td><td align="center">✅</td><td align="center">✅</td><td align="center">✅</td></tr>
<tr><td colspan="9">UIKit, Android Views: Stepper takes no keyboard focus here: it refuses it, and nothing is heard</td></tr></tbody>
<tbody><tr></tr><tr><td rowspan="2"><code>isFocusedChanged</code></td><td>event</td><td><code>Bool</code></td><td>native</td><td align="center">✅</td><td align="center">–</td><td align="center">–</td><td align="center">✅</td><td align="center">✅</td><td align="center">✅</td></tr>
<tr><td colspan="9">UIKit, Android Views: Stepper takes no keyboard focus here: it refuses it, and nothing is heard</td></tr></tbody>
<tbody><tr></tr><tr><td rowspan="2"><code>unfocus</code></td><td>act</td><td><code>() -&gt; Void</code></td><td>native</td><td align="center">✅</td><td align="center">–</td><td align="center">–</td><td align="center">✅</td><td align="center">✅</td><td align="center">✅</td></tr>
<tr><td colspan="9">UIKit, Android Views: Stepper takes no keyboard focus here: it refuses it, and nothing is heard</td></tr></tbody>
</table>
