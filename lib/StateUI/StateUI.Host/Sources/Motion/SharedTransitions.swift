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

    /// Every element the patches whose notes are kept made, by its mount: one a layout program places stands where
    /// its toolkit put it until the program has been asked.
    private var born: Set<UInt64> = []

    /// The patch being applied, or the last one, by its count: one commit is one patch.
    private var patch = 0

    /// How many frames the notes of the last patch still last: a toolkit lays the patch out within them.
    private var framesLeft = 0

    /// Told a key met partners it could not be matched with: `element` enters by its own transition.
    var refused: ((MountedElement) -> Void)?

    /// Shared transitions of a tree.
    public init() {}

    /// How many views dropped and made the last patch's notes hold.
    var entries: Int {
        sources.values.reduce(0) { $0 + $1.count } + made.values.reduce(0) { $0 + $1.count } + born.count
    }

    /// A patch is about to be applied: what it drops and makes is its own.
    func patchBegins() {
        patch += 1
        if framesLeft == 0 { born.removeAll() }
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
        born.insert(element.mount)
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
              let mine = made[key]?.first(where: { $0.mount == element.mount })?.patch,
              sources[key]?.contains(where: { $0.patch == mine }) == true
        else { return nil }
        defer {
            sources[key]?.removeAll { $0.patch == mine }
            made[key]?.removeAll { $0.patch == mine }
        }
        guard let source = partner(of: element, key: key, patch: mine),
              let destination = placeInWindow(of: element, scope: key.scope, in: tree),
              destination.width > 0, destination.height > 0
        else {
            refused?(element)
            return nil
        }
        return (source.drawn, destination, source.element)
    }

    /// Whether a view made under `element`, by the patch that made it, sets out from its partner, as far as is known
    /// before it is placed: `element` then comes as it stands, as its fade would hide where that view sets out.
    /// Design: docs/design/host/motion.md#a-shared-transition
    func holdsAPartner(_ element: MountedElement) -> Bool {
        made.contains { key, entering in
            entering.contains { mine in
                element.first(mount: mine.mount).map { partner(of: $0, key: key, patch: mine.patch) != nil } ?? false
            }
        }
    }

    /// The one view the patch `patch` dropped wearing `key` that `element`, made by it wearing the key, sets out
    /// from - all that is known before `element` is placed: one dropped and one made, drawn, in one window and one
    /// page, and nothing between `element` and its scope standing where the tree does not know.
    private func partner(of element: MountedElement, key: Key, patch: Int) -> Source? {
        let left = (sources[key] ?? []).filter { $0.patch == patch }
        guard left.count == 1, let source = left.first, (made[key] ?? []).count(where: { $0.patch == patch }) == 1,
              source.drawn.width > 0, source.drawn.height > 0,
              source.window == element.enclosing(type: .window)?.mount,
              source.page == element.enclosing(type: .page)?.mount
        else { return nil }

        var above: MountedElement? = element
        while let view = above, view.mount != key.scope {
            if standsUnknown(view) { return nil }
            above = view.parent
        }
        return source
    }

    /// A display frame ended: the notes of a patch laid out by now are let go.
    func frameEnded() {
        guard framesLeft > 0 else { return born.removeAll() }

        framesLeft -= 1
        if framesLeft == 0 {
            sources.removeAll()
            made.removeAll()
            born.removeAll()
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
    /// the toolkit says. Nil where a place is not known yet - one a layout program places, made with this patch.
    /// Design: docs/design/host/motion.md#a-shared-transition
    private func placeInWindow(of element: MountedElement, scope: UInt64, in tree: MountedTree) -> Rect? {
        guard case .at(let own) = place(of: element, in: tree) else { return nil }

        var (x, y) = (own.x, own.y)
        var above = element.parent
        while let holder = above {
            if holder.mount != scope {
                switch place(of: holder, in: tree) {
                case .at(let place):
                    x += place.x
                    y += place.y
                    above = holder.parent
                    continue
                case .unknown:
                    return nil
                case .toolkits:
                    break
                }
            }
            guard let numbers = holder.native.frameNumbers(), numbers.count >= 8 else { return nil }
            return Rect(x: numbers[4] + x, y: numbers[5] + y, width: own.width, height: own.height)
        }
        return nil
    }

    /// Where a view stands in what holds it, as the host layer knows it.
    private enum Place {
        /// At this place in what holds it.
        case at(Rect)
        /// Made with this patch, a layout program places it, and its toolkit holds it where the program has not.
        case unknown
        /// Where its toolkit holds it: no layout's motion placed it.
        case toolkits
    }

    /// Where `element` stands in what holds it: nowhere known where a layout program places it and this patch
    /// made it - its toolkit stands it across the layout's room until the program is asked - else the place a
    /// layout's motion gave it.
    private func place(of element: MountedElement, in tree: MountedTree) -> Place {
        if standsUnknown(element) { return .unknown }
        return tree.layoutMotion.placed(element.mount).map { .at($0.place) } ?? .toolkits
    }

    /// Whether `element` was made with the notes kept and a layout program places it: its toolkit holds it where
    /// the program has not been asked yet.
    private func standsUnknown(_ element: MountedElement) -> Bool {
        born.contains(element.mount) && element.parent?.layoutProgram != nil
    }
}
