<!-- Rendered by ControlDictionaryTests from the contracts and the verdicts each host's runs of its tests wrote under lib/StateUI/exports/marks: STATEUI_UPDATE_DOCS=1 swift test --filter ControlDictionaryTests writes it again. -->

# MenuItem

One entry in a menu.

```swift
@State var archived = false

Text("Report.pdf")
    .contextMenu {
        MenuItem(archived ? "Unarchive" : "Archive")
            .icon("archive.png")
            .onClicked { archived.toggle() }
    }
```

Layer: `structure`. It carries structure or protocol data rather than configuring a visual platform object.

Inherits: [PropertyContainer](tiers/PropertyContainer.md) · [MenuItemElement](tiers/MenuItemElement.md)

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
<thead><tr><th>Host</th><th>Created</th><th>Members (6)</th><th>Realization</th></tr></thead>
<tbody><tr></tr><tr><td>AppKit</td><td align="center">✅</td><td>4 ✅ · 1 ☑️</td><td><code>NSMenu</code> / <code>NSMenuItem</code></td></tr></tbody>
<tbody><tr></tr><tr><td>UIKit</td><td align="center">✅</td><td>6 ✅</td><td><code>UIMenu</code> / <code>UIAction</code></td></tr></tbody>
<tbody><tr></tr><tr><td>Android Views</td><td align="center">✅</td><td>4 ✅ · 2 –</td><td><code>PopupMenu</code> / <code>MenuItem</code>; no menu bar</td></tr></tbody>
<tbody><tr></tr><tr><td>WinUI 3</td><td align="center">✅</td><td>6 ✅</td><td><code>MenuFlyout</code> / <code>MenuBar</code></td></tr></tbody>
<tbody><tr></tr><tr><td>GTK 4</td><td align="center">✅</td><td>3 ✅ · 3 –</td><td><code>GMenu</code> in <code>GtkPopoverMenu</code> / <code>GtkPopoverMenuBar</code></td></tr></tbody>
<tbody><tr></tr><tr><td>Web</td><td align="center">✅</td><td>6 ✅</td><td>ARIA <code>menu</code> / <code>menubar</code> (?)</td></tr></tbody>
</table>

Declared in `lib/StateUI/Core/Sources/Contracts/Elements/Menus/MenuItemContract.swift`.

## MenuItem's own members

MenuItem declares no members of its own.

## From [PropertyContainer](tiers/PropertyContainer.md)

What anything carrying values in the tree has - a control, a `Style`, a text run: the name automation finds it by.

<table>
<thead><tr><th>Member</th><th>Kind</th><th>Value</th><th>Layer</th><th>AppKit</th><th>UIKit</th><th>Android Views</th><th>WinUI 3</th><th>GTK 4</th><th>Web</th></tr></thead>
<tbody><tr></tr><tr><td rowspan="2"><code>accessibilityIdentifier</code></td><td>property</td><td><code>String</code></td><td>native</td><td align="center">☑️</td><td align="center">✅</td><td align="center">–</td><td align="center">✅</td><td align="center">–</td><td align="center">✅</td></tr>
<tr><td colspan="9">AppKit: Only an entry of a context menu carries it; an entry the page puts in the menu bar does not.<br>Android Views: An Android menu entry holds no identifier: automation finds it by its title.<br>GTK 4: GTK 4 gives an accessible the identifier a GtkBuilder file names alone: none is set on a widget made in code.</td></tr></tbody>
</table>

## From [MenuItemElement](tiers/MenuItemElement.md)

What every item a user chooses from has - a menu's entry, a toolbar's item: a caption, a picture, and something to run.

<table>
<thead><tr><th>Member</th><th>Kind</th><th>Value</th><th>Layer</th><th>AppKit</th><th>UIKit</th><th>Android Views</th><th>WinUI 3</th><th>GTK 4</th><th>Web</th></tr></thead>
<tbody><tr></tr><tr><td><code>onClicked</code> (<code>clicked</code>)</td><td>event</td><td></td><td>native</td><td align="center">✅</td><td align="center">✅</td><td align="center">✅</td><td align="center">✅</td><td align="center">✅</td><td align="center">✅</td></tr></tbody>
<tbody><tr></tr><tr><td rowspan="2"><code>icon</code></td><td>property</td><td><code>ImageSource</code></td><td>adaptive</td><td align="center">·</td><td align="center">✅</td><td align="center">–</td><td align="center">✅</td><td align="center">–</td><td align="center">✅</td></tr>
<tr><td colspan="9">AppKit: cannot read icon of MenuItem - AppKit's driver has no path for it yet<br>Android Views: Android's menus - a view's context menu, a bar's overflow and its submenus - draw their entries' words alone.<br>GTK 4: GNOME's menus show words alone, no picture beside them.</td></tr></tbody>
<tbody><tr></tr><tr><td rowspan="2"><code>isDestructive</code></td><td>property</td><td><code>Bool</code></td><td>adaptive</td><td align="center">✅</td><td align="center">✅</td><td align="center">✅</td><td align="center">✅</td><td align="center">–</td><td align="center">✅</td></tr>
<tr><td colspan="9">GTK 4: GNOME's menus mark no entry as destroying something.</td></tr></tbody>
<tbody><tr></tr><tr><td><code>isEnabled</code></td><td>property</td><td><code>Bool</code></td><td>native</td><td align="center">✅</td><td align="center">✅</td><td align="center">✅</td><td align="center">✅</td><td align="center">✅</td><td align="center">✅</td></tr></tbody>
<tbody><tr></tr><tr><td><code>text</code></td><td>property</td><td><code>String</code></td><td>native</td><td align="center">✅</td><td align="center">✅</td><td align="center">✅</td><td align="center">✅</td><td align="center">✅</td><td align="center">✅</td></tr></tbody>
</table>
