<!-- Rendered by ControlDictionaryTests from the contracts and the verdicts each host's runs of its tests wrote under lib/StateUI/exports/marks: STATEUI_UPDATE_DOCS=1 swift test --filter ControlDictionaryTests writes it again. -->

# ToolbarButton

An action in the page's native navigation or toolbar surface.

```swift
@State var count = 0

Text("\(count) items")
    .toolbar {
        ToolbarButton("Add")
            .icon("add.png")
            .showsText(true)
            .onClicked { count += 1 }
        ToolbarButton("Clear")
            .placement(at: .overflow)
            .role(.destructive)
            .onClicked { count = 0 }
    }
```

Layer: `structure`. It carries structure or protocol data rather than configuring a visual platform object.

Inherits: [AutomationElement](tiers/AutomationElement.md) · [TextColorElement](tiers/TextColorElement.md) · [FontElement](tiers/FontElement.md) · [PaddingElement](tiers/PaddingElement.md) · [BorderElement](tiers/BorderElement.md) · [BarItemElement](tiers/BarItemElement.md) · [BarButtonElement](tiers/BarButtonElement.md) · [MenuItemElement](tiers/MenuItemElement.md) · [ActionElement](tiers/ActionElement.md) · [ButtonMenuElement](tiers/ButtonMenuElement.md) · [TextAndIconElement](tiers/TextAndIconElement.md)

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
<thead><tr><th>Host</th><th>Created</th><th>Members (27)</th><th>Realization</th></tr></thead>
<tbody><tr></tr><tr><td rowspan="2">AppKit</td><td align="center">✓</td><td>5 ✅ · 2 ✓ · 18 –</td><td><code>NSToolbarItem</code>; <code>NSMenuToolbarItem</code> overflow; at the page's foot a strip of native controls</td></tr>
<tr><td colspan="3">only through the host's own: activate on ToolbarButton: the host's toolbar entry called, no toolbar item touched</td></tr></tbody>
<tbody><tr></tr><tr><td>UIKit</td><td align="center">✅</td><td>6 ✅ · 1 ☑️ · 1 ✓ · 19 –</td><td><code>UIBarButtonItemGroup</code> / <code>UIBarButtonItem</code>; at the page's foot the navigation controller's <code>UIToolbar</code></td></tr></tbody>
<tbody><tr></tr><tr><td>Android Views</td><td align="center">✅</td><td>6 ✅ · 1 ☑️ · 19 –</td><td><code>Toolbar</code> <code>MenuItem</code>; at the page's foot a <code>Toolbar</code> of its own</td></tr></tbody>
<tbody><tr></tr><tr><td>WinUI 3</td><td align="center">✅</td><td>10 ✅ · 17 –</td><td>a <code>CommandBar</code>'s <code>AppBarElementContainer</code> in the <code>TitleBar</code>, a group's on a capsule; <code>AppBarButton</code> behind More; at the page's foot a <code>CommandBar</code> of its own</td></tr></tbody>
<tbody><tr></tr><tr><td>GTK 4</td><td align="center">✅</td><td>8 ✅ · 1 ✓ · 18 –</td><td><code>GtkButton</code> in an <code>AdwHeaderBar</code>; at the page's foot in a <code>GtkActionBar</code>, <code>AdwToolbarView</code>'s bottom bar</td></tr></tbody>
<tbody><tr></tr><tr><td>Web</td><td align="center">✅</td><td>27 ✅</td><td><code>&lt;button&gt;</code> in an ARIA <code>toolbar</code>; at the page's foot a <code>toolbar</code> of its own</td></tr></tbody>
</table>

Declared in `lib/StateUI/Core/Sources/Contracts/Elements/Menus/ToolbarButtonContract.swift`.

## ToolbarButton's own members

ToolbarButton declares no members of its own.

## From [AutomationElement](tiers/AutomationElement.md)

What an element the platform's automation meets has - a drawn element, a menu's entry or a bar's item, an arrangement of pages: the name automation finds it by.

<table>
<thead><tr><th>Member</th><th>Kind</th><th>Value</th><th>Layer</th><th>AppKit</th><th>UIKit</th><th>Android Views</th><th>WinUI 3</th><th>GTK 4</th><th>Web</th></tr></thead>
<tbody><tr></tr><tr><td rowspan="2"><code>accessibilityIdentifier</code></td><td>property</td><td><code>String</code></td><td>native</td><td align="center"></td><td align="center">✅</td><td align="center">–</td><td align="center">✅</td><td align="center">–</td><td align="center">✅</td></tr>
<tr><td colspan="9">AppKit: not realized<br>Android Views: An Android bar action is a menu entry, which holds no identifier: automation finds it by its title.<br>GTK 4: GTK 4 tells assistive technology no identifier before 4.22, and from 4.22 only a GtkBuilder file's id, which no public call sets on a widget made in code.</td></tr></tbody>
</table>

## From [TextColorElement](tiers/TextColorElement.md)

The color of text, wherever it is drawn.

<table>
<thead><tr><th>Member</th><th>Kind</th><th>Value</th><th>Layer</th><th>AppKit</th><th>UIKit</th><th>Android Views</th><th>WinUI 3</th><th>GTK 4</th><th>Web</th></tr></thead>
<tbody><tr></tr><tr><td rowspan="2"><code>textColor</code></td><td>property</td><td><code>Color</code></td><td>native</td><td align="center">–</td><td align="center">–</td><td align="center">–</td><td align="center">–</td><td align="center">–</td><td align="center">✅</td></tr>
<tr><td colspan="9">AppKit: The Mac's toolbar draws its items in the Mac's own look.<br>UIKit: A bar's items stand in the system's own look.<br>Android Views: A toolbar's actions stand in Android's own look.<br>WinUI 3: The title bar's commands stand in WinUI's own look.<br>GTK 4: A header bar's buttons stand in libadwaita's own look.</td></tr></tbody>
</table>

## From [FontElement](tiers/FontElement.md)

The font text is drawn in: its step of the platform's type ramp, its family, its size, its weight and slant, and whether it follows the user's text-size setting.

<table>
<thead><tr><th>Member</th><th>Kind</th><th>Value</th><th>Layer</th><th>AppKit</th><th>UIKit</th><th>Android Views</th><th>WinUI 3</th><th>GTK 4</th><th>Web</th></tr></thead>
<tbody><tr></tr><tr><td rowspan="2"><code>fontAttributes</code></td><td>property</td><td><code>FontAttributes</code></td><td>native</td><td align="center">–</td><td align="center">–</td><td align="center">–</td><td align="center">–</td><td align="center">–</td><td align="center">✅</td></tr>
<tr><td colspan="9">AppKit: The Mac's toolbar draws its items in the Mac's own look.<br>UIKit: A bar's items stand in the system's own look.<br>Android Views: A toolbar's actions stand in Android's own look.<br>WinUI 3: The title bar's commands stand in WinUI's own look.<br>GTK 4: A header bar's buttons stand in libadwaita's own look.</td></tr></tbody>
<tbody><tr></tr><tr><td rowspan="2"><code>fontWeight</code></td><td>property</td><td><code>FontWeight</code></td><td>native</td><td align="center">–</td><td align="center">–</td><td align="center">–</td><td align="center">–</td><td align="center">–</td><td align="center">✅</td></tr>
<tr><td colspan="9">AppKit: The Mac's toolbar draws its items in the Mac's own look.<br>UIKit: A bar's items stand in the system's own look.<br>Android Views: A toolbar's actions stand in Android's own look.<br>WinUI 3: The title bar's commands stand in WinUI's own look.<br>GTK 4: A header bar's buttons stand in libadwaita's own look.</td></tr></tbody>
<tbody><tr></tr><tr><td rowspan="2"><code>textStyle</code></td><td>property</td><td><code>TextStyle</code></td><td>native</td><td align="center">–</td><td align="center">–</td><td align="center">–</td><td align="center">–</td><td align="center">–</td><td align="center">✅</td></tr>
<tr><td colspan="9">AppKit: The Mac's toolbar draws its items in the Mac's own look.<br>UIKit: A bar's items stand in the system's own look.<br>Android Views: A toolbar's actions stand in Android's own look.<br>WinUI 3: The title bar's commands stand in WinUI's own look.<br>GTK 4: A header bar's buttons stand in libadwaita's own look.</td></tr></tbody>
<tbody><tr></tr><tr><td rowspan="2"><code>isFontAutoScalingEnabled</code></td><td>property</td><td><code>Bool</code></td><td>adaptive</td><td align="center">–</td><td align="center">–</td><td align="center">–</td><td align="center">–</td><td align="center">–</td><td align="center">✅</td></tr>
<tr><td colspan="9">AppKit: The Mac's toolbar draws its items in the Mac's own look.<br>UIKit: A bar's items stand in the system's own look.<br>Android Views: A toolbar's actions stand in Android's own look.<br>WinUI 3: The title bar's commands stand in WinUI's own look.<br>GTK 4: A header bar's buttons stand in libadwaita's own look.</td></tr></tbody>
<tbody><tr></tr><tr><td rowspan="2"><code>fontFamily</code></td><td>property</td><td><code>Name</code></td><td>native</td><td align="center">–</td><td align="center">–</td><td align="center">–</td><td align="center">–</td><td align="center">–</td><td align="center">✅</td></tr>
<tr><td colspan="9">AppKit: The Mac's toolbar draws its items in the Mac's own look.<br>UIKit: A bar's items stand in the system's own look.<br>Android Views: A toolbar's actions stand in Android's own look.<br>WinUI 3: The title bar's commands stand in WinUI's own look.<br>GTK 4: A header bar's buttons stand in libadwaita's own look.</td></tr></tbody>
<tbody><tr></tr><tr><td rowspan="2"><code>fontSize</code></td><td>property</td><td><code>Double</code></td><td>native</td><td align="center">–</td><td align="center">–</td><td align="center">–</td><td align="center">–</td><td align="center">–</td><td align="center">✅</td></tr>
<tr><td colspan="9">AppKit: The Mac's toolbar draws its items in the Mac's own look.<br>UIKit: A bar's items stand in the system's own look.<br>Android Views: A toolbar's actions stand in Android's own look.<br>WinUI 3: The title bar's commands stand in WinUI's own look.<br>GTK 4: A header bar's buttons stand in libadwaita's own look.</td></tr></tbody>
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

## From [BarButtonElement](tiers/BarButtonElement.md)

A button on a bar - an action or a setting: the press its visual states follow, beside the pointer over it every item on a bar reports.

<table>
<thead><tr><th>Member</th><th>Kind</th><th>Value</th><th>Layer</th><th>AppKit</th><th>UIKit</th><th>Android Views</th><th>WinUI 3</th><th>GTK 4</th><th>Web</th></tr></thead>
<tbody><tr></tr><tr><td rowspan="2"><code>onPressed</code> (<code>pressed</code>)</td><td>event</td><td></td><td>native</td><td align="center">–</td><td align="center">–</td><td align="center">–</td><td align="center">–</td><td align="center">–</td><td align="center">✅</td></tr>
<tr><td colspan="9">AppKit: The Mac's toolbar draws its items in the Mac's own look.<br>UIKit: A bar's items stand in the system's own look.<br>Android Views: A toolbar's actions stand in Android's own look.<br>WinUI 3: The title bar's commands stand in WinUI's own look.<br>GTK 4: A header bar's buttons stand in libadwaita's own look.</td></tr></tbody>
<tbody><tr></tr><tr><td rowspan="2"><code>onReleased</code> (<code>released</code>)</td><td>event</td><td></td><td>native</td><td align="center">–</td><td align="center">–</td><td align="center">–</td><td align="center">–</td><td align="center">–</td><td align="center">✅</td></tr>
<tr><td colspan="9">AppKit: The Mac's toolbar draws its items in the Mac's own look.<br>UIKit: A bar's items stand in the system's own look.<br>Android Views: A toolbar's actions stand in Android's own look.<br>WinUI 3: The title bar's commands stand in WinUI's own look.<br>GTK 4: A header bar's buttons stand in libadwaita's own look.</td></tr></tbody>
</table>

## From [MenuItemElement](tiers/MenuItemElement.md)

What every item a user chooses from says - a menu's entry, a toolbar's item, an action or a setting: a caption, a picture, whether it can be chosen, and the keys that choose it.

<table>
<thead><tr><th>Member</th><th>Kind</th><th>Value</th><th>Layer</th><th>AppKit</th><th>UIKit</th><th>Android Views</th><th>WinUI 3</th><th>GTK 4</th><th>Web</th></tr></thead>
<tbody><tr></tr><tr><td><code>icon</code></td><td>property</td><td><code>ImageSource</code></td><td>adaptive</td><td align="center">✅</td><td align="center">✅</td><td align="center">✅</td><td align="center">✅</td><td align="center">✅</td><td align="center">✅</td></tr></tbody>
<tbody><tr></tr><tr><td><code>isEnabled</code></td><td>property</td><td><code>Bool</code></td><td>native</td><td align="center">✅</td><td align="center">✅</td><td align="center">✅</td><td align="center">✅</td><td align="center">✅</td><td align="center">✅</td></tr></tbody>
<tbody><tr></tr><tr><td rowspan="2"><code>keyboardShortcut</code></td><td>property</td><td><code>KeyboardShortcut</code></td><td>native</td><td align="center">✅</td><td align="center">✓</td><td align="center">✅</td><td align="center">✅</td><td align="center">✓</td><td align="center">✅</td></tr>
<tr><td colspan="9">UIKit: only through the host's own: pressKeys on ToolbarButton: the window's or the main menu's key command performed, no key pressed<br>GTK 4: only through the host's own: pressKeys on ToolbarButton: the shortcut controller's action run, no key event</td></tr></tbody>
<tbody><tr></tr><tr><td><code>text</code></td><td>property</td><td><code>String</code></td><td>native</td><td align="center">✅</td><td align="center">✅</td><td align="center">✅</td><td align="center">✅</td><td align="center">✅</td><td align="center">✅</td></tr></tbody>
</table>

## From [ActionElement](tiers/ActionElement.md)

What an item that acts has - a menu's entry, a toolbar's button: what choosing it does, and how the platform marks it.

<table>
<thead><tr><th>Member</th><th>Kind</th><th>Value</th><th>Layer</th><th>AppKit</th><th>UIKit</th><th>Android Views</th><th>WinUI 3</th><th>GTK 4</th><th>Web</th></tr></thead>
<tbody><tr></tr><tr><td rowspan="2"><code>onClicked</code> (<code>clicked</code>)</td><td>event</td><td></td><td>native</td><td align="center">✓</td><td align="center">✅</td><td align="center">✅</td><td align="center">✅</td><td align="center">✅</td><td align="center">✅</td></tr>
<tr><td colspan="9">AppKit: only through the host's own: activate on ToolbarButton: the host's toolbar entry called, no toolbar item touched</td></tr></tbody>
<tbody><tr></tr><tr><td rowspan="2"><code>role</code></td><td>property</td><td><code>ActionRole</code></td><td>adaptive</td><td align="center"></td><td align="center">✅</td><td align="center">✅</td><td align="center">✅</td><td align="center">✅</td><td align="center">✅</td></tr>
<tr><td colspan="9">AppKit: not realized</td></tr></tbody>
</table>

## From [ButtonMenuElement](tiers/ButtonMenuElement.md)

What a button that holds a menu has - a button's, a toolbar button's: how its menu opens, and whether the arrow saying so shows.

<table>
<thead><tr><th>Member</th><th>Kind</th><th>Value</th><th>Layer</th><th>AppKit</th><th>UIKit</th><th>Android Views</th><th>WinUI 3</th><th>GTK 4</th><th>Web</th></tr></thead>
<tbody><tr></tr><tr><td rowspan="2"><code>menuKind</code></td><td>property</td><td><code>ButtonMenuKind</code></td><td>adaptive</td><td align="center">✓</td><td align="center">☑️</td><td align="center">☑️</td><td align="center">✅</td><td align="center">✅</td><td align="center">✅</td></tr>
<tr><td colspan="9">AppKit: only through the host's own: activate on ToolbarButton: the host's toolbar entry called, no toolbar item touched<br>UIKit: UIKit's bar offers no arrow part: a split bar button opens its menu held.<br>Android Views: An Android bar's split or held button stands as its action, its menu behind the overflow.</td></tr></tbody>
<tbody><tr></tr><tr><td rowspan="2"><code>showsMenuArrow</code></td><td>property</td><td><code>Bool</code></td><td>native</td><td align="center">✅</td><td align="center">–</td><td align="center">–</td><td align="center">✅</td><td align="center">✅</td><td align="center">✅</td></tr>
<tr><td colspan="9">UIKit: A UIKit bar button shows no arrow: its menu opens from its tap or its hold.<br>Android Views: An Android bar's action shows no arrow: its menu opens from its touch.</td></tr></tbody>
</table>

## From [TextAndIconElement](tiers/TextAndIconElement.md)

What an element showing words and a picture has - a button, a bar's item: whether its words stand beside its picture.

<table>
<thead><tr><th>Member</th><th>Kind</th><th>Value</th><th>Layer</th><th>AppKit</th><th>UIKit</th><th>Android Views</th><th>WinUI 3</th><th>GTK 4</th><th>Web</th></tr></thead>
<tbody><tr></tr><tr><td rowspan="2"><code>showsText</code></td><td>property</td><td><code>Bool</code></td><td>adaptive</td><td align="center">–</td><td align="center">–</td><td align="center">·</td><td align="center">✅</td><td align="center">✅</td><td align="center">✅</td></tr>
<tr><td colspan="9">AppKit: A Mac shows a toolbar's words as its user sets the whole toolbar, not item by item.<br>UIKit: A UIKit bar button shows its picture or its words, never both.<br>Android Views: cannot read an action's words beside its picture - Android shows them on a screen 480 points wide or more, and this one is narrower</td></tr></tbody>
</table>
