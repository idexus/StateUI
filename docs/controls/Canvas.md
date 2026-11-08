<!-- Rendered by ControlDictionaryTests from the contracts and the verdicts each host's runs of its tests wrote under lib/StateUI/exports/marks: STATEUI_UPDATE_DOCS=1 swift test --filter ControlDictionaryTests writes it again. -->

# Canvas

A canvas to draw on, one instruction at a time.

```swift
@State var dot = Point(40, 40)

Canvas {
    Draw.fillColor(.cornflowerBlue)
    Draw.fillEllipse(x: dot.x - 8, y: dot.y - 8, width: 16, height: 16)
}
.height(120)
.onPointerPressed { point in dot = point }
```

Layer: `native`. Every base host presents it with its native toolkit.

Inherits: [AutomationElement](tiers/AutomationElement.md) · [VisualElement](tiers/VisualElement.md) · [View](tiers/View.md) · [StyledElement](tiers/StyledElement.md) · [BackgroundElement](tiers/BackgroundElement.md) · [EnabledElement](tiers/EnabledElement.md) · [HoverElement](tiers/HoverElement.md)

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
<thead><tr><th>Host</th><th>Created</th><th>Members (75)</th><th>Realization</th></tr></thead>
<tbody><tr></tr><tr><td>AppKit</td><td align="center">✅</td><td>36 ✅ · 3 ☑️ · 36 ✓</td><td>custom <code>NSView</code> drawing</td></tr></tbody>
<tbody><tr></tr><tr><td>UIKit</td><td align="center">✅</td><td>35 ✅ · 3 ☑️ · 36 ✓ · 1 –</td><td>custom <code>UIView</code> <code>draw(_:)</code></td></tr></tbody>
<tbody><tr></tr><tr><td>Android Views</td><td align="center">✅</td><td>57 ✅ · 5 ☑️ · 10 ✓ · 2 –</td><td>custom <code>View</code> <code>onDraw(Canvas)</code></td></tr></tbody>
<tbody><tr></tr><tr><td>WinUI 3</td><td align="center">✅</td><td>2 ✅</td><td>custom <code>Panel</code> painting a Direct2D <code>SurfaceImageSource</code></td></tr></tbody>
<tbody><tr></tr><tr><td>GTK 4</td><td align="center">✅</td><td>1 ✅ · 1 –</td><td>custom <code>GtkWidget</code> snapshot</td></tr></tbody>
<tbody><tr></tr><tr><td>Web</td><td align="center">✅</td><td>50 ✅ · 1 ☑️ · 21 ✓ · 3 –</td><td><code>&lt;canvas&gt;</code></td></tr></tbody>
</table>

Declared in `lib/StateUI/Core/Sources/Contracts/Elements/Shapes/CanvasContract.swift`.

## Canvas's own members

<table>
<thead><tr><th>Member</th><th>Kind</th><th>Value</th><th>Layer</th><th>AppKit</th><th>UIKit</th><th>Android Views</th><th>WinUI 3</th><th>GTK 4</th><th>Web</th></tr></thead>
<tbody><tr></tr><tr><td><code>drawing</code></td><td>property</td><td><code>[DrawCommand]</code></td><td>structure</td><td align="center">✅</td><td align="center">✅</td><td align="center">✅</td><td align="center">✅</td><td align="center">✅</td><td align="center">✅</td></tr></tbody>
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
<tbody><tr></tr><tr><td rowspan="2"><code>accessibilityActionPerformed</code></td><td>event</td><td><code>String</code></td><td>native</td><td align="center">✅</td><td align="center">✅</td><td align="center">✅</td><td align="center">⌛</td><td align="center">⌛</td><td align="center">–</td></tr>
<tr><td colspan="9">Web: ARIA offers no action of an application's own words.</td></tr></tbody>
<tbody><tr></tr><tr><td rowspan="2"><code>accessibilityActions</code></td><td>property</td><td><code>[String]</code></td><td>structure</td><td align="center">✅</td><td align="center">✅</td><td align="center">✅</td><td align="center">⌛</td><td align="center">⌛</td><td align="center">–</td></tr>
<tr><td colspan="9">Web: ARIA offers no action of an application's own words.</td></tr></tbody>
<tbody><tr></tr><tr><td rowspan="2"><code>onAccessibilityAdjusted</code> (<code>accessibilityAdjusted</code>)</td><td>event</td><td><code>AccessibilityAdjustment</code></td><td>native</td><td align="center">✅</td><td align="center">✅</td><td align="center">✅</td><td align="center">⌛</td><td align="center">⌛</td><td align="center">–</td></tr>
<tr><td colspan="9">Web: A browser's screen reader steps a slider by the keys it sends the page, not by a step of its own.</td></tr></tbody>
<tbody><tr></tr><tr><td rowspan="2"><code>accessibilityHeading</code></td><td>property</td><td><code>AccessibilityHeadingLevel</code></td><td>native</td><td align="center">☑️</td><td align="center">☑️</td><td align="center">☑️</td><td align="center">⌛</td><td align="center">⌛</td><td align="center">✅</td></tr>
<tr><td colspan="9">AppKit: AppKit marks a heading, not its level: every level is a heading.<br>UIKit: UIKit marks a heading, not its level: every level is a heading.<br>Android Views: Android marks a heading, not its level: every level is a heading.</td></tr></tbody>
<tbody><tr></tr><tr><td><code>accessibilityHint</code></td><td>property</td><td><code>String</code></td><td>native</td><td align="center">✅</td><td align="center">✅</td><td align="center">✅</td><td align="center">⌛</td><td align="center">⌛</td><td align="center">✅</td></tr></tbody>
<tbody><tr></tr><tr><td><code>accessibilityLabel</code></td><td>property</td><td><code>String</code></td><td>native</td><td align="center">✅</td><td align="center">✅</td><td align="center">✅</td><td align="center">⌛</td><td align="center">⌛</td><td align="center">✅</td></tr></tbody>
<tbody><tr></tr><tr><td><code>accessibilityPresence</code></td><td>property</td><td><code>AccessibilityPresence</code></td><td>native</td><td align="center">✅</td><td align="center">✅</td><td align="center">✅</td><td align="center">⌛</td><td align="center">⌛</td><td align="center">✅</td></tr></tbody>
<tbody><tr></tr><tr><td rowspan="2"><code>accessibilityRole</code></td><td>property</td><td><code>AccessibilityRole</code></td><td>native</td><td align="center">✅</td><td align="center">✅</td><td align="center">☑️</td><td align="center">⌛</td><td align="center">⌛</td><td align="center">✅</td></tr>
<tr><td colspan="9">Android Views: A link: Android names no kind for one, and the view is said as what it is.</td></tr></tbody>
<tbody><tr></tr><tr><td rowspan="2"><code>accessibilityValue</code></td><td>property</td><td><code>String</code></td><td>native</td><td align="center">✅</td><td align="center">✅</td><td align="center">☑️</td><td align="center">⌛</td><td align="center">⌛</td><td align="center">✅</td></tr>
<tr><td colspan="9">Android Views: Before Android 11 a view says no value of its own words.</td></tr></tbody>
<tbody><tr></tr><tr><td><code>frame</code></td><td>property</td><td><code>Rect</code></td><td>structure</td><td align="center">✅</td><td align="center">✅</td><td align="center">✅</td><td align="center">⌛</td><td align="center">⌛</td><td align="center">✅</td></tr></tbody>
<tbody><tr></tr><tr><td><code>height</code></td><td>property</td><td><code>Double</code></td><td>native</td><td align="center">✅</td><td align="center">✅</td><td align="center">✅</td><td align="center">⌛</td><td align="center">⌛</td><td align="center">✅</td></tr></tbody>
<tbody><tr></tr><tr><td rowspan="2"><code>ignoresInput</code></td><td>property</td><td><code>Bool</code></td><td>native</td><td align="center">✅</td><td align="center">✅</td><td align="center"></td><td align="center">⌛</td><td align="center">⌛</td><td align="center">✅</td></tr>
<tr><td colspan="9">Android Views: not realized</td></tr></tbody>
<tbody><tr></tr><tr><td><code>isVisible</code></td><td>property</td><td><code>Bool</code></td><td>native</td><td align="center">✅</td><td align="center">✅</td><td align="center">✅</td><td align="center">⌛</td><td align="center">⌛</td><td align="center">✅</td></tr></tbody>
<tbody><tr></tr><tr><td><code>layoutDirection</code></td><td>property</td><td><code>LayoutDirection</code></td><td>native</td><td align="center">✅</td><td align="center">✅</td><td align="center">✅</td><td align="center">⌛</td><td align="center">⌛</td><td align="center">✅</td></tr></tbody>
<tbody><tr></tr><tr><td><code>maximumHeight</code></td><td>property</td><td><code>Double</code></td><td>native</td><td align="center">✅</td><td align="center">✅</td><td align="center">✅</td><td align="center">⌛</td><td align="center">⌛</td><td align="center">✅</td></tr></tbody>
<tbody><tr></tr><tr><td><code>maximumWidth</code></td><td>property</td><td><code>Double</code></td><td>native</td><td align="center">✅</td><td align="center">✅</td><td align="center">✅</td><td align="center">⌛</td><td align="center">⌛</td><td align="center">✅</td></tr></tbody>
<tbody><tr></tr><tr><td><code>minimumHeight</code></td><td>property</td><td><code>Double</code></td><td>native</td><td align="center">✅</td><td align="center">✅</td><td align="center">✅</td><td align="center">⌛</td><td align="center">⌛</td><td align="center">✅</td></tr></tbody>
<tbody><tr></tr><tr><td><code>minimumWidth</code></td><td>property</td><td><code>Double</code></td><td>native</td><td align="center">✅</td><td align="center">✅</td><td align="center">✅</td><td align="center">⌛</td><td align="center">⌛</td><td align="center">✅</td></tr></tbody>
<tbody><tr></tr><tr><td><code>opacity</code></td><td>property</td><td><code>Double</code></td><td>native</td><td align="center">✅</td><td align="center">✅</td><td align="center">✅</td><td align="center">⌛</td><td align="center">⌛</td><td align="center">✅</td></tr></tbody>
<tbody><tr></tr><tr><td rowspan="2"><code>pivotX</code></td><td>property</td><td><code>Double</code></td><td>native</td><td align="center">✓</td><td align="center">✓</td><td align="center">✅</td><td align="center">⌛</td><td align="center">⌛</td><td align="center">✓</td></tr>
<tr><td colspan="9">AppKit, UIKit: only through the host's own: read pivotX of Canvas: the host's own transform, checked against the layer it composed itself<br>Web: only through the host's own: read pivotX of Canvas: the host's own transform: the page holds one matrix of it, its parts no longer told apart</td></tr></tbody>
<tbody><tr></tr><tr><td rowspan="2"><code>pivotY</code></td><td>property</td><td><code>Double</code></td><td>native</td><td align="center">✓</td><td align="center">✓</td><td align="center">✅</td><td align="center">⌛</td><td align="center">⌛</td><td align="center">✓</td></tr>
<tr><td colspan="9">AppKit, UIKit: only through the host's own: read pivotY of Canvas: the host's own transform, checked against the layer it composed itself<br>Web: only through the host's own: read pivotY of Canvas: the host's own transform: the page holds one matrix of it, its parts no longer told apart</td></tr></tbody>
<tbody><tr></tr><tr><td rowspan="2"><code>rotation</code></td><td>property</td><td><code>Double</code></td><td>native</td><td align="center">✓</td><td align="center">✓</td><td align="center">✅</td><td align="center">⌛</td><td align="center">⌛</td><td align="center">✓</td></tr>
<tr><td colspan="9">AppKit, UIKit: only through the host's own: read rotation of Canvas: the host's own transform, checked against the layer it composed itself<br>Web: only through the host's own: read rotation of Canvas: the host's own transform: the page holds one matrix of it, its parts no longer told apart</td></tr></tbody>
<tbody><tr></tr><tr><td rowspan="2"><code>rotationX</code></td><td>property</td><td><code>Double</code></td><td>native</td><td align="center">✓</td><td align="center">✓</td><td align="center">✅</td><td align="center">⌛</td><td align="center">⌛</td><td align="center">✓</td></tr>
<tr><td colspan="9">AppKit, UIKit: only through the host's own: read rotationX of Canvas: the host's own transform, checked against the layer it composed itself<br>Web: only through the host's own: read rotationX of Canvas: the host's own transform: the page holds one matrix of it, its parts no longer told apart</td></tr></tbody>
<tbody><tr></tr><tr><td rowspan="2"><code>rotationY</code></td><td>property</td><td><code>Double</code></td><td>native</td><td align="center">✓</td><td align="center">✓</td><td align="center">✅</td><td align="center">⌛</td><td align="center">⌛</td><td align="center">✓</td></tr>
<tr><td colspan="9">AppKit, UIKit: only through the host's own: read rotationY of Canvas: the host's own transform, checked against the layer it composed itself<br>Web: only through the host's own: read rotationY of Canvas: the host's own transform: the page holds one matrix of it, its parts no longer told apart</td></tr></tbody>
<tbody><tr></tr><tr><td rowspan="2"><code>scale</code></td><td>property</td><td><code>Double</code></td><td>native</td><td align="center">✓</td><td align="center">✓</td><td align="center">✅</td><td align="center">⌛</td><td align="center">⌛</td><td align="center">✓</td></tr>
<tr><td colspan="9">AppKit, UIKit: only through the host's own: read scale of Canvas: the host's own transform, checked against the layer it composed itself<br>Web: only through the host's own: read scale of Canvas: the host's own transform: the page holds one matrix of it, its parts no longer told apart</td></tr></tbody>
<tbody><tr></tr><tr><td rowspan="2"><code>scaleX</code></td><td>property</td><td><code>Double</code></td><td>native</td><td align="center">✓</td><td align="center">✓</td><td align="center">✅</td><td align="center">⌛</td><td align="center">⌛</td><td align="center">✓</td></tr>
<tr><td colspan="9">AppKit, UIKit: only through the host's own: read scaleX of Canvas: the host's own transform, checked against the layer it composed itself<br>Web: only through the host's own: read scaleX of Canvas: the host's own transform: the page holds one matrix of it, its parts no longer told apart</td></tr></tbody>
<tbody><tr></tr><tr><td rowspan="2"><code>scaleY</code></td><td>property</td><td><code>Double</code></td><td>native</td><td align="center">✓</td><td align="center">✓</td><td align="center">✅</td><td align="center">⌛</td><td align="center">⌛</td><td align="center">✓</td></tr>
<tr><td colspan="9">AppKit, UIKit: only through the host's own: read scaleY of Canvas: the host's own transform, checked against the layer it composed itself<br>Web: only through the host's own: read scaleY of Canvas: the host's own transform: the page holds one matrix of it, its parts no longer told apart</td></tr></tbody>
<tbody><tr></tr><tr><td rowspan="2"><code>tooltip</code></td><td>property</td><td><code>String</code></td><td>native</td><td align="center">✅</td><td align="center">–</td><td align="center">✅</td><td align="center">⌛</td><td align="center">⌛</td><td align="center">✅</td></tr>
<tr><td colspan="9">UIKit: UIKit shows a tool tip on the Mac and on visionOS only: an iPhone and an iPad show none.</td></tr></tbody>
<tbody><tr></tr><tr><td rowspan="2"><code>translationX</code></td><td>property</td><td><code>Double</code></td><td>native</td><td align="center">✓</td><td align="center">✓</td><td align="center">✅</td><td align="center">⌛</td><td align="center">⌛</td><td align="center">✓</td></tr>
<tr><td colspan="9">AppKit, UIKit: only through the host's own: read translationX of Canvas: the host's own transform, checked against the layer it composed itself<br>Web: only through the host's own: read translationX of Canvas: the host's own transform: the page holds one matrix of it, its parts no longer told apart</td></tr></tbody>
<tbody><tr></tr><tr><td rowspan="2"><code>translationY</code></td><td>property</td><td><code>Double</code></td><td>native</td><td align="center">✓</td><td align="center">✓</td><td align="center">✅</td><td align="center">⌛</td><td align="center">⌛</td><td align="center">✓</td></tr>
<tr><td colspan="9">AppKit, UIKit: only through the host's own: read translationY of Canvas: the host's own transform, checked against the layer it composed itself<br>Web: only through the host's own: read translationY of Canvas: the host's own transform: the page holds one matrix of it, its parts no longer told apart</td></tr></tbody>
<tbody><tr></tr><tr><td><code>width</code></td><td>property</td><td><code>Double</code></td><td>native</td><td align="center">✅</td><td align="center">✅</td><td align="center">✅</td><td align="center">⌛</td><td align="center">⌛</td><td align="center">✅</td></tr></tbody>
<tbody><tr></tr><tr><td><code>zIndex</code></td><td>property</td><td><code>Int</code></td><td>native</td><td align="center">✅</td><td align="center">✅</td><td align="center">✅</td><td align="center">⌛</td><td align="center">⌛</td><td align="center">✅</td></tr></tbody>
</table>

## From [View](tiers/View.md)

What every view a layout positions has: where it sits in its layout, the space kept around it, and the gestures, drags and frame reports it answers.

<table>
<thead><tr><th>Member</th><th>Kind</th><th>Value</th><th>Layer</th><th>AppKit</th><th>UIKit</th><th>Android Views</th><th>WinUI 3</th><th>GTK 4</th><th>Web</th></tr></thead>
<tbody><tr></tr><tr><td rowspan="2"><code>allowsDrop</code></td><td>property</td><td><code>Bool</code></td><td>native</td><td align="center">✓</td><td align="center">✓</td><td align="center">✓</td><td align="center">⌛</td><td align="center">⌛</td><td align="center">✓</td></tr>
<tr><td colspan="9">AppKit: only through the host's own: dragAndDrop on Rectangle: the drag source and the window's drop routing told by the driver, no dragging session<br>UIKit: only through the host's own: dragAndDrop on Rectangle: the drag and drop interactions' handlers called, no drag session<br>Android Views: only through the host's own: dragAndDrop on Rectangle: the views' drag listeners' reports told by the driver, no drag started<br>Web: only through the host's own: dragAndDrop on Rectangle: the DOM's drag events dispatched by the driver, no drag the browser began</td></tr></tbody>
<tbody><tr></tr><tr><td><code>area</code></td><td>property</td><td><code>Area</code></td><td>structure</td><td align="center">✅</td><td align="center">✅</td><td align="center">✅</td><td align="center">⌛</td><td align="center">⌛</td><td align="center">✅</td></tr></tbody>
<tbody><tr></tr><tr><td rowspan="2"><code>onDragEntered</code> (<code>dragEntered</code>)</td><td>event</td><td></td><td>native</td><td align="center">✓</td><td align="center">✓</td><td align="center">✓</td><td align="center">⌛</td><td align="center">⌛</td><td align="center">✓</td></tr>
<tr><td colspan="9">AppKit: only through the host's own: dragAndDrop on Rectangle: the drag source and the window's drop routing told by the driver, no dragging session<br>UIKit: only through the host's own: dragAndDrop on Rectangle: the drag and drop interactions' handlers called, no drag session<br>Android Views: only through the host's own: dragAndDrop on Rectangle: the views' drag listeners' reports told by the driver, no drag started<br>Web: only through the host's own: dragAndDrop on Rectangle: the DOM's drag events dispatched by the driver, no drag the browser began</td></tr></tbody>
<tbody><tr></tr><tr><td rowspan="2"><code>onDragExited</code> (<code>dragExited</code>)</td><td>event</td><td></td><td>native</td><td align="center">✓</td><td align="center">✓</td><td align="center">✓</td><td align="center">⌛</td><td align="center">⌛</td><td align="center">✓</td></tr>
<tr><td colspan="9">AppKit: only through the host's own: dragAndDrop on Rectangle: the drag source and the window's drop routing told by the driver, no dragging session<br>UIKit: only through the host's own: dragAndDrop on Rectangle: the drag and drop interactions' handlers called, no drag session<br>Android Views: only through the host's own: dragAndDrop on Rectangle: the views' drag listeners' reports told by the driver, no drag started<br>Web: only through the host's own: dragAndDrop on Rectangle: the DOM's drag events dispatched by the driver, no drag the browser began</td></tr></tbody>
<tbody><tr></tr><tr><td rowspan="2"><code>onDragStarting</code> (<code>dragStarting</code>)</td><td>event</td><td></td><td>native</td><td align="center">✓</td><td align="center">✓</td><td align="center">✓</td><td align="center">⌛</td><td align="center">⌛</td><td align="center">✓</td></tr>
<tr><td colspan="9">AppKit: only through the host's own: dragAndDrop on Canvas: the drag source and the window's drop routing told by the driver, no dragging session<br>UIKit: only through the host's own: dragAndDrop on Canvas: the drag and drop interactions' handlers called, no drag session<br>Android Views: only through the host's own: dragAndDrop on Canvas: the views' drag listeners' reports told by the driver, no drag started<br>Web: only through the host's own: dragAndDrop on Canvas: the DOM's drag events dispatched by the driver, no drag the browser began</td></tr></tbody>
<tbody><tr></tr><tr><td rowspan="2"><code>dragText</code></td><td>property</td><td><code>String</code></td><td>native</td><td align="center">✓</td><td align="center">✓</td><td align="center">✓</td><td align="center">⌛</td><td align="center">⌛</td><td align="center">✓</td></tr>
<tr><td colspan="9">AppKit: only through the host's own: dragAndDrop on Canvas: the drag source and the window's drop routing told by the driver, no dragging session<br>UIKit: only through the host's own: dragAndDrop on Canvas: the drag and drop interactions' handlers called, no drag session<br>Android Views: only through the host's own: dragAndDrop on Canvas: the views' drag listeners' reports told by the driver, no drag started<br>Web: only through the host's own: dragAndDrop on Canvas: the DOM's drag events dispatched by the driver, no drag the browser began</td></tr></tbody>
<tbody><tr></tr><tr><td rowspan="2"><code>onDropped</code> (<code>dropped</code>)</td><td>event</td><td><code>String</code></td><td>native</td><td align="center">✓</td><td align="center">✓</td><td align="center">✓</td><td align="center">⌛</td><td align="center">⌛</td><td align="center">✓</td></tr>
<tr><td colspan="9">AppKit: only through the host's own: dragAndDrop on Rectangle: the drag source and the window's drop routing told by the driver, no dragging session<br>UIKit: only through the host's own: dragAndDrop on Rectangle: the drag and drop interactions' handlers called, no drag session<br>Android Views: only through the host's own: dragAndDrop on Rectangle: the views' drag listeners' reports told by the driver, no drag started<br>Web: only through the host's own: dragAndDrop on Rectangle: the DOM's drag events dispatched by the driver, no drag the browser began</td></tr></tbody>
<tbody><tr></tr><tr><td rowspan="2"><code>droppedFileTypes</code></td><td>property</td><td><code>[FileType]</code></td><td>native</td><td align="center">✓</td><td align="center">✓</td><td align="center">✓</td><td align="center">⌛</td><td align="center">⌛</td><td align="center">✓</td></tr>
<tr><td colspan="9">AppKit: only through the host's own: dropFiles on Canvas: the window's drop routing told the driver's files, no dragging session<br>UIKit: only through the host's own: dropFiles on Canvas: the drop interaction's handler told the driver's files, no drag session<br>Android Views: only through the host's own: dropFiles on Canvas: the view's drag listener's report told the driver's documents, no drag started<br>Web: only through the host's own: dropFiles on Canvas: the DOM's drag events dispatched by the driver with its files, no drag the browser began</td></tr></tbody>
<tbody><tr></tr><tr><td rowspan="2"><code>onDragEnded</code> (<code>dragEnded</code>)</td><td>event</td><td></td><td>native</td><td align="center">✓</td><td align="center">✓</td><td align="center">✓</td><td align="center">⌛</td><td align="center">⌛</td><td align="center">✓</td></tr>
<tr><td colspan="9">AppKit: only through the host's own: dragAndDrop on Canvas: the drag source and the window's drop routing told by the driver, no dragging session<br>UIKit: only through the host's own: dragAndDrop on Canvas: the drag and drop interactions' handlers called, no drag session<br>Android Views: only through the host's own: dragAndDrop on Canvas: the views' drag listeners' reports told by the driver, no drag started<br>Web: only through the host's own: dragAndDrop on Canvas: the DOM's drag events dispatched by the driver, no drag the browser began</td></tr></tbody>
<tbody><tr></tr><tr><td rowspan="2"><code>onDropped</code> (<code>filesDropped</code>)</td><td>event</td><td><code>[ChosenFile]</code></td><td>native</td><td align="center">✓</td><td align="center">✓</td><td align="center">✓</td><td align="center">⌛</td><td align="center">⌛</td><td align="center">✓</td></tr>
<tr><td colspan="9">AppKit: only through the host's own: dropFiles on Canvas: the window's drop routing told the driver's files, no dragging session<br>UIKit: only through the host's own: dropFiles on Canvas: the drop interaction's handler told the driver's files, no drag session<br>Android Views: only through the host's own: dropFiles on Canvas: the view's drag listener's report told the driver's documents, no drag started<br>Web: only through the host's own: dropFiles on Canvas: the DOM's drag events dispatched by the driver with its files, no drag the browser began</td></tr></tbody>
<tbody><tr></tr><tr><td><code>onFrameChanged</code> (<code>frameChanged</code>)</td><td>event</td><td><code>[Double]</code></td><td>native</td><td align="center">✅</td><td align="center">✅</td><td align="center">✅</td><td align="center">⌛</td><td align="center">⌛</td><td align="center">✅</td></tr></tbody>
<tbody><tr></tr><tr><td><code>gridColumn</code></td><td>property</td><td><code>Int</code></td><td>stateUI</td><td align="center">✅</td><td align="center">✅</td><td align="center">✅</td><td align="center">⌛</td><td align="center">⌛</td><td align="center">✅</td></tr></tbody>
<tbody><tr></tr><tr><td><code>gridColumnSpan</code></td><td>property</td><td><code>Int</code></td><td>stateUI</td><td align="center">✅</td><td align="center">✅</td><td align="center">✅</td><td align="center">⌛</td><td align="center">⌛</td><td align="center">✅</td></tr></tbody>
<tbody><tr></tr><tr><td><code>gridRow</code></td><td>property</td><td><code>Int</code></td><td>stateUI</td><td align="center">✅</td><td align="center">✅</td><td align="center">✅</td><td align="center">⌛</td><td align="center">⌛</td><td align="center">✅</td></tr></tbody>
<tbody><tr></tr><tr><td><code>gridRowSpan</code></td><td>property</td><td><code>Int</code></td><td>stateUI</td><td align="center">✅</td><td align="center">✅</td><td align="center">✅</td><td align="center">⌛</td><td align="center">⌛</td><td align="center">✅</td></tr></tbody>
<tbody><tr></tr><tr><td rowspan="2"><code>onHeld</code> (<code>held</code>)</td><td>event</td><td></td><td>native</td><td align="center">✓</td><td align="center">✓</td><td align="center">–</td><td align="center">⌛</td><td align="center">⌛</td><td align="center">✅</td></tr>
<tr><td colspan="9">AppKit: only through the host's own: hold on Canvas: handed to the host's recognizer or handler, no NSEvent sent<br>UIKit: only through the host's own: hold on Canvas: the view's listening handed the recognizer's states, no touch sent<br>Android Views: The control takes its own press - a drawing, a scroll, a thumb, its buttons: Android tells no long click of it.</td></tr></tbody>
<tbody><tr></tr><tr><td rowspan="2"><code>holdDuration</code></td><td>property</td><td><code>Double</code></td><td>structure</td><td align="center">✅</td><td align="center">✅</td><td align="center">–</td><td align="center">⌛</td><td align="center">⌛</td><td align="center">✓</td></tr>
<tr><td colspan="9">Android Views: Android's long click comes after the system's long-press time: a view keeps no time of its own.<br>Web: only through the host's own: read holdDuration of Canvas: the relay's own wait: a page holds no hold of the browser's</td></tr></tbody>
<tbody><tr></tr><tr><td><code>horizontalAlignment</code></td><td>property</td><td><code>Alignment</code></td><td>native</td><td align="center">✅</td><td align="center">✅</td><td align="center">✅</td><td align="center">⌛</td><td align="center">⌛</td><td align="center">✅</td></tr></tbody>
<tbody><tr></tr><tr><td rowspan="2"><code>isDraggable</code></td><td>property</td><td><code>Bool</code></td><td>native</td><td align="center">✓</td><td align="center">✓</td><td align="center">✓</td><td align="center">⌛</td><td align="center">⌛</td><td align="center">✓</td></tr>
<tr><td colspan="9">AppKit: only through the host's own: dragAndDrop on Canvas: the drag source and the window's drop routing told by the driver, no dragging session<br>UIKit: only through the host's own: dragAndDrop on Canvas: the drag and drop interactions' handlers called, no drag session<br>Android Views: only through the host's own: dragAndDrop on Canvas: the views' drag listeners' reports told by the driver, no drag started<br>Web: only through the host's own: dragAndDrop on Canvas: the DOM's drag events dispatched by the driver, no drag the browser began</td></tr></tbody>
<tbody><tr></tr><tr><td><code>margin</code></td><td>property</td><td><code>Insets</code></td><td>native</td><td align="center">✅</td><td align="center">✅</td><td align="center">✅</td><td align="center">⌛</td><td align="center">⌛</td><td align="center">✅</td></tr></tbody>
<tbody><tr></tr><tr><td rowspan="2"><code>panTouchCount</code></td><td>property</td><td><code>Int</code></td><td>structure</td><td align="center">☑️</td><td align="center">☑️</td><td align="center">☑️</td><td align="center">⌛</td><td align="center">⌛</td><td align="center">✅</td></tr>
<tr><td colspan="9">AppKit, UIKit, Android Views: The host layer hears a one-finger pan only; any other <code>panTouchCount</code> turns the pan off.</td></tr></tbody>
<tbody><tr></tr><tr><td rowspan="2"><code>onPanUpdated</code> (<code>panUpdated</code>)</td><td>event</td><td><code>(GesturePhase, Point, Point, Point)</code></td><td>native</td><td align="center">✓</td><td align="center">✓</td><td align="center">✅</td><td align="center">⌛</td><td align="center">⌛</td><td align="center">✅</td></tr>
<tr><td colspan="9">AppKit: only through the host's own: pan on Canvas: handed to the host's recognizer or handler, no NSEvent sent<br>UIKit: only through the host's own: pan on Canvas: the view's listening handed the recognizer's states, no touch sent</td></tr></tbody>
<tbody><tr></tr><tr><td rowspan="2"><code>panXChannel</code></td><td>property</td><td><code>Int</code></td><td>structure</td><td align="center">✓</td><td align="center">✓</td><td align="center">✅</td><td align="center">⌛</td><td align="center">⌛</td><td align="center">✅</td></tr>
<tr><td colspan="9">AppKit: only through the host's own: pan on Canvas: handed to the host's recognizer or handler, no NSEvent sent<br>UIKit: only through the host's own: pan on Canvas: the view's listening handed the recognizer's states, no touch sent</td></tr></tbody>
<tbody><tr></tr><tr><td rowspan="2"><code>panYChannel</code></td><td>property</td><td><code>Int</code></td><td>structure</td><td align="center">✓</td><td align="center">✓</td><td align="center">✅</td><td align="center">⌛</td><td align="center">⌛</td><td align="center">✅</td></tr>
<tr><td colspan="9">AppKit: only through the host's own: pan on Canvas: handed to the host's recognizer or handler, no NSEvent sent<br>UIKit: only through the host's own: pan on Canvas: the view's listening handed the recognizer's states, no touch sent</td></tr></tbody>
<tbody><tr></tr><tr><td><code>layoutBody</code></td><td>property</td><td><code>LayoutBody</code></td><td>stateUI</td><td align="center">✅</td><td align="center">✅</td><td align="center">✅</td><td align="center">⌛</td><td align="center">⌛</td><td align="center">✅</td></tr></tbody>
<tbody><tr></tr><tr><td rowspan="2"><code>onPinchUpdated</code> (<code>pinchUpdated</code>)</td><td>event</td><td><code>(GesturePhase, Double, Point, Double)</code></td><td>native</td><td align="center">✓</td><td align="center">✓</td><td align="center">✅</td><td align="center">⌛</td><td align="center">⌛</td><td align="center">✅</td></tr>
<tr><td colspan="9">AppKit: only through the host's own: pinch on Canvas: handed to the host's recognizer or handler, no NSEvent sent<br>UIKit: only through the host's own: pinch on Canvas: the view's listening handed the recognizer's states, no touch sent</td></tr></tbody>
<tbody><tr></tr><tr><td rowspan="2"><code>onPointerMoved</code> (<code>pointerMoved</code>)</td><td>event</td><td><code>Point?</code></td><td>native</td><td align="center">✓</td><td align="center">✓</td><td align="center">✅</td><td align="center">⌛</td><td align="center">⌛</td><td align="center">✅</td></tr>
<tr><td colspan="9">AppKit: only through the host's own: hover on Canvas: handed to the host's recognizer or handler, no NSEvent sent<br>UIKit: only through the host's own: hover on Canvas: the view's listening handed the recognizer's states, no touch sent</td></tr></tbody>
<tbody><tr></tr><tr><td rowspan="2"><code>onPointerPressed</code> (<code>pointerPressed</code>)</td><td>event</td><td><code>Point?</code></td><td>native</td><td align="center">✓</td><td align="center">✓</td><td align="center">✅</td><td align="center">⌛</td><td align="center">⌛</td><td align="center">✅</td></tr>
<tr><td colspan="9">AppKit: only through the host's own: hover on Canvas: handed to the host's recognizer or handler, no NSEvent sent<br>UIKit: only through the host's own: hover on Canvas: the view's listening handed the recognizer's states, no touch sent</td></tr></tbody>
<tbody><tr></tr><tr><td rowspan="2"><code>onPointerReleased</code> (<code>pointerReleased</code>)</td><td>event</td><td><code>Point?</code></td><td>native</td><td align="center">✓</td><td align="center">✓</td><td align="center">✅</td><td align="center">⌛</td><td align="center">⌛</td><td align="center">✅</td></tr>
<tr><td colspan="9">AppKit: only through the host's own: hover on Canvas: handed to the host's recognizer or handler, no NSEvent sent<br>UIKit: only through the host's own: hover on Canvas: the view's listening handed the recognizer's states, no touch sent</td></tr></tbody>
<tbody><tr></tr><tr><td rowspan="2"><code>onRotationUpdated</code> (<code>rotationUpdated</code>)</td><td>event</td><td><code>(GesturePhase, Double, Double)</code></td><td>native</td><td align="center">✓</td><td align="center">✓</td><td align="center">✅</td><td align="center">⌛</td><td align="center">⌛</td><td align="center">✅</td></tr>
<tr><td colspan="9">AppKit: only through the host's own: rotate on Canvas: handed to the host's recognizer or handler, no NSEvent sent<br>UIKit: only through the host's own: rotate on Canvas: the view's listening handed the recognizer's states, no touch sent</td></tr></tbody>
<tbody><tr></tr><tr><td rowspan="2"><code>swipeDirections</code></td><td>property</td><td><code>SwipeDirections</code></td><td>structure</td><td align="center">✓</td><td align="center">✓</td><td align="center">✅</td><td align="center">⌛</td><td align="center">⌛</td><td align="center">✅</td></tr>
<tr><td colspan="9">AppKit: only through the host's own: pan on Canvas: handed to the host's recognizer or handler, no NSEvent sent<br>UIKit: only through the host's own: pan on Canvas: the view's listening handed the recognizer's states, no touch sent</td></tr></tbody>
<tbody><tr></tr><tr><td rowspan="2"><code>swipeThreshold</code></td><td>property</td><td><code>Double</code></td><td>structure</td><td align="center">✓</td><td align="center">✓</td><td align="center">✅</td><td align="center">⌛</td><td align="center">⌛</td><td align="center">✅</td></tr>
<tr><td colspan="9">AppKit: only through the host's own: pan on Canvas: handed to the host's recognizer or handler, no NSEvent sent<br>UIKit: only through the host's own: pan on Canvas: the view's listening handed the recognizer's states, no touch sent</td></tr></tbody>
<tbody><tr></tr><tr><td rowspan="2"><code>onSwiped</code> (<code>swiped</code>)</td><td>event</td><td><code>SwipeDirection</code></td><td>native</td><td align="center">✓</td><td align="center">✓</td><td align="center">✅</td><td align="center">⌛</td><td align="center">⌛</td><td align="center">✅</td></tr>
<tr><td colspan="9">AppKit: only through the host's own: pan on Canvas: handed to the host's recognizer or handler, no NSEvent sent<br>UIKit: only through the host's own: pan on Canvas: the view's listening handed the recognizer's states, no touch sent</td></tr></tbody>
<tbody><tr></tr><tr><td rowspan="2"><code>tapCount</code></td><td>property</td><td><code>Int</code></td><td>structure</td><td align="center">✓</td><td align="center">✓</td><td align="center">✅</td><td align="center">⌛</td><td align="center">⌛</td><td align="center">✅</td></tr>
<tr><td colspan="9">AppKit: only through the host's own: tap on Canvas: handed to the host's recognizer or handler, no NSEvent sent<br>UIKit: only through the host's own: tap on Canvas: the view's listening handed the recognizer's states, no touch sent</td></tr></tbody>
<tbody><tr></tr><tr><td rowspan="2"><code>onTapped</code> (<code>tapped</code>)</td><td>event</td><td></td><td>native</td><td align="center">✓</td><td align="center">✓</td><td align="center">✅</td><td align="center">⌛</td><td align="center">⌛</td><td align="center">✅</td></tr>
<tr><td colspan="9">AppKit: only through the host's own: pressDown on Canvas: handed to the host's recognizer or handler, no NSEvent sent<br>UIKit: only through the host's own: pressDown on Canvas: the view's listening handed the recognizer's states, no touch sent</td></tr></tbody>
<tbody><tr></tr><tr><td><code>verticalAlignment</code></td><td>property</td><td><code>Alignment</code></td><td>native</td><td align="center">✅</td><td align="center">✅</td><td align="center">✅</td><td align="center">⌛</td><td align="center">⌛</td><td align="center">✅</td></tr></tbody>
</table>

## From [StyledElement](tiers/StyledElement.md)

The keyed style an element wears from the application's style sheet: a view's, a bar item's.

<table>
<thead><tr><th>Member</th><th>Kind</th><th>Value</th><th>Layer</th><th>AppKit</th><th>UIKit</th><th>Android Views</th><th>WinUI 3</th><th>GTK 4</th><th>Web</th></tr></thead>
<tbody><tr></tr><tr><td><code>style</code></td><td>property</td><td><code>Name</code></td><td>structure</td><td align="center">✅</td><td align="center">✅</td><td align="center">✅</td><td align="center">⌛</td><td align="center">⌛</td><td align="center">✅</td></tr></tbody>
</table>

## From [BackgroundElement](tiers/BackgroundElement.md)

What an element is painted on: a view's, a page's, a window's, a bar item's and a run of text's background.

<table>
<thead><tr><th>Member</th><th>Kind</th><th>Value</th><th>Layer</th><th>AppKit</th><th>UIKit</th><th>Android Views</th><th>WinUI 3</th><th>GTK 4</th><th>Web</th></tr></thead>
<tbody><tr></tr><tr><td rowspan="2"><code>background</code></td><td>property</td><td><code>Material</code></td><td>adaptive</td><td align="center">☑️</td><td align="center">☑️</td><td align="center">☑️</td><td align="center">⌛</td><td align="center">⌛</td><td align="center">☑️</td></tr>
<tr><td colspan="9">AppKit: AppKit paints a color on this view; a brush, a blur and glass are drawn only by a layout, and elsewhere a blur's color stands in.<br>UIKit: UIKit paints a color on this view; a brush, a blur and glass are drawn only by a layout, and elsewhere a blur's color stands in.<br>Android Views: Android blurs nothing behind a view: a blur or glass shows the theme's color standing in, its tint over it.<br>Web: A brush fills the view with its first color alone; a blur and glass are drawn by a layout, and elsewhere a blur's color stands in.</td></tr></tbody>
</table>

## From [EnabledElement](tiers/EnabledElement.md)

Whether the user's hand reaches an element: a view, a menu, an entry in one, a toolbar's group.

<table>
<thead><tr><th>Member</th><th>Kind</th><th>Value</th><th>Layer</th><th>AppKit</th><th>UIKit</th><th>Android Views</th><th>WinUI 3</th><th>GTK 4</th><th>Web</th></tr></thead>
<tbody><tr></tr><tr><td><code>isEnabled</code></td><td>property</td><td><code>Bool</code></td><td>native</td><td align="center">✅</td><td align="center">✅</td><td align="center">✅</td><td align="center">⌛</td><td align="center">⌛</td><td align="center">✅</td></tr></tbody>
</table>

## From [HoverElement](tiers/HoverElement.md)

What an element the pointer comes over and leaves reports: a view, an item on a bar.

<table>
<thead><tr><th>Member</th><th>Kind</th><th>Value</th><th>Layer</th><th>AppKit</th><th>UIKit</th><th>Android Views</th><th>WinUI 3</th><th>GTK 4</th><th>Web</th></tr></thead>
<tbody><tr></tr><tr><td rowspan="2"><code>onPointerEntered</code> (<code>pointerEntered</code>)</td><td>event</td><td></td><td>native</td><td align="center">✓</td><td align="center">✓</td><td align="center">✅</td><td align="center">⌛</td><td align="center">⌛</td><td align="center">✅</td></tr>
<tr><td colspan="9">AppKit: only through the host's own: hover on Canvas: handed to the host's recognizer or handler, no NSEvent sent<br>UIKit: only through the host's own: hover on Canvas: the view's listening handed the recognizer's states, no touch sent</td></tr></tbody>
<tbody><tr></tr><tr><td rowspan="2"><code>onPointerExited</code> (<code>pointerExited</code>)</td><td>event</td><td></td><td>native</td><td align="center">✓</td><td align="center">✓</td><td align="center">✅</td><td align="center">⌛</td><td align="center">⌛</td><td align="center">✅</td></tr>
<tr><td colspan="9">AppKit: only through the host's own: hover on Canvas: handed to the host's recognizer or handler, no NSEvent sent<br>UIKit: only through the host's own: hover on Canvas: the view's listening handed the recognizer's states, no touch sent</td></tr></tbody>
</table>
