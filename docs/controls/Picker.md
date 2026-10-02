<!-- Rendered by ControlDictionaryTests from the contracts and the verdicts each host's runs of its tests wrote under lib/StateUI/exports/marks: STATEUI_UPDATE_DOCS=1 swift test --filter ControlDictionaryTests writes it again. -->

# Picker

One choice out of a list.

```swift
@State var size = 1

Picker(["Small", "Medium", "Large"])
    .selectedIndex($size)
    .placeholder("Size")
```

Layer: `native`. Every base host presents it with its native toolkit.

Inherits: [PropertyContainer](tiers/PropertyContainer.md) · [VisualElement](tiers/VisualElement.md) · [View](tiers/View.md) · [TextStyleElement](tiers/TextStyleElement.md) · [FontElement](tiers/FontElement.md) · [TextAlignmentElement](tiers/TextAlignmentElement.md) · [TintElement](tiers/TintElement.md)

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
<thead><tr><th>Host</th><th>Created</th><th>Members (82)</th><th>Realization</th></tr></thead>
<tbody><tr></tr><tr><td>AppKit</td><td align="center">✅</td><td>39 ✅ · 1 ☑️ · 26 ✓ · 1 –</td><td><code>NSPopUpButton</code></td></tr></tbody>
<tbody><tr></tr><tr><td>UIKit</td><td align="center">✅</td><td>27 ✅ · 29 ✓ · 3 –</td><td>pop-up <code>UIButton</code> menu</td></tr></tbody>
<tbody><tr></tr><tr><td>Android Views</td><td align="center">✅</td><td>53 ✅ · 1 ☑️ · 2 ✓ · 3 –</td><td><code>Spinner</code></td></tr></tbody>
<tbody><tr></tr><tr><td>WinUI 3</td><td align="center">✅</td><td>67 ✅ · 2 ✓</td><td><code>ComboBox</code></td></tr></tbody>
<tbody><tr></tr><tr><td>GTK 4</td><td align="center">✅</td><td>50 ✅ · 11 ✓ · 7 –</td><td><code>GtkDropDown</code></td></tr></tbody>
<tbody><tr></tr><tr><td rowspan="2">Web</td><td align="center"></td><td></td><td><code>&lt;select&gt;</code></td></tr>
<tr><td colspan="3">no host yet</td></tr></tbody>
</table>

Declared in `lib/StateUI/Core/Sources/Contracts/Elements/Controls/PickerContract.swift`.

## Picker's own members

<table>
<thead><tr><th>Member</th><th>Kind</th><th>Value</th><th>Layer</th><th>AppKit</th><th>UIKit</th><th>Android Views</th><th>WinUI 3</th><th>GTK 4</th><th>Web</th></tr></thead>
<tbody><tr></tr><tr><td rowspan="2"><code>onClosed</code> (<code>closed</code>)</td><td>event</td><td></td><td>native</td><td align="center">·</td><td align="center">⏸</td><td align="center">·</td><td align="center">✅</td><td align="center">–</td><td></td></tr>
<tr><td colspan="9">AppKit: cannot read isOpen of Picker - AppKit's driver has no path for it yet<br>UIKit: waits on Picker.isOpen, not realized yet<br>Android Views: cannot open on Picker - Android's driver has no path for it yet<br>GTK 4: GTK's drop-down tells no one its list opened or closed.</td></tr></tbody>
<tbody><tr></tr><tr><td rowspan="2"><code>isOpen</code></td><td>property</td><td><code>Bool</code></td><td>native</td><td align="center">·</td><td align="center"></td><td align="center">·</td><td align="center">✅</td><td align="center">–</td><td></td></tr>
<tr><td colspan="9">AppKit: cannot read isOpen of Picker - AppKit's driver has no path for it yet<br>UIKit: not realized<br>Android Views: cannot open on Picker - Android's driver has no path for it yet<br>GTK 4: GTK's drop-down tells no one its list opened or closed.</td></tr></tbody>
<tbody><tr></tr><tr><td rowspan="2"><code>onOpened</code> (<code>opened</code>)</td><td>event</td><td></td><td>native</td><td align="center">·</td><td align="center">⏸</td><td align="center">·</td><td align="center">✅</td><td align="center">–</td><td></td></tr>
<tr><td colspan="9">AppKit: cannot read isOpen of Picker - AppKit's driver has no path for it yet<br>UIKit: waits on Picker.isOpen, not realized yet<br>Android Views: cannot open on Picker - Android's driver has no path for it yet<br>GTK 4: GTK's drop-down tells no one its list opened or closed.</td></tr></tbody>
<tbody><tr></tr><tr><td rowspan="2"><code>options</code></td><td>property</td><td><code>[String]</code></td><td>structure</td><td align="center">✅</td><td align="center">✓</td><td align="center">✓</td><td align="center">✅</td><td align="center">✅</td><td></td></tr>
<tr><td colspan="9">UIKit: only through the host's own: read options of Picker: the host's own choice, not the menu's<br>Android Views: only through the host's own: read options of Picker: the rows the relay keeps, not the spinner's</td></tr></tbody>
<tbody><tr></tr><tr><td rowspan="2"><code>placeholder</code></td><td>property</td><td><code>String</code></td><td>native</td><td align="center">✅</td><td align="center">✓</td><td align="center">✓</td><td align="center">✅</td><td align="center">–</td><td></td></tr>
<tr><td colspan="9">UIKit: only through the host's own: choose on Picker: the host's choice called, not the menu's action<br>Android Views: only through the host's own: read title of Picker: the rows the relay keeps, not the spinner's<br>GTK 4: GTK's drop-down shows a choice or nothing: it has no words standing for none.</td></tr></tbody>
<tbody><tr></tr><tr><td rowspan="2"><code>selectedIndex</code></td><td>property</td><td><code>Int</code></td><td>native</td><td align="center">✅</td><td align="center">✓</td><td align="center">✅</td><td align="center">✅</td><td align="center">✅</td><td></td></tr>
<tr><td colspan="9">UIKit: only through the host's own: choose on Picker: the host's choice called, not the menu's action</td></tr></tbody>
<tbody><tr></tr><tr><td rowspan="2"><code>onSelectedIndexChanged</code> (<code>selectedIndexChanged</code>)</td><td>event</td><td><code>Int</code></td><td>native</td><td align="center">✓</td><td align="center">✓</td><td align="center">✅</td><td align="center">✅</td><td align="center">✅</td><td></td></tr>
<tr><td colspan="9">AppKit: only through the host's own: choose on Picker: the host's action called, not the pop-up's<br>UIKit: only through the host's own: choose on Picker: the host's choice called, not the menu's action</td></tr></tbody>
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
<tbody><tr></tr><tr><td rowspan="2"><code>focus</code></td><td>act</td><td><code>() -&gt; Bool</code></td><td></td><td align="center">✅</td><td align="center">–</td><td align="center">–</td><td align="center">✅</td><td align="center">✅</td><td></td></tr>
<tr><td colspan="9">UIKit, Android Views: Picker takes no keyboard focus here: it refuses it, and nothing is heard</td></tr></tbody>
<tbody><tr></tr><tr><td><code>frame</code></td><td>property</td><td><code>Rect</code></td><td>structure</td><td align="center">✅</td><td align="center">✅</td><td align="center">✅</td><td align="center">✅</td><td align="center">✅</td><td></td></tr></tbody>
<tbody><tr></tr><tr><td><code>height</code></td><td>property</td><td><code>Double</code></td><td>native</td><td align="center">✅</td><td align="center">✅</td><td align="center">✅</td><td align="center">✅</td><td align="center">✅</td><td></td></tr></tbody>
<tbody><tr></tr><tr><td rowspan="2"><code>ignoresInput</code></td><td>property</td><td><code>Bool</code></td><td>native</td><td align="center">✅</td><td align="center">✅</td><td align="center"></td><td align="center">✅</td><td align="center"></td><td></td></tr>
<tr><td colspan="9">Android Views, GTK 4: not realized</td></tr></tbody>
<tbody><tr></tr><tr><td><code>isAccessibilityHidden</code></td><td>property</td><td><code>Bool</code></td><td>native</td><td align="center">✅</td><td align="center">✅</td><td align="center">✅</td><td align="center">✅</td><td align="center">✅</td><td></td></tr></tbody>
<tbody><tr></tr><tr><td><code>isEnabled</code></td><td>property</td><td><code>Bool</code></td><td>native</td><td align="center">✅</td><td align="center">✅</td><td align="center">✅</td><td align="center">✅</td><td align="center">✅</td><td></td></tr></tbody>
<tbody><tr></tr><tr><td rowspan="2"><code>isFocusedChanged</code></td><td>event</td><td><code>Bool</code></td><td>native</td><td align="center">✅</td><td align="center">–</td><td align="center">–</td><td align="center">✅</td><td align="center">✅</td><td></td></tr>
<tr><td colspan="9">UIKit, Android Views: Picker takes no keyboard focus here: it refuses it, and nothing is heard</td></tr></tbody>
<tbody><tr></tr><tr><td><code>isVisible</code></td><td>property</td><td><code>Bool</code></td><td>native</td><td align="center">✅</td><td align="center">✅</td><td align="center">✅</td><td align="center">✅</td><td align="center">✅</td><td></td></tr></tbody>
<tbody><tr></tr><tr><td><code>layoutDirection</code></td><td>property</td><td><code>LayoutDirection</code></td><td>native</td><td align="center">✅</td><td align="center">✅</td><td align="center">✅</td><td align="center">✅</td><td align="center">✅</td><td></td></tr></tbody>
<tbody><tr></tr><tr><td><code>maximumHeight</code></td><td>property</td><td><code>Double</code></td><td>native</td><td align="center">✅</td><td align="center">✅</td><td align="center">✅</td><td align="center">✅</td><td align="center">✅</td><td></td></tr></tbody>
<tbody><tr></tr><tr><td><code>maximumWidth</code></td><td>property</td><td><code>Double</code></td><td>native</td><td align="center">✅</td><td align="center">✅</td><td align="center">✅</td><td align="center">✅</td><td align="center">✅</td><td></td></tr></tbody>
<tbody><tr></tr><tr><td><code>minimumHeight</code></td><td>property</td><td><code>Double</code></td><td>native</td><td align="center">✅</td><td align="center">✅</td><td align="center">✅</td><td align="center">✅</td><td align="center">✅</td><td></td></tr></tbody>
<tbody><tr></tr><tr><td><code>minimumWidth</code></td><td>property</td><td><code>Double</code></td><td>native</td><td align="center">✅</td><td align="center">✅</td><td align="center">✅</td><td align="center">✅</td><td align="center">✅</td><td></td></tr></tbody>
<tbody><tr></tr><tr><td><code>opacity</code></td><td>property</td><td><code>Double</code></td><td>native</td><td align="center">✅</td><td align="center">✅</td><td align="center">✅</td><td align="center">✅</td><td align="center">✅</td><td></td></tr></tbody>
<tbody><tr></tr><tr><td rowspan="2"><code>pivotX</code></td><td>property</td><td><code>Double</code></td><td>native</td><td align="center">✓</td><td align="center">✓</td><td align="center">✅</td><td align="center">✅</td><td align="center">✓</td><td></td></tr>
<tr><td colspan="9">AppKit, UIKit: only through the host's own: read pivotX of Picker: the host's own transform, checked against the layer it composed itself<br>GTK 4: only through the host's own: read pivotX of Picker: the host's own transform: GTK reads back no part of one</td></tr></tbody>
<tbody><tr></tr><tr><td rowspan="2"><code>pivotY</code></td><td>property</td><td><code>Double</code></td><td>native</td><td align="center">✓</td><td align="center">✓</td><td align="center">✅</td><td align="center">✅</td><td align="center">✓</td><td></td></tr>
<tr><td colspan="9">AppKit, UIKit: only through the host's own: read pivotY of Picker: the host's own transform, checked against the layer it composed itself<br>GTK 4: only through the host's own: read pivotY of Picker: the host's own transform: GTK reads back no part of one</td></tr></tbody>
<tbody><tr></tr><tr><td rowspan="2"><code>rotation</code></td><td>property</td><td><code>Double</code></td><td>native</td><td align="center">✓</td><td align="center">✓</td><td align="center">✅</td><td align="center">✅</td><td align="center">✓</td><td></td></tr>
<tr><td colspan="9">AppKit, UIKit: only through the host's own: read rotation of Picker: the host's own transform, checked against the layer it composed itself<br>GTK 4: only through the host's own: read rotation of Picker: the host's own transform: GTK reads back no part of one</td></tr></tbody>
<tbody><tr></tr><tr><td rowspan="2"><code>rotationX</code></td><td>property</td><td><code>Double</code></td><td>native</td><td align="center">✓</td><td align="center">✓</td><td align="center">✅</td><td align="center">✓</td><td align="center">✓</td><td></td></tr>
<tr><td colspan="9">AppKit, UIKit: only through the host's own: read rotationX of Picker: the host's own transform, checked against the layer it composed itself<br>WinUI 3: only through the host's own: read rotationX of Picker: the host's own tip, checked against the projection it laid on the element<br>GTK 4: only through the host's own: read rotationX of Picker: the host's own transform: GTK reads back no part of one</td></tr></tbody>
<tbody><tr></tr><tr><td rowspan="2"><code>rotationY</code></td><td>property</td><td><code>Double</code></td><td>native</td><td align="center">✓</td><td align="center">✓</td><td align="center">✅</td><td align="center">✓</td><td align="center">✓</td><td></td></tr>
<tr><td colspan="9">AppKit, UIKit: only through the host's own: read rotationY of Picker: the host's own transform, checked against the layer it composed itself<br>WinUI 3: only through the host's own: read rotationY of Picker: the host's own tip, checked against the projection it laid on the element<br>GTK 4: only through the host's own: read rotationY of Picker: the host's own transform: GTK reads back no part of one</td></tr></tbody>
<tbody><tr></tr><tr><td rowspan="2"><code>scale</code></td><td>property</td><td><code>Double</code></td><td>native</td><td align="center">✓</td><td align="center">✓</td><td align="center">✅</td><td align="center">✅</td><td align="center">✓</td><td></td></tr>
<tr><td colspan="9">AppKit, UIKit: only through the host's own: read scale of Picker: the host's own transform, checked against the layer it composed itself<br>GTK 4: only through the host's own: read scale of Picker: the host's own transform: GTK reads back no part of one</td></tr></tbody>
<tbody><tr></tr><tr><td rowspan="2"><code>scaleX</code></td><td>property</td><td><code>Double</code></td><td>native</td><td align="center">✓</td><td align="center">✓</td><td align="center">✅</td><td align="center">✅</td><td align="center">✓</td><td></td></tr>
<tr><td colspan="9">AppKit, UIKit: only through the host's own: read scaleX of Picker: the host's own transform, checked against the layer it composed itself<br>GTK 4: only through the host's own: read scaleX of Picker: the host's own transform: GTK reads back no part of one</td></tr></tbody>
<tbody><tr></tr><tr><td rowspan="2"><code>scaleY</code></td><td>property</td><td><code>Double</code></td><td>native</td><td align="center">✓</td><td align="center">✓</td><td align="center">✅</td><td align="center">✅</td><td align="center">✓</td><td></td></tr>
<tr><td colspan="9">AppKit, UIKit: only through the host's own: read scaleY of Picker: the host's own transform, checked against the layer it composed itself<br>GTK 4: only through the host's own: read scaleY of Picker: the host's own transform: GTK reads back no part of one</td></tr></tbody>
<tbody><tr></tr><tr><td><code>style</code></td><td>property</td><td><code>Name</code></td><td>structure</td><td align="center">✅</td><td align="center">✅</td><td align="center">✅</td><td align="center">✅</td><td align="center">✅</td><td></td></tr></tbody>
<tbody><tr></tr><tr><td rowspan="2"><code>translationX</code></td><td>property</td><td><code>Double</code></td><td>native</td><td align="center">✓</td><td align="center">✓</td><td align="center">✅</td><td align="center">✅</td><td align="center">✓</td><td></td></tr>
<tr><td colspan="9">AppKit, UIKit: only through the host's own: read translationX of Picker: the host's own transform, checked against the layer it composed itself<br>GTK 4: only through the host's own: read translationX of Picker: the host's own transform: GTK reads back no part of one</td></tr></tbody>
<tbody><tr></tr><tr><td rowspan="2"><code>translationY</code></td><td>property</td><td><code>Double</code></td><td>native</td><td align="center">✓</td><td align="center">✓</td><td align="center">✅</td><td align="center">✅</td><td align="center">✓</td><td></td></tr>
<tr><td colspan="9">AppKit, UIKit: only through the host's own: read translationY of Picker: the host's own transform, checked against the layer it composed itself<br>GTK 4: only through the host's own: read translationY of Picker: the host's own transform: GTK reads back no part of one</td></tr></tbody>
<tbody><tr></tr><tr><td rowspan="2"><code>unfocus</code></td><td>act</td><td><code>() -&gt; Void</code></td><td></td><td align="center">✅</td><td align="center">–</td><td align="center">–</td><td align="center">✅</td><td align="center">✅</td><td></td></tr>
<tr><td colspan="9">UIKit, Android Views: Picker takes no keyboard focus here: it refuses it, and nothing is heard</td></tr></tbody>
<tbody><tr></tr><tr><td><code>width</code></td><td>property</td><td><code>Double</code></td><td>native</td><td align="center">✅</td><td align="center">✅</td><td align="center">✅</td><td align="center">✅</td><td align="center">✅</td><td></td></tr></tbody>
<tbody><tr></tr><tr><td rowspan="2"><code>zIndex</code></td><td>property</td><td><code>Int</code></td><td>native</td><td align="center"></td><td align="center"></td><td align="center"></td><td align="center"></td><td align="center"></td><td></td></tr>
<tr><td colspan="9">AppKit, UIKit, Android Views, WinUI 3, GTK 4: not realized</td></tr></tbody>
</table>

## From [View](tiers/View.md)

What every view a layout positions has: where it sits in its layout, the space kept around it, and the gestures, drags and frame reports it answers.

<table>
<thead><tr><th>Member</th><th>Kind</th><th>Value</th><th>Layer</th><th>AppKit</th><th>UIKit</th><th>Android Views</th><th>WinUI 3</th><th>GTK 4</th><th>Web</th></tr></thead>
<tbody><tr></tr><tr><td rowspan="2"><code>allowsDrop</code></td><td>property</td><td><code>Bool</code></td><td>native</td><td align="center"></td><td align="center"></td><td align="center"></td><td align="center"></td><td align="center"></td><td></td></tr>
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
<tbody><tr></tr><tr><td rowspan="2"><code>onDragEnded</code> (<code>dragEnded</code>)</td><td>event</td><td></td><td>native</td><td align="center"></td><td align="center"></td><td align="center"></td><td align="center"></td><td align="center"></td><td></td></tr>
<tr><td colspan="9">AppKit, UIKit, Android Views, WinUI 3, GTK 4: not realized</td></tr></tbody>
<tbody><tr></tr><tr><td><code>onFrameChanged</code> (<code>frameChanged</code>)</td><td>event</td><td><code>[Double]</code></td><td>native</td><td align="center">✅</td><td align="center">✅</td><td align="center">✅</td><td align="center">✅</td><td align="center">✅</td><td></td></tr></tbody>
<tbody><tr></tr><tr><td><code>gridColumn</code></td><td>property</td><td><code>Int</code></td><td>stateUI</td><td align="center">✅</td><td align="center">✅</td><td align="center">✅</td><td align="center">✅</td><td align="center">✅</td><td></td></tr></tbody>
<tbody><tr></tr><tr><td><code>gridColumnSpan</code></td><td>property</td><td><code>Int</code></td><td>stateUI</td><td align="center">✅</td><td align="center">✅</td><td align="center">✅</td><td align="center">✅</td><td align="center">✅</td><td></td></tr></tbody>
<tbody><tr></tr><tr><td><code>gridRow</code></td><td>property</td><td><code>Int</code></td><td>stateUI</td><td align="center">✅</td><td align="center">✅</td><td align="center">✅</td><td align="center">✅</td><td align="center">✅</td><td></td></tr></tbody>
<tbody><tr></tr><tr><td><code>gridRowSpan</code></td><td>property</td><td><code>Int</code></td><td>stateUI</td><td align="center">✅</td><td align="center">✅</td><td align="center">✅</td><td align="center">✅</td><td align="center">✅</td><td></td></tr></tbody>
<tbody><tr></tr><tr><td><code>horizontalAlignment</code></td><td>property</td><td><code>Alignment</code></td><td>native</td><td align="center">✅</td><td align="center">✅</td><td align="center">✅</td><td align="center">✅</td><td align="center">✅</td><td></td></tr></tbody>
<tbody><tr></tr><tr><td><code>margin</code></td><td>property</td><td><code>Insets</code></td><td>native</td><td align="center">✅</td><td align="center">✅</td><td align="center">✅</td><td align="center">✅</td><td align="center">✅</td><td></td></tr></tbody>
<tbody><tr></tr><tr><td rowspan="2"><code>panTouchCount</code></td><td>property</td><td><code>Int</code></td><td>structure</td><td align="center">✓</td><td align="center">✓</td><td align="center">☑️</td><td align="center">✅</td><td align="center">✅</td><td></td></tr>
<tr><td colspan="9">AppKit: only through the host's own: pan on Picker: handed to the host's recognizer or handler, no NSEvent sent<br>UIKit: only through the host's own: pan on Picker: the view's listening handed the recognizer's states, no touch sent<br>Android Views: The host layer hears a one-finger pan only; any other <code>panTouchCount</code> turns the pan off.</td></tr></tbody>
<tbody><tr></tr><tr><td rowspan="2"><code>onPanUpdated</code> (<code>panUpdated</code>)</td><td>event</td><td><code>(GesturePhase, Double, Double)</code></td><td>native</td><td align="center">✓</td><td align="center">✓</td><td align="center">✅</td><td align="center">✅</td><td align="center">✅</td><td></td></tr>
<tr><td colspan="9">AppKit: only through the host's own: pan on Picker: handed to the host's recognizer or handler, no NSEvent sent<br>UIKit: only through the host's own: pan on Picker: the view's listening handed the recognizer's states, no touch sent</td></tr></tbody>
<tbody><tr></tr><tr><td rowspan="2"><code>panXChannel</code></td><td>property</td><td><code>Int</code></td><td>structure</td><td align="center">✓</td><td align="center">✓</td><td align="center">✅</td><td align="center">✅</td><td align="center">✅</td><td></td></tr>
<tr><td colspan="9">AppKit: only through the host's own: pan on Picker: handed to the host's recognizer or handler, no NSEvent sent<br>UIKit: only through the host's own: pan on Picker: the view's listening handed the recognizer's states, no touch sent</td></tr></tbody>
<tbody><tr></tr><tr><td rowspan="2"><code>panYChannel</code></td><td>property</td><td><code>Int</code></td><td>structure</td><td align="center">✓</td><td align="center">✓</td><td align="center">✅</td><td align="center">✅</td><td align="center">✅</td><td></td></tr>
<tr><td colspan="9">AppKit: only through the host's own: pan on Picker: handed to the host's recognizer or handler, no NSEvent sent<br>UIKit: only through the host's own: pan on Picker: the view's listening handed the recognizer's states, no touch sent</td></tr></tbody>
<tbody><tr></tr><tr><td rowspan="2"><code>onPinchUpdated</code> (<code>pinchUpdated</code>)</td><td>event</td><td><code>(GesturePhase, Double, Point)</code></td><td>native</td><td align="center">✓</td><td align="center">✓</td><td align="center">✅</td><td align="center">✅</td><td align="center">✓</td><td></td></tr>
<tr><td colspan="9">AppKit: only through the host's own: pinch on Picker: handed to the host's recognizer or handler, no NSEvent sent<br>UIKit: only through the host's own: pinch on Picker: the view's listening handed the recognizer's states, no touch sent<br>GTK 4: only through the host's own: pinch on Picker: the fingers' place handed to the host's recognizer as GTK's zoom would: GTK takes no touch a driver puts down</td></tr></tbody>
<tbody><tr></tr><tr><td rowspan="2"><code>onPointerEntered</code> (<code>pointerEntered</code>)</td><td>event</td><td></td><td>native</td><td align="center">✓</td><td align="center">✓</td><td align="center">✅</td><td align="center">✅</td><td align="center">✅</td><td></td></tr>
<tr><td colspan="9">AppKit: only through the host's own: hover on Picker: handed to the host's recognizer or handler, no NSEvent sent<br>UIKit: only through the host's own: hover on Picker: the view's listening handed the recognizer's states, no touch sent</td></tr></tbody>
<tbody><tr></tr><tr><td rowspan="2"><code>onPointerExited</code> (<code>pointerExited</code>)</td><td>event</td><td></td><td>native</td><td align="center">✓</td><td align="center">✓</td><td align="center">✅</td><td align="center">✅</td><td align="center">✅</td><td></td></tr>
<tr><td colspan="9">AppKit: only through the host's own: hover on Picker: handed to the host's recognizer or handler, no NSEvent sent<br>UIKit: only through the host's own: hover on Picker: the view's listening handed the recognizer's states, no touch sent</td></tr></tbody>
<tbody><tr></tr><tr><td rowspan="2"><code>onPointerMoved</code> (<code>pointerMoved</code>)</td><td>event</td><td><code>Point?</code></td><td>native</td><td align="center">✓</td><td align="center">✓</td><td align="center">✅</td><td align="center">✅</td><td align="center">✅</td><td></td></tr>
<tr><td colspan="9">AppKit: only through the host's own: hover on Picker: handed to the host's recognizer or handler, no NSEvent sent<br>UIKit: only through the host's own: hover on Picker: the view's listening handed the recognizer's states, no touch sent</td></tr></tbody>
<tbody><tr></tr><tr><td rowspan="2"><code>onPointerPressed</code> (<code>pointerPressed</code>)</td><td>event</td><td><code>Point?</code></td><td>native</td><td align="center">✓</td><td align="center">✓</td><td align="center">✅</td><td align="center">✅</td><td align="center">✅</td><td></td></tr>
<tr><td colspan="9">AppKit: only through the host's own: hover on Picker: handed to the host's recognizer or handler, no NSEvent sent<br>UIKit: only through the host's own: hover on Picker: the view's listening handed the recognizer's states, no touch sent</td></tr></tbody>
<tbody><tr></tr><tr><td rowspan="2"><code>onPointerReleased</code> (<code>pointerReleased</code>)</td><td>event</td><td><code>Point?</code></td><td>native</td><td align="center">✓</td><td align="center">✓</td><td align="center">✅</td><td align="center">✅</td><td align="center">✅</td><td></td></tr>
<tr><td colspan="9">AppKit: only through the host's own: hover on Picker: handed to the host's recognizer or handler, no NSEvent sent<br>UIKit: only through the host's own: hover on Picker: the view's listening handed the recognizer's states, no touch sent</td></tr></tbody>
<tbody><tr></tr><tr><td rowspan="2"><code>swipeDirection</code></td><td>property</td><td><code>SwipeDirection</code></td><td>structure</td><td align="center">✓</td><td align="center">✓</td><td align="center">✅</td><td align="center">✅</td><td align="center">✅</td><td></td></tr>
<tr><td colspan="9">AppKit: only through the host's own: pan on Picker: handed to the host's recognizer or handler, no NSEvent sent<br>UIKit: only through the host's own: pan on Picker: the view's listening handed the recognizer's states, no touch sent</td></tr></tbody>
<tbody><tr></tr><tr><td rowspan="2"><code>swipeThreshold</code></td><td>property</td><td><code>Double</code></td><td>structure</td><td align="center">✓</td><td align="center">✓</td><td align="center">✅</td><td align="center">✅</td><td align="center">✅</td><td></td></tr>
<tr><td colspan="9">AppKit: only through the host's own: pan on Picker: handed to the host's recognizer or handler, no NSEvent sent<br>UIKit: only through the host's own: pan on Picker: the view's listening handed the recognizer's states, no touch sent</td></tr></tbody>
<tbody><tr></tr><tr><td rowspan="2"><code>onSwiped</code> (<code>swiped</code>)</td><td>event</td><td><code>SwipeDirection</code></td><td>native</td><td align="center">✓</td><td align="center">✓</td><td align="center">✅</td><td align="center">✅</td><td align="center">✅</td><td></td></tr>
<tr><td colspan="9">AppKit: only through the host's own: pan on Picker: handed to the host's recognizer or handler, no NSEvent sent<br>UIKit: only through the host's own: pan on Picker: the view's listening handed the recognizer's states, no touch sent</td></tr></tbody>
<tbody><tr></tr><tr><td rowspan="2"><code>tapCount</code></td><td>property</td><td><code>Int</code></td><td>structure</td><td align="center">✓</td><td align="center">✓</td><td align="center">✅</td><td align="center">✅</td><td align="center">✅</td><td></td></tr>
<tr><td colspan="9">AppKit: only through the host's own: tap on Picker: handed to the host's recognizer or handler, no NSEvent sent<br>UIKit: only through the host's own: tap on Picker: the view's listening handed the recognizer's states, no touch sent</td></tr></tbody>
<tbody><tr></tr><tr><td rowspan="2"><code>onTapped</code> (<code>tapped</code>)</td><td>event</td><td></td><td>native</td><td align="center">✓</td><td align="center">✓</td><td align="center">✅</td><td align="center">✅</td><td align="center">✅</td><td></td></tr>
<tr><td colspan="9">AppKit: only through the host's own: tap on Picker: handed to the host's recognizer or handler, no NSEvent sent<br>UIKit: only through the host's own: tap on Picker: the view's listening handed the recognizer's states, no touch sent</td></tr></tbody>
<tbody><tr></tr><tr><td><code>verticalAlignment</code></td><td>property</td><td><code>Alignment</code></td><td>native</td><td align="center">✅</td><td align="center">✅</td><td align="center">✅</td><td align="center">✅</td><td align="center">✅</td><td></td></tr></tbody>
</table>

## From [TextStyleElement](tiers/TextStyleElement.md)

How text looks wherever it is drawn: its colour and the space between its letters.

<table>
<thead><tr><th>Member</th><th>Kind</th><th>Value</th><th>Layer</th><th>AppKit</th><th>UIKit</th><th>Android Views</th><th>WinUI 3</th><th>GTK 4</th><th>Web</th></tr></thead>
<tbody><tr></tr><tr><td rowspan="2"><code>characterSpacing</code></td><td>property</td><td><code>Double</code></td><td>native</td><td align="center"></td><td align="center"></td><td align="center"></td><td align="center"></td><td align="center"></td><td></td></tr>
<tr><td colspan="9">AppKit, UIKit, Android Views, WinUI 3, GTK 4: not realized</td></tr></tbody>
<tbody><tr></tr><tr><td rowspan="2"><code>textColor</code></td><td>property</td><td><code>Color</code></td><td>native</td><td align="center">✅</td><td align="center"></td><td align="center">·</td><td align="center">✅</td><td align="center">✅</td><td></td></tr>
<tr><td colspan="9">UIKit: not realized<br>Android Views: cannot read textColor of Picker - Android's driver has no path for it yet</td></tr></tbody>
</table>

## From [FontElement](tiers/FontElement.md)

The font text is drawn in: its family, its size, its weight and slant, and whether it follows the user's text-size setting.

<table>
<thead><tr><th>Member</th><th>Kind</th><th>Value</th><th>Layer</th><th>AppKit</th><th>UIKit</th><th>Android Views</th><th>WinUI 3</th><th>GTK 4</th><th>Web</th></tr></thead>
<tbody><tr></tr><tr><td rowspan="2"><code>fontAttributes</code></td><td>property</td><td><code>FontAttributes</code></td><td>native</td><td align="center">✅</td><td align="center"></td><td align="center">·</td><td align="center">✅</td><td align="center">✅</td><td></td></tr>
<tr><td colspan="9">UIKit: not realized<br>Android Views: cannot read fontAttributes of Picker - Android's driver has no path for it yet</td></tr></tbody>
<tbody><tr></tr><tr><td rowspan="2"><code>isFontAutoScalingEnabled</code></td><td>property</td><td><code>Bool</code></td><td>adaptive</td><td align="center">–</td><td align="center"></td><td align="center"></td><td align="center"></td><td align="center"></td><td></td></tr>
<tr><td colspan="9">AppKit: macOS gives an application no text size of the user's to follow.<br>UIKit, Android Views, WinUI 3, GTK 4: not realized</td></tr></tbody>
<tbody><tr></tr><tr><td rowspan="2"><code>fontFamily</code></td><td>property</td><td><code>Name</code></td><td>native</td><td align="center">✅</td><td align="center"></td><td align="center">·</td><td align="center">✅</td><td align="center">✅</td><td></td></tr>
<tr><td colspan="9">UIKit: not realized<br>Android Views: cannot read fontFamily of Picker - Android's driver has no path for it yet</td></tr></tbody>
<tbody><tr></tr><tr><td rowspan="2"><code>fontSize</code></td><td>property</td><td><code>Double</code></td><td>native</td><td align="center">✅</td><td align="center"></td><td align="center">·</td><td align="center">✅</td><td align="center">✅</td><td></td></tr>
<tr><td colspan="9">UIKit: not realized<br>Android Views: cannot read fontSize of Picker - Android's driver has no path for it yet</td></tr></tbody>
</table>

## From [TextAlignmentElement](tiers/TextAlignmentElement.md)

Where text sits inside the space its own element was given.

<table>
<thead><tr><th>Member</th><th>Kind</th><th>Value</th><th>Layer</th><th>AppKit</th><th>UIKit</th><th>Android Views</th><th>WinUI 3</th><th>GTK 4</th><th>Web</th></tr></thead>
<tbody><tr></tr><tr><td rowspan="2"><code>horizontalTextAlignment</code></td><td>property</td><td><code>TextAlignment</code></td><td>native</td><td align="center">✅</td><td align="center"></td><td align="center">·</td><td align="center">✅</td><td align="center">–</td><td></td></tr>
<tr><td colspan="9">UIKit: not realized<br>Android Views: cannot read horizontalTextAlignment of Picker - Android's driver has no path for it yet<br>GTK 4: GTK's drop-down draws its choice with the factory that draws its list: the choice alone takes no alignment without redrawing GNOME's list.</td></tr></tbody>
<tbody><tr></tr><tr><td rowspan="2"><code>verticalTextAlignment</code></td><td>property</td><td><code>TextAlignment</code></td><td>native</td><td align="center"></td><td align="center"></td><td align="center"></td><td align="center"></td><td align="center"></td><td></td></tr>
<tr><td colspan="9">AppKit, UIKit, Android Views, WinUI 3, GTK 4: not realized</td></tr></tbody>
</table>

## From [TintElement](tiers/TintElement.md)

A control's one accent colour.

<table>
<thead><tr><th>Member</th><th>Kind</th><th>Value</th><th>Layer</th><th>AppKit</th><th>UIKit</th><th>Android Views</th><th>WinUI 3</th><th>GTK 4</th><th>Web</th></tr></thead>
<tbody><tr></tr><tr><td rowspan="2"><code>tint</code></td><td>property</td><td><code>Color</code></td><td>adaptive</td><td align="center">✅</td><td align="center"></td><td align="center">·</td><td align="center">✅</td><td align="center">–</td><td></td></tr>
<tr><td colspan="9">UIKit: not realized<br>Android Views: cannot read tint of Picker - Android's driver has no path for it yet<br>GTK 4: A GNOME drop-down wears no accent: a check in its words' colour marks the choice.</td></tr></tbody>
</table>
