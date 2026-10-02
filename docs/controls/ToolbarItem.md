<!-- Rendered by ControlDictionaryTests from the contracts and the verdicts each host's runs of its tests wrote under lib/StateUI/exports/marks: STATEUI_UPDATE_DOCS=1 swift test --filter ControlDictionaryTests writes it again. -->

# ToolbarItem

An action in the page's native navigation or toolbar surface.

```swift
@State var count = 0

Label("\(count) items")
    .toolbar {
        ToolbarItem("Add")
            .icon("add.png")
            .showsText(true)
            .onClicked { count += 1 }
        ToolbarItem("Clear")
            .placement(.overflow)
            .isDestructive(true)
            .onClicked { count = 0 }
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
<tr><th>Host</th><th>Created</th><th>Members (8)</th><th>Realization</th></tr>
<tr><td>AppKit</td><td align="center">✓</td><td>2 ✅ · 1 ✓</td><td><code>NSToolbarItem</code>; <code>NSMenuToolbarItem</code> overflow</td></tr>
<tr><td></td><td colspan="3">only through the host's own: activate on ToolbarItem: the host's toolbar entry called, no toolbar item touched</td></tr>
<tr><td>UIKit</td><td align="center">✅</td><td>6 ✅</td><td><code>UIBarButtonItem</code></td></tr>
<tr><td>Android Views</td><td align="center">✅</td><td>4 ✅ · 1 –</td><td><code>Toolbar</code> <code>MenuItem</code></td></tr>
<tr><td>WinUI 3</td><td align="center">✅</td><td>8 ✅</td><td><code>CommandBar</code> <code>AppBarButton</code></td></tr>
<tr><td>GTK 4</td><td align="center">✅</td><td>7 ✅ · 1 –</td><td><code>GtkButton</code> in <code>GtkHeaderBar</code></td></tr>
<tr><td>Web</td><td align="center"></td><td></td><td><code>&lt;button&gt;</code> in an ARIA <code>toolbar</code></td></tr>
<tr><td></td><td colspan="3">no host yet</td></tr>
</table>

Declared in `lib/StateUI/Core/Sources/Contracts/Elements/Menus/ToolbarItemContract.swift`.

## ToolbarItem's own members

<table>
<tr><th>Member</th><th>Kind</th><th>Value</th><th>Layer</th><th>AppKit</th><th>UIKit</th><th>Android Views</th><th>WinUI 3</th><th>GTK 4</th><th>Web</th></tr>
<tr><td><code>placement</code></td><td>property</td><td><code>ToolbarItemPlacement</code></td><td>adaptive</td><td align="center">·</td><td align="center">·</td><td align="center">·</td><td align="center">✅</td><td align="center">✅</td><td></td></tr>
<tr><td></td><td colspan="9">AppKit: cannot read placement of ToolbarItem - AppKit's driver has no path for it yet<br>UIKit: cannot read placement of ToolbarItem - UIKit's driver has no path for it yet<br>Android Views: cannot read placement of ToolbarItem - Android's driver has no path for it yet</td></tr>
<tr><td><code>showsText</code></td><td>property</td><td><code>Bool</code></td><td>adaptive</td><td align="center"></td><td align="center"></td><td align="center">·</td><td align="center">✅</td><td align="center">✅</td><td></td></tr>
<tr><td></td><td colspan="9">AppKit, UIKit: not realized<br>Android Views: cannot read showsText of ToolbarItem - Android's driver has no path for it yet</td></tr>
</table>

## From [PropertyContainer](tiers/PropertyContainer.md)

What anything carrying values in the tree has - a control, a `Style`, a text run: the name automation finds it by.

<table>
<tr><th>Member</th><th>Kind</th><th>Value</th><th>Layer</th><th>AppKit</th><th>UIKit</th><th>Android Views</th><th>WinUI 3</th><th>GTK 4</th><th>Web</th></tr>
<tr><td><code>accessibilityIdentifier</code></td><td>property</td><td><code>String</code></td><td>native</td><td align="center"></td><td align="center">✅</td><td align="center">–</td><td align="center">✅</td><td align="center">–</td><td></td></tr>
<tr><td></td><td colspan="9">AppKit: not realized<br>Android Views: An Android bar action is a menu entry, which holds no identifier: automation finds it by its title.<br>GTK 4: GTK 4 gives an accessible the identifier a GtkBuilder file names alone: none is set on a widget made in code.</td></tr>
</table>

## From [MenuItemElement](tiers/MenuItemElement.md)

What every item a user chooses from has - a menu's entry, a toolbar's item: a caption, a picture, and something to run.

<table>
<tr><th>Member</th><th>Kind</th><th>Value</th><th>Layer</th><th>AppKit</th><th>UIKit</th><th>Android Views</th><th>WinUI 3</th><th>GTK 4</th><th>Web</th></tr>
<tr><td><code>onClicked</code> (<code>clicked</code>)</td><td>event</td><td></td><td>native</td><td align="center">✓</td><td align="center">✅</td><td align="center">✅</td><td align="center">✅</td><td align="center">✅</td><td></td></tr>
<tr><td></td><td colspan="9">AppKit: only through the host's own: activate on ToolbarItem: the host's toolbar entry called, no toolbar item touched</td></tr>
<tr><td><code>icon</code></td><td>property</td><td><code>ImageSource</code></td><td>adaptive</td><td align="center">·</td><td align="center">✅</td><td align="center">·</td><td align="center">✅</td><td align="center">✅</td><td></td></tr>
<tr><td></td><td colspan="9">AppKit: cannot read icon of ToolbarItem - AppKit's driver has no path for it yet<br>Android Views: cannot read a picture's name - Android's item keeps its picture, not its name</td></tr>
<tr><td><code>isDestructive</code></td><td>property</td><td><code>Bool</code></td><td>adaptive</td><td align="center"></td><td align="center">✅</td><td align="center">✅</td><td align="center">✅</td><td align="center">✅</td><td></td></tr>
<tr><td></td><td colspan="9">AppKit: not realized</td></tr>
<tr><td><code>isEnabled</code></td><td>property</td><td><code>Bool</code></td><td>native</td><td align="center">✅</td><td align="center">✅</td><td align="center">✅</td><td align="center">✅</td><td align="center">✅</td><td></td></tr>
<tr><td><code>text</code></td><td>property</td><td><code>String</code></td><td>native</td><td align="center">✅</td><td align="center">✅</td><td align="center">✅</td><td align="center">✅</td><td align="center">✅</td><td></td></tr>
</table>
