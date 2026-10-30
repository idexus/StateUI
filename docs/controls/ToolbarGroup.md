<!-- Rendered by ControlDictionaryTests from the contracts and the verdicts each host's runs of its tests wrote under lib/StateUI/exports/marks: STATEUI_UPDATE_DOCS=1 swift test --filter ControlDictionaryTests writes it again. -->

# ToolbarGroup

A group of actions a page or a split view declares for its bar - one shared background where the platform draws one - and where it stands: a lone item stands in a group of its own.

```swift
@State var edited = false

TextEditor()
    .onTextChanged { _ in edited = true }
    .toolbar {
        ToolbarButton("New").placement(at: .start)
        ToolbarGroup {
            ToolbarButton("Save")
                .isEnabled(edited)
                .onClicked { edited = false }
            ToolbarButton("Revert")
                .isEnabled(edited)
                .onClicked { edited = false }
        }
        .placement(order: 1)
    }
```

Layer: `structure`. It carries structure or protocol data rather than configuring a visual platform object.

Inherits: [PaddingElement](tiers/PaddingElement.md) · [BorderElement](tiers/BorderElement.md) · [BarItemElement](tiers/BarItemElement.md)

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
<thead><tr><th>Host</th><th>Created</th><th>Members (16)</th><th>Realization</th></tr></thead>
<tbody><tr></tr><tr><td>AppKit</td><td align="center">✅</td><td>6 ✅ · 10 –</td><td><code>NSToolbarItem</code>; <code>NSMenuToolbarItem</code> overflow; at the page's foot a strip of native controls</td></tr></tbody>
<tbody><tr></tr><tr><td>UIKit</td><td align="center">✅</td><td>6 ✅ · 10 –</td><td><code>UIBarButtonItemGroup</code> / <code>UIBarButtonItem</code>; at the page's foot the navigation controller's <code>UIToolbar</code></td></tr></tbody>
<tbody><tr></tr><tr><td>Android Views</td><td align="center">⌛</td><td>8 –</td><td><code>Toolbar</code> <code>MenuItem</code>; at the page's foot a <code>Toolbar</code> of its own</td></tr></tbody>
<tbody><tr></tr><tr><td>WinUI 3</td><td align="center">⌛</td><td>8 –</td><td>a <code>CommandBar</code>'s <code>AppBarElementContainer</code> in the <code>TitleBar</code>, a group's on a capsule; <code>AppBarButton</code> behind More; at the page's foot a <code>CommandBar</code> of its own</td></tr></tbody>
<tbody><tr></tr><tr><td>GTK 4</td><td align="center">⌛</td><td>8 –</td><td><code>GtkButton</code> in an <code>AdwHeaderBar</code>; at the page's foot in a <code>GtkActionBar</code>, <code>AdwToolbarView</code>'s bottom bar</td></tr></tbody>
<tbody><tr></tr><tr><td>Web</td><td align="center">⌛</td><td>8 ✅</td><td><code>&lt;button&gt;</code> in an ARIA <code>toolbar</code>; at the page's foot a <code>toolbar</code> of its own</td></tr></tbody>
</table>

Declared in `lib/StateUI/Core/Sources/Contracts/Elements/Menus/ToolbarGroupContract.swift`.

## ToolbarGroup's own members

<table>
<thead><tr><th>Member</th><th>Kind</th><th>Value</th><th>Layer</th><th>AppKit</th><th>UIKit</th><th>Android Views</th><th>WinUI 3</th><th>GTK 4</th><th>Web</th></tr></thead>
<tbody><tr></tr><tr><td><code>barEdge</code></td><td>property</td><td><code>ToolbarEdge</code></td><td>adaptive</td><td align="center">✅</td><td align="center">✅</td><td align="center"></td><td align="center"></td><td align="center"></td><td align="center"></td></tr></tbody>
<tbody><tr></tr><tr><td><code>hidesWithSidebar</code></td><td>property</td><td><code>Bool</code></td><td>stateUI</td><td align="center">✅</td><td align="center">✅</td><td align="center">⌛</td><td align="center">⌛</td><td align="center">⌛</td><td align="center">⌛</td></tr></tbody>
<tbody><tr></tr><tr><td><code>isEnabled</code></td><td>property</td><td><code>Bool</code></td><td>native</td><td align="center">✅</td><td align="center">✅</td><td align="center">⌛</td><td align="center">⌛</td><td align="center">⌛</td><td align="center">⌛</td></tr></tbody>
<tbody><tr></tr><tr><td><code>order</code></td><td>property</td><td><code>Int</code></td><td>stateUI</td><td align="center">✅</td><td align="center">✅</td><td align="center">⌛</td><td align="center">⌛</td><td align="center">⌛</td><td align="center">⌛</td></tr></tbody>
<tbody><tr></tr><tr><td><code>part</code></td><td>property</td><td><code>ToolbarPart</code></td><td>stateUI</td><td align="center">✅</td><td align="center">✅</td><td align="center">⌛</td><td align="center">⌛</td><td align="center">⌛</td><td align="center">⌛</td></tr></tbody>
<tbody><tr></tr><tr><td><code>position</code></td><td>property</td><td><code>ToolbarPosition</code></td><td>adaptive</td><td align="center">✅</td><td align="center">✅</td><td align="center">⌛</td><td align="center">⌛</td><td align="center">⌛</td><td align="center">⌛</td></tr></tbody>
<tbody><tr></tr><tr><td rowspan="2"><code>spacing</code></td><td>property</td><td><code>Double</code></td><td>adaptive</td><td align="center">–</td><td align="center">–</td><td align="center">⌛</td><td align="center">⌛</td><td align="center">⌛</td><td align="center">⌛</td></tr>
<tr><td colspan="9">AppKit: The Mac's toolbar draws its items in the Mac's own look.<br>UIKit: A bar's items stand in the system's own look.</td></tr></tbody>
<tbody><tr></tr><tr><td rowspan="2"><code>standsAlone</code></td><td>property</td><td><code>Bool</code></td><td>stateUI</td><td align="center">–</td><td align="center">–</td><td align="center">⌛</td><td align="center">⌛</td><td align="center">⌛</td><td align="center">⌛</td></tr>
<tr><td colspan="9">AppKit: The Mac's toolbar draws every group on a glass of its own, a lone item's too.<br>UIKit: UIKit's bar draws every group on a glass of its own, a lone item's too.</td></tr></tbody>
</table>

## From [PaddingElement](tiers/PaddingElement.md)

The space kept inside an element, around what it holds.

<table>
<thead><tr><th>Member</th><th>Kind</th><th>Value</th><th>Layer</th><th>AppKit</th><th>UIKit</th><th>Android Views</th><th>WinUI 3</th><th>GTK 4</th><th>Web</th></tr></thead>
<tbody><tr></tr><tr><td rowspan="2"><code>padding</code></td><td>property</td><td><code>Insets</code></td><td>native</td><td align="center">–</td><td align="center">–</td><td align="center">–</td><td align="center">–</td><td align="center">–</td><td align="center">✅</td></tr>
<tr><td colspan="9">AppKit: The Mac's toolbar draws its items in the Mac's own look.<br>UIKit: A bar's items stand in the system's own look.<br>Android Views: A toolbar's actions stand in Android's own look.<br>WinUI 3: The title bar's commands stand in WinUI's own look.<br>GTK 4: A header bar's buttons stand in libadwaita's own look.</td></tr></tbody>
</table>

## From [BorderElement](tiers/BorderElement.md)

What an element draws of its own box: the shape its background, its outline and its cut follow, and the outline.

<table>
<thead><tr><th>Member</th><th>Kind</th><th>Value</th><th>Layer</th><th>AppKit</th><th>UIKit</th><th>Android Views</th><th>WinUI 3</th><th>GTK 4</th><th>Web</th></tr></thead>
<tbody><tr></tr><tr><td rowspan="2"><code>shape</code></td><td>property</td><td><code>ContainerShape</code></td><td>stateUI</td><td align="center">–</td><td align="center">–</td><td align="center">–</td><td align="center">–</td><td align="center">–</td><td align="center">✅</td></tr>
<tr><td colspan="9">AppKit: The Mac's toolbar draws its items in the Mac's own look.<br>UIKit: A bar's items stand in the system's own look.<br>Android Views: A toolbar's actions stand in Android's own look.<br>WinUI 3: The title bar's commands stand in WinUI's own look.<br>GTK 4: A header bar's buttons stand in libadwaita's own look.</td></tr></tbody>
<tbody><tr></tr><tr><td rowspan="2"><code>stroke</code></td><td>property</td><td><code>Brush</code></td><td>stateUI</td><td align="center">–</td><td align="center">–</td><td align="center">–</td><td align="center">–</td><td align="center">–</td><td align="center">✅</td></tr>
<tr><td colspan="9">AppKit: The Mac's toolbar draws its items in the Mac's own look.<br>UIKit: A bar's items stand in the system's own look.<br>Android Views: A toolbar's actions stand in Android's own look.<br>WinUI 3: The title bar's commands stand in WinUI's own look.<br>GTK 4: A header bar's buttons stand in libadwaita's own look.</td></tr></tbody>
<tbody><tr></tr><tr><td rowspan="2"><code>lineWidth</code></td><td>property</td><td><code>Double</code></td><td>stateUI</td><td align="center">–</td><td align="center">–</td><td align="center">–</td><td align="center">–</td><td align="center">–</td><td align="center">✅</td></tr>
<tr><td colspan="9">AppKit: The Mac's toolbar draws its items in the Mac's own look.<br>UIKit: A bar's items stand in the system's own look.<br>Android Views: A toolbar's actions stand in Android's own look.<br>WinUI 3: The title bar's commands stand in WinUI's own look.<br>GTK 4: A header bar's buttons stand in libadwaita's own look.</td></tr></tbody>
</table>

## From [BarItemElement](tiers/BarItemElement.md)

What an item standing on a bar - a button, a setting or a group of them - shows of its own where its host draws the bar itself: the keyed style it wears, what its surface is made of, and the pointer over it its visual states follow.

<table>
<thead><tr><th>Member</th><th>Kind</th><th>Value</th><th>Layer</th><th>AppKit</th><th>UIKit</th><th>Android Views</th><th>WinUI 3</th><th>GTK 4</th><th>Web</th></tr></thead>
<tbody><tr></tr><tr><td rowspan="2"><code>style</code></td><td>property</td><td><code>Name</code></td><td>structure</td><td align="center">–</td><td align="center">–</td><td align="center">–</td><td align="center">–</td><td align="center">–</td><td align="center">✅</td></tr>
<tr><td colspan="9">AppKit: The Mac's toolbar draws its items in the Mac's own look.<br>UIKit: A bar's items stand in the system's own look.<br>Android Views: A toolbar's actions stand in Android's own look.<br>WinUI 3: The title bar's commands stand in WinUI's own look.<br>GTK 4: A header bar's buttons stand in libadwaita's own look.</td></tr></tbody>
<tbody><tr></tr><tr><td rowspan="2"><code>background</code></td><td>property</td><td><code>Material</code></td><td>adaptive</td><td align="center">–</td><td align="center">–</td><td align="center">–</td><td align="center">–</td><td align="center">–</td><td align="center">✅</td></tr>
<tr><td colspan="9">AppKit: The Mac's toolbar draws its items in the Mac's own look.<br>UIKit: A bar's items stand in the system's own look.<br>Android Views: A toolbar's actions stand in Android's own look.<br>WinUI 3: The title bar's commands stand in WinUI's own look.<br>GTK 4: A header bar's buttons stand in libadwaita's own look.</td></tr></tbody>
<tbody><tr></tr><tr><td rowspan="2"><code>onPointerEntered</code> (<code>pointerEntered</code>)</td><td>event</td><td></td><td>native</td><td align="center">–</td><td align="center">–</td><td align="center">–</td><td align="center">–</td><td align="center">–</td><td align="center">✅</td></tr>
<tr><td colspan="9">AppKit: The Mac's toolbar draws its items in the Mac's own look.<br>UIKit: A bar's items stand in the system's own look.<br>Android Views: A toolbar's actions stand in Android's own look.<br>WinUI 3: The title bar's commands stand in WinUI's own look.<br>GTK 4: A header bar's buttons stand in libadwaita's own look.</td></tr></tbody>
<tbody><tr></tr><tr><td rowspan="2"><code>onPointerExited</code> (<code>pointerExited</code>)</td><td>event</td><td></td><td>native</td><td align="center">–</td><td align="center">–</td><td align="center">–</td><td align="center">–</td><td align="center">–</td><td align="center">✅</td></tr>
<tr><td colspan="9">AppKit: The Mac's toolbar draws its items in the Mac's own look.<br>UIKit: A bar's items stand in the system's own look.<br>Android Views: A toolbar's actions stand in Android's own look.<br>WinUI 3: The title bar's commands stand in WinUI's own look.<br>GTK 4: A header bar's buttons stand in libadwaita's own look.</td></tr></tbody>
</table>
