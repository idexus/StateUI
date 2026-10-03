// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

/// The properties every positioned view has: the value half of `View`, shared
/// by the control and its `Style`, including where it sits in a Grid or a
/// ZStack.
public protocol ViewProperties: VisualElementProperties {}

/// A visual element a layout positions, with the gestures, the pan feeds,
/// the frame report and the context menu only a control can carry. A
/// modifier on a view gives back a view, so a chain goes on - on `any View`
/// too.
///
/// A view of the application's own is made of other views, in its `body`:
///
///     struct Header: View {
///         private let title: String
///
///         init(_ title: String) {
///             self.title = title
///         }
///
///         var body: some View {
///             Text(title).fontSize(28).fontAttributes(.bold)
///         }
///     }
///
/// `body` is read the first time the view is built, and again when what it
/// was built with or a state it read changes; otherwise the view is carried
/// whole.
///
/// Configure it the way every control is: what it is goes in the initializer,
/// with no default, and what a caller may leave out is a modifier returning
/// `Self` that sets a `private` field. The modifiers every view has work on it
/// too, written after its own, since they return a `ModifiedContent`:
///
///     Header("Settings")
///         .margin(horizontal: 0, vertical: 8)
///         .gridRow(1)
public protocol View: VisualElement, ViewProperties, Views where Modified: View {
    /// The view it is made of.
    associatedtype Body: View

    /// What this view is made of, read each time the view is built: one view -
    /// an `if`/`else` of views is one, its branches two elements.
    @ViewBuilder var body: Body { get }
}

extension ViewProperties {
    /// The space kept outside the view, between it and its neighbours.
    /// Padding is the space inside.
    ///
    ///     Text("Total").margin(16)                      // all four sides
    ///     Text("Total").margin(Insets(left: 16, top: 0, right: 0, bottom: 0))  // the left edge only
    public func margin(_ value: Insets) -> Modified { setValue(ViewContract.margin, value) }

    /// The same on the left and the right, and the same above and below.
    public func margin(horizontal: Double, vertical: Double) -> Modified {
        margin(Insets(horizontal: horizontal, vertical: vertical))
    }

    /// Each side by name.
    public func margin(left: Double, top: Double, right: Double, bottom: Double) -> Modified {
        margin(Insets(left: left, top: top, right: right, bottom: bottom))
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
    ///     Text(item.name)
    ///         .contextMenu {
    ///             MenuItem("Rename").onClicked { rename(item) }
    ///             Divider()
    ///             MenuItem("Delete").isDestructive(true).onClicked { remove(item) }
    ///         }
    ///
    /// The same entries a menu bar takes - `MenuItem`, `Menu`
    /// and `Divider` - attached to a view instead of to a page.
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
            $0.children.append(Node(contract: ContextMenuContract.self, children: items().map { $0.node }))
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
