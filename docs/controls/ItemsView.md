<!-- Rendered by ControlDictionaryTests from the contracts and the verdicts each host's runs of its tests wrote under lib/StateUI/exports/marks: STATEUI_UPDATE_DOCS=1 swift test --filter ControlDictionaryTests writes it again. -->

# ItemsView

The platform's own collection of items: StateUI says which items there are, in order, and builds the one the platform asks for; the platform scrolls them, holds each in a cell it reuses, lets the user choose and open one, and tells assistive technology about them.

```swift
@State var chosen: String? = nil

ItemsView(["Apple", "Banana", "Cherry"]) { fruit in
    Label(fruit).padding(14, 10)
}
.selection($chosen)
.onItemActivated { fruit in chosen = fruit }
```

Layer: `native`. Every base host presents it with its native toolkit.

Inherits: [PropertyContainer](tiers/PropertyContainer.md) · [VisualElement](tiers/VisualElement.md) · [View](tiers/View.md)

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
<tr><th>Host</th><th>Created</th><th>Members (76)</th><th>Realization</th></tr>
<tr><td>AppKit</td><td align="center">✅</td><td>34 ✅ · 1 ☑️ · 29 ✓</td><td><code>NSCollectionView</code> / <code>NSTableView</code></td></tr>
<tr><td>UIKit</td><td align="center">✅</td><td>31 ✅ · 29 ✓ · 3 –</td><td><code>UICollectionView</code></td></tr>
<tr><td>Android Views</td><td align="center">✅</td><td>61 ✅ · 1 ☑️ · 1 ✓</td><td>AndroidX <code>RecyclerView</code></td></tr>
<tr><td>WinUI 3</td><td align="center">✅</td><td>60 ✅</td><td><code>ItemsView</code></td></tr>
<tr><td>GTK 4</td><td align="center">✅</td><td>51 ✅ · 11 ✓ · 1 –</td><td><code>GtkListView</code> / <code>GtkGridView</code></td></tr>
<tr><td>Web</td><td align="center"></td><td></td><td>semantic list or grid</td></tr>
<tr><td></td><td colspan="3">no host yet</td></tr>
</table>

Declared in `lib/StateUI/Core/Sources/Contracts/Elements/Collections/ItemsViewContract.swift`.

## ItemsView's own members

<table>
<tr><th>Member</th><th>Kind</th><th>Value</th><th>Layer</th><th>AppKit</th><th>UIKit</th><th>Android Views</th><th>WinUI 3</th><th>GTK 4</th><th>Web</th></tr>
<tr><td><code>items</code></td><td>property</td><td><code>ItemsEntries</code></td><td>native</td><td align="center">✅</td><td align="center">✅</td><td align="center">✅</td><td align="center">✅</td><td align="center">✅</td><td></td></tr>
<tr><td><code>itemsLayout</code></td><td>property</td><td><code>ItemsLayout</code></td><td>native</td><td align="center">✅</td><td align="center">✅</td><td align="center">✅</td><td align="center">✅</td><td align="center">✅</td><td></td></tr>
<tr><td><code>selectionMode</code></td><td>property</td><td><code>SelectionMode</code></td><td>native</td><td align="center">✓</td><td align="center">✓</td><td align="center">✓</td><td align="center">✅</td><td align="center">✅</td><td></td></tr>
<tr><td></td><td colspan="9">AppKit: only through the host's own: choose on ItemsView: the collection's delegate told, no click<br>UIKit: only through the host's own: choose on ItemsView: the collection's delegate told, no touch<br>Android Views: only through the host's own: read selectionMode of ItemsView: the mode the relay keeps, which its cells tell TalkBack</td></tr>
<tr><td><code>selectedItems</code></td><td>property</td><td><code>[String]</code></td><td>native</td><td align="center">✓</td><td align="center">✓</td><td align="center">✅</td><td align="center">✅</td><td align="center">✅</td><td></td></tr>
<tr><td></td><td colspan="9">AppKit: only through the host's own: choose on ItemsView: the collection's delegate told, no click<br>UIKit: only through the host's own: choose on ItemsView: the collection's delegate told, no touch</td></tr>
<tr><td><code>selectionChanged</code></td><td>event</td><td><code>[String]</code></td><td>native</td><td align="center">✓</td><td align="center">✓</td><td align="center">✅</td><td align="center">✅</td><td align="center">✅</td><td></td></tr>
<tr><td></td><td colspan="9">AppKit: only through the host's own: choose on ItemsView: the collection's delegate told, no click<br>UIKit: only through the host's own: choose on ItemsView: the collection's delegate told, no touch</td></tr>
<tr><td><code>itemActivated</code></td><td>event</td><td><code>String</code></td><td>adaptive</td><td align="center">✓</td><td align="center">✓</td><td align="center">✅</td><td align="center">✅</td><td align="center">✅</td><td></td></tr>
<tr><td></td><td colspan="9">AppKit: only through the host's own: activate on an item of ItemsView: the collection's delegate told, no click<br>UIKit: only through the host's own: activate on an item of ItemsView: the collection's delegate told, no touch</td></tr>
<tr><td><code>endReachedWithin</code></td><td>property</td><td><code>Int</code></td><td>native</td><td align="center">✅</td><td align="center">✅</td><td align="center">✅</td><td align="center">✅</td><td align="center">✅</td><td></td></tr>
<tr><td><code>endReached</code></td><td>event</td><td></td><td>native</td><td align="center">✅</td><td align="center">✅</td><td align="center">✅</td><td align="center">✅</td><td align="center">✅</td><td></td></tr>
<tr><td><code>realizedChanged</code></td><td>event</td><td><code>[String]</code></td><td>structure</td><td align="center">✅</td><td align="center">✅</td><td align="center">✅</td><td align="center">✅</td><td align="center">✅</td><td></td></tr>
<tr><td><code>scrollTo</code></td><td>act</td><td><code>(String, ScrollAnchor) -&gt; Void</code></td><td></td><td align="center">✅</td><td align="center">✅</td><td align="center">✅</td><td align="center">✅</td><td align="center">✅</td><td></td></tr>
</table>

## From [PropertyContainer](tiers/PropertyContainer.md)

What anything carrying values in the tree has - a control, a `Style`, a text run: the name automation finds it by.

<table>
<tr><th>Member</th><th>Kind</th><th>Value</th><th>Layer</th><th>AppKit</th><th>UIKit</th><th>Android Views</th><th>WinUI 3</th><th>GTK 4</th><th>Web</th></tr>
<tr><td><code>accessibilityIdentifier</code></td><td>property</td><td><code>String</code></td><td>native</td><td align="center">✅</td><td align="center">✅</td><td align="center">✅</td><td align="center">✅</td><td align="center">–</td><td></td></tr>
<tr><td></td><td colspan="9">GTK 4: GTK 4 gives an accessible the identifier a GtkBuilder file names alone: none is set on a widget made in code.</td></tr>
</table>

## From [VisualElement](tiers/VisualElement.md)

What every drawn element has: its size and its bounds, how it is shown and turned, whether it answers input and holds the keyboard focus, the visual states it enters, and what a screen reader says about it.

<table>
<tr><th>Member</th><th>Kind</th><th>Value</th><th>Layer</th><th>AppKit</th><th>UIKit</th><th>Android Views</th><th>WinUI 3</th><th>GTK 4</th><th>Web</th></tr>
<tr><td><code>accessibilityHeadingLevel</code></td><td>property</td><td><code>HeadingLevel</code></td><td>native</td><td align="center">·</td><td align="center">·</td><td align="center">·</td><td align="center">✅</td><td align="center">✅</td><td></td></tr>
<tr><td></td><td colspan="9">AppKit: cannot read a heading's level - AppKit marks a heading, not its level<br>UIKit: cannot read a heading's level - UIKit marks a heading, not its level<br>Android Views: cannot read a heading's level - Android marks a heading, not its level</td></tr>
<tr><td><code>accessibilityHint</code></td><td>property</td><td><code>String</code></td><td>native</td><td align="center">✅</td><td align="center">✅</td><td align="center">✅</td><td align="center">✅</td><td align="center">✅</td><td></td></tr>
<tr><td><code>accessibilityLabel</code></td><td>property</td><td><code>String</code></td><td>native</td><td align="center">✅</td><td align="center">✅</td><td align="center">✅</td><td align="center">✅</td><td align="center">✅</td><td></td></tr>
<tr><td><code>automationExcludedWithChildren</code></td><td>property</td><td><code>Bool</code></td><td>native</td><td align="center">✅</td><td align="center">✅</td><td align="center">✅</td><td align="center">✅</td><td align="center">✅</td><td></td></tr>
<tr><td><code>background</code></td><td>property</td><td><code>Background</code></td><td>native</td><td align="center">☑️</td><td align="center"></td><td align="center">✅</td><td align="center"></td><td align="center"></td><td></td></tr>
<tr><td></td><td colspan="9">AppKit: AppKit paints a colour on this view; a brush is drawn only by a layout.<br>UIKit, WinUI 3, GTK 4: not realized</td></tr>
<tr><td><code>focus</code></td><td>act</td><td><code>() -&gt; Bool</code></td><td></td><td align="center">✅</td><td align="center">–</td><td align="center">✅</td><td align="center">✅</td><td align="center">✅</td><td></td></tr>
<tr><td></td><td colspan="9">UIKit: ItemsView takes no keyboard focus here: it refuses it, and nothing is heard</td></tr>
<tr><td><code>frame</code></td><td>property</td><td><code>Rect</code></td><td>structure</td><td align="center">✅</td><td align="center">✅</td><td align="center">✅</td><td align="center">✅</td><td align="center">✅</td><td></td></tr>
<tr><td><code>height</code></td><td>property</td><td><code>Double</code></td><td>native</td><td align="center">✅</td><td align="center">✅</td><td align="center">✅</td><td align="center">✅</td><td align="center">✅</td><td></td></tr>
<tr><td><code>ignoresInput</code></td><td>property</td><td><code>Bool</code></td><td>native</td><td align="center">✅</td><td align="center">✅</td><td align="center"></td><td align="center"></td><td align="center"></td><td></td></tr>
<tr><td></td><td colspan="9">Android Views, WinUI 3, GTK 4: not realized</td></tr>
<tr><td><code>isAccessibilityHidden</code></td><td>property</td><td><code>Bool</code></td><td>native</td><td align="center">✅</td><td align="center">✅</td><td align="center">✅</td><td align="center">✅</td><td align="center">✅</td><td></td></tr>
<tr><td><code>isEnabled</code></td><td>property</td><td><code>Bool</code></td><td>native</td><td align="center"></td><td align="center"></td><td align="center"></td><td align="center"></td><td align="center">✅</td><td></td></tr>
<tr><td></td><td colspan="9">AppKit, UIKit, Android Views, WinUI 3: not realized</td></tr>
<tr><td><code>isFocusedChanged</code></td><td>event</td><td><code>Bool</code></td><td>native</td><td align="center">✅</td><td align="center">–</td><td align="center">✅</td><td align="center">✅</td><td align="center">✅</td><td></td></tr>
<tr><td></td><td colspan="9">UIKit: ItemsView takes no keyboard focus here: it refuses it, and nothing is heard</td></tr>
<tr><td><code>isVisible</code></td><td>property</td><td><code>Bool</code></td><td>native</td><td align="center">✅</td><td align="center">✅</td><td align="center">✅</td><td align="center">✅</td><td align="center">✅</td><td></td></tr>
<tr><td><code>layoutDirection</code></td><td>property</td><td><code>LayoutDirection</code></td><td>native</td><td align="center">✅</td><td align="center">✅</td><td align="center">✅</td><td align="center"></td><td align="center"></td><td></td></tr>
<tr><td></td><td colspan="9">WinUI 3, GTK 4: not realized</td></tr>
<tr><td><code>maximumHeight</code></td><td>property</td><td><code>Double</code></td><td>native</td><td align="center">✅</td><td align="center">✅</td><td align="center">✅</td><td align="center">✅</td><td align="center">✅</td><td></td></tr>
<tr><td><code>maximumWidth</code></td><td>property</td><td><code>Double</code></td><td>native</td><td align="center">✅</td><td align="center">✅</td><td align="center">✅</td><td align="center">✅</td><td align="center">✅</td><td></td></tr>
<tr><td><code>minimumHeight</code></td><td>property</td><td><code>Double</code></td><td>native</td><td align="center">✅</td><td align="center">✅</td><td align="center">✅</td><td align="center">✅</td><td align="center">✅</td><td></td></tr>
<tr><td><code>minimumWidth</code></td><td>property</td><td><code>Double</code></td><td>native</td><td align="center">✅</td><td align="center">✅</td><td align="center">✅</td><td align="center">✅</td><td align="center">✅</td><td></td></tr>
<tr><td><code>opacity</code></td><td>property</td><td><code>Double</code></td><td>native</td><td align="center">✅</td><td align="center">✅</td><td align="center">✅</td><td align="center">✅</td><td align="center">✅</td><td></td></tr>
<tr><td><code>pivotX</code></td><td>property</td><td><code>Double</code></td><td>native</td><td align="center">✓</td><td align="center">✓</td><td align="center">✅</td><td align="center">✅</td><td align="center">✓</td><td></td></tr>
<tr><td></td><td colspan="9">AppKit, UIKit: only through the host's own: read pivotX of ItemsView: the host's own transform, checked against the layer it composed itself<br>GTK 4: only through the host's own: read pivotX of ItemsView: the host's own transform: GTK reads back no part of one</td></tr>
<tr><td><code>pivotY</code></td><td>property</td><td><code>Double</code></td><td>native</td><td align="center">✓</td><td align="center">✓</td><td align="center">✅</td><td align="center">✅</td><td align="center">✓</td><td></td></tr>
<tr><td></td><td colspan="9">AppKit, UIKit: only through the host's own: read pivotY of ItemsView: the host's own transform, checked against the layer it composed itself<br>GTK 4: only through the host's own: read pivotY of ItemsView: the host's own transform: GTK reads back no part of one</td></tr>
<tr><td><code>rotation</code></td><td>property</td><td><code>Double</code></td><td>native</td><td align="center">✓</td><td align="center">✓</td><td align="center">✅</td><td align="center">✅</td><td align="center">✓</td><td></td></tr>
<tr><td></td><td colspan="9">AppKit, UIKit: only through the host's own: read rotation of ItemsView: the host's own transform, checked against the layer it composed itself<br>GTK 4: only through the host's own: read rotation of ItemsView: the host's own transform: GTK reads back no part of one</td></tr>
<tr><td><code>rotationX</code></td><td>property</td><td><code>Double</code></td><td>native</td><td align="center">✓</td><td align="center">✓</td><td align="center">✅</td><td align="center"></td><td align="center">✓</td><td></td></tr>
<tr><td></td><td colspan="9">AppKit, UIKit: only through the host's own: read rotationX of ItemsView: the host's own transform, checked against the layer it composed itself<br>WinUI 3: not realized<br>GTK 4: only through the host's own: read rotationX of ItemsView: the host's own transform: GTK reads back no part of one</td></tr>
<tr><td><code>rotationY</code></td><td>property</td><td><code>Double</code></td><td>native</td><td align="center">✓</td><td align="center">✓</td><td align="center">✅</td><td align="center"></td><td align="center">✓</td><td></td></tr>
<tr><td></td><td colspan="9">AppKit, UIKit: only through the host's own: read rotationY of ItemsView: the host's own transform, checked against the layer it composed itself<br>WinUI 3: not realized<br>GTK 4: only through the host's own: read rotationY of ItemsView: the host's own transform: GTK reads back no part of one</td></tr>
<tr><td><code>scale</code></td><td>property</td><td><code>Double</code></td><td>native</td><td align="center">✓</td><td align="center">✓</td><td align="center">✅</td><td align="center">✅</td><td align="center">✓</td><td></td></tr>
<tr><td></td><td colspan="9">AppKit, UIKit: only through the host's own: read scale of ItemsView: the host's own transform, checked against the layer it composed itself<br>GTK 4: only through the host's own: read scale of ItemsView: the host's own transform: GTK reads back no part of one</td></tr>
<tr><td><code>scaleX</code></td><td>property</td><td><code>Double</code></td><td>native</td><td align="center">✓</td><td align="center">✓</td><td align="center">✅</td><td align="center">✅</td><td align="center">✓</td><td></td></tr>
<tr><td></td><td colspan="9">AppKit, UIKit: only through the host's own: read scaleX of ItemsView: the host's own transform, checked against the layer it composed itself<br>GTK 4: only through the host's own: read scaleX of ItemsView: the host's own transform: GTK reads back no part of one</td></tr>
<tr><td><code>scaleY</code></td><td>property</td><td><code>Double</code></td><td>native</td><td align="center">✓</td><td align="center">✓</td><td align="center">✅</td><td align="center">✅</td><td align="center">✓</td><td></td></tr>
<tr><td></td><td colspan="9">AppKit, UIKit: only through the host's own: read scaleY of ItemsView: the host's own transform, checked against the layer it composed itself<br>GTK 4: only through the host's own: read scaleY of ItemsView: the host's own transform: GTK reads back no part of one</td></tr>
<tr><td><code>style</code></td><td>property</td><td><code>Name</code></td><td>structure</td><td align="center"></td><td align="center"></td><td align="center"></td><td align="center"></td><td align="center"></td><td></td></tr>
<tr><td></td><td colspan="9">AppKit, UIKit, Android Views, WinUI 3, GTK 4: not realized</td></tr>
<tr><td><code>translationX</code></td><td>property</td><td><code>Double</code></td><td>native</td><td align="center">✓</td><td align="center">✓</td><td align="center">✅</td><td align="center">✅</td><td align="center">✓</td><td></td></tr>
<tr><td></td><td colspan="9">AppKit, UIKit: only through the host's own: read translationX of ItemsView: the host's own transform, checked against the layer it composed itself<br>GTK 4: only through the host's own: read translationX of ItemsView: the host's own transform: GTK reads back no part of one</td></tr>
<tr><td><code>translationY</code></td><td>property</td><td><code>Double</code></td><td>native</td><td align="center">✓</td><td align="center">✓</td><td align="center">✅</td><td align="center">✅</td><td align="center">✓</td><td></td></tr>
<tr><td></td><td colspan="9">AppKit, UIKit: only through the host's own: read translationY of ItemsView: the host's own transform, checked against the layer it composed itself<br>GTK 4: only through the host's own: read translationY of ItemsView: the host's own transform: GTK reads back no part of one</td></tr>
<tr><td><code>unfocus</code></td><td>act</td><td><code>() -&gt; Void</code></td><td></td><td align="center">✅</td><td align="center">–</td><td align="center">✅</td><td align="center">✅</td><td align="center">✅</td><td></td></tr>
<tr><td></td><td colspan="9">UIKit: ItemsView takes no keyboard focus here: it refuses it, and nothing is heard</td></tr>
<tr><td><code>width</code></td><td>property</td><td><code>Double</code></td><td>native</td><td align="center">✅</td><td align="center">✅</td><td align="center">✅</td><td align="center">✅</td><td align="center">✅</td><td></td></tr>
<tr><td><code>zIndex</code></td><td>property</td><td><code>Int</code></td><td>native</td><td align="center"></td><td align="center"></td><td align="center"></td><td align="center"></td><td align="center"></td><td></td></tr>
<tr><td></td><td colspan="9">AppKit, UIKit, Android Views, WinUI 3, GTK 4: not realized</td></tr>
</table>

## From [View](tiers/View.md)

What every view a layout positions has: where it sits in its layout, the space kept around it, and the gestures, drags and frame reports it answers.

<table>
<tr><th>Member</th><th>Kind</th><th>Value</th><th>Layer</th><th>AppKit</th><th>UIKit</th><th>Android Views</th><th>WinUI 3</th><th>GTK 4</th><th>Web</th></tr>
<tr><td><code>allowDrop</code></td><td>property</td><td><code>Bool</code></td><td>native</td><td align="center"></td><td align="center"></td><td align="center"></td><td align="center"></td><td align="center"></td><td></td></tr>
<tr><td></td><td colspan="9">AppKit, UIKit, Android Views, WinUI 3, GTK 4: not realized</td></tr>
<tr><td><code>area</code></td><td>property</td><td><code>Area</code></td><td>structure</td><td align="center">✅</td><td align="center">✅</td><td align="center">✅</td><td align="center">✅</td><td align="center">✅</td><td></td></tr>
<tr><td><code>canDrag</code></td><td>property</td><td><code>Bool</code></td><td>native</td><td align="center"></td><td align="center"></td><td align="center"></td><td align="center"></td><td align="center"></td><td></td></tr>
<tr><td></td><td colspan="9">AppKit, UIKit, Android Views, WinUI 3, GTK 4: not realized</td></tr>
<tr><td><code>onDragLeave</code> (<code>dragLeave</code>)</td><td>event</td><td></td><td>native</td><td align="center"></td><td align="center"></td><td align="center"></td><td align="center"></td><td align="center"></td><td></td></tr>
<tr><td></td><td colspan="9">AppKit, UIKit, Android Views, WinUI 3, GTK 4: not realized</td></tr>
<tr><td><code>onDragOver</code> (<code>dragOver</code>)</td><td>event</td><td></td><td>native</td><td align="center"></td><td align="center"></td><td align="center"></td><td align="center"></td><td align="center"></td><td></td></tr>
<tr><td></td><td colspan="9">AppKit, UIKit, Android Views, WinUI 3, GTK 4: not realized</td></tr>
<tr><td><code>dragStarting</code></td><td>event</td><td></td><td>native</td><td align="center"></td><td align="center"></td><td align="center"></td><td align="center"></td><td align="center"></td><td></td></tr>
<tr><td></td><td colspan="9">AppKit, UIKit, Android Views, WinUI 3, GTK 4: not realized</td></tr>
<tr><td><code>dragText</code></td><td>property</td><td><code>String</code></td><td>native</td><td align="center"></td><td align="center"></td><td align="center"></td><td align="center"></td><td align="center"></td><td></td></tr>
<tr><td></td><td colspan="9">AppKit, UIKit, Android Views, WinUI 3, GTK 4: not realized</td></tr>
<tr><td><code>onDrop</code> (<code>drop</code>)</td><td>event</td><td><code>String</code></td><td>native</td><td align="center"></td><td align="center"></td><td align="center"></td><td align="center"></td><td align="center"></td><td></td></tr>
<tr><td></td><td colspan="9">AppKit, UIKit, Android Views, WinUI 3, GTK 4: not realized</td></tr>
<tr><td><code>onDropCompleted</code> (<code>dropCompleted</code>)</td><td>event</td><td></td><td>native</td><td align="center"></td><td align="center"></td><td align="center"></td><td align="center"></td><td align="center"></td><td></td></tr>
<tr><td></td><td colspan="9">AppKit, UIKit, Android Views, WinUI 3, GTK 4: not realized</td></tr>
<tr><td><code>onFrameChanged</code> (<code>frameChanged</code>)</td><td>event</td><td><code>[Double]</code></td><td>native</td><td align="center">✅</td><td align="center">✅</td><td align="center">✅</td><td align="center">✅</td><td align="center">✅</td><td></td></tr>
<tr><td><code>gridColumn</code></td><td>property</td><td><code>Int</code></td><td>stateUI</td><td align="center">✅</td><td align="center">✅</td><td align="center">✅</td><td align="center">✅</td><td align="center">✅</td><td></td></tr>
<tr><td><code>gridColumnSpan</code></td><td>property</td><td><code>Int</code></td><td>stateUI</td><td align="center">✅</td><td align="center">✅</td><td align="center">✅</td><td align="center">✅</td><td align="center">✅</td><td></td></tr>
<tr><td><code>gridRow</code></td><td>property</td><td><code>Int</code></td><td>stateUI</td><td align="center">✅</td><td align="center">✅</td><td align="center">✅</td><td align="center">✅</td><td align="center">✅</td><td></td></tr>
<tr><td><code>gridRowSpan</code></td><td>property</td><td><code>Int</code></td><td>stateUI</td><td align="center">✅</td><td align="center">✅</td><td align="center">✅</td><td align="center">✅</td><td align="center">✅</td><td></td></tr>
<tr><td><code>horizontalAlignment</code></td><td>property</td><td><code>Alignment</code></td><td>native</td><td align="center">✅</td><td align="center">✅</td><td align="center">✅</td><td align="center">✅</td><td align="center">✅</td><td></td></tr>
<tr><td><code>margin</code></td><td>property</td><td><code>Insets</code></td><td>native</td><td align="center">✅</td><td align="center">✅</td><td align="center">✅</td><td align="center">✅</td><td align="center">✅</td><td></td></tr>
<tr><td><code>panTouchCount</code></td><td>property</td><td><code>Int</code></td><td>structure</td><td align="center">✓</td><td align="center">✓</td><td align="center">☑️</td><td align="center">✅</td><td align="center">✅</td><td></td></tr>
<tr><td></td><td colspan="9">AppKit: only through the host's own: pan on ItemsView: handed to the host's recognizer or handler, no NSEvent sent<br>UIKit: only through the host's own: pan on ItemsView: the view's listening handed the recognizer's states, no touch sent<br>Android Views: The host layer hears a one-finger pan only; any other <code>panTouchCount</code> turns the pan off.</td></tr>
<tr><td><code>onPanUpdated</code> (<code>panUpdated</code>)</td><td>event</td><td><code>(GesturePhase, Double, Double)</code></td><td>native</td><td align="center">✓</td><td align="center">✓</td><td align="center">✅</td><td align="center">✅</td><td align="center">✅</td><td></td></tr>
<tr><td></td><td colspan="9">AppKit: only through the host's own: pan on ItemsView: handed to the host's recognizer or handler, no NSEvent sent<br>UIKit: only through the host's own: pan on ItemsView: the view's listening handed the recognizer's states, no touch sent</td></tr>
<tr><td><code>panXChannel</code></td><td>property</td><td><code>Int</code></td><td>structure</td><td align="center">✓</td><td align="center">✓</td><td align="center">✅</td><td align="center">✅</td><td align="center">✅</td><td></td></tr>
<tr><td></td><td colspan="9">AppKit: only through the host's own: pan on ItemsView: handed to the host's recognizer or handler, no NSEvent sent<br>UIKit: only through the host's own: pan on ItemsView: the view's listening handed the recognizer's states, no touch sent</td></tr>
<tr><td><code>panYChannel</code></td><td>property</td><td><code>Int</code></td><td>structure</td><td align="center">✓</td><td align="center">✓</td><td align="center">✅</td><td align="center">✅</td><td align="center">✅</td><td></td></tr>
<tr><td></td><td colspan="9">AppKit: only through the host's own: pan on ItemsView: handed to the host's recognizer or handler, no NSEvent sent<br>UIKit: only through the host's own: pan on ItemsView: the view's listening handed the recognizer's states, no touch sent</td></tr>
<tr><td><code>onPinchUpdated</code> (<code>pinchUpdated</code>)</td><td>event</td><td><code>(GesturePhase, Double, Point)</code></td><td>native</td><td align="center">✓</td><td align="center">✓</td><td align="center">✅</td><td align="center">✅</td><td align="center">✓</td><td></td></tr>
<tr><td></td><td colspan="9">AppKit: only through the host's own: pinch on ItemsView: handed to the host's recognizer or handler, no NSEvent sent<br>UIKit: only through the host's own: pinch on ItemsView: the view's listening handed the recognizer's states, no touch sent<br>GTK 4: only through the host's own: pinch on ItemsView: the fingers' place handed to the host's recognizer as GTK's zoom would: GTK takes no touch a driver puts down</td></tr>
<tr><td><code>onPointerEntered</code> (<code>pointerEntered</code>)</td><td>event</td><td></td><td>native</td><td align="center">✓</td><td align="center">✓</td><td align="center">✅</td><td align="center">✅</td><td align="center">✅</td><td></td></tr>
<tr><td></td><td colspan="9">AppKit: only through the host's own: hover on ItemsView: handed to the host's recognizer or handler, no NSEvent sent<br>UIKit: only through the host's own: hover on ItemsView: the view's listening handed the recognizer's states, no touch sent</td></tr>
<tr><td><code>onPointerExited</code> (<code>pointerExited</code>)</td><td>event</td><td></td><td>native</td><td align="center">✓</td><td align="center">✓</td><td align="center">✅</td><td align="center">✅</td><td align="center">✅</td><td></td></tr>
<tr><td></td><td colspan="9">AppKit: only through the host's own: hover on ItemsView: handed to the host's recognizer or handler, no NSEvent sent<br>UIKit: only through the host's own: hover on ItemsView: the view's listening handed the recognizer's states, no touch sent</td></tr>
<tr><td><code>onPointerMoved</code> (<code>pointerMoved</code>)</td><td>event</td><td><code>Point?</code></td><td>native</td><td align="center">✓</td><td align="center">✓</td><td align="center">✅</td><td align="center">✅</td><td align="center">✅</td><td></td></tr>
<tr><td></td><td colspan="9">AppKit: only through the host's own: hover on ItemsView: handed to the host's recognizer or handler, no NSEvent sent<br>UIKit: only through the host's own: hover on ItemsView: the view's listening handed the recognizer's states, no touch sent</td></tr>
<tr><td><code>onPointerPressed</code> (<code>pointerPressed</code>)</td><td>event</td><td><code>Point?</code></td><td>native</td><td align="center">✓</td><td align="center">✓</td><td align="center">✅</td><td align="center">✅</td><td align="center">✅</td><td></td></tr>
<tr><td></td><td colspan="9">AppKit: only through the host's own: hover on ItemsView: handed to the host's recognizer or handler, no NSEvent sent<br>UIKit: only through the host's own: hover on ItemsView: the view's listening handed the recognizer's states, no touch sent</td></tr>
<tr><td><code>onPointerReleased</code> (<code>pointerReleased</code>)</td><td>event</td><td><code>Point?</code></td><td>native</td><td align="center">✓</td><td align="center">✓</td><td align="center">✅</td><td align="center">✅</td><td align="center">✅</td><td></td></tr>
<tr><td></td><td colspan="9">AppKit: only through the host's own: hover on ItemsView: handed to the host's recognizer or handler, no NSEvent sent<br>UIKit: only through the host's own: hover on ItemsView: the view's listening handed the recognizer's states, no touch sent</td></tr>
<tr><td><code>swipeDirection</code></td><td>property</td><td><code>SwipeDirection</code></td><td>structure</td><td align="center">✓</td><td align="center">✓</td><td align="center">✅</td><td align="center">✅</td><td align="center">✅</td><td></td></tr>
<tr><td></td><td colspan="9">AppKit: only through the host's own: pan on ItemsView: handed to the host's recognizer or handler, no NSEvent sent<br>UIKit: only through the host's own: pan on ItemsView: the view's listening handed the recognizer's states, no touch sent</td></tr>
<tr><td><code>swipeThreshold</code></td><td>property</td><td><code>Double</code></td><td>structure</td><td align="center">✓</td><td align="center">✓</td><td align="center">✅</td><td align="center">✅</td><td align="center">✅</td><td></td></tr>
<tr><td></td><td colspan="9">AppKit: only through the host's own: pan on ItemsView: handed to the host's recognizer or handler, no NSEvent sent<br>UIKit: only through the host's own: pan on ItemsView: the view's listening handed the recognizer's states, no touch sent</td></tr>
<tr><td><code>onSwiped</code> (<code>swiped</code>)</td><td>event</td><td><code>SwipeDirection</code></td><td>native</td><td align="center">✓</td><td align="center">✓</td><td align="center">✅</td><td align="center">✅</td><td align="center">✅</td><td></td></tr>
<tr><td></td><td colspan="9">AppKit: only through the host's own: pan on ItemsView: handed to the host's recognizer or handler, no NSEvent sent<br>UIKit: only through the host's own: pan on ItemsView: the view's listening handed the recognizer's states, no touch sent</td></tr>
<tr><td><code>tapCount</code></td><td>property</td><td><code>Int</code></td><td>structure</td><td align="center">✓</td><td align="center">✓</td><td align="center">✅</td><td align="center">✅</td><td align="center">✅</td><td></td></tr>
<tr><td></td><td colspan="9">AppKit: only through the host's own: tap on ItemsView: handed to the host's recognizer or handler, no NSEvent sent<br>UIKit: only through the host's own: tap on ItemsView: the view's listening handed the recognizer's states, no touch sent</td></tr>
<tr><td><code>onTapped</code> (<code>tapped</code>)</td><td>event</td><td></td><td>native</td><td align="center">✓</td><td align="center">✓</td><td align="center">✅</td><td align="center">✅</td><td align="center">✅</td><td></td></tr>
<tr><td></td><td colspan="9">AppKit: only through the host's own: tap on ItemsView: handed to the host's recognizer or handler, no NSEvent sent<br>UIKit: only through the host's own: tap on ItemsView: the view's listening handed the recognizer's states, no touch sent</td></tr>
<tr><td><code>verticalAlignment</code></td><td>property</td><td><code>Alignment</code></td><td>native</td><td align="center">✅</td><td align="center">✅</td><td align="center">✅</td><td align="center">✅</td><td align="center">✅</td><td></td></tr>
</table>
