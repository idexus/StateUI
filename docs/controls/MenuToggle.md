<!-- Rendered by ControlDictionaryTests from the contracts and the verdicts each host's runs of its tests wrote under lib/StateUI/exports/marks: STATEUI_UPDATE_DOCS=1 swift test --filter ControlDictionaryTests writes it again. -->

# MenuToggle

One entry in a menu standing checked or not - a setting choosing it turns on and off.

```swift
@State var showsRuler = false

Text("Draft")
    .contextMenu {
        MenuToggle("Show Ruler", isOn: $showsRuler)
            .keyboardShortcut("r")
    }
```

Layer: `structure`. It carries structure or protocol data rather than configuring a visual platform object.

Inherits: [AutomationElement](tiers/AutomationElement.md) · [MenuItemElement](tiers/MenuItemElement.md)

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
<thead><tr><th>Host</th><th>Created</th><th>Members (7)</th><th>Realization</th></tr></thead>
<tbody><tr></tr><tr><td>AppKit</td><td align="center">✅</td><td>6 ✅ · 1 ☑️</td><td>an <code>NSMenuItem</code> whose <code>state</code> is on or off</td></tr></tbody>
<tbody><tr></tr><tr><td>UIKit</td><td align="center">✅</td><td>6 ✅ · 1 ☑️</td><td>a <code>UIAction</code> whose <code>state</code> is on or off</td></tr></tbody>
<tbody><tr></tr><tr><td>Android Views</td><td align="center">✅</td><td>5 ✅ · 2 –</td><td>a checkable <code>MenuItem</code></td></tr></tbody>
<tbody><tr></tr><tr><td>WinUI 3</td><td align="center">✅</td><td>7 ✅</td><td><code>ToggleMenuFlyoutItem</code></td></tr></tbody>
<tbody><tr></tr><tr><td>GTK 4</td><td align="center">✅</td><td>5 ✅ · 2 –</td><td>a <code>GMenu</code> item of a stateful action</td></tr></tbody>
<tbody><tr></tr><tr><td>Web</td><td align="center">✅</td><td>7 ✅</td><td><code>role=menuitemcheckbox</code> with <code>aria-checked</code> in an ARIA <code>menu</code></td></tr></tbody>
</table>

Declared in `lib/StateUI/Core/Sources/Contracts/Elements/Menus/MenuToggleContract.swift`.

## MenuToggle's own members

<table>
<thead><tr><th>Member</th><th>Kind</th><th>Value</th><th>Layer</th><th>AppKit</th><th>UIKit</th><th>Android Views</th><th>WinUI 3</th><th>GTK 4</th><th>Web</th></tr></thead>
<tbody><tr></tr><tr><td><code>isOn</code></td><td>property</td><td><code>Bool</code></td><td>native</td><td align="center">✅</td><td align="center">✅</td><td align="center">✅</td><td align="center">✅</td><td align="center">✅</td><td align="center">✅</td></tr></tbody>
<tbody><tr></tr><tr><td><code>onToggled</code> (<code>toggled</code>)</td><td>event</td><td><code>Bool</code></td><td>native</td><td align="center">✅</td><td align="center">✅</td><td align="center">✅</td><td align="center">✅</td><td align="center">✅</td><td align="center">✅</td></tr></tbody>
</table>

## From [AutomationElement](tiers/AutomationElement.md)

What an element the platform's automation meets has - a drawn element, a menu's entry or a bar's item, an arrangement of pages: the name automation finds it by.

<table>
<thead><tr><th>Member</th><th>Kind</th><th>Value</th><th>Layer</th><th>AppKit</th><th>UIKit</th><th>Android Views</th><th>WinUI 3</th><th>GTK 4</th><th>Web</th></tr></thead>
<tbody><tr></tr><tr><td rowspan="2"><code>accessibilityIdentifier</code></td><td>property</td><td><code>String</code></td><td>native</td><td align="center">☑️</td><td align="center">✅</td><td align="center">–</td><td align="center">✅</td><td align="center">–</td><td align="center">✅</td></tr>
<tr><td colspan="9">AppKit: Only an entry of a context menu carries it; an entry the page puts in the menu bar does not.<br>Android Views: An Android menu entry holds no identifier: automation finds it by its title.<br>GTK 4: GTK 4 tells assistive technology no identifier before 4.22, and from 4.22 only a GtkBuilder file's id, which no public call sets on a widget made in code.</td></tr></tbody>
</table>

## From [MenuItemElement](tiers/MenuItemElement.md)

What every item a user chooses from says - a menu's entry, a toolbar's item, an action or a setting: a caption, a picture, whether it can be chosen, and the keys that choose it.

<table>
<thead><tr><th>Member</th><th>Kind</th><th>Value</th><th>Layer</th><th>AppKit</th><th>UIKit</th><th>Android Views</th><th>WinUI 3</th><th>GTK 4</th><th>Web</th></tr></thead>
<tbody><tr></tr><tr><td rowspan="2"><code>icon</code></td><td>property</td><td><code>ImageSource</code></td><td>adaptive</td><td align="center">✅</td><td align="center">✅</td><td align="center">–</td><td align="center">✅</td><td align="center">–</td><td align="center">✅</td></tr>
<tr><td colspan="9">Android Views: Android's menus - a view's context menu, a bar's overflow and its submenus - draw their entries' words alone.<br>GTK 4: GNOME's menus show words alone, no picture beside them.</td></tr></tbody>
<tbody><tr></tr><tr><td><code>isEnabled</code></td><td>property</td><td><code>Bool</code></td><td>native</td><td align="center">✅</td><td align="center">✅</td><td align="center">✅</td><td align="center">✅</td><td align="center">✅</td><td align="center">✅</td></tr></tbody>
<tbody><tr></tr><tr><td rowspan="2"><code>keyboardShortcut</code></td><td>property</td><td><code>KeyboardShortcut</code></td><td>native</td><td align="center">✅</td><td align="center">☑️</td><td align="center">✅</td><td align="center">✅</td><td align="center">✅</td><td align="center">✅</td></tr>
<tr><td colspan="9">UIKit: UIKit shows a shortcut in the main menu alone, none in a context menu.</td></tr></tbody>
<tbody><tr></tr><tr><td><code>text</code></td><td>property</td><td><code>String</code></td><td>native</td><td align="center">✅</td><td align="center">✅</td><td align="center">✅</td><td align="center">✅</td><td align="center">✅</td><td align="center">✅</td></tr></tbody>
</table>
