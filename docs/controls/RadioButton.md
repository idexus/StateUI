<!-- Rendered by ControlDictionaryTests from the contracts and the verdicts each host's runs of its tests wrote under lib/StateUI/exports/marks: STATEUI_UPDATE_DOCS=1 swift test --filter ControlDictionaryTests writes it again. -->

# RadioButton

One choice out of several, where picking one clears the rest.

```swift
@State var size = "Medium"

VStack {
    ForEach(["Small", "Medium", "Large"]) { option in
        RadioButton(option)
            .groupName("size")
            .isOn(option == size)
            .onToggled { checked in
                if checked { size = option }
            }
    }
}
```

Layer: `adaptive`. Every base host presents it by its platform's conventions, keeping StateUI's state contract.

Inherits: [PropertyContainer](tiers/PropertyContainer.md) · [VisualElement](tiers/VisualElement.md) · [View](tiers/View.md) · [TextualElement](tiers/TextualElement.md) · [TextStyleElement](tiers/TextStyleElement.md) · [FontElement](tiers/FontElement.md) · [PaddingElement](tiers/PaddingElement.md) · [BorderElement](tiers/BorderElement.md)

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
<thead><tr><th>Host</th><th>Created</th><th>Members (83)</th><th>Realization</th></tr></thead>
<tbody><tr></tr><tr><td>AppKit</td><td align="center">✅</td><td>40 ✅ · 2 ☑️ · 35 ✓ · 1 –</td><td><code>NSButton</code> radio</td></tr></tbody>
<tbody><tr></tr><tr><td>UIKit</td><td align="center">✅</td><td>38 ✅ · 2 ☑️ · 36 ✓ · 3 –</td><td><code>UIButton</code> with a circle symbol</td></tr></tbody>
<tbody><tr></tr><tr><td>Android Views</td><td align="center">✅</td><td>61 ✅ · 3 ☑️ · 10 ✓ · 3 –</td><td><code>RadioButton</code></td></tr></tbody>
<tbody><tr></tr><tr><td>WinUI 3</td><td align="center">✅</td><td>66 ✅ · 1 ☑️ · 12 ✓</td><td><code>RadioButton</code></td></tr></tbody>
<tbody><tr></tr><tr><td>GTK 4</td><td align="center">✅</td><td>54 ✅ · 1 ☑️ · 23 ✓ · 1 –</td><td>grouped <code>GtkCheckButton</code></td></tr></tbody>
<tbody><tr></tr><tr><td>Web</td><td align="center">✅</td><td>58 ✅ · 1 ☑️ · 20 ✓</td><td><code>&lt;input type=radio&gt;</code></td></tr></tbody>
</table>

Declared in `lib/StateUI/Core/Sources/Contracts/Elements/Controls/RadioButtonContract.swift`.

## RadioButton's own members

<table>
<thead><tr><th>Member</th><th>Kind</th><th>Value</th><th>Layer</th><th>AppKit</th><th>UIKit</th><th>Android Views</th><th>WinUI 3</th><th>GTK 4</th><th>Web</th></tr></thead>
<tbody><tr></tr><tr><td><code>groupName</code></td><td>property</td><td><code>Name</code></td><td>stateUI</td><td align="center">✅</td><td align="center">✅</td><td align="center">✅</td><td align="center">✅</td><td align="center">✅</td><td align="center">✅</td></tr></tbody>
<tbody><tr></tr><tr><td rowspan="2"><code>isOn</code></td><td>property</td><td><code>Bool</code></td><td>native</td><td align="center">✅</td><td align="center">✓</td><td align="center">✅</td><td align="center">✅</td><td align="center">✅</td><td align="center">✅</td></tr>
<tr><td colspan="9">UIKit: only through the host's own: read isOn of RadioButton: the host's own flag, not the button's state</td></tr></tbody>
<tbody><tr></tr><tr><td><code>onToggled</code> (<code>toggled</code>)</td><td>event</td><td><code>Bool</code></td><td>native</td><td align="center">✅</td><td align="center">✅</td><td align="center">✅</td><td align="center">✅</td><td align="center">✅</td><td align="center">✅</td></tr></tbody>
</table>

## From [PropertyContainer](tiers/PropertyContainer.md)

What anything carrying values in the tree has - a control, a `Style`, a text run: the name automation finds it by.

<table>
<thead><tr><th>Member</th><th>Kind</th><th>Value</th><th>Layer</th><th>AppKit</th><th>UIKit</th><th>Android Views</th><th>WinUI 3</th><th>GTK 4</th><th>Web</th></tr></thead>
<tbody><tr></tr><tr><td rowspan="2"><code>accessibilityIdentifier</code></td><td>property</td><td><code>String</code></td><td>native</td><td align="center">✅</td><td align="center">✅</td><td align="center">✅</td><td align="center">✅</td><td align="center">–</td><td align="center">✅</td></tr>
<tr><td colspan="9">GTK 4: GTK 4 tells assistive technology no identifier before 4.22, and from 4.22 only a GtkBuilder file's id, which no public call sets on a widget made in code.</td></tr></tbody>
</table>

## From [VisualElement](tiers/VisualElement.md)

What every drawn element has: its size and its bounds, how it is shown and turned, whether it answers input and holds the keyboard focus, the visual states it enters, and what a screen reader says about it.

<table>
<thead><tr><th>Member</th><th>Kind</th><th>Value</th><th>Layer</th><th>AppKit</th><th>UIKit</th><th>Android Views</th><th>WinUI 3</th><th>GTK 4</th><th>Web</th></tr></thead>
<tbody><tr></tr><tr><td rowspan="2"><code>accessibilityHeading</code></td><td>property</td><td><code>AccessibilityHeadingLevel</code></td><td>native</td><td align="center">☑️</td><td align="center">☑️</td><td align="center">☑️</td><td align="center">✅</td><td align="center">☑️</td><td align="center">✅</td></tr>
<tr><td colspan="9">AppKit: AppKit marks a heading, not its level: every level is a heading.<br>UIKit: UIKit marks a heading, not its level: every level is a heading.<br>Android Views: Android marks a heading, not its level: every level is a heading.<br>GTK 4: GTK fixes a widget's role once it is shown: a view becomes a heading, or stops being one, only as it is made; its level changes.</td></tr></tbody>
<tbody><tr></tr><tr><td><code>accessibilityHint</code></td><td>property</td><td><code>String</code></td><td>native</td><td align="center">✅</td><td align="center">✅</td><td align="center">✅</td><td align="center">✅</td><td align="center">✅</td><td align="center">✅</td></tr></tbody>
<tbody><tr></tr><tr><td><code>accessibilityLabel</code></td><td>property</td><td><code>String</code></td><td>native</td><td align="center">✅</td><td align="center">✅</td><td align="center">✅</td><td align="center">✅</td><td align="center">✅</td><td align="center">✅</td></tr></tbody>
<tbody><tr></tr><tr><td><code>automationExcludedWithChildren</code></td><td>property</td><td><code>Bool</code></td><td>native</td><td align="center">✅</td><td align="center">✅</td><td align="center">✅</td><td align="center">✅</td><td align="center">✅</td><td align="center">✅</td></tr></tbody>
<tbody><tr></tr><tr><td rowspan="2"><code>background</code></td><td>property</td><td><code>Material</code></td><td>adaptive</td><td align="center">☑️</td><td align="center">☑️</td><td align="center">☑️</td><td align="center">☑️</td><td align="center">✓</td><td align="center">☑️</td></tr>
<tr><td colspan="9">AppKit: AppKit paints a colour on this view; a brush, a blur and glass are drawn only by a layout, and elsewhere a blur's colour stands in.<br>UIKit: UIKit paints a colour on this view; a brush, a blur and glass are drawn only by a layout, and elsewhere a blur's colour stands in.<br>Android Views: Android blurs nothing behind a view: a blur or glass shows the theme's colour standing in, its tint over it.<br>WinUI 3: An element's acrylic is not drawn yet: a blur or glass shows the theme's colour standing in, its tint over it.<br>GTK 4: only through the host's own: read background of RadioButton: the class of the host's style sheet the widget wears: GTK reads back no background<br>Web: A brush fills the view with its first colour alone; a blur and glass are drawn by a layout, and elsewhere a blur's colour stands in.</td></tr></tbody>
<tbody><tr></tr><tr><td rowspan="2"><code>focus</code></td><td>act</td><td><code>() -&gt; Bool</code></td><td></td><td align="center">✅</td><td align="center">–</td><td align="center">–</td><td align="center">✅</td><td align="center">✅</td><td align="center">✅</td></tr>
<tr><td colspan="9">UIKit, Android Views: RadioButton takes no keyboard focus here: it refuses it, and nothing is heard</td></tr></tbody>
<tbody><tr></tr><tr><td><code>frame</code></td><td>property</td><td><code>Rect</code></td><td>structure</td><td align="center">✅</td><td align="center">✅</td><td align="center">✅</td><td align="center">✅</td><td align="center">✅</td><td align="center">✅</td></tr></tbody>
<tbody><tr></tr><tr><td><code>height</code></td><td>property</td><td><code>Double</code></td><td>native</td><td align="center">✅</td><td align="center">✅</td><td align="center">✅</td><td align="center">✅</td><td align="center">✅</td><td align="center">✅</td></tr></tbody>
<tbody><tr></tr><tr><td rowspan="2"><code>ignoresInput</code></td><td>property</td><td><code>Bool</code></td><td>native</td><td align="center">✅</td><td align="center">✅</td><td align="center"></td><td align="center">✅</td><td align="center">✅</td><td align="center">✅</td></tr>
<tr><td colspan="9">Android Views: not realized</td></tr></tbody>
<tbody><tr></tr><tr><td><code>isAccessibilityHidden</code></td><td>property</td><td><code>Bool</code></td><td>native</td><td align="center">✅</td><td align="center">✅</td><td align="center">✅</td><td align="center">✅</td><td align="center">✅</td><td align="center">✅</td></tr></tbody>
<tbody><tr></tr><tr><td><code>isEnabled</code></td><td>property</td><td><code>Bool</code></td><td>native</td><td align="center">✅</td><td align="center">✅</td><td align="center">✅</td><td align="center">✅</td><td align="center">✅</td><td align="center">✅</td></tr></tbody>
<tbody><tr></tr><tr><td rowspan="2"><code>isFocusedChanged</code></td><td>event</td><td><code>Bool</code></td><td>native</td><td align="center">✅</td><td align="center">–</td><td align="center">–</td><td align="center">✅</td><td align="center">✅</td><td align="center">✅</td></tr>
<tr><td colspan="9">UIKit, Android Views: RadioButton takes no keyboard focus here: it refuses it, and nothing is heard</td></tr></tbody>
<tbody><tr></tr><tr><td><code>isVisible</code></td><td>property</td><td><code>Bool</code></td><td>native</td><td align="center">✅</td><td align="center">✅</td><td align="center">✅</td><td align="center">✅</td><td align="center">✅</td><td align="center">✅</td></tr></tbody>
<tbody><tr></tr><tr><td><code>layoutDirection</code></td><td>property</td><td><code>LayoutDirection</code></td><td>native</td><td align="center">✅</td><td align="center">✅</td><td align="center">✅</td><td align="center">✅</td><td align="center">✅</td><td align="center">✅</td></tr></tbody>
<tbody><tr></tr><tr><td><code>maximumHeight</code></td><td>property</td><td><code>Double</code></td><td>native</td><td align="center">✅</td><td align="center">✅</td><td align="center">✅</td><td align="center">✅</td><td align="center">✅</td><td align="center">✅</td></tr></tbody>
<tbody><tr></tr><tr><td><code>maximumWidth</code></td><td>property</td><td><code>Double</code></td><td>native</td><td align="center">✅</td><td align="center">✅</td><td align="center">✅</td><td align="center">✅</td><td align="center">✅</td><td align="center">✅</td></tr></tbody>
<tbody><tr></tr><tr><td><code>minimumHeight</code></td><td>property</td><td><code>Double</code></td><td>native</td><td align="center">✅</td><td align="center">✅</td><td align="center">✅</td><td align="center">✅</td><td align="center">✅</td><td align="center">✅</td></tr></tbody>
<tbody><tr></tr><tr><td><code>minimumWidth</code></td><td>property</td><td><code>Double</code></td><td>native</td><td align="center">✅</td><td align="center">✅</td><td align="center">✅</td><td align="center">✅</td><td align="center">✅</td><td align="center">✅</td></tr></tbody>
<tbody><tr></tr><tr><td><code>opacity</code></td><td>property</td><td><code>Double</code></td><td>native</td><td align="center">✅</td><td align="center">✅</td><td align="center">✅</td><td align="center">✅</td><td align="center">✅</td><td align="center">✅</td></tr></tbody>
<tbody><tr></tr><tr><td rowspan="2"><code>pivotX</code></td><td>property</td><td><code>Double</code></td><td>native</td><td align="center">✓</td><td align="center">✓</td><td align="center">✅</td><td align="center">✅</td><td align="center">✓</td><td align="center">✓</td></tr>
<tr><td colspan="9">AppKit, UIKit: only through the host's own: read pivotX of RadioButton: the host's own transform, checked against the layer it composed itself<br>GTK 4: only through the host's own: read pivotX of RadioButton: the host's own transform: GTK reads back no part of one<br>Web: only through the host's own: read pivotX of RadioButton: the host's own transform: the page holds one matrix of it, its parts no longer told apart</td></tr></tbody>
<tbody><tr></tr><tr><td rowspan="2"><code>pivotY</code></td><td>property</td><td><code>Double</code></td><td>native</td><td align="center">✓</td><td align="center">✓</td><td align="center">✅</td><td align="center">✅</td><td align="center">✓</td><td align="center">✓</td></tr>
<tr><td colspan="9">AppKit, UIKit: only through the host's own: read pivotY of RadioButton: the host's own transform, checked against the layer it composed itself<br>GTK 4: only through the host's own: read pivotY of RadioButton: the host's own transform: GTK reads back no part of one<br>Web: only through the host's own: read pivotY of RadioButton: the host's own transform: the page holds one matrix of it, its parts no longer told apart</td></tr></tbody>
<tbody><tr></tr><tr><td rowspan="2"><code>rotation</code></td><td>property</td><td><code>Double</code></td><td>native</td><td align="center">✓</td><td align="center">✓</td><td align="center">✅</td><td align="center">✅</td><td align="center">✓</td><td align="center">✓</td></tr>
<tr><td colspan="9">AppKit, UIKit: only through the host's own: read rotation of RadioButton: the host's own transform, checked against the layer it composed itself<br>GTK 4: only through the host's own: read rotation of RadioButton: the host's own transform: GTK reads back no part of one<br>Web: only through the host's own: read rotation of RadioButton: the host's own transform: the page holds one matrix of it, its parts no longer told apart</td></tr></tbody>
<tbody><tr></tr><tr><td rowspan="2"><code>rotationX</code></td><td>property</td><td><code>Double</code></td><td>native</td><td align="center">✓</td><td align="center">✓</td><td align="center">✅</td><td align="center">✓</td><td align="center">✓</td><td align="center">✓</td></tr>
<tr><td colspan="9">AppKit, UIKit: only through the host's own: read rotationX of RadioButton: the host's own transform, checked against the layer it composed itself<br>WinUI 3: only through the host's own: read rotationX of RadioButton: the host's own tip, checked against the projection it laid on the element<br>GTK 4: only through the host's own: read rotationX of RadioButton: the host's own transform: GTK reads back no part of one<br>Web: only through the host's own: read rotationX of RadioButton: the host's own transform: the page holds one matrix of it, its parts no longer told apart</td></tr></tbody>
<tbody><tr></tr><tr><td rowspan="2"><code>rotationY</code></td><td>property</td><td><code>Double</code></td><td>native</td><td align="center">✓</td><td align="center">✓</td><td align="center">✅</td><td align="center">✓</td><td align="center">✓</td><td align="center">✓</td></tr>
<tr><td colspan="9">AppKit, UIKit: only through the host's own: read rotationY of RadioButton: the host's own transform, checked against the layer it composed itself<br>WinUI 3: only through the host's own: read rotationY of RadioButton: the host's own tip, checked against the projection it laid on the element<br>GTK 4: only through the host's own: read rotationY of RadioButton: the host's own transform: GTK reads back no part of one<br>Web: only through the host's own: read rotationY of RadioButton: the host's own transform: the page holds one matrix of it, its parts no longer told apart</td></tr></tbody>
<tbody><tr></tr><tr><td rowspan="2"><code>scale</code></td><td>property</td><td><code>Double</code></td><td>native</td><td align="center">✓</td><td align="center">✓</td><td align="center">✅</td><td align="center">✅</td><td align="center">✓</td><td align="center">✓</td></tr>
<tr><td colspan="9">AppKit, UIKit: only through the host's own: read scale of RadioButton: the host's own transform, checked against the layer it composed itself<br>GTK 4: only through the host's own: read scale of RadioButton: the host's own transform: GTK reads back no part of one<br>Web: only through the host's own: read scale of RadioButton: the host's own transform: the page holds one matrix of it, its parts no longer told apart</td></tr></tbody>
<tbody><tr></tr><tr><td rowspan="2"><code>scaleX</code></td><td>property</td><td><code>Double</code></td><td>native</td><td align="center">✓</td><td align="center">✓</td><td align="center">✅</td><td align="center">✅</td><td align="center">✓</td><td align="center">✓</td></tr>
<tr><td colspan="9">AppKit, UIKit: only through the host's own: read scaleX of RadioButton: the host's own transform, checked against the layer it composed itself<br>GTK 4: only through the host's own: read scaleX of RadioButton: the host's own transform: GTK reads back no part of one<br>Web: only through the host's own: read scaleX of RadioButton: the host's own transform: the page holds one matrix of it, its parts no longer told apart</td></tr></tbody>
<tbody><tr></tr><tr><td rowspan="2"><code>scaleY</code></td><td>property</td><td><code>Double</code></td><td>native</td><td align="center">✓</td><td align="center">✓</td><td align="center">✅</td><td align="center">✅</td><td align="center">✓</td><td align="center">✓</td></tr>
<tr><td colspan="9">AppKit, UIKit: only through the host's own: read scaleY of RadioButton: the host's own transform, checked against the layer it composed itself<br>GTK 4: only through the host's own: read scaleY of RadioButton: the host's own transform: GTK reads back no part of one<br>Web: only through the host's own: read scaleY of RadioButton: the host's own transform: the page holds one matrix of it, its parts no longer told apart</td></tr></tbody>
<tbody><tr></tr><tr><td><code>style</code></td><td>property</td><td><code>Name</code></td><td>structure</td><td align="center">✅</td><td align="center">✅</td><td align="center">✅</td><td align="center">✅</td><td align="center">✅</td><td align="center">✅</td></tr></tbody>
<tbody><tr></tr><tr><td rowspan="2"><code>translationX</code></td><td>property</td><td><code>Double</code></td><td>native</td><td align="center">✓</td><td align="center">✓</td><td align="center">✅</td><td align="center">✅</td><td align="center">✓</td><td align="center">✓</td></tr>
<tr><td colspan="9">AppKit, UIKit: only through the host's own: read translationX of RadioButton: the host's own transform, checked against the layer it composed itself<br>GTK 4: only through the host's own: read translationX of RadioButton: the host's own transform: GTK reads back no part of one<br>Web: only through the host's own: read translationX of RadioButton: the host's own transform: the page holds one matrix of it, its parts no longer told apart</td></tr></tbody>
<tbody><tr></tr><tr><td rowspan="2"><code>translationY</code></td><td>property</td><td><code>Double</code></td><td>native</td><td align="center">✓</td><td align="center">✓</td><td align="center">✅</td><td align="center">✅</td><td align="center">✓</td><td align="center">✓</td></tr>
<tr><td colspan="9">AppKit, UIKit: only through the host's own: read translationY of RadioButton: the host's own transform, checked against the layer it composed itself<br>GTK 4: only through the host's own: read translationY of RadioButton: the host's own transform: GTK reads back no part of one<br>Web: only through the host's own: read translationY of RadioButton: the host's own transform: the page holds one matrix of it, its parts no longer told apart</td></tr></tbody>
<tbody><tr></tr><tr><td rowspan="2"><code>unfocus</code></td><td>act</td><td><code>() -&gt; Void</code></td><td></td><td align="center">✅</td><td align="center">–</td><td align="center">–</td><td align="center">✅</td><td align="center">✅</td><td align="center">✅</td></tr>
<tr><td colspan="9">UIKit, Android Views: RadioButton takes no keyboard focus here: it refuses it, and nothing is heard</td></tr></tbody>
<tbody><tr></tr><tr><td><code>width</code></td><td>property</td><td><code>Double</code></td><td>native</td><td align="center">✅</td><td align="center">✅</td><td align="center">✅</td><td align="center">✅</td><td align="center">✅</td><td align="center">✅</td></tr></tbody>
<tbody><tr></tr><tr><td><code>zIndex</code></td><td>property</td><td><code>Int</code></td><td>native</td><td align="center">✅</td><td align="center">✅</td><td align="center">✅</td><td align="center">✅</td><td align="center">✅</td><td align="center">✅</td></tr></tbody>
</table>

## From [View](tiers/View.md)

What every view a layout positions has: where it sits in its layout, the space kept around it, and the gestures, drags and frame reports it answers.

<table>
<thead><tr><th>Member</th><th>Kind</th><th>Value</th><th>Layer</th><th>AppKit</th><th>UIKit</th><th>Android Views</th><th>WinUI 3</th><th>GTK 4</th><th>Web</th></tr></thead>
<tbody><tr></tr><tr><td rowspan="2"><code>allowsDrop</code></td><td>property</td><td><code>Bool</code></td><td>native</td><td align="center">✓</td><td align="center">✓</td><td align="center">✓</td><td align="center">✓</td><td align="center">✓</td><td align="center">✓</td></tr>
<tr><td colspan="9">AppKit: only through the host's own: dragAndDrop on ColorBox: the drag source and the window's drop routing told by the driver, no dragging session<br>UIKit: only through the host's own: dragAndDrop on ColorBox: the drag and drop interactions' handlers called, no drag session<br>Android Views: only through the host's own: dragAndDrop on ColorBox: the views' drag listeners' reports told by the driver, no drag started<br>WinUI 3: only through the host's own: dragAndDrop on ColorBox: the relay's drag reports told by the driver, no drag WinUI began<br>GTK 4: only through the host's own: dragAndDrop on ColorBox: the drag source's and the drop targets' signals told by the driver, no drag GTK began<br>Web: only through the host's own: dragAndDrop on ColorBox: the DOM's drag events dispatched by the driver, no drag the browser began</td></tr></tbody>
<tbody><tr></tr><tr><td><code>area</code></td><td>property</td><td><code>Area</code></td><td>structure</td><td align="center">✅</td><td align="center">✅</td><td align="center">✅</td><td align="center">✅</td><td align="center">✅</td><td align="center">✅</td></tr></tbody>
<tbody><tr></tr><tr><td rowspan="2"><code>canDrag</code></td><td>property</td><td><code>Bool</code></td><td>native</td><td align="center">✓</td><td align="center">✓</td><td align="center">✓</td><td align="center">✓</td><td align="center">✓</td><td align="center">✓</td></tr>
<tr><td colspan="9">AppKit: only through the host's own: dragAndDrop on RadioButton: the drag source and the window's drop routing told by the driver, no dragging session<br>UIKit: only through the host's own: dragAndDrop on RadioButton: the drag and drop interactions' handlers called, no drag session<br>Android Views: only through the host's own: dragAndDrop on RadioButton: the views' drag listeners' reports told by the driver, no drag started<br>WinUI 3: only through the host's own: dragAndDrop on RadioButton: the relay's drag reports told by the driver, no drag WinUI began<br>GTK 4: only through the host's own: dragAndDrop on RadioButton: the drag source's and the drop targets' signals told by the driver, no drag GTK began<br>Web: only through the host's own: dragAndDrop on RadioButton: the DOM's drag events dispatched by the driver, no drag the browser began</td></tr></tbody>
<tbody><tr></tr><tr><td rowspan="2"><code>onDragLeave</code> (<code>dragLeave</code>)</td><td>event</td><td></td><td>native</td><td align="center">✓</td><td align="center">✓</td><td align="center">✓</td><td align="center">✓</td><td align="center">✓</td><td align="center">✓</td></tr>
<tr><td colspan="9">AppKit: only through the host's own: dragAndDrop on ColorBox: the drag source and the window's drop routing told by the driver, no dragging session<br>UIKit: only through the host's own: dragAndDrop on ColorBox: the drag and drop interactions' handlers called, no drag session<br>Android Views: only through the host's own: dragAndDrop on ColorBox: the views' drag listeners' reports told by the driver, no drag started<br>WinUI 3: only through the host's own: dragAndDrop on ColorBox: the relay's drag reports told by the driver, no drag WinUI began<br>GTK 4: only through the host's own: dragAndDrop on ColorBox: the drag source's and the drop targets' signals told by the driver, no drag GTK began<br>Web: only through the host's own: dragAndDrop on ColorBox: the DOM's drag events dispatched by the driver, no drag the browser began</td></tr></tbody>
<tbody><tr></tr><tr><td rowspan="2"><code>onDragOver</code> (<code>dragOver</code>)</td><td>event</td><td></td><td>native</td><td align="center">✓</td><td align="center">✓</td><td align="center">✓</td><td align="center">✓</td><td align="center">✓</td><td align="center">✓</td></tr>
<tr><td colspan="9">AppKit: only through the host's own: dragAndDrop on ColorBox: the drag source and the window's drop routing told by the driver, no dragging session<br>UIKit: only through the host's own: dragAndDrop on ColorBox: the drag and drop interactions' handlers called, no drag session<br>Android Views: only through the host's own: dragAndDrop on ColorBox: the views' drag listeners' reports told by the driver, no drag started<br>WinUI 3: only through the host's own: dragAndDrop on ColorBox: the relay's drag reports told by the driver, no drag WinUI began<br>GTK 4: only through the host's own: dragAndDrop on ColorBox: the drag source's and the drop targets' signals told by the driver, no drag GTK began<br>Web: only through the host's own: dragAndDrop on ColorBox: the DOM's drag events dispatched by the driver, no drag the browser began</td></tr></tbody>
<tbody><tr></tr><tr><td rowspan="2"><code>dragStarting</code></td><td>event</td><td></td><td>native</td><td align="center">✓</td><td align="center">✓</td><td align="center">✓</td><td align="center">✓</td><td align="center">✓</td><td align="center">✓</td></tr>
<tr><td colspan="9">AppKit: only through the host's own: dragAndDrop on RadioButton: the drag source and the window's drop routing told by the driver, no dragging session<br>UIKit: only through the host's own: dragAndDrop on RadioButton: the drag and drop interactions' handlers called, no drag session<br>Android Views: only through the host's own: dragAndDrop on RadioButton: the views' drag listeners' reports told by the driver, no drag started<br>WinUI 3: only through the host's own: dragAndDrop on RadioButton: the relay's drag reports told by the driver, no drag WinUI began<br>GTK 4: only through the host's own: dragAndDrop on RadioButton: the drag source's and the drop targets' signals told by the driver, no drag GTK began<br>Web: only through the host's own: dragAndDrop on RadioButton: the DOM's drag events dispatched by the driver, no drag the browser began</td></tr></tbody>
<tbody><tr></tr><tr><td rowspan="2"><code>dragText</code></td><td>property</td><td><code>String</code></td><td>native</td><td align="center">✓</td><td align="center">✓</td><td align="center">✓</td><td align="center">✓</td><td align="center">✓</td><td align="center">✓</td></tr>
<tr><td colspan="9">AppKit: only through the host's own: dragAndDrop on RadioButton: the drag source and the window's drop routing told by the driver, no dragging session<br>UIKit: only through the host's own: dragAndDrop on RadioButton: the drag and drop interactions' handlers called, no drag session<br>Android Views: only through the host's own: dragAndDrop on RadioButton: the views' drag listeners' reports told by the driver, no drag started<br>WinUI 3: only through the host's own: dragAndDrop on RadioButton: the relay's drag reports told by the driver, no drag WinUI began<br>GTK 4: only through the host's own: dragAndDrop on RadioButton: the drag source's and the drop targets' signals told by the driver, no drag GTK began<br>Web: only through the host's own: dragAndDrop on RadioButton: the DOM's drag events dispatched by the driver, no drag the browser began</td></tr></tbody>
<tbody><tr></tr><tr><td rowspan="2"><code>onDrop</code> (<code>drop</code>)</td><td>event</td><td><code>String</code></td><td>native</td><td align="center">✓</td><td align="center">✓</td><td align="center">✓</td><td align="center">✓</td><td align="center">✓</td><td align="center">✓</td></tr>
<tr><td colspan="9">AppKit: only through the host's own: dragAndDrop on ColorBox: the drag source and the window's drop routing told by the driver, no dragging session<br>UIKit: only through the host's own: dragAndDrop on ColorBox: the drag and drop interactions' handlers called, no drag session<br>Android Views: only through the host's own: dragAndDrop on ColorBox: the views' drag listeners' reports told by the driver, no drag started<br>WinUI 3: only through the host's own: dragAndDrop on ColorBox: the relay's drag reports told by the driver, no drag WinUI began<br>GTK 4: only through the host's own: dragAndDrop on ColorBox: the drag source's and the drop targets' signals told by the driver, no drag GTK began<br>Web: only through the host's own: dragAndDrop on ColorBox: the DOM's drag events dispatched by the driver, no drag the browser began</td></tr></tbody>
<tbody><tr></tr><tr><td rowspan="2"><code>droppedFileTypes</code></td><td>property</td><td><code>[FileType]</code></td><td>native</td><td align="center">✓</td><td align="center">✓</td><td align="center">✓</td><td align="center">✓</td><td align="center">✓</td><td align="center">✓</td></tr>
<tr><td colspan="9">AppKit: only through the host's own: dropFiles on RadioButton: the window's drop routing told the driver's files, no dragging session<br>UIKit: only through the host's own: dropFiles on RadioButton: the drop interaction's handler told the driver's files, no drag session<br>Android Views: only through the host's own: dropFiles on RadioButton: the view's drag listener's report told the driver's documents, no drag started<br>WinUI 3: only through the host's own: dropFiles on RadioButton: the relay's drop report told the driver's files, no drag WinUI began<br>GTK 4: only through the host's own: dropFiles on RadioButton: the drop target's signal told the driver's files, no drag GTK began<br>Web: only through the host's own: dropFiles on RadioButton: the DOM's drag events dispatched by the driver with its files, no drag the browser began</td></tr></tbody>
<tbody><tr></tr><tr><td rowspan="2"><code>onDragEnded</code> (<code>dragEnded</code>)</td><td>event</td><td></td><td>native</td><td align="center">✓</td><td align="center">✓</td><td align="center">✓</td><td align="center">✓</td><td align="center">✓</td><td align="center">✓</td></tr>
<tr><td colspan="9">AppKit: only through the host's own: dragAndDrop on RadioButton: the drag source and the window's drop routing told by the driver, no dragging session<br>UIKit: only through the host's own: dragAndDrop on RadioButton: the drag and drop interactions' handlers called, no drag session<br>Android Views: only through the host's own: dragAndDrop on RadioButton: the views' drag listeners' reports told by the driver, no drag started<br>WinUI 3: only through the host's own: dragAndDrop on RadioButton: the relay's drag reports told by the driver, no drag WinUI began<br>GTK 4: only through the host's own: dragAndDrop on RadioButton: the drag source's and the drop targets' signals told by the driver, no drag GTK began<br>Web: only through the host's own: dragAndDrop on RadioButton: the DOM's drag events dispatched by the driver, no drag the browser began</td></tr></tbody>
<tbody><tr></tr><tr><td rowspan="2"><code>onDrop</code> (<code>filesDropped</code>)</td><td>event</td><td><code>[ChosenFile]</code></td><td>native</td><td align="center">✓</td><td align="center">✓</td><td align="center">✓</td><td align="center">✓</td><td align="center">✓</td><td align="center">✓</td></tr>
<tr><td colspan="9">AppKit: only through the host's own: dropFiles on RadioButton: the window's drop routing told the driver's files, no dragging session<br>UIKit: only through the host's own: dropFiles on RadioButton: the drop interaction's handler told the driver's files, no drag session<br>Android Views: only through the host's own: dropFiles on RadioButton: the view's drag listener's report told the driver's documents, no drag started<br>WinUI 3: only through the host's own: dropFiles on RadioButton: the relay's drop report told the driver's files, no drag WinUI began<br>GTK 4: only through the host's own: dropFiles on RadioButton: the drop target's signal told the driver's files, no drag GTK began<br>Web: only through the host's own: dropFiles on RadioButton: the DOM's drag events dispatched by the driver with its files, no drag the browser began</td></tr></tbody>
<tbody><tr></tr><tr><td><code>onFrameChanged</code> (<code>frameChanged</code>)</td><td>event</td><td><code>[Double]</code></td><td>native</td><td align="center">✅</td><td align="center">✅</td><td align="center">✅</td><td align="center">✅</td><td align="center">✅</td><td align="center">✅</td></tr></tbody>
<tbody><tr></tr><tr><td><code>gridColumn</code></td><td>property</td><td><code>Int</code></td><td>stateUI</td><td align="center">✅</td><td align="center">✅</td><td align="center">✅</td><td align="center">✅</td><td align="center">✅</td><td align="center">✅</td></tr></tbody>
<tbody><tr></tr><tr><td><code>gridColumnSpan</code></td><td>property</td><td><code>Int</code></td><td>stateUI</td><td align="center">✅</td><td align="center">✅</td><td align="center">✅</td><td align="center">✅</td><td align="center">✅</td><td align="center">✅</td></tr></tbody>
<tbody><tr></tr><tr><td><code>gridRow</code></td><td>property</td><td><code>Int</code></td><td>stateUI</td><td align="center">✅</td><td align="center">✅</td><td align="center">✅</td><td align="center">✅</td><td align="center">✅</td><td align="center">✅</td></tr></tbody>
<tbody><tr></tr><tr><td><code>gridRowSpan</code></td><td>property</td><td><code>Int</code></td><td>stateUI</td><td align="center">✅</td><td align="center">✅</td><td align="center">✅</td><td align="center">✅</td><td align="center">✅</td><td align="center">✅</td></tr></tbody>
<tbody><tr></tr><tr><td><code>horizontalAlignment</code></td><td>property</td><td><code>Alignment</code></td><td>native</td><td align="center">✅</td><td align="center">✅</td><td align="center">✅</td><td align="center">✅</td><td align="center">✅</td><td align="center">✅</td></tr></tbody>
<tbody><tr></tr><tr><td><code>margin</code></td><td>property</td><td><code>Insets</code></td><td>native</td><td align="center">✅</td><td align="center">✅</td><td align="center">✅</td><td align="center">✅</td><td align="center">✅</td><td align="center">✅</td></tr></tbody>
<tbody><tr></tr><tr><td rowspan="2"><code>panTouchCount</code></td><td>property</td><td><code>Int</code></td><td>structure</td><td align="center">✓</td><td align="center">✓</td><td align="center">☑️</td><td align="center">✅</td><td align="center">✅</td><td align="center">✅</td></tr>
<tr><td colspan="9">AppKit: only through the host's own: pan on RadioButton: handed to the host's recognizer or handler, no NSEvent sent<br>UIKit: only through the host's own: pan on RadioButton: the view's listening handed the recognizer's states, no touch sent<br>Android Views: The host layer hears a one-finger pan only; any other <code>panTouchCount</code> turns the pan off.</td></tr></tbody>
<tbody><tr></tr><tr><td rowspan="2"><code>onPanUpdated</code> (<code>panUpdated</code>)</td><td>event</td><td><code>(GesturePhase, Double, Double)</code></td><td>native</td><td align="center">✓</td><td align="center">✓</td><td align="center">✅</td><td align="center">✅</td><td align="center">✅</td><td align="center">✅</td></tr>
<tr><td colspan="9">AppKit: only through the host's own: pan on RadioButton: handed to the host's recognizer or handler, no NSEvent sent<br>UIKit: only through the host's own: pan on RadioButton: the view's listening handed the recognizer's states, no touch sent</td></tr></tbody>
<tbody><tr></tr><tr><td rowspan="2"><code>panXChannel</code></td><td>property</td><td><code>Int</code></td><td>structure</td><td align="center">✓</td><td align="center">✓</td><td align="center">✅</td><td align="center">✅</td><td align="center">✅</td><td align="center">✅</td></tr>
<tr><td colspan="9">AppKit: only through the host's own: pan on RadioButton: handed to the host's recognizer or handler, no NSEvent sent<br>UIKit: only through the host's own: pan on RadioButton: the view's listening handed the recognizer's states, no touch sent</td></tr></tbody>
<tbody><tr></tr><tr><td rowspan="2"><code>panYChannel</code></td><td>property</td><td><code>Int</code></td><td>structure</td><td align="center">✓</td><td align="center">✓</td><td align="center">✅</td><td align="center">✅</td><td align="center">✅</td><td align="center">✅</td></tr>
<tr><td colspan="9">AppKit: only through the host's own: pan on RadioButton: handed to the host's recognizer or handler, no NSEvent sent<br>UIKit: only through the host's own: pan on RadioButton: the view's listening handed the recognizer's states, no touch sent</td></tr></tbody>
<tbody><tr></tr><tr><td rowspan="2"><code>onPinchUpdated</code> (<code>pinchUpdated</code>)</td><td>event</td><td><code>(GesturePhase, Double, Point)</code></td><td>native</td><td align="center">✓</td><td align="center">✓</td><td align="center">✅</td><td align="center">✅</td><td align="center">✓</td><td align="center">✅</td></tr>
<tr><td colspan="9">AppKit: only through the host's own: pinch on RadioButton: handed to the host's recognizer or handler, no NSEvent sent<br>UIKit: only through the host's own: pinch on RadioButton: the view's listening handed the recognizer's states, no touch sent<br>GTK 4: only through the host's own: pinch on RadioButton: the fingers' place handed to the host's recognizer as GTK's zoom would: GTK takes no touch a driver puts down</td></tr></tbody>
<tbody><tr></tr><tr><td rowspan="2"><code>onPointerEntered</code> (<code>pointerEntered</code>)</td><td>event</td><td></td><td>native</td><td align="center">✓</td><td align="center">✓</td><td align="center">✅</td><td align="center">✅</td><td align="center">✅</td><td align="center">✅</td></tr>
<tr><td colspan="9">AppKit: only through the host's own: hover on RadioButton: handed to the host's recognizer or handler, no NSEvent sent<br>UIKit: only through the host's own: hover on RadioButton: the view's listening handed the recognizer's states, no touch sent</td></tr></tbody>
<tbody><tr></tr><tr><td rowspan="2"><code>onPointerExited</code> (<code>pointerExited</code>)</td><td>event</td><td></td><td>native</td><td align="center">✓</td><td align="center">✓</td><td align="center">✅</td><td align="center">✅</td><td align="center">✅</td><td align="center">✅</td></tr>
<tr><td colspan="9">AppKit: only through the host's own: hover on RadioButton: handed to the host's recognizer or handler, no NSEvent sent<br>UIKit: only through the host's own: hover on RadioButton: the view's listening handed the recognizer's states, no touch sent</td></tr></tbody>
<tbody><tr></tr><tr><td rowspan="2"><code>onPointerMoved</code> (<code>pointerMoved</code>)</td><td>event</td><td><code>Point?</code></td><td>native</td><td align="center">✓</td><td align="center">✓</td><td align="center">✅</td><td align="center">✅</td><td align="center">✅</td><td align="center">✅</td></tr>
<tr><td colspan="9">AppKit: only through the host's own: hover on RadioButton: handed to the host's recognizer or handler, no NSEvent sent<br>UIKit: only through the host's own: hover on RadioButton: the view's listening handed the recognizer's states, no touch sent</td></tr></tbody>
<tbody><tr></tr><tr><td rowspan="2"><code>onPointerPressed</code> (<code>pointerPressed</code>)</td><td>event</td><td><code>Point?</code></td><td>native</td><td align="center">✓</td><td align="center">✓</td><td align="center">✅</td><td align="center">✅</td><td align="center">✅</td><td align="center">✅</td></tr>
<tr><td colspan="9">AppKit: only through the host's own: hover on RadioButton: handed to the host's recognizer or handler, no NSEvent sent<br>UIKit: only through the host's own: hover on RadioButton: the view's listening handed the recognizer's states, no touch sent</td></tr></tbody>
<tbody><tr></tr><tr><td rowspan="2"><code>onPointerReleased</code> (<code>pointerReleased</code>)</td><td>event</td><td><code>Point?</code></td><td>native</td><td align="center">✓</td><td align="center">✓</td><td align="center">✅</td><td align="center">✅</td><td align="center">✅</td><td align="center">✅</td></tr>
<tr><td colspan="9">AppKit: only through the host's own: hover on RadioButton: handed to the host's recognizer or handler, no NSEvent sent<br>UIKit: only through the host's own: hover on RadioButton: the view's listening handed the recognizer's states, no touch sent</td></tr></tbody>
<tbody><tr></tr><tr><td rowspan="2"><code>swipeDirection</code></td><td>property</td><td><code>SwipeDirection</code></td><td>structure</td><td align="center">✓</td><td align="center">✓</td><td align="center">✅</td><td align="center">✅</td><td align="center">✅</td><td align="center">✅</td></tr>
<tr><td colspan="9">AppKit: only through the host's own: pan on RadioButton: handed to the host's recognizer or handler, no NSEvent sent<br>UIKit: only through the host's own: pan on RadioButton: the view's listening handed the recognizer's states, no touch sent</td></tr></tbody>
<tbody><tr></tr><tr><td rowspan="2"><code>swipeThreshold</code></td><td>property</td><td><code>Double</code></td><td>structure</td><td align="center">✓</td><td align="center">✓</td><td align="center">✅</td><td align="center">✅</td><td align="center">✅</td><td align="center">✅</td></tr>
<tr><td colspan="9">AppKit: only through the host's own: pan on RadioButton: handed to the host's recognizer or handler, no NSEvent sent<br>UIKit: only through the host's own: pan on RadioButton: the view's listening handed the recognizer's states, no touch sent</td></tr></tbody>
<tbody><tr></tr><tr><td rowspan="2"><code>onSwiped</code> (<code>swiped</code>)</td><td>event</td><td><code>SwipeDirection</code></td><td>native</td><td align="center">✓</td><td align="center">✓</td><td align="center">✅</td><td align="center">✅</td><td align="center">✅</td><td align="center">✅</td></tr>
<tr><td colspan="9">AppKit: only through the host's own: pan on RadioButton: handed to the host's recognizer or handler, no NSEvent sent<br>UIKit: only through the host's own: pan on RadioButton: the view's listening handed the recognizer's states, no touch sent</td></tr></tbody>
<tbody><tr></tr><tr><td rowspan="2"><code>tapCount</code></td><td>property</td><td><code>Int</code></td><td>structure</td><td align="center">✓</td><td align="center">✓</td><td align="center">✅</td><td align="center">✅</td><td align="center">✅</td><td align="center">✅</td></tr>
<tr><td colspan="9">AppKit: only through the host's own: tap on RadioButton: handed to the host's recognizer or handler, no NSEvent sent<br>UIKit: only through the host's own: tap on RadioButton: the view's listening handed the recognizer's states, no touch sent</td></tr></tbody>
<tbody><tr></tr><tr><td rowspan="2"><code>onTapped</code> (<code>tapped</code>)</td><td>event</td><td></td><td>native</td><td align="center">✓</td><td align="center">✓</td><td align="center">✅</td><td align="center">✅</td><td align="center">✅</td><td align="center">✅</td></tr>
<tr><td colspan="9">AppKit: only through the host's own: tap on RadioButton: handed to the host's recognizer or handler, no NSEvent sent<br>UIKit: only through the host's own: tap on RadioButton: the view's listening handed the recognizer's states, no touch sent</td></tr></tbody>
<tbody><tr></tr><tr><td><code>verticalAlignment</code></td><td>property</td><td><code>Alignment</code></td><td>native</td><td align="center">✅</td><td align="center">✅</td><td align="center">✅</td><td align="center">✅</td><td align="center">✅</td><td align="center">✅</td></tr></tbody>
</table>

## From [TextualElement](tiers/TextualElement.md)

What every element showing words has: the words, and the case they are drawn in.

<table>
<thead><tr><th>Member</th><th>Kind</th><th>Value</th><th>Layer</th><th>AppKit</th><th>UIKit</th><th>Android Views</th><th>WinUI 3</th><th>GTK 4</th><th>Web</th></tr></thead>
<tbody><tr></tr><tr><td><code>text</code></td><td>property</td><td><code>String</code></td><td>native</td><td align="center">✅</td><td align="center">✅</td><td align="center">✅</td><td align="center">✅</td><td align="center">✅</td><td align="center">✅</td></tr></tbody>
<tbody><tr></tr><tr><td><code>textCase</code></td><td>property</td><td><code>TextCase</code></td><td>native</td><td align="center">✅</td><td align="center">✅</td><td align="center">✅</td><td align="center">✅</td><td align="center">✅</td><td align="center">✅</td></tr></tbody>
</table>

## From [TextStyleElement](tiers/TextStyleElement.md)

How text looks wherever it is drawn: its colour and the space between its letters.

<table>
<thead><tr><th>Member</th><th>Kind</th><th>Value</th><th>Layer</th><th>AppKit</th><th>UIKit</th><th>Android Views</th><th>WinUI 3</th><th>GTK 4</th><th>Web</th></tr></thead>
<tbody><tr></tr><tr><td rowspan="2"><code>tracking</code></td><td>property</td><td><code>Double</code></td><td>native</td><td align="center"></td><td align="center"></td><td align="center"></td><td align="center"></td><td align="center"></td><td align="center"></td></tr>
<tr><td colspan="9">AppKit, UIKit, Android Views, WinUI 3, GTK 4, Web: not realized</td></tr></tbody>
<tbody><tr></tr><tr><td><code>textColor</code></td><td>property</td><td><code>Color</code></td><td>native</td><td align="center">✅</td><td align="center">✅</td><td align="center">✅</td><td align="center">✅</td><td align="center">✅</td><td align="center">✅</td></tr></tbody>
</table>

## From [FontElement](tiers/FontElement.md)

The font text is drawn in: its family, its size, its weight and slant, and whether it follows the user's text-size setting.

<table>
<thead><tr><th>Member</th><th>Kind</th><th>Value</th><th>Layer</th><th>AppKit</th><th>UIKit</th><th>Android Views</th><th>WinUI 3</th><th>GTK 4</th><th>Web</th></tr></thead>
<tbody><tr></tr><tr><td><code>fontAttributes</code></td><td>property</td><td><code>FontAttributes</code></td><td>native</td><td align="center">✅</td><td align="center">✅</td><td align="center">✅</td><td align="center">✅</td><td align="center">✅</td><td align="center">✅</td></tr></tbody>
<tbody><tr></tr><tr><td rowspan="2"><code>isFontAutoScalingEnabled</code></td><td>property</td><td><code>Bool</code></td><td>adaptive</td><td align="center">–</td><td align="center">✅</td><td align="center">✅</td><td align="center">✅</td><td align="center">✅</td><td align="center">✅</td></tr>
<tr><td colspan="9">AppKit: macOS gives an application no text size of the user's to follow.</td></tr></tbody>
<tbody><tr></tr><tr><td rowspan="2"><code>fontFamily</code></td><td>property</td><td><code>Name</code></td><td>native</td><td align="center">✅</td><td align="center">✅</td><td align="center">·</td><td align="center">✅</td><td align="center">✅</td><td align="center">✅</td></tr>
<tr><td colspan="9">Android Views: cannot read a family - Android's typeface keeps no family's name</td></tr></tbody>
<tbody><tr></tr><tr><td><code>fontSize</code></td><td>property</td><td><code>Double</code></td><td>native</td><td align="center">✅</td><td align="center">✅</td><td align="center">✅</td><td align="center">✅</td><td align="center">✅</td><td align="center">✅</td></tr></tbody>
</table>

## From [PaddingElement](tiers/PaddingElement.md)

The space kept inside an element, around what it holds.

<table>
<thead><tr><th>Member</th><th>Kind</th><th>Value</th><th>Layer</th><th>AppKit</th><th>UIKit</th><th>Android Views</th><th>WinUI 3</th><th>GTK 4</th><th>Web</th></tr></thead>
<tbody><tr></tr><tr><td rowspan="2"><code>padding</code></td><td>property</td><td><code>Insets</code></td><td>native</td><td align="center">·</td><td align="center">✅</td><td align="center">✅</td><td align="center">✅</td><td align="center">✓</td><td align="center">✅</td></tr>
<tr><td colspan="9">AppKit: cannot read padding of RadioButton - AppKit's driver has no path for it yet<br>GTK 4: only through the host's own: read padding of RadioButton: the class of the host's style sheet the widget wears: GTK reads back no padding</td></tr></tbody>
</table>

## From [BorderElement](tiers/BorderElement.md)

What an element draws of its own box: the shape its background, its outline and its cut follow, and the outline.

<table>
<thead><tr><th>Member</th><th>Kind</th><th>Value</th><th>Layer</th><th>AppKit</th><th>UIKit</th><th>Android Views</th><th>WinUI 3</th><th>GTK 4</th><th>Web</th></tr></thead>
<tbody><tr></tr><tr><td rowspan="2"><code>shape</code></td><td>property</td><td><code>ContainerShape</code></td><td>stateUI</td><td align="center"></td><td align="center"></td><td align="center"></td><td align="center"></td><td align="center"></td><td align="center"></td></tr>
<tr><td colspan="9">AppKit, UIKit, Android Views, WinUI 3, GTK 4, Web: not realized</td></tr></tbody>
<tbody><tr></tr><tr><td rowspan="2"><code>stroke</code></td><td>property</td><td><code>Brush</code></td><td>stateUI</td><td align="center"></td><td align="center"></td><td align="center"></td><td align="center"></td><td align="center"></td><td align="center"></td></tr>
<tr><td colspan="9">AppKit, UIKit, Android Views, WinUI 3, GTK 4, Web: not realized</td></tr></tbody>
<tbody><tr></tr><tr><td rowspan="2"><code>lineWidth</code></td><td>property</td><td><code>Double</code></td><td>stateUI</td><td align="center"></td><td align="center"></td><td align="center"></td><td align="center"></td><td align="center"></td><td align="center"></td></tr>
<tr><td colspan="9">AppKit, UIKit, Android Views, WinUI 3, GTK 4, Web: not realized</td></tr></tbody>
</table>
