<!-- Rendered by ControlDictionaryTests from the contracts and the verdicts each host's runs of its tests wrote under lib/StateUI/exports/marks: STATEUI_UPDATE_DOCS=1 swift test --filter ControlDictionaryTests writes it again. -->

# Line

A straight line between two points, in device units from the top left of the space the line is given.

```swift
Line()
    .x1(0).y1(0)
    .x2(240).y2(0)
    .stroke(.lightGray)
    .strokeWidth(1)
```

Layer: `stateUI`. StateUI composes it from smaller primitives before a host receives the tree.

Inherits: [PropertyContainer](tiers/PropertyContainer.md) · [VisualElement](tiers/VisualElement.md) · [View](tiers/View.md) · [Shape](tiers/Shape.md)

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
<thead><tr><th>Host</th><th>Created</th><th>Members (80)</th><th>Realization</th></tr></thead>
<tbody><tr></tr><tr><td>AppKit</td><td align="center">✅</td><td>30 ✅ · 1 ☑️ · 25 ✓ · 3 –</td><td><code>NSView</code> drawing <code>NSBezierPath</code></td></tr></tbody>
<tbody><tr></tr><tr><td>UIKit</td><td align="center">✅</td><td>32 ✅ · 25 ✓ · 3 –</td><td><code>UIView</code> drawing <code>UIBezierPath</code></td></tr></tbody>
<tbody><tr></tr><tr><td>Android Views</td><td align="center">✅</td><td>54 ✅ · 1 ☑️ · 3 –</td><td><code>View</code> drawing <code>Path</code></td></tr></tbody>
<tbody><tr></tr><tr><td>WinUI 3</td><td align="center">✅</td><td>62 ✅ · 3 –</td><td><code>Microsoft.UI.Xaml.Shapes</code></td></tr></tbody>
<tbody><tr></tr><tr><td>GTK 4</td><td align="center">✅</td><td>48 ✅ · 11 ✓ · 4 –</td><td><code>GskPath</code> in a snapshot</td></tr></tbody>
<tbody><tr></tr><tr><td rowspan="2">Web</td><td align="center"></td><td></td><td>inline SVG</td></tr>
<tr><td colspan="3">no host yet</td></tr></tbody>
</table>

Declared in `lib/StateUI/Core/Sources/Contracts/Elements/Shapes/LineContract.swift`.

## Line's own members

<table>
<thead><tr><th>Member</th><th>Kind</th><th>Value</th><th>Layer</th><th>AppKit</th><th>UIKit</th><th>Android Views</th><th>WinUI 3</th><th>GTK 4</th><th>Web</th></tr></thead>
<tbody><tr></tr><tr><td><code>x1</code></td><td>property</td><td><code>Double</code></td><td>stateUI</td><td align="center">✅</td><td align="center">✅</td><td align="center">✅</td><td align="center">✅</td><td align="center">✅</td><td></td></tr></tbody>
<tbody><tr></tr><tr><td><code>x2</code></td><td>property</td><td><code>Double</code></td><td>stateUI</td><td align="center">✅</td><td align="center">✅</td><td align="center">✅</td><td align="center">✅</td><td align="center">✅</td><td></td></tr></tbody>
<tbody><tr></tr><tr><td><code>y1</code></td><td>property</td><td><code>Double</code></td><td>stateUI</td><td align="center">✅</td><td align="center">✅</td><td align="center">✅</td><td align="center">✅</td><td align="center">✅</td><td></td></tr></tbody>
<tbody><tr></tr><tr><td><code>y2</code></td><td>property</td><td><code>Double</code></td><td>stateUI</td><td align="center">✅</td><td align="center">✅</td><td align="center">✅</td><td align="center">✅</td><td align="center">✅</td><td></td></tr></tbody>
</table>

## From [PropertyContainer](tiers/PropertyContainer.md)

What anything carrying values in the tree has - a control, a `Style`, a text run: the name automation finds it by.

<table>
<thead><tr><th>Member</th><th>Kind</th><th>Value</th><th>Layer</th><th>AppKit</th><th>UIKit</th><th>Android Views</th><th>WinUI 3</th><th>GTK 4</th><th>Web</th></tr></thead>
<tbody><tr></tr><tr><td rowspan="2"><code>accessibilityIdentifier</code></td><td>property</td><td><code>String</code></td><td>native</td><td align="center">✅</td><td align="center">✅</td><td align="center">✅</td><td align="center">✅</td><td align="center">–</td><td></td></tr>
<tr><td colspan="9">GTK 4: GTK 4 gives an accessible the identifier a GtkBuilder file names alone: none is set on a widget made in code.</td></tr></tbody>
</table>

## From [VisualElement](tiers/VisualElement.md)

What every drawn element has: its size and its bounds, how it is shown and turned, whether it answers input and holds the keyboard focus, the visual states it enters, and what a screen reader says about it.

<table>
<thead><tr><th>Member</th><th>Kind</th><th>Value</th><th>Layer</th><th>AppKit</th><th>UIKit</th><th>Android Views</th><th>WinUI 3</th><th>GTK 4</th><th>Web</th></tr></thead>
<tbody><tr></tr><tr><td rowspan="2"><code>accessibilityHeadingLevel</code></td><td>property</td><td><code>HeadingLevel</code></td><td>native</td><td align="center">·</td><td align="center">·</td><td align="center">·</td><td align="center">✅</td><td align="center">✅</td><td></td></tr>
<tr><td colspan="9">AppKit: cannot read a heading's level - AppKit marks a heading, not its level<br>UIKit: cannot read a heading's level - UIKit marks a heading, not its level<br>Android Views: cannot read a heading's level - Android marks a heading, not its level</td></tr></tbody>
<tbody><tr></tr><tr><td><code>accessibilityHint</code></td><td>property</td><td><code>String</code></td><td>native</td><td align="center">✅</td><td align="center">✅</td><td align="center">✅</td><td align="center">✅</td><td align="center">✅</td><td></td></tr></tbody>
<tbody><tr></tr><tr><td><code>accessibilityLabel</code></td><td>property</td><td><code>String</code></td><td>native</td><td align="center">✅</td><td align="center">✅</td><td align="center">✅</td><td align="center">✅</td><td align="center">✅</td><td></td></tr></tbody>
<tbody><tr></tr><tr><td><code>automationExcludedWithChildren</code></td><td>property</td><td><code>Bool</code></td><td>native</td><td align="center">✅</td><td align="center">✅</td><td align="center">✅</td><td align="center">✅</td><td align="center">✅</td><td></td></tr></tbody>
<tbody><tr></tr><tr><td rowspan="2"><code>background</code></td><td>property</td><td><code>Background</code></td><td>native</td><td align="center">☑️</td><td align="center"></td><td align="center">✅</td><td align="center"></td><td align="center"></td><td></td></tr>
<tr><td colspan="9">AppKit: AppKit paints a colour on this view; a brush is drawn only by a layout.<br>UIKit, WinUI 3, GTK 4: not realized</td></tr></tbody>
<tbody><tr></tr><tr><td rowspan="2"><code>focus</code></td><td>act</td><td><code>() -&gt; Bool</code></td><td></td><td align="center">–</td><td align="center">–</td><td align="center">–</td><td align="center">–</td><td align="center">–</td><td></td></tr>
<tr><td colspan="9">AppKit, UIKit, Android Views, WinUI 3, GTK 4: Line takes no keyboard focus here: it refuses it, and nothing is heard</td></tr></tbody>
<tbody><tr></tr><tr><td><code>frame</code></td><td>property</td><td><code>Rect</code></td><td>structure</td><td align="center">✅</td><td align="center">✅</td><td align="center">✅</td><td align="center">✅</td><td align="center">✅</td><td></td></tr></tbody>
<tbody><tr></tr><tr><td><code>height</code></td><td>property</td><td><code>Double</code></td><td>native</td><td align="center">✅</td><td align="center">✅</td><td align="center">✅</td><td align="center">✅</td><td align="center">✅</td><td></td></tr></tbody>
<tbody><tr></tr><tr><td rowspan="2"><code>ignoresInput</code></td><td>property</td><td><code>Bool</code></td><td>native</td><td align="center">✅</td><td align="center">✅</td><td align="center"></td><td align="center"></td><td align="center"></td><td></td></tr>
<tr><td colspan="9">Android Views, WinUI 3, GTK 4: not realized</td></tr></tbody>
<tbody><tr></tr><tr><td><code>isAccessibilityHidden</code></td><td>property</td><td><code>Bool</code></td><td>native</td><td align="center">✅</td><td align="center">✅</td><td align="center">✅</td><td align="center">✅</td><td align="center">✅</td><td></td></tr></tbody>
<tbody><tr></tr><tr><td rowspan="2"><code>isEnabled</code></td><td>property</td><td><code>Bool</code></td><td>native</td><td align="center"></td><td align="center"></td><td align="center"></td><td align="center"></td><td align="center">✅</td><td></td></tr>
<tr><td colspan="9">AppKit, UIKit, Android Views, WinUI 3: not realized</td></tr></tbody>
<tbody><tr></tr><tr><td rowspan="2"><code>isFocusedChanged</code></td><td>event</td><td><code>Bool</code></td><td>native</td><td align="center">–</td><td align="center">–</td><td align="center">–</td><td align="center">–</td><td align="center">–</td><td></td></tr>
<tr><td colspan="9">AppKit, UIKit, Android Views, WinUI 3, GTK 4: Line takes no keyboard focus here: it refuses it, and nothing is heard</td></tr></tbody>
<tbody><tr></tr><tr><td><code>isVisible</code></td><td>property</td><td><code>Bool</code></td><td>native</td><td align="center">✅</td><td align="center">✅</td><td align="center">✅</td><td align="center">✅</td><td align="center">✅</td><td></td></tr></tbody>
<tbody><tr></tr><tr><td rowspan="2"><code>layoutDirection</code></td><td>property</td><td><code>LayoutDirection</code></td><td>native</td><td align="center">✅</td><td align="center">✅</td><td align="center">✅</td><td align="center"></td><td align="center"></td><td></td></tr>
<tr><td colspan="9">WinUI 3, GTK 4: not realized</td></tr></tbody>
<tbody><tr></tr><tr><td><code>maximumHeight</code></td><td>property</td><td><code>Double</code></td><td>native</td><td align="center">✅</td><td align="center">✅</td><td align="center">✅</td><td align="center">✅</td><td align="center">✅</td><td></td></tr></tbody>
<tbody><tr></tr><tr><td><code>maximumWidth</code></td><td>property</td><td><code>Double</code></td><td>native</td><td align="center">✅</td><td align="center">✅</td><td align="center">✅</td><td align="center">✅</td><td align="center">✅</td><td></td></tr></tbody>
<tbody><tr></tr><tr><td><code>minimumHeight</code></td><td>property</td><td><code>Double</code></td><td>native</td><td align="center">✅</td><td align="center">✅</td><td align="center">✅</td><td align="center">✅</td><td align="center">✅</td><td></td></tr></tbody>
<tbody><tr></tr><tr><td><code>minimumWidth</code></td><td>property</td><td><code>Double</code></td><td>native</td><td align="center">✅</td><td align="center">✅</td><td align="center">✅</td><td align="center">✅</td><td align="center">✅</td><td></td></tr></tbody>
<tbody><tr></tr><tr><td><code>opacity</code></td><td>property</td><td><code>Double</code></td><td>native</td><td align="center">✅</td><td align="center">✅</td><td align="center">✅</td><td align="center">✅</td><td align="center">✅</td><td></td></tr></tbody>
<tbody><tr></tr><tr><td rowspan="2"><code>pivotX</code></td><td>property</td><td><code>Double</code></td><td>native</td><td align="center">✓</td><td align="center">✓</td><td align="center">✅</td><td align="center">✅</td><td align="center">✓</td><td></td></tr>
<tr><td colspan="9">AppKit, UIKit: only through the host's own: read pivotX of Line: the host's own transform, checked against the layer it composed itself<br>GTK 4: only through the host's own: read pivotX of Line: the host's own transform: GTK reads back no part of one</td></tr></tbody>
<tbody><tr></tr><tr><td rowspan="2"><code>pivotY</code></td><td>property</td><td><code>Double</code></td><td>native</td><td align="center">✓</td><td align="center">✓</td><td align="center">✅</td><td align="center">✅</td><td align="center">✓</td><td></td></tr>
<tr><td colspan="9">AppKit, UIKit: only through the host's own: read pivotY of Line: the host's own transform, checked against the layer it composed itself<br>GTK 4: only through the host's own: read pivotY of Line: the host's own transform: GTK reads back no part of one</td></tr></tbody>
<tbody><tr></tr><tr><td rowspan="2"><code>rotation</code></td><td>property</td><td><code>Double</code></td><td>native</td><td align="center">✓</td><td align="center">✓</td><td align="center">✅</td><td align="center">✅</td><td align="center">✓</td><td></td></tr>
<tr><td colspan="9">AppKit, UIKit: only through the host's own: read rotation of Line: the host's own transform, checked against the layer it composed itself<br>GTK 4: only through the host's own: read rotation of Line: the host's own transform: GTK reads back no part of one</td></tr></tbody>
<tbody><tr></tr><tr><td rowspan="2"><code>rotationX</code></td><td>property</td><td><code>Double</code></td><td>native</td><td align="center">✓</td><td align="center">✓</td><td align="center">✅</td><td align="center"></td><td align="center">✓</td><td></td></tr>
<tr><td colspan="9">AppKit, UIKit: only through the host's own: read rotationX of Line: the host's own transform, checked against the layer it composed itself<br>WinUI 3: not realized<br>GTK 4: only through the host's own: read rotationX of Line: the host's own transform: GTK reads back no part of one</td></tr></tbody>
<tbody><tr></tr><tr><td rowspan="2"><code>rotationY</code></td><td>property</td><td><code>Double</code></td><td>native</td><td align="center">✓</td><td align="center">✓</td><td align="center">✅</td><td align="center"></td><td align="center">✓</td><td></td></tr>
<tr><td colspan="9">AppKit, UIKit: only through the host's own: read rotationY of Line: the host's own transform, checked against the layer it composed itself<br>WinUI 3: not realized<br>GTK 4: only through the host's own: read rotationY of Line: the host's own transform: GTK reads back no part of one</td></tr></tbody>
<tbody><tr></tr><tr><td rowspan="2"><code>scale</code></td><td>property</td><td><code>Double</code></td><td>native</td><td align="center">✓</td><td align="center">✓</td><td align="center">✅</td><td align="center">✅</td><td align="center">✓</td><td></td></tr>
<tr><td colspan="9">AppKit, UIKit: only through the host's own: read scale of Line: the host's own transform, checked against the layer it composed itself<br>GTK 4: only through the host's own: read scale of Line: the host's own transform: GTK reads back no part of one</td></tr></tbody>
<tbody><tr></tr><tr><td rowspan="2"><code>scaleX</code></td><td>property</td><td><code>Double</code></td><td>native</td><td align="center">✓</td><td align="center">✓</td><td align="center">✅</td><td align="center">✅</td><td align="center">✓</td><td></td></tr>
<tr><td colspan="9">AppKit, UIKit: only through the host's own: read scaleX of Line: the host's own transform, checked against the layer it composed itself<br>GTK 4: only through the host's own: read scaleX of Line: the host's own transform: GTK reads back no part of one</td></tr></tbody>
<tbody><tr></tr><tr><td rowspan="2"><code>scaleY</code></td><td>property</td><td><code>Double</code></td><td>native</td><td align="center">✓</td><td align="center">✓</td><td align="center">✅</td><td align="center">✅</td><td align="center">✓</td><td></td></tr>
<tr><td colspan="9">AppKit, UIKit: only through the host's own: read scaleY of Line: the host's own transform, checked against the layer it composed itself<br>GTK 4: only through the host's own: read scaleY of Line: the host's own transform: GTK reads back no part of one</td></tr></tbody>
<tbody><tr></tr><tr><td><code>style</code></td><td>property</td><td><code>Name</code></td><td>structure</td><td align="center">✅</td><td align="center">✅</td><td align="center">✅</td><td align="center">✅</td><td align="center">✅</td><td></td></tr></tbody>
<tbody><tr></tr><tr><td rowspan="2"><code>translationX</code></td><td>property</td><td><code>Double</code></td><td>native</td><td align="center">✓</td><td align="center">✓</td><td align="center">✅</td><td align="center">✅</td><td align="center">✓</td><td></td></tr>
<tr><td colspan="9">AppKit, UIKit: only through the host's own: read translationX of Line: the host's own transform, checked against the layer it composed itself<br>GTK 4: only through the host's own: read translationX of Line: the host's own transform: GTK reads back no part of one</td></tr></tbody>
<tbody><tr></tr><tr><td rowspan="2"><code>translationY</code></td><td>property</td><td><code>Double</code></td><td>native</td><td align="center">✓</td><td align="center">✓</td><td align="center">✅</td><td align="center">✅</td><td align="center">✓</td><td></td></tr>
<tr><td colspan="9">AppKit, UIKit: only through the host's own: read translationY of Line: the host's own transform, checked against the layer it composed itself<br>GTK 4: only through the host's own: read translationY of Line: the host's own transform: GTK reads back no part of one</td></tr></tbody>
<tbody><tr></tr><tr><td rowspan="2"><code>unfocus</code></td><td>act</td><td><code>() -&gt; Void</code></td><td></td><td align="center">–</td><td align="center">–</td><td align="center">–</td><td align="center">–</td><td align="center">–</td><td></td></tr>
<tr><td colspan="9">AppKit, UIKit, Android Views, WinUI 3, GTK 4: Line takes no keyboard focus here: it refuses it, and nothing is heard</td></tr></tbody>
<tbody><tr></tr><tr><td><code>width</code></td><td>property</td><td><code>Double</code></td><td>native</td><td align="center">✅</td><td align="center">✅</td><td align="center">✅</td><td align="center">✅</td><td align="center">✅</td><td></td></tr></tbody>
<tbody><tr></tr><tr><td rowspan="2"><code>zIndex</code></td><td>property</td><td><code>Int</code></td><td>native</td><td align="center"></td><td align="center"></td><td align="center"></td><td align="center"></td><td align="center"></td><td></td></tr>
<tr><td colspan="9">AppKit, UIKit, Android Views, WinUI 3, GTK 4: not realized</td></tr></tbody>
</table>

## From [View](tiers/View.md)

What every view a layout positions has: where it sits in its layout, the space kept around it, and the gestures, drags and frame reports it answers.

<table>
<thead><tr><th>Member</th><th>Kind</th><th>Value</th><th>Layer</th><th>AppKit</th><th>UIKit</th><th>Android Views</th><th>WinUI 3</th><th>GTK 4</th><th>Web</th></tr></thead>
<tbody><tr></tr><tr><td rowspan="2"><code>allowDrop</code></td><td>property</td><td><code>Bool</code></td><td>native</td><td align="center"></td><td align="center"></td><td align="center"></td><td align="center"></td><td align="center"></td><td></td></tr>
<tr><td colspan="9">AppKit, UIKit, Android Views, WinUI 3, GTK 4: not realized</td></tr></tbody>
<tbody><tr></tr><tr><td><code>area</code></td><td>property</td><td><code>Area</code></td><td>structure</td><td align="center">✅</td><td align="center">✅</td><td align="center">✅</td><td align="center">✅</td><td align="center">✅</td><td></td></tr></tbody>
<tbody><tr></tr><tr><td rowspan="2"><code>canDrag</code></td><td>property</td><td><code>Bool</code></td><td>native</td><td align="center"></td><td align="center"></td><td align="center"></td><td align="center"></td><td align="center"></td><td></td></tr>
<tr><td colspan="9">AppKit, UIKit, Android Views, WinUI 3, GTK 4: not realized</td></tr></tbody>
<tbody><tr></tr><tr><td rowspan="2"><code>onDragLeave</code> (<code>dragLeave</code>)</td><td>event</td><td></td><td>native</td><td align="center"></td><td align="center"></td><td align="center"></td><td align="center"></td><td align="center"></td><td></td></tr>
<tr><td colspan="9">AppKit, UIKit, Android Views, WinUI 3, GTK 4: not realized</td></tr></tbody>
<tbody><tr></tr><tr><td rowspan="2"><code>onDragOver</code> (<code>dragOver</code>)</td><td>event</td><td></td><td>native</td><td align="center"></td><td align="center"></td><td align="center"></td><td align="center"></td><td align="center"></td><td></td></tr>
<tr><td colspan="9">AppKit, UIKit, Android Views, WinUI 3, GTK 4: not realized</td></tr></tbody>
<tbody><tr></tr><tr><td rowspan="2"><code>dragStarting</code></td><td>event</td><td></td><td>native</td><td align="center"></td><td align="center"></td><td align="center"></td><td align="center"></td><td align="center"></td><td></td></tr>
<tr><td colspan="9">AppKit, UIKit, Android Views, WinUI 3, GTK 4: not realized</td></tr></tbody>
<tbody><tr></tr><tr><td rowspan="2"><code>dragText</code></td><td>property</td><td><code>String</code></td><td>native</td><td align="center"></td><td align="center"></td><td align="center"></td><td align="center"></td><td align="center"></td><td></td></tr>
<tr><td colspan="9">AppKit, UIKit, Android Views, WinUI 3, GTK 4: not realized</td></tr></tbody>
<tbody><tr></tr><tr><td rowspan="2"><code>onDrop</code> (<code>drop</code>)</td><td>event</td><td><code>String</code></td><td>native</td><td align="center"></td><td align="center"></td><td align="center"></td><td align="center"></td><td align="center"></td><td></td></tr>
<tr><td colspan="9">AppKit, UIKit, Android Views, WinUI 3, GTK 4: not realized</td></tr></tbody>
<tbody><tr></tr><tr><td rowspan="2"><code>onDropCompleted</code> (<code>dropCompleted</code>)</td><td>event</td><td></td><td>native</td><td align="center"></td><td align="center"></td><td align="center"></td><td align="center"></td><td align="center"></td><td></td></tr>
<tr><td colspan="9">AppKit, UIKit, Android Views, WinUI 3, GTK 4: not realized</td></tr></tbody>
<tbody><tr></tr><tr><td><code>onFrameChanged</code> (<code>frameChanged</code>)</td><td>event</td><td><code>[Double]</code></td><td>native</td><td align="center">✅</td><td align="center">✅</td><td align="center">✅</td><td align="center">✅</td><td align="center">✅</td><td></td></tr></tbody>
<tbody><tr></tr><tr><td><code>gridColumn</code></td><td>property</td><td><code>Int</code></td><td>stateUI</td><td align="center">✅</td><td align="center">✅</td><td align="center">✅</td><td align="center">✅</td><td align="center">✅</td><td></td></tr></tbody>
<tbody><tr></tr><tr><td><code>gridColumnSpan</code></td><td>property</td><td><code>Int</code></td><td>stateUI</td><td align="center">✅</td><td align="center">✅</td><td align="center">✅</td><td align="center">✅</td><td align="center">✅</td><td></td></tr></tbody>
<tbody><tr></tr><tr><td><code>gridRow</code></td><td>property</td><td><code>Int</code></td><td>stateUI</td><td align="center">✅</td><td align="center">✅</td><td align="center">✅</td><td align="center">✅</td><td align="center">✅</td><td></td></tr></tbody>
<tbody><tr></tr><tr><td><code>gridRowSpan</code></td><td>property</td><td><code>Int</code></td><td>stateUI</td><td align="center">✅</td><td align="center">✅</td><td align="center">✅</td><td align="center">✅</td><td align="center">✅</td><td></td></tr></tbody>
<tbody><tr></tr><tr><td><code>horizontalAlignment</code></td><td>property</td><td><code>Alignment</code></td><td>native</td><td align="center">✅</td><td align="center">✅</td><td align="center">✅</td><td align="center">✅</td><td align="center">✅</td><td></td></tr></tbody>
<tbody><tr></tr><tr><td><code>margin</code></td><td>property</td><td><code>Insets</code></td><td>native</td><td align="center">✅</td><td align="center">✅</td><td align="center">✅</td><td align="center">✅</td><td align="center">✅</td><td></td></tr></tbody>
<tbody><tr></tr><tr><td rowspan="2"><code>panTouchCount</code></td><td>property</td><td><code>Int</code></td><td>structure</td><td align="center">✓</td><td align="center">✓</td><td align="center">☑️</td><td align="center">✅</td><td align="center">✅</td><td></td></tr>
<tr><td colspan="9">AppKit: only through the host's own: pan on Line: handed to the host's recognizer or handler, no NSEvent sent<br>UIKit: only through the host's own: pan on Line: the view's listening handed the recognizer's states, no touch sent<br>Android Views: The host layer hears a one-finger pan only; any other <code>panTouchCount</code> turns the pan off.</td></tr></tbody>
<tbody><tr></tr><tr><td rowspan="2"><code>onPanUpdated</code> (<code>panUpdated</code>)</td><td>event</td><td><code>(GesturePhase, Double, Double)</code></td><td>native</td><td align="center">✓</td><td align="center">✓</td><td align="center">✅</td><td align="center">✅</td><td align="center">✅</td><td></td></tr>
<tr><td colspan="9">AppKit: only through the host's own: pan on Line: handed to the host's recognizer or handler, no NSEvent sent<br>UIKit: only through the host's own: pan on Line: the view's listening handed the recognizer's states, no touch sent</td></tr></tbody>
<tbody><tr></tr><tr><td rowspan="2"><code>panXChannel</code></td><td>property</td><td><code>Int</code></td><td>structure</td><td align="center">✓</td><td align="center">✓</td><td align="center">✅</td><td align="center">✅</td><td align="center">✅</td><td></td></tr>
<tr><td colspan="9">AppKit: only through the host's own: pan on Line: handed to the host's recognizer or handler, no NSEvent sent<br>UIKit: only through the host's own: pan on Line: the view's listening handed the recognizer's states, no touch sent</td></tr></tbody>
<tbody><tr></tr><tr><td rowspan="2"><code>panYChannel</code></td><td>property</td><td><code>Int</code></td><td>structure</td><td align="center">✓</td><td align="center">✓</td><td align="center">✅</td><td align="center">✅</td><td align="center">✅</td><td></td></tr>
<tr><td colspan="9">AppKit: only through the host's own: pan on Line: handed to the host's recognizer or handler, no NSEvent sent<br>UIKit: only through the host's own: pan on Line: the view's listening handed the recognizer's states, no touch sent</td></tr></tbody>
<tbody><tr></tr><tr><td rowspan="2"><code>onPinchUpdated</code> (<code>pinchUpdated</code>)</td><td>event</td><td><code>(GesturePhase, Double, Point)</code></td><td>native</td><td align="center">✓</td><td align="center">✓</td><td align="center">✅</td><td align="center">✅</td><td align="center">✓</td><td></td></tr>
<tr><td colspan="9">AppKit: only through the host's own: pinch on Line: handed to the host's recognizer or handler, no NSEvent sent<br>UIKit: only through the host's own: pinch on Line: the view's listening handed the recognizer's states, no touch sent<br>GTK 4: only through the host's own: pinch on Line: the fingers' place handed to the host's recognizer as GTK's zoom would: GTK takes no touch a driver puts down</td></tr></tbody>
<tbody><tr></tr><tr><td rowspan="2"><code>onPointerEntered</code> (<code>pointerEntered</code>)</td><td>event</td><td></td><td>native</td><td align="center">✓</td><td align="center">✓</td><td align="center">✅</td><td align="center">✅</td><td align="center">✅</td><td></td></tr>
<tr><td colspan="9">AppKit: only through the host's own: hover on Line: handed to the host's recognizer or handler, no NSEvent sent<br>UIKit: only through the host's own: hover on Line: the view's listening handed the recognizer's states, no touch sent</td></tr></tbody>
<tbody><tr></tr><tr><td rowspan="2"><code>onPointerExited</code> (<code>pointerExited</code>)</td><td>event</td><td></td><td>native</td><td align="center">✓</td><td align="center">✓</td><td align="center">✅</td><td align="center">✅</td><td align="center">✅</td><td></td></tr>
<tr><td colspan="9">AppKit: only through the host's own: hover on Line: handed to the host's recognizer or handler, no NSEvent sent<br>UIKit: only through the host's own: hover on Line: the view's listening handed the recognizer's states, no touch sent</td></tr></tbody>
<tbody><tr></tr><tr><td rowspan="2"><code>onPointerMoved</code> (<code>pointerMoved</code>)</td><td>event</td><td><code>Point?</code></td><td>native</td><td align="center">✓</td><td align="center">✓</td><td align="center">✅</td><td align="center">✅</td><td align="center">✅</td><td></td></tr>
<tr><td colspan="9">AppKit: only through the host's own: hover on Line: handed to the host's recognizer or handler, no NSEvent sent<br>UIKit: only through the host's own: hover on Line: the view's listening handed the recognizer's states, no touch sent</td></tr></tbody>
<tbody><tr></tr><tr><td rowspan="2"><code>onPointerPressed</code> (<code>pointerPressed</code>)</td><td>event</td><td><code>Point?</code></td><td>native</td><td align="center">✓</td><td align="center">✓</td><td align="center">✅</td><td align="center">✅</td><td align="center">✅</td><td></td></tr>
<tr><td colspan="9">AppKit: only through the host's own: hover on Line: handed to the host's recognizer or handler, no NSEvent sent<br>UIKit: only through the host's own: hover on Line: the view's listening handed the recognizer's states, no touch sent</td></tr></tbody>
<tbody><tr></tr><tr><td rowspan="2"><code>onPointerReleased</code> (<code>pointerReleased</code>)</td><td>event</td><td><code>Point?</code></td><td>native</td><td align="center">✓</td><td align="center">✓</td><td align="center">✅</td><td align="center">✅</td><td align="center">✅</td><td></td></tr>
<tr><td colspan="9">AppKit: only through the host's own: hover on Line: handed to the host's recognizer or handler, no NSEvent sent<br>UIKit: only through the host's own: hover on Line: the view's listening handed the recognizer's states, no touch sent</td></tr></tbody>
<tbody><tr></tr><tr><td rowspan="2"><code>swipeDirection</code></td><td>property</td><td><code>SwipeDirection</code></td><td>structure</td><td align="center">✓</td><td align="center">✓</td><td align="center">✅</td><td align="center">✅</td><td align="center">✅</td><td></td></tr>
<tr><td colspan="9">AppKit: only through the host's own: pan on Line: handed to the host's recognizer or handler, no NSEvent sent<br>UIKit: only through the host's own: pan on Line: the view's listening handed the recognizer's states, no touch sent</td></tr></tbody>
<tbody><tr></tr><tr><td rowspan="2"><code>swipeThreshold</code></td><td>property</td><td><code>Double</code></td><td>structure</td><td align="center">✓</td><td align="center">✓</td><td align="center">✅</td><td align="center">✅</td><td align="center">✅</td><td></td></tr>
<tr><td colspan="9">AppKit: only through the host's own: pan on Line: handed to the host's recognizer or handler, no NSEvent sent<br>UIKit: only through the host's own: pan on Line: the view's listening handed the recognizer's states, no touch sent</td></tr></tbody>
<tbody><tr></tr><tr><td rowspan="2"><code>onSwiped</code> (<code>swiped</code>)</td><td>event</td><td><code>SwipeDirection</code></td><td>native</td><td align="center">✓</td><td align="center">✓</td><td align="center">✅</td><td align="center">✅</td><td align="center">✅</td><td></td></tr>
<tr><td colspan="9">AppKit: only through the host's own: pan on Line: handed to the host's recognizer or handler, no NSEvent sent<br>UIKit: only through the host's own: pan on Line: the view's listening handed the recognizer's states, no touch sent</td></tr></tbody>
<tbody><tr></tr><tr><td rowspan="2"><code>tapCount</code></td><td>property</td><td><code>Int</code></td><td>structure</td><td align="center">✓</td><td align="center">✓</td><td align="center">✅</td><td align="center">✅</td><td align="center">✅</td><td></td></tr>
<tr><td colspan="9">AppKit: only through the host's own: tap on Line: handed to the host's recognizer or handler, no NSEvent sent<br>UIKit: only through the host's own: tap on Line: the view's listening handed the recognizer's states, no touch sent</td></tr></tbody>
<tbody><tr></tr><tr><td rowspan="2"><code>onTapped</code> (<code>tapped</code>)</td><td>event</td><td></td><td>native</td><td align="center">✓</td><td align="center">✓</td><td align="center">✅</td><td align="center">✅</td><td align="center">✅</td><td></td></tr>
<tr><td colspan="9">AppKit: only through the host's own: tap on Line: handed to the host's recognizer or handler, no NSEvent sent<br>UIKit: only through the host's own: tap on Line: the view's listening handed the recognizer's states, no touch sent</td></tr></tbody>
<tbody><tr></tr><tr><td><code>verticalAlignment</code></td><td>property</td><td><code>Alignment</code></td><td>native</td><td align="center">✅</td><td align="center">✅</td><td align="center">✅</td><td align="center">✅</td><td align="center">✅</td><td></td></tr></tbody>
</table>

## From [Shape](tiers/Shape.md)

What every drawn shape has: what fills it, the line around it, how it fits its room, and a transform of its own drawing.

<table>
<thead><tr><th>Member</th><th>Kind</th><th>Value</th><th>Layer</th><th>AppKit</th><th>UIKit</th><th>Android Views</th><th>WinUI 3</th><th>GTK 4</th><th>Web</th></tr></thead>
<tbody><tr></tr><tr><td rowspan="2"><code>aspect</code></td><td>property</td><td><code>Aspect</code></td><td>native</td><td align="center">◐</td><td align="center">◐</td><td align="center">◐</td><td align="center">✅</td><td align="center">✅</td><td></td></tr>
<tr><td colspan="9">AppKit: cannot read aspect of Line - StateUI draws a shape in its view's draw(_:), which holds none of its aspect; its drawing proves it<br>UIKit: cannot read aspect of Line - StateUI places and moves a shape's figure into its layer's path, which holds no aspect; its drawing proves it<br>Android Views: cannot read aspect of Line - StateUI draws a shape in its view's onDraw, which holds none of its aspect; its drawing proves it</td></tr></tbody>
<tbody><tr></tr><tr><td rowspan="2"><code>fill</code></td><td>property</td><td><code>Brush</code></td><td>stateUI</td><td align="center">◐</td><td align="center">✅</td><td align="center">◐</td><td align="center">✅</td><td align="center">✅</td><td></td></tr>
<tr><td colspan="9">AppKit: cannot read fill of Line - StateUI draws a shape in its view's draw(_:), which holds none of its fill; its drawing proves it<br>Android Views: cannot read fill of Line - StateUI draws a shape in its view's onDraw, which holds none of its fill; its drawing proves it</td></tr></tbody>
<tbody><tr></tr><tr><td rowspan="2"><code>renderTransform</code></td><td>property</td><td><code>ViewTransform</code></td><td>native</td><td align="center">◐</td><td align="center">◐</td><td align="center">◐</td><td align="center">✅</td><td align="center">✅</td><td></td></tr>
<tr><td colspan="9">AppKit: cannot read renderTransform of Line - StateUI draws a shape in its view's draw(_:), which holds none of its renderTransform; its drawing proves it<br>UIKit: cannot read renderTransform of Line - StateUI places and moves a shape's figure into its layer's path, which holds no renderTransform; its drawing proves it<br>Android Views: cannot read renderTransform of Line - StateUI draws a shape in its view's onDraw, which holds none of its renderTransform; its drawing proves it</td></tr></tbody>
<tbody><tr></tr><tr><td rowspan="2"><code>stroke</code></td><td>property</td><td><code>Brush</code></td><td>stateUI</td><td align="center">◐</td><td align="center">✅</td><td align="center">◐</td><td align="center">✅</td><td align="center">✅</td><td></td></tr>
<tr><td colspan="9">AppKit: cannot read stroke of Line - StateUI draws a shape in its view's draw(_:), which holds none of its stroke; its drawing proves it<br>Android Views: cannot read stroke of Line - StateUI draws a shape in its view's onDraw, which holds none of its stroke; its drawing proves it</td></tr></tbody>
<tbody><tr></tr><tr><td rowspan="2"><code>strokeDashOffset</code></td><td>property</td><td><code>Double</code></td><td>stateUI</td><td align="center">·</td><td align="center">·</td><td align="center">·</td><td align="center">✅</td><td align="center">·</td><td></td></tr>
<tr><td colspan="9">AppKit: cannot read strokeDashOffset of Line - StateUI draws a shape in its view's draw(_:), which holds none of its strokeDashOffset; its drawing proves it<br>UIKit: cannot read the line of a shape drawing no outline - UIKit draws no outline for a shape given no stroke, and holds none of its line<br>Android Views: cannot read strokeDashOffset of Line - StateUI draws a shape in its view's onDraw, which holds none of its strokeDashOffset; its drawing proves it<br>GTK 4: cannot read strokeDashOffset of Line - StateUI draws a shape on GTK's snapshot, which holds none of its strokeDashOffset; its drawing proves it</td></tr></tbody>
<tbody><tr></tr><tr><td rowspan="2"><code>strokeDashPattern</code></td><td>property</td><td><code>[Double]</code></td><td>stateUI</td><td align="center">·</td><td align="center">·</td><td align="center">·</td><td align="center">✅</td><td align="center">·</td><td></td></tr>
<tr><td colspan="9">AppKit: cannot read strokeDashPattern of Line - StateUI draws a shape in its view's draw(_:), which holds none of its strokeDashPattern; its drawing proves it<br>UIKit: cannot read the line of a shape drawing no outline - UIKit draws no outline for a shape given no stroke, and holds none of its line<br>Android Views: cannot read strokeDashPattern of Line - StateUI draws a shape in its view's onDraw, which holds none of its strokeDashPattern; its drawing proves it<br>GTK 4: cannot read strokeDashPattern of Line - StateUI draws a shape on GTK's snapshot, which holds none of its strokeDashPattern; its drawing proves it</td></tr></tbody>
<tbody><tr></tr><tr><td rowspan="2"><code>strokeLineCap</code></td><td>property</td><td><code>LineCap</code></td><td>stateUI</td><td align="center">·</td><td align="center">·</td><td align="center">·</td><td align="center">✅</td><td align="center">·</td><td></td></tr>
<tr><td colspan="9">AppKit: cannot read strokeLineCap of Line - StateUI draws a shape in its view's draw(_:), which holds none of its strokeLineCap; its drawing proves it<br>UIKit: cannot read the line of a shape drawing no outline - UIKit draws no outline for a shape given no stroke, and holds none of its line<br>Android Views: cannot read strokeLineCap of Line - StateUI draws a shape in its view's onDraw, which holds none of its strokeLineCap; its drawing proves it<br>GTK 4: cannot read strokeLineCap of Line - StateUI draws a shape on GTK's snapshot, which holds none of its strokeLineCap; its drawing proves it</td></tr></tbody>
<tbody><tr></tr><tr><td rowspan="2"><code>strokeLineJoin</code></td><td>property</td><td><code>LineJoin</code></td><td>stateUI</td><td align="center">·</td><td align="center">·</td><td align="center">·</td><td align="center">✅</td><td align="center">·</td><td></td></tr>
<tr><td colspan="9">AppKit: cannot read strokeLineJoin of Line - StateUI draws a shape in its view's draw(_:), which holds none of its strokeLineJoin; its drawing proves it<br>UIKit: cannot read the line of a shape drawing no outline - UIKit draws no outline for a shape given no stroke, and holds none of its line<br>Android Views: cannot read strokeLineJoin of Line - StateUI draws a shape in its view's onDraw, which holds none of its strokeLineJoin; its drawing proves it<br>GTK 4: cannot read strokeLineJoin of Line - StateUI draws a shape on GTK's snapshot, which holds none of its strokeLineJoin; its drawing proves it</td></tr></tbody>
<tbody><tr></tr><tr><td rowspan="2"><code>strokeMiterLimit</code></td><td>property</td><td><code>Double</code></td><td>stateUI</td><td align="center">·</td><td align="center">·</td><td align="center">·</td><td align="center">✅</td><td align="center">·</td><td></td></tr>
<tr><td colspan="9">AppKit: cannot read strokeMiterLimit of Line - StateUI draws a shape in its view's draw(_:), which holds none of its strokeMiterLimit; its drawing proves it<br>UIKit: cannot read the line of a shape drawing no outline - UIKit draws no outline for a shape given no stroke, and holds none of its line<br>Android Views: cannot read strokeMiterLimit of Line - StateUI draws a shape in its view's onDraw, which holds none of its strokeMiterLimit; its drawing proves it<br>GTK 4: cannot read strokeMiterLimit of Line - StateUI draws a shape on GTK's snapshot, which holds none of its strokeMiterLimit; its drawing proves it</td></tr></tbody>
<tbody><tr></tr><tr><td rowspan="2"><code>strokeWidth</code></td><td>property</td><td><code>Double</code></td><td>stateUI</td><td align="center">◐</td><td align="center">◐</td><td align="center">◐</td><td align="center">✅</td><td align="center">✅</td><td></td></tr>
<tr><td colspan="9">AppKit: cannot read strokeWidth of Line - StateUI draws a shape in its view's draw(_:), which holds none of its strokeWidth; its drawing proves it<br>UIKit: cannot read the line of a shape drawing no outline - UIKit draws no outline for a shape given no stroke, and holds none of its line<br>Android Views: cannot read strokeWidth of Line - StateUI draws a shape in its view's onDraw, which holds none of its strokeWidth; its drawing proves it</td></tr></tbody>
</table>
