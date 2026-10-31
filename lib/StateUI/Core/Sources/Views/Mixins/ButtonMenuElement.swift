// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

/// What a button and a toolbar button share: a menu, opened as its kind
/// says, and the arrow saying a click opens it.
///
///     Button("Share").menu {
///         MenuItem("Mail").onClicked { mail() }
///     }
///
///     ToolbarButton("New")
///         .onClicked { newNote() }
///         .menu { MenuItem("New folder").onClicked { newFolder() } }
public protocol ButtonMenuElement: PropertyContainer {}

extension ButtonMenuElement {
    /// Whether a button whose click opens its menu shows the arrow saying so -
    /// true unless said; a button standing for its picture alone may leave it
    /// out. A split button's arrow is its menu's, and a held one has none.
    public func showsMenuArrow(_ value: Bool) -> Modified {
        setValue(ButtonMenuElementContract.showsMenuArrow, value)
    }
}

extension ButtonMenuElement where Self: Element, Modified == Self {
    /// A menu the button opens, holding what a menu holds - `MenuItem`,
    /// `MenuToggle`, `Menu`, `MenuSeparator` - as `kind` says. With no
    /// `.onClicked` a click opens it, an arrow pointing down saying so; with
    /// one the button splits: its click is its own action, and its menu opens
    /// from an arrow of its own. `.held` keeps the click the button's own and
    /// opens the menu as the button is held, with no arrow.
    ///
    ///     Button("Share").menu {
    ///         MenuItem("Mail").onClicked { mail() }
    ///         MenuItem("Message").onClicked { message() }
    ///     }
    ///
    ///     Button("Save")
    ///         .onClicked { save() }
    ///         .menu { MenuItem("Save as…").onClicked { saveAs() } }
    public func menu(_ kind: ButtonMenuKind = .automatic, @MenuBuilder _ entries: () -> MenuEntries) -> Modified {
        let menu = modified {
            // The button's one menu, after its own children; written again, it stands in for the last.
            // Design: docs/design/views/modifiers.md#slot-children
            $0.children.removeAll { $0.type == .buttonMenu }
            $0.children.append(Node(contract: ButtonMenuContract.self, children: entries().nodes))
            // Its kind with it: a menu saying none takes no kind an earlier one said.
            $0.props[ButtonMenuElementContract.menuKind.token] = nil
        }
        return kind == .automatic ? menu : menu.setValue(ButtonMenuElementContract.menuKind, kind)
    }
}
