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

Inherits: [AutomationElement](tiers/AutomationElement.md) · [MenuItemElement](tiers/MenuItemElement.md) · [ActionElement](tiers/ActionElement.md) · [ButtonMenuElement](tiers/ButtonMenuElement.md) · [TextAndIconElement](tiers/TextAndIconElement.md)

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
<thead><tr><th>Host</th><th>Created</th><th>Members (10)</th><th>Realization</th></tr></thead>
<tbody><tr></tr><tr><td rowspan="2">AppKit</td><td align="center">✓</td><td>5 ✅ · 2 ✓ · 1 –</td><td><code>NSToolbarItem</code>; <code>NSMenuToolbarItem</code> overflow</td></tr>
<tr><td colspan="3">only through the host's own: activate on ToolbarButton: the host's toolbar entry called, no toolbar item touched</td></tr></tbody>
<tbody><tr></tr><tr><td>UIKit</td><td align="center">✅</td><td>6 ✅ · 1 ☑️ · 1 ✓ · 2 –</td><td><code>UIBarButtonItemGroup</code> / <code>UIBarButtonItem</code></td></tr></tbody>
<tbody><tr></tr><tr><td>Android Views</td><td align="center">✅</td><td>6 ✅ · 1 ☑️ · 2 –</td><td><code>Toolbar</code> <code>MenuItem</code></td></tr></tbody>
<tbody><tr></tr><tr><td>WinUI 3</td><td align="center">✅</td><td>10 ✅</td><td><code>CommandBar</code> <code>AppBarButton</code> in the <code>TitleBar</code></td></tr></tbody>
<tbody><tr></tr><tr><td>GTK 4</td><td align="center">✅</td><td>8 ✅ · 1 ✓ · 1 –</td><td><code>GtkButton</code> in an <code>AdwHeaderBar</code></td></tr></tbody>
<tbody><tr></tr><tr><td>Web</td><td align="center">✅</td><td>10 ✅</td><td><code>&lt;button&gt;</code> in an ARIA <code>toolbar</code></td></tr></tbody>
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
