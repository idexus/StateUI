<!-- Rendered by ControlDictionaryTests from the contracts and the verdicts each host's runs of its tests wrote under lib/StateUI/exports/marks: STATEUI_UPDATE_DOCS=1 swift test --filter ControlDictionaryTests writes it again. -->

# ToolbarToggle

A setting on the page's bar, standing on or off - a two-state button.

```swift
@State var showsInspector = false

Text("Draft")
    .toolbar {
        ToolbarToggle("Inspector", isOn: $showsInspector)
            .icon("sidebar.png", on: "sidebar_filled.png")
    }
```

Layer: `structure`. It carries structure or protocol data rather than configuring a visual platform object.

Inherits: [AutomationElement](tiers/AutomationElement.md) · [TextColorElement](tiers/TextColorElement.md) · [FontElement](tiers/FontElement.md) · [BorderElement](tiers/BorderElement.md) · [BarItemElement](tiers/BarItemElement.md) · [BarButtonElement](tiers/BarButtonElement.md) · [MenuItemElement](tiers/MenuItemElement.md) · [TextAndIconElement](tiers/TextAndIconElement.md)

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
<thead><tr><th>Host</th><th>Created</th><th>Members (25)</th><th>Realization</th></tr></thead>
<tbody><tr></tr><tr><td>AppKit</td><td align="center">✅</td><td>7 ✅ · 17 –</td><td>an <code>NSToolbarItem</code> showing its on picture, prominent while on with none; a checked <code>NSMenuItem</code> in the overflow</td></tr></tbody>
<tbody><tr></tr><tr><td>UIKit</td><td align="center">✅</td><td>8 ✅ · 17 –</td><td>a <code>UIBarButtonItem</code> with <code>changesSelectionAsPrimaryAction</code>, <code>isSelected</code> while on</td></tr></tbody>
<tbody><tr></tr><tr><td>Android Views</td><td align="center">✅</td><td>6 ✅ · 1 ☑️ · 17 –</td><td>a checkable <code>Toolbar</code> <code>MenuItem</code>, its state on the bar by its on picture</td></tr></tbody>
<tbody><tr></tr><tr><td>WinUI 3</td><td align="center">✅</td><td>9 ✅ · 16 –</td><td>a <code>ToggleButton</code> in a <code>CommandBar</code>'s <code>AppBarElementContainer</code> in the <code>TitleBar</code>; <code>AppBarToggleButton</code> behind More</td></tr></tbody>
<tbody><tr></tr><tr><td>GTK 4</td><td align="center">✅</td><td>8 ✅ · 17 –</td><td><code>GtkToggleButton</code> in an <code>AdwHeaderBar</code></td></tr></tbody>
<tbody><tr></tr><tr><td>Web</td><td align="center">✅</td><td>25 ✅</td><td><code>&lt;button aria-pressed&gt;</code> in an ARIA <code>toolbar</code></td></tr></tbody>
</table>

Declared in `lib/StateUI/Core/Sources/Contracts/Elements/Menus/ToolbarToggleContract.swift`.

## ToolbarToggle's own members

<table>
<thead><tr><th>Member</th><th>Kind</th><th>Value</th><th>Layer</th><th>AppKit</th><th>UIKit</th><th>Android Views</th><th>WinUI 3</th><th>GTK 4</th><th>Web</th></tr></thead>
<tbody><tr></tr><tr><td rowspan="2"><code>isOn</code></td><td>property</td><td><code>Bool</code></td><td>native</td><td align="center">✅</td><td align="center">✅</td><td align="center">☑️</td><td align="center">✅</td><td align="center">✅</td><td align="center">✅</td></tr>
<tr><td colspan="9">Android Views: An Android bar shows a setting's state by its on picture alone; behind the overflow, by its check.</td></tr></tbody>
<tbody><tr></tr><tr><td><code>onIcon</code></td><td>property</td><td><code>ImageSource</code></td><td>adaptive</td><td align="center">✅</td><td align="center">✅</td><td align="center">✅</td><td align="center">✅</td><td align="center">✅</td><td align="center">✅</td></tr></tbody>
<tbody><tr></tr><tr><td><code>onToggled</code> (<code>toggled</code>)</td><td>event</td><td><code>Bool</code></td><td>native</td><td align="center">✅</td><td align="center">✅</td><td align="center">✅</td><td align="center">✅</td><td align="center">✅</td><td align="center">✅</td></tr></tbody>
</table>

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
<tbody><tr></tr><tr><td><code>keyboardShortcut</code></td><td>property</td><td><code>KeyboardShortcut</code></td><td>native</td><td align="center">✅</td><td align="center">✅</td><td align="center">✅</td><td align="center">✅</td><td align="center">✅</td><td align="center">✅</td></tr></tbody>
<tbody><tr></tr><tr><td><code>text</code></td><td>property</td><td><code>String</code></td><td>native</td><td align="center">✅</td><td align="center">✅</td><td align="center">✅</td><td align="center">✅</td><td align="center">✅</td><td align="center">✅</td></tr></tbody>
</table>

## From [TextAndIconElement](tiers/TextAndIconElement.md)

What an element showing words and a picture has - a button, a bar's item: whether its words stand beside its picture.

<table>
<thead><tr><th>Member</th><th>Kind</th><th>Value</th><th>Layer</th><th>AppKit</th><th>UIKit</th><th>Android Views</th><th>WinUI 3</th><th>GTK 4</th><th>Web</th></tr></thead>
<tbody><tr></tr><tr><td rowspan="2"><code>showsText</code></td><td>property</td><td><code>Bool</code></td><td>adaptive</td><td align="center">–</td><td align="center">–</td><td align="center">·</td><td align="center">✅</td><td align="center">✅</td><td align="center">✅</td></tr>
<tr><td colspan="9">AppKit: A Mac shows a toolbar's words as its user sets the whole toolbar, not item by item.<br>UIKit: A UIKit bar button shows its picture or its words, never both.<br>Android Views: cannot read an action's words beside its picture - Android shows them on a screen 480 points wide or more, and this one is narrower</td></tr></tbody>
</table>
