// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI

/// The shared transitions of one tree: a view dropped and a view made in one patch, wearing one key in one
/// scope, are one - the made one enters from the rectangle the dropped one was drawn in.
/// Design: docs/design/host/motion.md#a-shared-transition
@_spi(Host) @MainActor public final class SharedTransitions {
    /// A key in its scope: the element that is the scope, by its mount, and the key's number.
    private struct Key: Hashable {
        let scope: UInt64
        let number: Int
    }

    /// A view that left wearing a key: the patch that dropped it, where it was drawn, in its window's
    /// coordinates, and where it stood.
    private struct Source {
        let patch: Int
        let drawn: Rect
        let window: UInt64?
        let page: UInt64?
        weak var element: MountedElement?
    }

    private var sources: [Key: [Source]] = [:]
    private var made: [Key: [(mount: UInt64, patch: Int)]] = [:]

    /// The patch being applied, or the last one, by its count: one commit is one patch.
    private var patch = 0

    /// How many frames the notes of the last patch still last: a toolkit lays the patch out within them.
    private var framesLeft = 0

    /// Told a key met partners it could not be matched with: `element` enters by its own transition.
    var refused: ((MountedElement) -> Void)?

    /// Shared transitions of a tree.
    public init() {}

    /// A patch is about to be applied: what it drops and makes is its own.
    func patchBegins() {
        patch += 1
    }

    /// `element` is dropped by the patch being applied, before it is let go: every view wearing a key in it or
    /// under it is noted where it is drawn.
    func dropped(_ element: MountedElement) {
        if let key = Self.key(of: element), let numbers = element.native.frameNumbers(), numbers.count >= 8 {
            let drawn = element.presentationFrame(from: numbers)
            sources[key, default: []].append(Source(
                patch: patch, drawn: Rect(x: drawn[4], y: drawn[5], width: drawn[2], height: drawn[3]),
                window: element.enclosing(type: .window)?.mount, page: element.enclosing(type: .page)?.mount,
                element: element))
            framesLeft = PresentationChanges.layoutWindow
        }
        for child in element.children { dropped(child) }
    }

    /// `element` was made by the patch being applied, wearing a key.
    func made(_ element: MountedElement) {
        guard let key = Self.key(of: element) else { return }

        made[key, default: []].append((element.mount, patch))
        framesLeft = PresentationChanges.layoutWindow
    }

    /// The rectangle `element`, given its first place, enters from: where the one view its patch dropped
    /// wearing its key was drawn, in its window's coordinates, with where `element` is placed there - and that
    /// view, should it still be leaving. Nil where the patch dropped none wearing the key; nil too, and said,
    /// where it dropped or made more than one, they stood in other windows or pages, or where `element` stands
    /// is not known yet.
    func source(for element: MountedElement, in tree: MountedTree) -> (from: Rect, to: Rect, leaving: MountedElement?)? {
        guard let key = Self.key(of: element),
              let mine = made[key]?.first(where: { $0.mount == element.mount })?.patch
        else { return nil }
        let left = (sources[key] ?? []).filter { $0.patch == mine }
        let born = (made[key] ?? []).filter { $0.patch == mine }
        guard !left.isEmpty else { return nil }
        defer {
            sources[key]?.removeAll { $0.patch == mine }
            made[key]?.removeAll { $0.patch == mine }
        }
        guard left.count == 1, born.count == 1, let source = left.first,
              source.window == element.enclosing(type: .window)?.mount,
              source.page == element.enclosing(type: .page)?.mount,
              let destination = Self.placeInWindow(of: element, scope: key.scope, in: tree),
              destination.width > 0, destination.height > 0, source.drawn.width > 0, source.drawn.height > 0
        else {
            refused?(element)
            return nil
        }
        return (source.drawn, destination, source.element)
    }

    /// A display frame ended: the notes of a patch laid out by now are let go.
    func frameEnded() {
        guard framesLeft > 0 else { return }

        framesLeft -= 1
        if framesLeft == 0 {
            sources.removeAll()
            made.removeAll()
        }
    }

    /// The key `element` wears in the scope it stands under; nil where it wears none or stands under no scope.
    private static func key(of element: MountedElement) -> Key? {
        guard let number = element.value(ViewContract.sharedTransition.token)?.int else { return nil }

        var above = element.parent
        while let holder = above {
            if holder.value(LayoutContract.transitionScope.token) != nil { return Key(scope: holder.mount, number: number) }
            above = holder.parent
        }
        return nil
    }

    /// Where `element` is placed, in its window's coordinates: the place its layout gave it, and each place a
    /// layout gave what holds it, up to its scope or to the first view no layout's motion placed - whose corner
    /// the toolkit says. Nil where that view stands nowhere yet.
    private static func placeInWindow(of element: MountedElement, scope: UInt64, in tree: MountedTree) -> Rect? {
        guard let own = tree.layoutMotion.placed(element.mount)?.place else { return nil }

        var (x, y) = (own.x, own.y)
        var above = element.parent
        while let holder = above {
            if holder.mount != scope, let place = tree.layoutMotion.placed(holder.mount)?.place {
                x += place.x
                y += place.y
                above = holder.parent
                continue
            }
            guard let numbers = holder.native.frameNumbers(), numbers.count >= 8 else { return nil }
            return Rect(x: numbers[4] + x, y: numbers[5] + y, width: own.width, height: own.height)
        }
        return nil
    }
}
