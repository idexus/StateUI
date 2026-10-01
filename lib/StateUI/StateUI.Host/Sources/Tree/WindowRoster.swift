// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI

/// The windows a tree holds, the same on every host: its window elements in the tree's order, each with the host's
/// controller of it - the one a window the tree keeps had, made for one new, closed for one gone, the last first, so
/// a window closes before the one it belongs to.
/// Design: docs/design/host/tree.md#the-windows-a-tree-holds
@_spi(Host) @MainActor public final class WindowRoster<Controller: AnyObject> {
    private struct Entry {
        weak var element: MountedElement?
        let controller: Controller
    }

    private var entries: [Entry] = []

    /// No window yet.
    public init() {}

    /// Each window element and its controller, in the tree's order.
    public var windows: [(element: MountedElement, controller: Controller)] {
        entries.compactMap { entry in entry.element.map { ($0, entry.controller) } }
    }

    /// The controllers, in the tree's order of their windows.
    public var controllers: [Controller] {
        entries.map(\.controller)
    }

    /// Stands the roster as `root` holds its windows now: a controller made by `make` for each new window, one
    /// handed to `close` for each window gone, the last first; whether the first window came now.
    @discardableResult
    public func update(
        root: MountedElement?, make: (MountedElement) -> Controller, close: (Controller) -> Void
    ) -> Bool {
        let elements = root?.windows ?? []
        for entry in entries.reversed() where !elements.contains(where: { $0 === entry.element }) {
            close(entry.controller)
        }

        let first = entries.isEmpty && !elements.isEmpty
        entries = elements.map { element in
            entries.first { $0.element === element } ?? Entry(element: element, controller: make(element))
        }
        return first
    }

    /// The controller of the window `element` stands in; nil for none.
    public func controller(of element: MountedElement) -> Controller? {
        guard let window = element.enclosing(type: .window) else { return nil }

        return entries.first { $0.element === window }?.controller
    }
}
