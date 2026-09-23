// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

/// The properties every positioned view has: the value half of `View`, shared
/// by the control and its `Style`, including where it sits in a Grid or an
/// AbsoluteLayout.
public protocol ViewProperties: VisualElementProperties {}

/// A visual element a layout positions, with the gestures, the pan feeds,
/// the frame report and the context menu only a control can carry.
public protocol View: VisualElement, ViewProperties, Page {}

extension ViewProperties {
    /// The space kept outside the view, between it and its neighbours.
    /// Padding is the space inside.
    ///
    ///     Label("Total").margin(16)                      // all four sides
    ///     Label("Total").margin(Insets(16, 0, 0, 0))  // the left edge only
    public func margin(_ value: Insets) -> Modified { setValue(ViewContract.margin, value) }

    /// Left and right, then top and bottom.
    public func margin(_ horizontalSize: Double, _ verticalSize: Double) -> Modified {
        margin(Insets(horizontalSize, verticalSize))
    }

    /// Each side in turn: left, top, right, bottom.
    public func margin(_ left: Double, _ top: Double, _ right: Double, _ bottom: Double) -> Modified {
        margin(Insets(left, top, right, bottom))
    }

    /// How the view uses the width its parent offers - filling it, or sitting at
    /// one end of it.
    ///
    ///     Button("Save").horizontalAlignment(.center)
    public func horizontalAlignment(_ value: Alignment) -> Modified {
        setValue(ViewContract.horizontalAlignment, value)
    }

    /// The same, for the height.
    public func verticalAlignment(_ value: Alignment) -> Modified {
        setValue(ViewContract.verticalAlignment, value)
    }
}

extension View {
    /// A menu on the view itself, opened with a right-click.
    ///
    ///     Label(item.name)
    ///         .contextMenu {
    ///             MenuItem("Rename").onClicked { rename(item) }
    ///             MenuSeparator()
    ///             MenuItem("Delete").isDestructive(true).onClicked { remove(item) }
    ///         }
    ///
    /// The same entries a menu bar takes - `MenuItem`, `Menu`
    /// and `MenuSeparator` - attached to a view instead of to a page.
    ///
    /// Context menus are a desktop interaction. A host with no native context
    /// menu interaction leaves this modifier inert, so do not put the only way
    /// to perform an essential action behind it.
    ///
    /// - Parameter items: the entries, in the order they are shown.
    public func contextMenu(@MenuBuilder _ items: () -> [Element]) -> Modified {
        modified {
            // After the view's own children; the host finds it by type.
            // Design: docs/design/views/modifiers.md#slot-children
            $0.children.append(Node(contract: ContextMenuContract.self, children: items().map { $0.body }))
        }
    }
}

extension View {
    /// `horizontalAlignment` from a state, `$x`: the host sets each new value
    /// as it stands, and no view is rebuilt for it.
    public func horizontalAlignment(_ state: Binding<Alignment>) -> Modified {
        plain(ViewContract.horizontalAlignment, by: state)
    }

    /// `margin` from a state, `$x`: the host animates the property to each new
    /// value, and no view is rebuilt for it.
    public func margin(_ state: Binding<Insets>) -> Modified {
        journey(ViewContract.margin, by: state)
    }

    /// `verticalAlignment` from a state, `$x`: the host sets each new value as
    /// it stands, and no view is rebuilt for it.
    public func verticalAlignment(_ state: Binding<Alignment>) -> Modified {
        plain(ViewContract.verticalAlignment, by: state)
    }
}
