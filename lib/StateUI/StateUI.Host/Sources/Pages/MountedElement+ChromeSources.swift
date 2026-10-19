// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI

/// What a render changes of the windows' chrome, the same on every host: whether it made, let go of or changed an
/// element the chrome is made of, put declarations in a new order, or turned the enablement of a branch holding
/// one. A render that did none of it shows no window again.
/// Design: docs/design/host/pages.md#a-render-that-touches-the-chrome
extension MountedElement {
    /// A render made this element, or lets go of it.
    func madeOrLeftByRender() {
        if Self.chromeTypes.contains(type) { tree?.chromeTouched = true }
    }

    /// A render changed this element's `changed` values, its handlers or which children it holds.
    func changedByRender(_ changed: Set<Prop>) {
        guard let tree, !tree.chromeTouched else { return }

        if makesChrome || changed.contains(.isEnabled) && holdsDeclarations { tree.chromeTouched = true }
    }

    /// A render arranged this element's children anew, where it held `before`: the chrome follows where it is made
    /// of the element, or where the children it kept stand in a new order and one holds a declaration.
    func arrangedByRender(from before: [MountedElement]) {
        guard let tree, !tree.chromeTouched else { return }
        guard !makesChrome else {
            tree.chromeTouched = true
            return
        }

        let (wasHeld, isHeld) = (Set(before.map(ObjectIdentifier.init)), Set(held.map(ObjectIdentifier.init)))
        let keptBefore = before.lazy.filter { isHeld.contains(ObjectIdentifier($0)) }
        let keptNow = held.lazy.filter { wasHeld.contains(ObjectIdentifier($0)) }
        if !keptBefore.elementsEqual(keptNow, by: ===) { reorderedByRender() }
    }

    /// A render put this element's children in a new order.
    func reorderedByRender() {
        guard let tree, !tree.chromeTouched else { return }

        if makesChrome || held.contains(where: \.holdsDeclarations) { tree.chromeTouched = true }
    }

    /// Whether the chrome is made of this element: a window, its scene and application, an arrangement of pages or
    /// a page, a declaration the chrome takes, or what one holds.
    var makesChrome: Bool {
        if Self.chromeTypes.contains(type) { return true }

        var each = parent
        while let element = each, element.type != .window, !NodeType.pageTypes.contains(element.type) {
            if Self.declarationTypes.contains(element.type) { return true }
            each = element.parent
        }
        return false
    }

    /// Whether a declaration the chrome takes stands in this element's tree, as a page's path finds them: looking
    /// into no other slot and into no collection's items.
    var holdsDeclarations: Bool {
        if Self.declarationTypes.contains(type) { return true }
        if NodeType.slotTypes.contains(type) || type == .itemsView { return false }
        return held.contains(where: \.holdsDeclarations)
    }

    /// The declarations the chrome takes from a page's path: its actions, its title view, its menus, its overlays.
    private static let declarationTypes: Set<NodeType> = [.toolbarItemGroup, .titleView, .menuBar, .overlay]

    /// The elements the chrome is made of by their type.
    private static let chromeTypes = declarationTypes.union(NodeType.pageTypes).union([.application, .scene, .window])
}
