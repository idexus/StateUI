<!-- Rendered by ControlDictionaryTests from the contracts and the verdicts each host's runs of its tests wrote under lib/StateUI/exports/marks: STATEUI_UPDATE_DOCS=1 swift test --filter ControlDictionaryTests writes it again. -->

# Grid

Arranges its children in rows and columns.

```swift
@State var name = ""

Grid {
    Text("Name")
    TextField($name)
        .gridColumn(1)
    Button("Save")
        .gridRow(1)
        .gridColumnSpan(2)
}
.rows(.auto, .auto)
.columns(.auto, .fill)
.columnSpacing(12)
```

Layer: `stateUI`. StateUI composes it from smaller primitives before a host receives the tree.

Inherits: [PropertyContainer](tiers/PropertyContainer.md) · [VisualElement](tiers/VisualElement.md) · [View](tiers/View.md) · [Layout](tiers/Layout.md) · [PaddingElement](tiers/PaddingElement.md) · [BorderElement](tiers/BorderElement.md)

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
<thead><tr><th>Host</th><th>Created</th><th>Members (77)</th><th>Realization</th></tr></thead>
<tbody><tr></tr><tr><td>AppKit</td><td align="center">✅</td><td>33 ✅ · 33 ✓ · 3 –</td><td>custom <code>NSView</code></td></tr></tbody>
<tbody><tr></tr><tr><td>UIKit</td><td align="center">✅</td><td>35 ✅ · 33 ✓ · 3 –</td><td>composed by StateUI</td></tr></tbody>
<tbody><tr></tr><tr><td>Android Views</td><td align="center">✅</td><td>56 ✅ · 1 ☑️ · 8 ✓ · 3 –</td><td>composed by StateUI</td></tr></tbody>
<tbody><tr></tr><tr><td>WinUI 3</td><td align="center">✅</td><td>59 ✅ · 3 ✓ · 3 –</td><td>composed by StateUI</td></tr></tbody>
<tbody><tr></tr><tr><td>GTK 4</td><td align="center">✅</td><td>48 ✅ · 11 ✓ · 4 –</td><td>composed by StateUI</td></tr></tbody>
<tbody><tr></tr><tr><td>Web</td><td align="center">✅</td><td>54 ✅ · 18 ✓</td><td>composed by StateUI</td></tr></tbody>
</table>

Declared in `lib/StateUI/Core/Sources/Contracts/Elements/Layouts/GridContract.swift`.

## Grid's own members

<table>
<thead><tr><th>Member</th><th>Kind</th><th>Value</th><th>Layer</th><th>AppKit</th><th>UIKit</th><th>Android Views</th><th>WinUI 3</th><th>GTK 4</th><th>Web</th></tr></thead>
<tbody><tr></tr><tr><td><code>columnSpacing</code></td><td>property</td><td><code>Double</code></td><td>stateUI</td><td align="center">✅</td><td align="center">✅</td><td align="center">✅</td><td align="center">✅</td><td align="center">✅</td><td align="center">✅</td></tr></tbody>
<tbody><tr></tr><tr><td><code>columns</code></td><td>property</td><td><code>[GridLength]</code></td><td>stateUI</td><td align="center">✅</td><td align="center">✅</td><td align="center">✅</td><td align="center">✅</td><td align="center">✅</td><td align="center">✅</td></tr></tbody>
<tbody><tr></tr><tr><td><code>rowSpacing</code></td><td>property</td><td><code>Double</code></td><td>stateUI</td><td align="center">✅</td><td align="center">✅</td><td align="center">✅</td><td align="center">✅</td><td align="center">✅</td><td align="center">✅</td></tr></tbody>
<tbody><tr></tr><tr><td><code>rows</code></td><td>property</td><td><code>[GridLength]</code></td><td>stateUI</td><td align="center">✅</td><td align="center">✅</td><td align="center">✅</td><td align="center">✅</td><td align="center">✅</td><td align="center">✅</td></tr></tbody>
</table>

## From [PropertyContainer](tiers/PropertyContainer.md)

What anything carrying values in the tree has - a control, a `Style`, a text run: the name automation finds it by.

<table>
<thead><tr><th>Member</th><th>Kind</th><th>Value</th><th>Layer</th><th>AppKit</th><th>UIKit</th><th>Android Views</th><th>WinUI 3</th><th>GTK 4</th><th>Web</th></tr></thead>
<tbody><tr></tr><tr><td rowspan="2"><code>accessibilityIdentifier</code></td><td>property</td><td><code>String</code></td><td>native</td><td align="center">✅</td><td align="center">✅</td><td align="center">✅</td><td align="center">✅</td><td align="center">–</td><td align="center">✅</td></tr>
<tr><td colspan="9">GTK 4: GTK 4 gives an accessible the identifier a GtkBuilder file names alone: none is set on a widget made in code.</td></tr></tbody>
</table>

## From [VisualElement](tiers/VisualElement.md)

What every drawn element has: its size and its bounds, how it is shown and turned, whether it answers input and holds the keyboard focus, the visual states it enters, and what a screen reader says about it.

<table>
<thead><tr><th>Member</th><th>Kind</th><th>Value</th><th>Layer</th><th>AppKit</th><th>UIKit</th><th>Android Views</th><th>WinUI 3</th><th>GTK 4</th><th>Web</th></tr></thead>
<tbody><tr></tr><tr><td rowspan="2"><code>accessibilityHeading</code></td><td>property</td><td><code>AccessibilityHeadingLevel</code></td><td>native</td><td align="center">·</td><td align="center">·</td><td align="center">·</td><td align="center">✅</td><td align="center">✅</td><td align="center">✅</td></tr>
<tr><td colspan="9">AppKit: cannot read a heading's level - AppKit marks a heading, not its level<br>UIKit: cannot read a heading's level - UIKit marks a heading, not its level<br>Android Views: cannot read a heading's level - Android marks a heading, not its level</td></tr></tbody>
<tbody><tr></tr><tr><td><code>accessibilityHint</code></td><td>property</td><td><code>String</code></td><td>native</td><td align="center">✅</td><td align="center">✅</td><td align="center">✅</td><td align="center">✅</td><td align="center">✅</td><td align="center">✅</td></tr></tbody>
<tbody><tr></tr><tr><td><code>accessibilityLabel</code></td><td>property</td><td><code>String</code></td><td>native</td><td align="center">✅</td><td align="center">✅</td><td align="center">✅</td><td align="center">✅</td><td align="center">✅</td><td align="center">✅</td></tr></tbody>
<tbody><tr></tr><tr><td><code>automationExcludedWithChildren</code></td><td>property</td><td><code>Bool</code></td><td>native</td><td align="center">✅</td><td align="center">✅</td><td align="center">✅</td><td align="center">✅</td><td align="center">✅</td><td align="center">✅</td></tr></tbody>
<tbody><tr></tr><tr><td rowspan="2"><code>background</code></td><td>property</td><td><code>Background</code></td><td>native</td><td align="center">✅</td><td align="center">✅</td><td align="center">✅</td><td align="center">✅</td><td align="center">·</td><td align="center">✅</td></tr>
<tr><td colspan="9">GTK 4: cannot read background of Grid - StateUI draws a layout's box on GTK's snapshot, which holds none of its background; its drawing proves it</td></tr></tbody>
<tbody><tr></tr><tr><td rowspan="2"><code>focus</code></td><td>act</td><td><code>() -&gt; Bool</code></td><td></td><td align="center">–</td><td align="center">–</td><td align="center">–</td><td align="center">–</td><td align="center">–</td><td align="center">⏸</td></tr>
<tr><td colspan="9">AppKit, UIKit, Android Views, WinUI 3, GTK 4: Grid takes no keyboard focus here: it refuses it, and nothing is heard<br>Web: waits on Grid.isFocusedChanged, not realized yet</td></tr></tbody>
<tbody><tr></tr><tr><td><code>frame</code></td><td>property</td><td><code>Rect</code></td><td>structure</td><td align="center">✅</td><td align="center">✅</td><td align="center">✅</td><td align="center">✅</td><td align="center">✅</td><td align="center">✅</td></tr></tbody>
<tbody><tr></tr><tr><td><code>height</code></td><td>property</td><td><code>Double</code></td><td>native</td><td align="center">✅</td><td align="center">✅</td><td align="center">✅</td><td align="center">✅</td><td align="center">✅</td><td align="center">✅</td></tr></tbody>
<tbody><tr></tr><tr><td rowspan="2"><code>ignoresInput</code></td><td>property</td><td><code>Bool</code></td><td>native</td><td align="center">✅</td><td align="center">✅</td><td align="center">·</td><td align="center">✅</td><td align="center">✅</td><td align="center">✅</td></tr>
<tr><td colspan="9">Android Views: cannot read what reaches Grid - Android's driver has no path for it yet</td></tr></tbody>
<tbody><tr></tr><tr><td><code>isAccessibilityHidden</code></td><td>property</td><td><code>Bool</code></td><td>native</td><td align="center">✅</td><td align="center">✅</td><td align="center">✅</td><td align="center">✅</td><td align="center">✅</td><td align="center">✅</td></tr></tbody>
<tbody><tr></tr><tr><td rowspan="2"><code>isEnabled</code></td><td>property</td><td><code>Bool</code></td><td>native</td><td align="center"></td><td align="center"></td><td align="center"></td><td align="center"></td><td align="center">✅</td><td align="center">✅</td></tr>
<tr><td colspan="9">AppKit, UIKit, Android Views, WinUI 3: not realized</td></tr></tbody>
<tbody><tr></tr><tr><td rowspan="2"><code>isFocusedChanged</code></td><td>event</td><td><code>Bool</code></td><td>native</td><td align="center">–</td><td align="center">–</td><td align="center">–</td><td align="center">–</td><td align="center">–</td><td align="center"></td></tr>
<tr><td colspan="9">AppKit, UIKit, Android Views, WinUI 3, GTK 4: Grid takes no keyboard focus here: it refuses it, and nothing is heard<br>Web: not realized</td></tr></tbody>
<tbody><tr></tr><tr><td><code>isVisible</code></td><td>property</td><td><code>Bool</code></td><td>native</td><td align="center">✅</td><td align="center">✅</td><td align="center">✅</td><td align="center">✅</td><td align="center">✅</td><td align="center">✅</td></tr></tbody>
<tbody><tr></tr><tr><td rowspan="2"><code>layoutDirection</code></td><td>property</td><td><code>LayoutDirection</code></td><td>native</td><td align="center">✅</td><td align="center">✅</td><td align="center">✅</td><td align="center">✓</td><td align="center">✅</td><td align="center">✅</td></tr>
<tr><td colspan="9">WinUI 3: only through the host's own: read layoutDirection of Grid: the direction the host lays it out in: in WinUI it stands left to right, where a layout told right to left would mirror its places again and a drawing would be turned</td></tr></tbody>
<tbody><tr></tr><tr><td><code>maximumHeight</code></td><td>property</td><td><code>Double</code></td><td>native</td><td align="center">✅</td><td align="center">✅</td><td align="center">✅</td><td align="center">✅</td><td align="center">✅</td><td align="center">✅</td></tr></tbody>
<tbody><tr></tr><tr><td><code>maximumWidth</code></td><td>property</td><td><code>Double</code></td><td>native</td><td align="center">✅</td><td align="center">✅</td><td align="center">✅</td><td align="center">✅</td><td align="center">✅</td><td align="center">✅</td></tr></tbody>
<tbody><tr></tr><tr><td><code>minimumHeight</code></td><td>property</td><td><code>Double</code></td><td>native</td><td align="center">✅</td><td align="center">✅</td><td align="center">✅</td><td align="center">✅</td><td align="center">✅</td><td align="center">✅</td></tr></tbody>
<tbody><tr></tr><tr><td><code>minimumWidth</code></td><td>property</td><td><code>Double</code></td><td>native</td><td align="center">✅</td><td align="center">✅</td><td align="center">✅</td><td align="center">✅</td><td align="center">✅</td><td align="center">✅</td></tr></tbody>
<tbody><tr></tr><tr><td><code>opacity</code></td><td>property</td><td><code>Double</code></td><td>native</td><td align="center">✅</td><td align="center">✅</td><td align="center">✅</td><td align="center">✅</td><td align="center">✅</td><td align="center">✅</td></tr></tbody>
<tbody><tr></tr><tr><td rowspan="2"><code>pivotX</code></td><td>property</td><td><code>Double</code></td><td>native</td><td align="center">✓</td><td align="center">✓</td><td align="center">✅</td><td align="center">✅</td><td align="center">✓</td><td align="center">✓</td></tr>
<tr><td colspan="9">AppKit, UIKit: only through the host's own: read pivotX of Grid: the host's own transform, checked against the layer it composed itself<br>GTK 4: only through the host's own: read pivotX of Grid: the host's own transform: GTK reads back no part of one<br>Web: only through the host's own: read pivotX of Grid: the host's own transform: the page holds one matrix of it, its parts no longer told apart</td></tr></tbody>
<tbody><tr></tr><tr><td rowspan="2"><code>pivotY</code></td><td>property</td><td><code>Double</code></td><td>native</td><td align="center">✓</td><td align="center">✓</td><td align="center">✅</td><td align="center">✅</td><td align="center">✓</td><td align="center">✓</td></tr>
<tr><td colspan="9">AppKit, UIKit: only through the host's own: read pivotY of Grid: the host's own transform, checked against the layer it composed itself<br>GTK 4: only through the host's own: read pivotY of Grid: the host's own transform: GTK reads back no part of one<br>Web: only through the host's own: read pivotY of Grid: the host's own transform: the page holds one matrix of it, its parts no longer told apart</td></tr></tbody>
<tbody><tr></tr><tr><td rowspan="2"><code>rotation</code></td><td>property</td><td><code>Double</code></td><td>native</td><td align="center">✓</td><td align="center">✓</td><td align="center">✅</td><td align="center">✅</td><td align="center">✓</td><td align="center">✓</td></tr>
<tr><td colspan="9">AppKit, UIKit: only through the host's own: read rotation of Grid: the host's own transform, checked against the layer it composed itself<br>GTK 4: only through the host's own: read rotation of Grid: the host's own transform: GTK reads back no part of one<br>Web: only through the host's own: read rotation of Grid: the host's own transform: the page holds one matrix of it, its parts no longer told apart</td></tr></tbody>
<tbody><tr></tr><tr><td rowspan="2"><code>rotationX</code></td><td>property</td><td><code>Double</code></td><td>native</td><td align="center">✓</td><td align="center">✓</td><td align="center">✅</td><td align="center">✓</td><td align="center">✓</td><td align="center">✓</td></tr>
<tr><td colspan="9">AppKit, UIKit: only through the host's own: read rotationX of Grid: the host's own transform, checked against the layer it composed itself<br>WinUI 3: only through the host's own: read rotationX of Grid: the host's own tip, checked against the projection it laid on the element<br>GTK 4: only through the host's own: read rotationX of Grid: the host's own transform: GTK reads back no part of one<br>Web: only through the host's own: read rotationX of Grid: the host's own transform: the page holds one matrix of it, its parts no longer told apart</td></tr></tbody>
<tbody><tr></tr><tr><td rowspan="2"><code>rotationY</code></td><td>property</td><td><code>Double</code></td><td>native</td><td align="center">✓</td><td align="center">✓</td><td align="center">✅</td><td align="center">✓</td><td align="center">✓</td><td align="center">✓</td></tr>
<tr><td colspan="9">AppKit, UIKit: only through the host's own: read rotationY of Grid: the host's own transform, checked against the layer it composed itself<br>WinUI 3: only through the host's own: read rotationY of Grid: the host's own tip, checked against the projection it laid on the element<br>GTK 4: only through the host's own: read rotationY of Grid: the host's own transform: GTK reads back no part of one<br>Web: only through the host's own: read rotationY of Grid: the host's own transform: the page holds one matrix of it, its parts no longer told apart</td></tr></tbody>
<tbody><tr></tr><tr><td rowspan="2"><code>scale</code></td><td>property</td><td><code>Double</code></td><td>native</td><td align="center">✓</td><td align="center">✓</td><td align="center">✅</td><td align="center">✅</td><td align="center">✓</td><td align="center">✓</td></tr>
<tr><td colspan="9">AppKit, UIKit: only through the host's own: read scale of Grid: the host's own transform, checked against the layer it composed itself<br>GTK 4: only through the host's own: read scale of Grid: the host's own transform: GTK reads back no part of one<br>Web: only through the host's own: read scale of Grid: the host's own transform: the page holds one matrix of it, its parts no longer told apart</td></tr></tbody>
<tbody><tr></tr><tr><td rowspan="2"><code>scaleX</code></td><td>property</td><td><code>Double</code></td><td>native</td><td align="center">✓</td><td align="center">✓</td><td align="center">✅</td><td align="center">✅</td><td align="center">✓</td><td align="center">✓</td></tr>
<tr><td colspan="9">AppKit, UIKit: only through the host's own: read scaleX of Grid: the host's own transform, checked against the layer it composed itself<br>GTK 4: only through the host's own: read scaleX of Grid: the host's own transform: GTK reads back no part of one<br>Web: only through the host's own: read scaleX of Grid: the host's own transform: the page holds one matrix of it, its parts no longer told apart</td></tr></tbody>
<tbody><tr></tr><tr><td rowspan="2"><code>scaleY</code></td><td>property</td><td><code>Double</code></td><td>native</td><td align="center">✓</td><td align="center">✓</td><td align="center">✅</td><td align="center">✅</td><td align="center">✓</td><td align="center">✓</td></tr>
<tr><td colspan="9">AppKit, UIKit: only through the host's own: read scaleY of Grid: the host's own transform, checked against the layer it composed itself<br>GTK 4: only through the host's own: read scaleY of Grid: the host's own transform: GTK reads back no part of one<br>Web: only through the host's own: read scaleY of Grid: the host's own transform: the page holds one matrix of it, its parts no longer told apart</td></tr></tbody>
<tbody><tr></tr><tr><td><code>style</code></td><td>property</td><td><code>Name</code></td><td>structure</td><td align="center">✅</td><td align="center">✅</td><td align="center">✅</td><td align="center">✅</td><td align="center">✅</td><td align="center">✅</td></tr></tbody>
<tbody><tr></tr><tr><td rowspan="2"><code>translationX</code></td><td>property</td><td><code>Double</code></td><td>native</td><td align="center">✓</td><td align="center">✓</td><td align="center">✅</td><td align="center">✅</td><td align="center">✓</td><td align="center">✓</td></tr>
<tr><td colspan="9">AppKit, UIKit: only through the host's own: read translationX of Grid: the host's own transform, checked against the layer it composed itself<br>GTK 4: only through the host's own: read translationX of Grid: the host's own transform: GTK reads back no part of one<br>Web: only through the host's own: read translationX of Grid: the host's own transform: the page holds one matrix of it, its parts no longer told apart</td></tr></tbody>
<tbody><tr></tr><tr><td rowspan="2"><code>translationY</code></td><td>property</td><td><code>Double</code></td><td>native</td><td align="center">✓</td><td align="center">✓</td><td align="center">✅</td><td align="center">✅</td><td align="center">✓</td><td align="center">✓</td></tr>
<tr><td colspan="9">AppKit, UIKit: only through the host's own: read translationY of Grid: the host's own transform, checked against the layer it composed itself<br>GTK 4: only through the host's own: read translationY of Grid: the host's own transform: GTK reads back no part of one<br>Web: only through the host's own: read translationY of Grid: the host's own transform: the page holds one matrix of it, its parts no longer told apart</td></tr></tbody>
<tbody><tr></tr><tr><td rowspan="2"><code>unfocus</code></td><td>act</td><td><code>() -&gt; Void</code></td><td></td><td align="center">–</td><td align="center">–</td><td align="center">–</td><td align="center">–</td><td align="center">–</td><td align="center">⏸</td></tr>
<tr><td colspan="9">AppKit, UIKit, Android Views, WinUI 3, GTK 4: Grid takes no keyboard focus here: it refuses it, and nothing is heard<br>Web: waits on Grid.isFocusedChanged, not realized yet</td></tr></tbody>
<tbody><tr></tr><tr><td><code>width</code></td><td>property</td><td><code>Double</code></td><td>native</td><td align="center">✅</td><td align="center">✅</td><td align="center">✅</td><td align="center">✅</td><td align="center">✅</td><td align="center">✅</td></tr></tbody>
<tbody><tr></tr><tr><td rowspan="2"><code>zIndex</code></td><td>property</td><td><code>Int</code></td><td>native</td><td align="center"></td><td align="center"></td><td align="center"></td><td align="center"></td><td align="center"></td><td align="center"></td></tr>
<tr><td colspan="9">AppKit, UIKit, Android Views, WinUI 3, GTK 4, Web: not realized</td></tr></tbody>
</table>

## From [View](tiers/View.md)

What every view a layout positions has: where it sits in its layout, the space kept around it, and the gestures, drags and frame reports it answers.

<table>
<thead><tr><th>Member</th><th>Kind</th><th>Value</th><th>Layer</th><th>AppKit</th><th>UIKit</th><th>Android Views</th><th>WinUI 3</th><th>GTK 4</th><th>Web</th></tr></thead>
<tbody><tr></tr><tr><td rowspan="2"><code>allowsDrop</code></td><td>property</td><td><code>Bool</code></td><td>native</td><td align="center">✓</td><td align="center">✓</td><td align="center">✓</td><td align="center"></td><td align="center"></td><td align="center">✓</td></tr>
<tr><td colspan="9">AppKit: only through the host's own: dragAndDrop on ColorBox: the drag source and the window's drop routing told by the driver, no dragging session<br>UIKit: only through the host's own: dragAndDrop on ColorBox: the drag and drop interactions' handlers called, no drag session<br>Android Views: only through the host's own: dragAndDrop on ColorBox: the views' drag listeners' reports told by the driver, no drag started<br>WinUI 3, GTK 4: not realized<br>Web: only through the host's own: dragAndDrop on ColorBox: the DOM's drag events dispatched by the driver, no drag the browser began</td></tr></tbody>
<tbody><tr></tr><tr><td><code>area</code></td><td>property</td><td><code>Area</code></td><td>structure</td><td align="center">✅</td><td align="center">✅</td><td align="center">✅</td><td align="center">✅</td><td align="center">✅</td><td align="center">✅</td></tr></tbody>
<tbody><tr></tr><tr><td rowspan="2"><code>canDrag</code></td><td>property</td><td><code>Bool</code></td><td>native</td><td align="center">✓</td><td align="center">✓</td><td align="center">✓</td><td align="center"></td><td align="center"></td><td align="center">✓</td></tr>
<tr><td colspan="9">AppKit: only through the host's own: dragAndDrop on Grid: the drag source and the window's drop routing told by the driver, no dragging session<br>UIKit: only through the host's own: dragAndDrop on Grid: the drag and drop interactions' handlers called, no drag session<br>Android Views: only through the host's own: dragAndDrop on Grid: the views' drag listeners' reports told by the driver, no drag started<br>WinUI 3, GTK 4: not realized<br>Web: only through the host's own: dragAndDrop on Grid: the DOM's drag events dispatched by the driver, no drag the browser began</td></tr></tbody>
<tbody><tr></tr><tr><td rowspan="2"><code>onDragLeave</code> (<code>dragLeave</code>)</td><td>event</td><td></td><td>native</td><td align="center">✓</td><td align="center">✓</td><td align="center">✓</td><td align="center"></td><td align="center"></td><td align="center">✓</td></tr>
<tr><td colspan="9">AppKit: only through the host's own: dragAndDrop on ColorBox: the drag source and the window's drop routing told by the driver, no dragging session<br>UIKit: only through the host's own: dragAndDrop on ColorBox: the drag and drop interactions' handlers called, no drag session<br>Android Views: only through the host's own: dragAndDrop on ColorBox: the views' drag listeners' reports told by the driver, no drag started<br>WinUI 3, GTK 4: not realized<br>Web: only through the host's own: dragAndDrop on ColorBox: the DOM's drag events dispatched by the driver, no drag the browser began</td></tr></tbody>
<tbody><tr></tr><tr><td rowspan="2"><code>onDragOver</code> (<code>dragOver</code>)</td><td>event</td><td></td><td>native</td><td align="center">✓</td><td align="center">✓</td><td align="center">✓</td><td align="center"></td><td align="center"></td><td align="center">✓</td></tr>
<tr><td colspan="9">AppKit: only through the host's own: dragAndDrop on ColorBox: the drag source and the window's drop routing told by the driver, no dragging session<br>UIKit: only through the host's own: dragAndDrop on ColorBox: the drag and drop interactions' handlers called, no drag session<br>Android Views: only through the host's own: dragAndDrop on ColorBox: the views' drag listeners' reports told by the driver, no drag started<br>WinUI 3, GTK 4: not realized<br>Web: only through the host's own: dragAndDrop on ColorBox: the DOM's drag events dispatched by the driver, no drag the browser began</td></tr></tbody>
<tbody><tr></tr><tr><td rowspan="2"><code>dragStarting</code></td><td>event</td><td></td><td>native</td><td align="center">✓</td><td align="center">✓</td><td align="center">✓</td><td align="center"></td><td align="center"></td><td align="center">✓</td></tr>
<tr><td colspan="9">AppKit: only through the host's own: dragAndDrop on Grid: the drag source and the window's drop routing told by the driver, no dragging session<br>UIKit: only through the host's own: dragAndDrop on Grid: the drag and drop interactions' handlers called, no drag session<br>Android Views: only through the host's own: dragAndDrop on Grid: the views' drag listeners' reports told by the driver, no drag started<br>WinUI 3, GTK 4: not realized<br>Web: only through the host's own: dragAndDrop on Grid: the DOM's drag events dispatched by the driver, no drag the browser began</td></tr></tbody>
<tbody><tr></tr><tr><td rowspan="2"><code>dragText</code></td><td>property</td><td><code>String</code></td><td>native</td><td align="center">✓</td><td align="center">✓</td><td align="center">✓</td><td align="center"></td><td align="center"></td><td align="center">✓</td></tr>
<tr><td colspan="9">AppKit: only through the host's own: dragAndDrop on Grid: the drag source and the window's drop routing told by the driver, no dragging session<br>UIKit: only through the host's own: dragAndDrop on Grid: the drag and drop interactions' handlers called, no drag session<br>Android Views: only through the host's own: dragAndDrop on Grid: the views' drag listeners' reports told by the driver, no drag started<br>WinUI 3, GTK 4: not realized<br>Web: only through the host's own: dragAndDrop on Grid: the DOM's drag events dispatched by the driver, no drag the browser began</td></tr></tbody>
<tbody><tr></tr><tr><td rowspan="2"><code>onDrop</code> (<code>drop</code>)</td><td>event</td><td><code>String</code></td><td>native</td><td align="center">✓</td><td align="center">✓</td><td align="center">✓</td><td align="center"></td><td align="center"></td><td align="center">✓</td></tr>
<tr><td colspan="9">AppKit: only through the host's own: dragAndDrop on ColorBox: the drag source and the window's drop routing told by the driver, no dragging session<br>UIKit: only through the host's own: dragAndDrop on ColorBox: the drag and drop interactions' handlers called, no drag session<br>Android Views: only through the host's own: dragAndDrop on ColorBox: the views' drag listeners' reports told by the driver, no drag started<br>WinUI 3, GTK 4: not realized<br>Web: only through the host's own: dragAndDrop on ColorBox: the DOM's drag events dispatched by the driver, no drag the browser began</td></tr></tbody>
<tbody><tr></tr><tr><td rowspan="2"><code>onDragEnded</code> (<code>dragEnded</code>)</td><td>event</td><td></td><td>native</td><td align="center">✓</td><td align="center">✓</td><td align="center">✓</td><td align="center"></td><td align="center"></td><td align="center">✓</td></tr>
<tr><td colspan="9">AppKit: only through the host's own: dragAndDrop on Grid: the drag source and the window's drop routing told by the driver, no dragging session<br>UIKit: only through the host's own: dragAndDrop on Grid: the drag and drop interactions' handlers called, no drag session<br>Android Views: only through the host's own: dragAndDrop on Grid: the views' drag listeners' reports told by the driver, no drag started<br>WinUI 3, GTK 4: not realized<br>Web: only through the host's own: dragAndDrop on Grid: the DOM's drag events dispatched by the driver, no drag the browser began</td></tr></tbody>
<tbody><tr></tr><tr><td><code>onFrameChanged</code> (<code>frameChanged</code>)</td><td>event</td><td><code>[Double]</code></td><td>native</td><td align="center">✅</td><td align="center">✅</td><td align="center">✅</td><td align="center">✅</td><td align="center">✅</td><td align="center">✅</td></tr></tbody>
<tbody><tr></tr><tr><td><code>gridColumn</code></td><td>property</td><td><code>Int</code></td><td>stateUI</td><td align="center">✅</td><td align="center">✅</td><td align="center">✅</td><td align="center">✅</td><td align="center">✅</td><td align="center">✅</td></tr></tbody>
<tbody><tr></tr><tr><td><code>gridColumnSpan</code></td><td>property</td><td><code>Int</code></td><td>stateUI</td><td align="center">✅</td><td align="center">✅</td><td align="center">✅</td><td align="center">✅</td><td align="center">✅</td><td align="center">✅</td></tr></tbody>
<tbody><tr></tr><tr><td><code>gridRow</code></td><td>property</td><td><code>Int</code></td><td>stateUI</td><td align="center">✅</td><td align="center">✅</td><td align="center">✅</td><td align="center">✅</td><td align="center">✅</td><td align="center">✅</td></tr></tbody>
<tbody><tr></tr><tr><td><code>gridRowSpan</code></td><td>property</td><td><code>Int</code></td><td>stateUI</td><td align="center">✅</td><td align="center">✅</td><td align="center">✅</td><td align="center">✅</td><td align="center">✅</td><td align="center">✅</td></tr></tbody>
<tbody><tr></tr><tr><td><code>horizontalAlignment</code></td><td>property</td><td><code>Alignment</code></td><td>native</td><td align="center">✅</td><td align="center">✅</td><td align="center">✅</td><td align="center">✅</td><td align="center">✅</td><td align="center">✅</td></tr></tbody>
<tbody><tr></tr><tr><td><code>margin</code></td><td>property</td><td><code>Insets</code></td><td>native</td><td align="center">✅</td><td align="center">✅</td><td align="center">✅</td><td align="center">✅</td><td align="center">✅</td><td align="center">✅</td></tr></tbody>
<tbody><tr></tr><tr><td rowspan="2"><code>panTouchCount</code></td><td>property</td><td><code>Int</code></td><td>structure</td><td align="center">✓</td><td align="center">✓</td><td align="center">☑️</td><td align="center">✅</td><td align="center">✅</td><td align="center">✅</td></tr>
<tr><td colspan="9">AppKit: only through the host's own: pan on Grid: handed to the host's recognizer or handler, no NSEvent sent<br>UIKit: only through the host's own: pan on Grid: the view's listening handed the recognizer's states, no touch sent<br>Android Views: The host layer hears a one-finger pan only; any other <code>panTouchCount</code> turns the pan off.</td></tr></tbody>
<tbody><tr></tr><tr><td rowspan="2"><code>onPanUpdated</code> (<code>panUpdated</code>)</td><td>event</td><td><code>(GesturePhase, Double, Double)</code></td><td>native</td><td align="center">✓</td><td align="center">✓</td><td align="center">✅</td><td align="center">✅</td><td align="center">✅</td><td align="center">✅</td></tr>
<tr><td colspan="9">AppKit: only through the host's own: pan on Grid: handed to the host's recognizer or handler, no NSEvent sent<br>UIKit: only through the host's own: pan on Grid: the view's listening handed the recognizer's states, no touch sent</td></tr></tbody>
<tbody><tr></tr><tr><td rowspan="2"><code>panXChannel</code></td><td>property</td><td><code>Int</code></td><td>structure</td><td align="center">✓</td><td align="center">✓</td><td align="center">✅</td><td align="center">✅</td><td align="center">✅</td><td align="center">✅</td></tr>
<tr><td colspan="9">AppKit: only through the host's own: pan on Grid: handed to the host's recognizer or handler, no NSEvent sent<br>UIKit: only through the host's own: pan on Grid: the view's listening handed the recognizer's states, no touch sent</td></tr></tbody>
<tbody><tr></tr><tr><td rowspan="2"><code>panYChannel</code></td><td>property</td><td><code>Int</code></td><td>structure</td><td align="center">✓</td><td align="center">✓</td><td align="center">✅</td><td align="center">✅</td><td align="center">✅</td><td align="center">✅</td></tr>
<tr><td colspan="9">AppKit: only through the host's own: pan on Grid: handed to the host's recognizer or handler, no NSEvent sent<br>UIKit: only through the host's own: pan on Grid: the view's listening handed the recognizer's states, no touch sent</td></tr></tbody>
<tbody><tr></tr><tr><td rowspan="2"><code>onPinchUpdated</code> (<code>pinchUpdated</code>)</td><td>event</td><td><code>(GesturePhase, Double, Point)</code></td><td>native</td><td align="center">✓</td><td align="center">✓</td><td align="center">✅</td><td align="center">✅</td><td align="center">✓</td><td align="center">✅</td></tr>
<tr><td colspan="9">AppKit: only through the host's own: pinch on Grid: handed to the host's recognizer or handler, no NSEvent sent<br>UIKit: only through the host's own: pinch on Grid: the view's listening handed the recognizer's states, no touch sent<br>GTK 4: only through the host's own: pinch on Grid: the fingers' place handed to the host's recognizer as GTK's zoom would: GTK takes no touch a driver puts down</td></tr></tbody>
<tbody><tr></tr><tr><td rowspan="2"><code>onPointerEntered</code> (<code>pointerEntered</code>)</td><td>event</td><td></td><td>native</td><td align="center">✓</td><td align="center">✓</td><td align="center">✅</td><td align="center">✅</td><td align="center">✅</td><td align="center">✅</td></tr>
<tr><td colspan="9">AppKit: only through the host's own: hover on Grid: handed to the host's recognizer or handler, no NSEvent sent<br>UIKit: only through the host's own: hover on Grid: the view's listening handed the recognizer's states, no touch sent</td></tr></tbody>
<tbody><tr></tr><tr><td rowspan="2"><code>onPointerExited</code> (<code>pointerExited</code>)</td><td>event</td><td></td><td>native</td><td align="center">✓</td><td align="center">✓</td><td align="center">✅</td><td align="center">✅</td><td align="center">✅</td><td align="center">✅</td></tr>
<tr><td colspan="9">AppKit: only through the host's own: hover on Grid: handed to the host's recognizer or handler, no NSEvent sent<br>UIKit: only through the host's own: hover on Grid: the view's listening handed the recognizer's states, no touch sent</td></tr></tbody>
<tbody><tr></tr><tr><td rowspan="2"><code>onPointerMoved</code> (<code>pointerMoved</code>)</td><td>event</td><td><code>Point?</code></td><td>native</td><td align="center">✓</td><td align="center">✓</td><td align="center">✅</td><td align="center">✅</td><td align="center">✅</td><td align="center">✅</td></tr>
<tr><td colspan="9">AppKit: only through the host's own: hover on Grid: handed to the host's recognizer or handler, no NSEvent sent<br>UIKit: only through the host's own: hover on Grid: the view's listening handed the recognizer's states, no touch sent</td></tr></tbody>
<tbody><tr></tr><tr><td rowspan="2"><code>onPointerPressed</code> (<code>pointerPressed</code>)</td><td>event</td><td><code>Point?</code></td><td>native</td><td align="center">✓</td><td align="center">✓</td><td align="center">✅</td><td align="center">✅</td><td align="center">✅</td><td align="center">✅</td></tr>
<tr><td colspan="9">AppKit: only through the host's own: hover on Grid: handed to the host's recognizer or handler, no NSEvent sent<br>UIKit: only through the host's own: hover on Grid: the view's listening handed the recognizer's states, no touch sent</td></tr></tbody>
<tbody><tr></tr><tr><td rowspan="2"><code>onPointerReleased</code> (<code>pointerReleased</code>)</td><td>event</td><td><code>Point?</code></td><td>native</td><td align="center">✓</td><td align="center">✓</td><td align="center">✅</td><td align="center">✅</td><td align="center">✅</td><td align="center">✅</td></tr>
<tr><td colspan="9">AppKit: only through the host's own: hover on Grid: handed to the host's recognizer or handler, no NSEvent sent<br>UIKit: only through the host's own: hover on Grid: the view's listening handed the recognizer's states, no touch sent</td></tr></tbody>
<tbody><tr></tr><tr><td rowspan="2"><code>swipeDirection</code></td><td>property</td><td><code>SwipeDirection</code></td><td>structure</td><td align="center">✓</td><td align="center">✓</td><td align="center">✅</td><td align="center">✅</td><td align="center">✅</td><td align="center">✅</td></tr>
<tr><td colspan="9">AppKit: only through the host's own: pan on Grid: handed to the host's recognizer or handler, no NSEvent sent<br>UIKit: only through the host's own: pan on Grid: the view's listening handed the recognizer's states, no touch sent</td></tr></tbody>
<tbody><tr></tr><tr><td rowspan="2"><code>swipeThreshold</code></td><td>property</td><td><code>Double</code></td><td>structure</td><td align="center">✓</td><td align="center">✓</td><td align="center">✅</td><td align="center">✅</td><td align="center">✅</td><td align="center">✅</td></tr>
<tr><td colspan="9">AppKit: only through the host's own: pan on Grid: handed to the host's recognizer or handler, no NSEvent sent<br>UIKit: only through the host's own: pan on Grid: the view's listening handed the recognizer's states, no touch sent</td></tr></tbody>
<tbody><tr></tr><tr><td rowspan="2"><code>onSwiped</code> (<code>swiped</code>)</td><td>event</td><td><code>SwipeDirection</code></td><td>native</td><td align="center">✓</td><td align="center">✓</td><td align="center">✅</td><td align="center">✅</td><td align="center">✅</td><td align="center">✅</td></tr>
<tr><td colspan="9">AppKit: only through the host's own: pan on Grid: handed to the host's recognizer or handler, no NSEvent sent<br>UIKit: only through the host's own: pan on Grid: the view's listening handed the recognizer's states, no touch sent</td></tr></tbody>
<tbody><tr></tr><tr><td rowspan="2"><code>tapCount</code></td><td>property</td><td><code>Int</code></td><td>structure</td><td align="center">✓</td><td align="center">✓</td><td align="center">✅</td><td align="center">✅</td><td align="center">✅</td><td align="center">✅</td></tr>
<tr><td colspan="9">AppKit: only through the host's own: tap on Grid: handed to the host's recognizer or handler, no NSEvent sent<br>UIKit: only through the host's own: tap on Grid: the view's listening handed the recognizer's states, no touch sent</td></tr></tbody>
<tbody><tr></tr><tr><td rowspan="2"><code>onTapped</code> (<code>tapped</code>)</td><td>event</td><td></td><td>native</td><td align="center">✓</td><td align="center">✓</td><td align="center">✅</td><td align="center">✅</td><td align="center">✅</td><td align="center">✅</td></tr>
<tr><td colspan="9">AppKit: only through the host's own: tap on Grid: handed to the host's recognizer or handler, no NSEvent sent<br>UIKit: only through the host's own: tap on Grid: the view's listening handed the recognizer's states, no touch sent</td></tr></tbody>
<tbody><tr></tr><tr><td><code>verticalAlignment</code></td><td>property</td><td><code>Alignment</code></td><td>native</td><td align="center">✅</td><td align="center">✅</td><td align="center">✅</td><td align="center">✅</td><td align="center">✅</td><td align="center">✅</td></tr></tbody>
</table>

## From [Layout](tiers/Layout.md)

What every layout has: the screen's unsafe strips it keeps clear of, and whether its children are clipped or let input through.

<table>
<thead><tr><th>Member</th><th>Kind</th><th>Value</th><th>Layer</th><th>AppKit</th><th>UIKit</th><th>Android Views</th><th>WinUI 3</th><th>GTK 4</th><th>Web</th></tr></thead>
<tbody><tr></tr><tr><td rowspan="2"><code>avoidsSafeArea</code></td><td>property</td><td><code>SafeAreaEdges</code></td><td>adaptive</td><td align="center"></td><td align="center">·</td><td align="center"></td><td align="center"></td><td align="center"></td><td align="center"></td></tr>
<tr><td colspan="9">AppKit, Android Views, WinUI 3, GTK 4, Web: not realized<br>UIKit: cannot read avoidsSafeArea of Grid - UIKit's view places its children where StateUI's layout says; their frames prove it</td></tr></tbody>
<tbody><tr></tr><tr><td><code>clipsContent</code></td><td>property</td><td><code>Bool</code></td><td>native</td><td align="center">✅</td><td align="center">✅</td><td align="center">✅</td><td align="center">✅</td><td align="center">✅</td><td align="center">✅</td></tr></tbody>
<tbody><tr></tr><tr><td rowspan="2"><code>letsInputThrough</code></td><td>property</td><td><code>Bool</code></td><td>native</td><td align="center">◐</td><td align="center">◐</td><td align="center"></td><td align="center"></td><td align="center">✅</td><td align="center">✅</td></tr>
<tr><td colspan="9">AppKit: cannot read letsInputThrough of Grid - AppKit's driver has no path for it yet<br>UIKit: cannot read letsInputThrough of Grid - UIKit's driver has no path for it yet<br>Android Views, WinUI 3: not realized</td></tr></tbody>
</table>

## From [PaddingElement](tiers/PaddingElement.md)

The space kept inside an element, around what it holds.

<table>
<thead><tr><th>Member</th><th>Kind</th><th>Value</th><th>Layer</th><th>AppKit</th><th>UIKit</th><th>Android Views</th><th>WinUI 3</th><th>GTK 4</th><th>Web</th></tr></thead>
<tbody><tr></tr><tr><td><code>padding</code></td><td>property</td><td><code>Insets</code></td><td>native</td><td align="center">✅</td><td align="center">✅</td><td align="center">✅</td><td align="center">✅</td><td align="center">✅</td><td align="center">✅</td></tr></tbody>
</table>

## From [BorderElement](tiers/BorderElement.md)

What an element draws of its own box: the shape its background, its outline and its cut follow, and the outline.

<table>
<thead><tr><th>Member</th><th>Kind</th><th>Value</th><th>Layer</th><th>AppKit</th><th>UIKit</th><th>Android Views</th><th>WinUI 3</th><th>GTK 4</th><th>Web</th></tr></thead>
<tbody><tr></tr><tr><td rowspan="2"><code>shape</code></td><td>property</td><td><code>ContainerShape</code></td><td>stateUI</td><td align="center">·</td><td align="center">·</td><td align="center">·</td><td align="center">✅</td><td align="center">·</td><td align="center">✅</td></tr>
<tr><td colspan="9">AppKit: cannot read shape of Grid - StateUI draws a layout's box in its view's draw(_:), which holds none of its shape; its drawing proves it<br>UIKit: cannot read shape of Grid - UIKit holds a layout's outline as its layer's path, no shape; its drawing proves it<br>Android Views: cannot read shape of Grid - StateUI draws a layout's box in a drawable of its own, which holds none of its shape; its drawing proves it<br>GTK 4: cannot read shape of Grid - StateUI draws a layout's box on GTK's snapshot, which holds none of its shape; its drawing proves it</td></tr></tbody>
<tbody><tr></tr><tr><td rowspan="2"><code>stroke</code></td><td>property</td><td><code>Brush</code></td><td>stateUI</td><td align="center"></td><td align="center">✅</td><td align="center">·</td><td align="center">✅</td><td align="center">·</td><td align="center">✅</td></tr>
<tr><td colspan="9">AppKit: not realized<br>Android Views: cannot read stroke of Grid - StateUI draws a layout's box in a drawable of its own, which holds none of its stroke; its drawing proves it<br>GTK 4: cannot read stroke of Grid - StateUI draws a layout's box on GTK's snapshot, which holds none of its stroke; its drawing proves it</td></tr></tbody>
<tbody><tr></tr><tr><td rowspan="2"><code>lineWidth</code></td><td>property</td><td><code>Double</code></td><td>stateUI</td><td align="center">·</td><td align="center">✅</td><td align="center">·</td><td align="center">✅</td><td align="center">·</td><td align="center">✅</td></tr>
<tr><td colspan="9">AppKit: cannot read lineWidth of Grid - StateUI draws a layout's box in its view's draw(_:), which holds none of its lineWidth; its drawing proves it<br>Android Views: cannot read lineWidth of Grid - StateUI draws a layout's box in a drawable of its own, which holds none of its lineWidth; its drawing proves it<br>GTK 4: cannot read lineWidth of Grid - StateUI draws a layout's box on GTK's snapshot, which holds none of its lineWidth; its drawing proves it</td></tr></tbody>
</table>
