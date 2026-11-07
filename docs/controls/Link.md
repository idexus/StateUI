<!-- Rendered by ControlDictionaryTests from the contracts and the verdicts each host's runs of its tests wrote under lib/StateUI/exports/marks: STATEUI_UPDATE_DOCS=1 swift test --filter ControlDictionaryTests writes it again. -->

# Link

Words that open an address - a page, a mail, a call - in the application the system gives it.

```swift
Link("Terms of use", address: "https://stateui.dev/terms")
```

Layer: `adaptive`. Every base host presents it by its platform's conventions, keeping StateUI's state contract.

Inherits: [AutomationElement](tiers/AutomationElement.md) · [VisualElement](tiers/VisualElement.md) · [View](tiers/View.md) · [TextualElement](tiers/TextualElement.md) · [TextColorElement](tiers/TextColorElement.md) · [KeyboardElement](tiers/KeyboardElement.md) · [FocusElement](tiers/FocusElement.md)

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
<tbody><tr></tr><tr><td>AppKit</td><td align="center">✅</td><td>43 ✅ · 3 ☑️ · 37 ✓ · 1 –</td><td>a borderless <code>NSButton</code> in the link color, the link role</td></tr></tbody>
<tbody><tr></tr><tr><td>UIKit</td><td align="center">✅</td><td>5 ✅ · 3 ✓ · 3 –</td><td>a plain <code>UIButton</code> in the link color, the link trait</td></tr></tbody>
<tbody><tr></tr><tr><td>Android Views</td><td align="center">✅</td><td>5 ✅ · 3 ✓ · 3 –</td><td>a <code>TextView</code> in the theme's link color, underlined</td></tr></tbody>
<tbody><tr></tr><tr><td>WinUI 3</td><td align="center">✅</td><td>10 ✅ · 1 ✓</td><td><code>HyperlinkButton</code></td></tr></tbody>
<tbody><tr></tr><tr><td>GTK 4</td><td align="center">✅</td><td>7 ✅ · 3 ✓ · 1 –</td><td><code>GtkLinkButton</code></td></tr></tbody>
<tbody><tr></tr><tr><td>Web</td><td align="center">✅</td><td>10 ✅ · 1 ✓</td><td><code>&lt;a href&gt;</code></td></tr></tbody>
</table>

Declared in `lib/StateUI/Core/Sources/Contracts/Elements/Controls/LinkContract.swift`.

## Link's own members

<table>
<thead><tr><th>Member</th><th>Kind</th><th>Value</th><th>Layer</th><th>AppKit</th><th>UIKit</th><th>Android Views</th><th>WinUI 3</th><th>GTK 4</th><th>Web</th></tr></thead>
<tbody><tr></tr><tr><td rowspan="2"><code>address</code></td><td>property</td><td><code>String</code></td><td>native</td><td align="center">✓</td><td align="center">✓</td><td align="center">✓</td><td align="center">✓</td><td align="center">✓</td><td align="center">✓</td></tr>
<tr><td colspan="9">AppKit: only through the host's own: read what was launched: the host's own record of what it handed macOS, which a test holds back from launching<br>UIKit: only through the host's own: read what was launched: the host's own record of what it handed iOS, which a test holds back from launching<br>Android Views: only through the host's own: read what was launched: the relay's own record of what it handed the system, which a test holds back from launching<br>WinUI 3: only through the host's own: read what was launched: the host's own record of what it handed Windows, which a test holds back from launching<br>GTK 4: only through the host's own: read what was launched: the host's own record of what it handed the desktop, which a test holds back<br>Web: only through the host's own: read what was launched: the relay's own record of what it would open, which a test holds back</td></tr></tbody>
<tbody><tr></tr><tr><td><code>onClicked</code> (<code>clicked</code>)</td><td>event</td><td></td><td>native</td><td align="center">✅</td><td align="center">✅</td><td align="center">✅</td><td align="center">✅</td><td align="center">✅</td><td align="center">✅</td></tr></tbody>
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
<tbody><tr></tr><tr><td rowspan="2"><code>background</code></td><td>property</td><td><code>Material</code></td><td>adaptive</td><td align="center">☑️</td><td align="center">⌛</td><td align="center">⌛</td><td align="center">⌛</td><td align="center">⌛</td><td align="center">⌛</td></tr>
<tr><td colspan="9">AppKit: AppKit paints a color on this view; a brush, a blur and glass are drawn only by a layout, and elsewhere a blur's color stands in.</td></tr></tbody>
<tbody><tr></tr><tr><td><code>frame</code></td><td>property</td><td><code>Rect</code></td><td>structure</td><td align="center">✅</td><td align="center">⌛</td><td align="center">⌛</td><td align="center">⌛</td><td align="center">⌛</td><td align="center">⌛</td></tr></tbody>
<tbody><tr></tr><tr><td><code>height</code></td><td>property</td><td><code>Double</code></td><td>native</td><td align="center">✅</td><td align="center">⌛</td><td align="center">⌛</td><td align="center">⌛</td><td align="center">⌛</td><td align="center">⌛</td></tr></tbody>
<tbody><tr></tr><tr><td><code>ignoresInput</code></td><td>property</td><td><code>Bool</code></td><td>native</td><td align="center">✅</td><td align="center">⌛</td><td align="center">⌛</td><td align="center">⌛</td><td align="center">⌛</td><td align="center">⌛</td></tr></tbody>
<tbody><tr></tr><tr><td><code>isEnabled</code></td><td>property</td><td><code>Bool</code></td><td>native</td><td align="center">✅</td><td align="center">⌛</td><td align="center">⌛</td><td align="center">⌛</td><td align="center">⌛</td><td align="center">⌛</td></tr></tbody>
<tbody><tr></tr><tr><td><code>isVisible</code></td><td>property</td><td><code>Bool</code></td><td>native</td><td align="center">✅</td><td align="center">⌛</td><td align="center">⌛</td><td align="center">⌛</td><td align="center">⌛</td><td align="center">⌛</td></tr></tbody>
<tbody><tr></tr><tr><td><code>layoutDirection</code></td><td>property</td><td><code>LayoutDirection</code></td><td>native</td><td align="center">✅</td><td align="center">⌛</td><td align="center">⌛</td><td align="center">⌛</td><td align="center">⌛</td><td align="center">⌛</td></tr></tbody>
<tbody><tr></tr><tr><td><code>maximumHeight</code></td><td>property</td><td><code>Double</code></td><td>native</td><td align="center">✅</td><td align="center">⌛</td><td align="center">⌛</td><td align="center">⌛</td><td align="center">⌛</td><td align="center">⌛</td></tr></tbody>
<tbody><tr></tr><tr><td><code>maximumWidth</code></td><td>property</td><td><code>Double</code></td><td>native</td><td align="center">✅</td><td align="center">⌛</td><td align="center">⌛</td><td align="center">⌛</td><td align="center">⌛</td><td align="center">⌛</td></tr></tbody>
<tbody><tr></tr><tr><td><code>minimumHeight</code></td><td>property</td><td><code>Double</code></td><td>native</td><td align="center">✅</td><td align="center">⌛</td><td align="center">⌛</td><td align="center">⌛</td><td align="center">⌛</td><td align="center">⌛</td></tr></tbody>
<tbody><tr></tr><tr><td><code>minimumWidth</code></td><td>property</td><td><code>Double</code></td><td>native</td><td align="center">✅</td><td align="center">⌛</td><td align="center">⌛</td><td align="center">⌛</td><td align="center">⌛</td><td align="center">⌛</td></tr></tbody>
<tbody><tr></tr><tr><td><code>opacity</code></td><td>property</td><td><code>Double</code></td><td>native</td><td align="center">✅</td><td align="center">⌛</td><td align="center">⌛</td><td align="center">⌛</td><td align="center">⌛</td><td align="center">⌛</td></tr></tbody>
<tbody><tr></tr><tr><td rowspan="2"><code>pivotX</code></td><td>property</td><td><code>Double</code></td><td>native</td><td align="center">✓</td><td align="center">⌛</td><td align="center">⌛</td><td align="center">⌛</td><td align="center">⌛</td><td align="center">⌛</td></tr>
<tr><td colspan="9">AppKit: only through the host's own: read pivotX of Link: the host's own transform, checked against the layer it composed itself</td></tr></tbody>
<tbody><tr></tr><tr><td rowspan="2"><code>pivotY</code></td><td>property</td><td><code>Double</code></td><td>native</td><td align="center">✓</td><td align="center">⌛</td><td align="center">⌛</td><td align="center">⌛</td><td align="center">⌛</td><td align="center">⌛</td></tr>
<tr><td colspan="9">AppKit: only through the host's own: read pivotY of Link: the host's own transform, checked against the layer it composed itself</td></tr></tbody>
<tbody><tr></tr><tr><td rowspan="2"><code>rotation</code></td><td>property</td><td><code>Double</code></td><td>native</td><td align="center">✓</td><td align="center">⌛</td><td align="center">⌛</td><td align="center">⌛</td><td align="center">⌛</td><td align="center">⌛</td></tr>
<tr><td colspan="9">AppKit: only through the host's own: read rotation of Link: the host's own transform, checked against the layer it composed itself</td></tr></tbody>
<tbody><tr></tr><tr><td rowspan="2"><code>rotationX</code></td><td>property</td><td><code>Double</code></td><td>native</td><td align="center">✓</td><td align="center">⌛</td><td align="center">⌛</td><td align="center">⌛</td><td align="center">⌛</td><td align="center">⌛</td></tr>
<tr><td colspan="9">AppKit: only through the host's own: read rotationX of Link: the host's own transform, checked against the layer it composed itself</td></tr></tbody>
<tbody><tr></tr><tr><td rowspan="2"><code>rotationY</code></td><td>property</td><td><code>Double</code></td><td>native</td><td align="center">✓</td><td align="center">⌛</td><td align="center">⌛</td><td align="center">⌛</td><td align="center">⌛</td><td align="center">⌛</td></tr>
<tr><td colspan="9">AppKit: only through the host's own: read rotationY of Link: the host's own transform, checked against the layer it composed itself</td></tr></tbody>
<tbody><tr></tr><tr><td rowspan="2"><code>scale</code></td><td>property</td><td><code>Double</code></td><td>native</td><td align="center">✓</td><td align="center">⌛</td><td align="center">⌛</td><td align="center">⌛</td><td align="center">⌛</td><td align="center">⌛</td></tr>
<tr><td colspan="9">AppKit: only through the host's own: read scale of Link: the host's own transform, checked against the layer it composed itself</td></tr></tbody>
<tbody><tr></tr><tr><td rowspan="2"><code>scaleX</code></td><td>property</td><td><code>Double</code></td><td>native</td><td align="center">✓</td><td align="center">⌛</td><td align="center">⌛</td><td align="center">⌛</td><td align="center">⌛</td><td align="center">⌛</td></tr>
<tr><td colspan="9">AppKit: only through the host's own: read scaleX of Link: the host's own transform, checked against the layer it composed itself</td></tr></tbody>
<tbody><tr></tr><tr><td rowspan="2"><code>scaleY</code></td><td>property</td><td><code>Double</code></td><td>native</td><td align="center">✓</td><td align="center">⌛</td><td align="center">⌛</td><td align="center">⌛</td><td align="center">⌛</td><td align="center">⌛</td></tr>
<tr><td colspan="9">AppKit: only through the host's own: read scaleY of Link: the host's own transform, checked against the layer it composed itself</td></tr></tbody>
<tbody><tr></tr><tr><td><code>style</code></td><td>property</td><td><code>Name</code></td><td>structure</td><td align="center">✅</td><td align="center">⌛</td><td align="center">⌛</td><td align="center">⌛</td><td align="center">⌛</td><td align="center">⌛</td></tr></tbody>
<tbody><tr></tr><tr><td><code>tooltip</code></td><td>property</td><td><code>String</code></td><td>native</td><td align="center">✅</td><td align="center">⌛</td><td align="center">⌛</td><td align="center">⌛</td><td align="center">⌛</td><td align="center">⌛</td></tr></tbody>
<tbody><tr></tr><tr><td rowspan="2"><code>translationX</code></td><td>property</td><td><code>Double</code></td><td>native</td><td align="center">✓</td><td align="center">⌛</td><td align="center">⌛</td><td align="center">⌛</td><td align="center">⌛</td><td align="center">⌛</td></tr>
<tr><td colspan="9">AppKit: only through the host's own: read translationX of Link: the host's own transform, checked against the layer it composed itself</td></tr></tbody>
<tbody><tr></tr><tr><td rowspan="2"><code>translationY</code></td><td>property</td><td><code>Double</code></td><td>native</td><td align="center">✓</td><td align="center">⌛</td><td align="center">⌛</td><td align="center">⌛</td><td align="center">⌛</td><td align="center">⌛</td></tr>
<tr><td colspan="9">AppKit: only through the host's own: read translationY of Link: the host's own transform, checked against the layer it composed itself</td></tr></tbody>
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
<tr><td colspan="9">AppKit: only through the host's own: dragAndDrop on Link: the drag source and the window's drop routing told by the driver, no dragging session</td></tr></tbody>
<tbody><tr></tr><tr><td rowspan="2"><code>dragText</code></td><td>property</td><td><code>String</code></td><td>native</td><td align="center">✓</td><td align="center">⌛</td><td align="center">⌛</td><td align="center">⌛</td><td align="center">⌛</td><td align="center">⌛</td></tr>
<tr><td colspan="9">AppKit: only through the host's own: dragAndDrop on Link: the drag source and the window's drop routing told by the driver, no dragging session</td></tr></tbody>
<tbody><tr></tr><tr><td rowspan="2"><code>onDropped</code> (<code>dropped</code>)</td><td>event</td><td><code>String</code></td><td>native</td><td align="center">✓</td><td align="center">⌛</td><td align="center">⌛</td><td align="center">⌛</td><td align="center">⌛</td><td align="center">⌛</td></tr>
<tr><td colspan="9">AppKit: only through the host's own: dragAndDrop on Rectangle: the drag source and the window's drop routing told by the driver, no dragging session</td></tr></tbody>
<tbody><tr></tr><tr><td rowspan="2"><code>droppedFileTypes</code></td><td>property</td><td><code>[FileType]</code></td><td>native</td><td align="center">✓</td><td align="center">⌛</td><td align="center">⌛</td><td align="center">⌛</td><td align="center">⌛</td><td align="center">⌛</td></tr>
<tr><td colspan="9">AppKit: only through the host's own: dropFiles on Link: the window's drop routing told the driver's files, no dragging session</td></tr></tbody>
<tbody><tr></tr><tr><td rowspan="2"><code>onDragEnded</code> (<code>dragEnded</code>)</td><td>event</td><td></td><td>native</td><td align="center">✓</td><td align="center">⌛</td><td align="center">⌛</td><td align="center">⌛</td><td align="center">⌛</td><td align="center">⌛</td></tr>
<tr><td colspan="9">AppKit: only through the host's own: dragAndDrop on Link: the drag source and the window's drop routing told by the driver, no dragging session</td></tr></tbody>
<tbody><tr></tr><tr><td rowspan="2"><code>onDropped</code> (<code>filesDropped</code>)</td><td>event</td><td><code>[ChosenFile]</code></td><td>native</td><td align="center">✓</td><td align="center">⌛</td><td align="center">⌛</td><td align="center">⌛</td><td align="center">⌛</td><td align="center">⌛</td></tr>
<tr><td colspan="9">AppKit: only through the host's own: dropFiles on Link: the window's drop routing told the driver's files, no dragging session</td></tr></tbody>
<tbody><tr></tr><tr><td><code>onFrameChanged</code> (<code>frameChanged</code>)</td><td>event</td><td><code>[Double]</code></td><td>native</td><td align="center">✅</td><td align="center">⌛</td><td align="center">⌛</td><td align="center">⌛</td><td align="center">⌛</td><td align="center">⌛</td></tr></tbody>
<tbody><tr></tr><tr><td><code>gridColumn</code></td><td>property</td><td><code>Int</code></td><td>stateUI</td><td align="center">✅</td><td align="center">⌛</td><td align="center">⌛</td><td align="center">⌛</td><td align="center">⌛</td><td align="center">⌛</td></tr></tbody>
<tbody><tr></tr><tr><td><code>gridColumnSpan</code></td><td>property</td><td><code>Int</code></td><td>stateUI</td><td align="center">✅</td><td align="center">⌛</td><td align="center">⌛</td><td align="center">⌛</td><td align="center">⌛</td><td align="center">⌛</td></tr></tbody>
<tbody><tr></tr><tr><td><code>gridRow</code></td><td>property</td><td><code>Int</code></td><td>stateUI</td><td align="center">✅</td><td align="center">⌛</td><td align="center">⌛</td><td align="center">⌛</td><td align="center">⌛</td><td align="center">⌛</td></tr></tbody>
<tbody><tr></tr><tr><td><code>gridRowSpan</code></td><td>property</td><td><code>Int</code></td><td>stateUI</td><td align="center">✅</td><td align="center">⌛</td><td align="center">⌛</td><td align="center">⌛</td><td align="center">⌛</td><td align="center">⌛</td></tr></tbody>
<tbody><tr></tr><tr><td rowspan="2"><code>onHeld</code> (<code>held</code>)</td><td>event</td><td></td><td>native</td><td align="center">✓</td><td align="center">⌛</td><td align="center">⌛</td><td align="center">⌛</td><td align="center">⌛</td><td align="center">⌛</td></tr>
<tr><td colspan="9">AppKit: only through the host's own: hold on Link: handed to the host's recognizer or handler, no NSEvent sent</td></tr></tbody>
<tbody><tr></tr><tr><td><code>holdDuration</code></td><td>property</td><td><code>Double</code></td><td>structure</td><td align="center">✅</td><td align="center">⌛</td><td align="center">⌛</td><td align="center">⌛</td><td align="center">⌛</td><td align="center">⌛</td></tr></tbody>
<tbody><tr></tr><tr><td><code>horizontalAlignment</code></td><td>property</td><td><code>Alignment</code></td><td>native</td><td align="center">✅</td><td align="center">⌛</td><td align="center">⌛</td><td align="center">⌛</td><td align="center">⌛</td><td align="center">⌛</td></tr></tbody>
<tbody><tr></tr><tr><td rowspan="2"><code>isDraggable</code></td><td>property</td><td><code>Bool</code></td><td>native</td><td align="center">✓</td><td align="center">⌛</td><td align="center">⌛</td><td align="center">⌛</td><td align="center">⌛</td><td align="center">⌛</td></tr>
<tr><td colspan="9">AppKit: only through the host's own: dragAndDrop on Link: the drag source and the window's drop routing told by the driver, no dragging session</td></tr></tbody>
<tbody><tr></tr><tr><td><code>margin</code></td><td>property</td><td><code>Insets</code></td><td>native</td><td align="center">✅</td><td align="center">⌛</td><td align="center">⌛</td><td align="center">⌛</td><td align="center">⌛</td><td align="center">⌛</td></tr></tbody>
<tbody><tr></tr><tr><td rowspan="2"><code>panTouchCount</code></td><td>property</td><td><code>Int</code></td><td>structure</td><td align="center">☑️</td><td align="center">⌛</td><td align="center">⌛</td><td align="center">⌛</td><td align="center">⌛</td><td align="center">⌛</td></tr>
<tr><td colspan="9">AppKit: The host layer hears a one-finger pan only; any other <code>panTouchCount</code> turns the pan off.</td></tr></tbody>
<tbody><tr></tr><tr><td rowspan="2"><code>onPanUpdated</code> (<code>panUpdated</code>)</td><td>event</td><td><code>(GesturePhase, Point, Point, Point)</code></td><td>native</td><td align="center">✓</td><td align="center">⌛</td><td align="center">⌛</td><td align="center">⌛</td><td align="center">⌛</td><td align="center">⌛</td></tr>
<tr><td colspan="9">AppKit: only through the host's own: pan on Link: handed to the host's recognizer or handler, no NSEvent sent</td></tr></tbody>
<tbody><tr></tr><tr><td rowspan="2"><code>panXChannel</code></td><td>property</td><td><code>Int</code></td><td>structure</td><td align="center">✓</td><td align="center">⌛</td><td align="center">⌛</td><td align="center">⌛</td><td align="center">⌛</td><td align="center">⌛</td></tr>
<tr><td colspan="9">AppKit: only through the host's own: pan on Link: handed to the host's recognizer or handler, no NSEvent sent</td></tr></tbody>
<tbody><tr></tr><tr><td rowspan="2"><code>panYChannel</code></td><td>property</td><td><code>Int</code></td><td>structure</td><td align="center">✓</td><td align="center">⌛</td><td align="center">⌛</td><td align="center">⌛</td><td align="center">⌛</td><td align="center">⌛</td></tr>
<tr><td colspan="9">AppKit: only through the host's own: pan on Link: handed to the host's recognizer or handler, no NSEvent sent</td></tr></tbody>
<tbody><tr></tr><tr><td><code>layoutBody</code></td><td>property</td><td><code>LayoutBody</code></td><td>stateUI</td><td align="center">✅</td><td align="center">⌛</td><td align="center">⌛</td><td align="center">⌛</td><td align="center">⌛</td><td align="center">⌛</td></tr></tbody>
<tbody><tr></tr><tr><td rowspan="2"><code>onPinchUpdated</code> (<code>pinchUpdated</code>)</td><td>event</td><td><code>(GesturePhase, Double, Point, Double)</code></td><td>native</td><td align="center">✓</td><td align="center">⌛</td><td align="center">⌛</td><td align="center">⌛</td><td align="center">⌛</td><td align="center">⌛</td></tr>
<tr><td colspan="9">AppKit: only through the host's own: pinch on Link: handed to the host's recognizer or handler, no NSEvent sent</td></tr></tbody>
<tbody><tr></tr><tr><td rowspan="2"><code>onPointerEntered</code> (<code>pointerEntered</code>)</td><td>event</td><td></td><td>native</td><td align="center">✓</td><td align="center">⌛</td><td align="center">⌛</td><td align="center">⌛</td><td align="center">⌛</td><td align="center">⌛</td></tr>
<tr><td colspan="9">AppKit: only through the host's own: hover on Link: handed to the host's recognizer or handler, no NSEvent sent</td></tr></tbody>
<tbody><tr></tr><tr><td rowspan="2"><code>onPointerExited</code> (<code>pointerExited</code>)</td><td>event</td><td></td><td>native</td><td align="center">✓</td><td align="center">⌛</td><td align="center">⌛</td><td align="center">⌛</td><td align="center">⌛</td><td align="center">⌛</td></tr>
<tr><td colspan="9">AppKit: only through the host's own: hover on Link: handed to the host's recognizer or handler, no NSEvent sent</td></tr></tbody>
<tbody><tr></tr><tr><td rowspan="2"><code>onPointerMoved</code> (<code>pointerMoved</code>)</td><td>event</td><td><code>Point?</code></td><td>native</td><td align="center">✓</td><td align="center">⌛</td><td align="center">⌛</td><td align="center">⌛</td><td align="center">⌛</td><td align="center">⌛</td></tr>
<tr><td colspan="9">AppKit: only through the host's own: hover on Link: handed to the host's recognizer or handler, no NSEvent sent</td></tr></tbody>
<tbody><tr></tr><tr><td rowspan="2"><code>onPointerPressed</code> (<code>pointerPressed</code>)</td><td>event</td><td><code>Point?</code></td><td>native</td><td align="center">✓</td><td align="center">⌛</td><td align="center">⌛</td><td align="center">⌛</td><td align="center">⌛</td><td align="center">⌛</td></tr>
<tr><td colspan="9">AppKit: only through the host's own: hover on Link: handed to the host's recognizer or handler, no NSEvent sent</td></tr></tbody>
<tbody><tr></tr><tr><td rowspan="2"><code>onPointerReleased</code> (<code>pointerReleased</code>)</td><td>event</td><td><code>Point?</code></td><td>native</td><td align="center">✓</td><td align="center">⌛</td><td align="center">⌛</td><td align="center">⌛</td><td align="center">⌛</td><td align="center">⌛</td></tr>
<tr><td colspan="9">AppKit: only through the host's own: hover on Link: handed to the host's recognizer or handler, no NSEvent sent</td></tr></tbody>
<tbody><tr></tr><tr><td rowspan="2"><code>onRotationUpdated</code> (<code>rotationUpdated</code>)</td><td>event</td><td><code>(GesturePhase, Double, Double)</code></td><td>native</td><td align="center">✓</td><td align="center">⌛</td><td align="center">⌛</td><td align="center">⌛</td><td align="center">⌛</td><td align="center">⌛</td></tr>
<tr><td colspan="9">AppKit: only through the host's own: rotate on Link: handed to the host's recognizer or handler, no NSEvent sent</td></tr></tbody>
<tbody><tr></tr><tr><td rowspan="2"><code>swipeDirections</code></td><td>property</td><td><code>SwipeDirections</code></td><td>structure</td><td align="center">✓</td><td align="center">⌛</td><td align="center">⌛</td><td align="center">⌛</td><td align="center">⌛</td><td align="center">⌛</td></tr>
<tr><td colspan="9">AppKit: only through the host's own: pan on Link: handed to the host's recognizer or handler, no NSEvent sent</td></tr></tbody>
<tbody><tr></tr><tr><td rowspan="2"><code>swipeThreshold</code></td><td>property</td><td><code>Double</code></td><td>structure</td><td align="center">✓</td><td align="center">⌛</td><td align="center">⌛</td><td align="center">⌛</td><td align="center">⌛</td><td align="center">⌛</td></tr>
<tr><td colspan="9">AppKit: only through the host's own: pan on Link: handed to the host's recognizer or handler, no NSEvent sent</td></tr></tbody>
<tbody><tr></tr><tr><td rowspan="2"><code>onSwiped</code> (<code>swiped</code>)</td><td>event</td><td><code>SwipeDirection</code></td><td>native</td><td align="center">✓</td><td align="center">⌛</td><td align="center">⌛</td><td align="center">⌛</td><td align="center">⌛</td><td align="center">⌛</td></tr>
<tr><td colspan="9">AppKit: only through the host's own: pan on Link: handed to the host's recognizer or handler, no NSEvent sent</td></tr></tbody>
<tbody><tr></tr><tr><td rowspan="2"><code>tapCount</code></td><td>property</td><td><code>Int</code></td><td>structure</td><td align="center">✓</td><td align="center">⌛</td><td align="center">⌛</td><td align="center">⌛</td><td align="center">⌛</td><td align="center">⌛</td></tr>
<tr><td colspan="9">AppKit: only through the host's own: tap on Link: handed to the host's recognizer or handler, no NSEvent sent</td></tr></tbody>
<tbody><tr></tr><tr><td rowspan="2"><code>onTapped</code> (<code>tapped</code>)</td><td>event</td><td></td><td>native</td><td align="center">✓</td><td align="center">⌛</td><td align="center">⌛</td><td align="center">⌛</td><td align="center">⌛</td><td align="center">⌛</td></tr>
<tr><td colspan="9">AppKit: only through the host's own: pressDown on Link: handed to the host's recognizer or handler, no NSEvent sent</td></tr></tbody>
<tbody><tr></tr><tr><td><code>verticalAlignment</code></td><td>property</td><td><code>Alignment</code></td><td>native</td><td align="center">✅</td><td align="center">⌛</td><td align="center">⌛</td><td align="center">⌛</td><td align="center">⌛</td><td align="center">⌛</td></tr></tbody>
</table>

## From [TextualElement](tiers/TextualElement.md)

What every element showing words has: the words, and the case they are drawn in.

<table>
<thead><tr><th>Member</th><th>Kind</th><th>Value</th><th>Layer</th><th>AppKit</th><th>UIKit</th><th>Android Views</th><th>WinUI 3</th><th>GTK 4</th><th>Web</th></tr></thead>
<tbody><tr></tr><tr><td><code>text</code></td><td>property</td><td><code>String</code></td><td>native</td><td align="center">✅</td><td align="center">✅</td><td align="center">✅</td><td align="center">✅</td><td align="center">✅</td><td align="center">✅</td></tr></tbody>
<tbody><tr></tr><tr><td><code>textCase</code></td><td>property</td><td><code>TextCase</code></td><td>native</td><td align="center">✅</td><td align="center">✅</td><td align="center">✅</td><td align="center">✅</td><td align="center">✅</td><td align="center">✅</td></tr></tbody>
</table>

## From [TextColorElement](tiers/TextColorElement.md)

The color of text, wherever it is drawn.

<table>
<thead><tr><th>Member</th><th>Kind</th><th>Value</th><th>Layer</th><th>AppKit</th><th>UIKit</th><th>Android Views</th><th>WinUI 3</th><th>GTK 4</th><th>Web</th></tr></thead>
<tbody><tr></tr><tr><td><code>textColor</code></td><td>property</td><td><code>Color</code></td><td>native</td><td align="center">✅</td><td align="center">✅</td><td align="center">✅</td><td align="center">✅</td><td align="center">✅</td><td align="center">✅</td></tr></tbody>
</table>

## From [KeyboardElement](tiers/KeyboardElement.md)

An element that can hold the keyboard - a control taking the focus, or a layout holding the view that does - and so hear the keys it takes.

<table>
<thead><tr><th>Member</th><th>Kind</th><th>Value</th><th>Layer</th><th>AppKit</th><th>UIKit</th><th>Android Views</th><th>WinUI 3</th><th>GTK 4</th><th>Web</th></tr></thead>
<tbody><tr></tr><tr><td rowspan="2"><code>keyPressed</code></td><td>event</td><td><code>(Key, KeyModifiers)</code></td><td>native</td><td align="center">✅</td><td align="center">✓</td><td align="center">✓</td><td align="center">✅</td><td align="center">✓</td><td align="center">✅</td></tr>
<tr><td colspan="9">UIKit: only through the host's own: pressKeys on Link: the window's or the main menu's key command performed, no key pressed<br>Android Views: only through the host's own: pressKeys on Link: the key event no view took handed to the host as the application's activity hands it<br>GTK 4: only through the host's own: pressKeys on Link: the shortcut controller's action run, no key event</td></tr></tbody>
<tbody><tr></tr><tr><td rowspan="2"><code>keysTaken</code></td><td>property</td><td><code>[Key]</code></td><td>structure</td><td align="center">✅</td><td align="center">✓</td><td align="center">✓</td><td align="center">✅</td><td align="center">✓</td><td align="center">✅</td></tr>
<tr><td colspan="9">UIKit: only through the host's own: pressKeys on Link: the window's or the main menu's key command performed, no key pressed<br>Android Views: only through the host's own: pressKeys on Link: the key event no view took handed to the host as the application's activity hands it<br>GTK 4: only through the host's own: pressKeys on Link: the shortcut controller's action run, no key event</td></tr></tbody>
</table>

## From [FocusElement](tiers/FocusElement.md)

An element that takes the keyboard focus itself - a field, a button, a list - and so holds the keyboard.

<table>
<thead><tr><th>Member</th><th>Kind</th><th>Value</th><th>Layer</th><th>AppKit</th><th>UIKit</th><th>Android Views</th><th>WinUI 3</th><th>GTK 4</th><th>Web</th></tr></thead>
<tbody><tr></tr><tr><td rowspan="2"><code>focus</code></td><td>act</td><td><code>() -&gt; Bool</code></td><td></td><td align="center">✅</td><td align="center">–</td><td align="center">–</td><td align="center">✅</td><td align="center">✅</td><td align="center">✅</td></tr>
<tr><td colspan="9">UIKit, Android Views: Link takes no keyboard focus here: it refuses it, and nothing is heard</td></tr></tbody>
<tbody><tr></tr><tr><td rowspan="2"><code>isFocusedChanged</code></td><td>event</td><td><code>Bool</code></td><td>native</td><td align="center">✅</td><td align="center">–</td><td align="center">–</td><td align="center">✅</td><td align="center">✅</td><td align="center">✅</td></tr>
<tr><td colspan="9">UIKit, Android Views: Link takes no keyboard focus here: it refuses it, and nothing is heard</td></tr></tbody>
<tbody><tr></tr><tr><td rowspan="2"><code>unfocus</code></td><td>act</td><td><code>() -&gt; Void</code></td><td></td><td align="center">✅</td><td align="center">–</td><td align="center">–</td><td align="center">✅</td><td align="center">✅</td><td align="center">✅</td></tr>
<tr><td colspan="9">UIKit, Android Views: Link takes no keyboard focus here: it refuses it, and nothing is heard</td></tr></tbody>
</table>
