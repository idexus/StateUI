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
    /// coordinates, its corner as drawn there, and where it stood.
    private struct Source {
        let patch: Int
        let drawn: Rect
        let corner: Double?
        let window: UInt64?
        let page: UInt64?
        weak var element: MountedElement?
    }

    /// Two views made one: where the dropped one was drawn and the made one lands as drawn, in the scope; the
    /// same two as the made one's own place stands, what holds it undone; the scope they are one in, the view
    /// dropped - and the view kept for it as it left, should its holder keep one - and its corner as drawn.
    struct Pair {
        let from: Rect
        let to: Rect
        let setsOut: Rect
        let lands: Rect
        let scope: UInt64
        weak var leaving: MountedElement?
        weak var kept: MountedElement?
        let corner: Double?
    }

    private var sources: [Key: [Source]] = [:]
    private var made: [Key: [(mount: UInt64, patch: Int)]] = [:]

    /// The views a patch dropped holding a key, kept for the partner it may have made, by their mount.
    private var awaiting: [UInt64: (patch: Int, root: Weak)] = [:]
    struct Weak {
        weak var element: MountedElement?
    }

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
            + awaiting.count
    }

    /// A patch is about to be applied: what it drops and makes is its own.
    func patchBegins() {
        patch += 1
        if framesLeft == 0 { born.removeAll() }
    }

    /// `element` is dropped by the patch being applied, before it is let go: every view wearing a key in it or
    /// under it is noted where it is drawn, its corner as drawn. Whether one was.
    @discardableResult
    func dropped(_ element: MountedElement) -> Bool {
        var noted = false
        if let key = Self.key(of: element), let numbers = element.native.frameNumbers(), numbers.count >= 8 {
            let own = element.drawnTransform.bounds(of: Rect(x: numbers[4], y: numbers[5], width: numbers[2], height: numbers[3]))
            let drawn = Self.drawn(own, above: element, to: key.scope)
            let scale = numbers[2] > 0 && numbers[3] > 0 ? (drawn.width / numbers[2] * drawn.height / numbers[3]).squareRoot() : 1
            sources[key, default: []].append(Source(
                patch: patch, drawn: drawn, corner: element.ownCorner.map { $0 * scale },
                window: element.enclosing(type: .window)?.mount, page: element.enclosing(type: .page)?.mount,
                element: element))
            framesLeft = PresentationChanges.layoutWindow
            noted = true
        }
        for child in element.children where dropped(child) { noted = true }
        return noted
    }

    /// `root`, dropped holding a key, is kept for the partner its patch may make.
    func awaits(_ root: MountedElement) {
        awaiting[root.mount] = (patch, Weak(element: root))
        framesLeft = PresentationChanges.layoutWindow
    }

    /// The patch is applied whole: a view kept for a partner its patch made none for - one made under none of its
    /// keys - goes at once.
    func patchApplied() {
        for (mount, held) in awaiting.sorted(by: { $0.key < $1.key }) where held.patch == patch {
            guard let root = held.root.element else {
                awaiting[mount] = nil
                continue
            }
            let partnered = sources.contains { key, left in
                left.contains { $0.patch == patch && $0.element.map { holds(root, $0) } == true }
                    && (made[key] ?? []).contains { $0.patch == patch }
            }
            if !partnered { release(mount) }
        }
    }

    /// The view kept for a partner, `mount`, goes now.
    private func release(_ mount: UInt64) {
        let root = awaiting.removeValue(forKey: mount)?.root.element
        root?.endExit(.finished, arranging: true)
    }

    /// The view kept for a partner that holds `element`, or is it; nil where none does.
    private func keptHolding(_ element: MountedElement?) -> MountedElement? {
        var each = element
        while let view = each {
            if awaiting[view.mount]?.root.element === view { return view }
            each = view.parent
        }
        return nil
    }

    /// Whether `root` is `element` or holds it.
    private func holds(_ root: MountedElement, _ element: MountedElement) -> Bool {
        var each: MountedElement? = element
        while let view = each {
            if view === root { return true }
            each = view.parent
        }
        return false
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
    /// is not known yet - and a view kept for it goes then.
    func source(for element: MountedElement, in tree: MountedTree) -> Pair? {
        guard let key = Self.key(of: element),
              let mine = made[key]?.first(where: { $0.mount == element.mount })?.patch,
              let left = sources[key]?.filter({ $0.patch == mine }), !left.isEmpty
        else { return nil }
        defer {
            sources[key]?.removeAll { $0.patch == mine }
            made[key]?.removeAll { $0.patch == mine }
        }
        guard let source = partner(of: element, key: key, patch: mine),
              let destination = placeInWindow(of: element, scope: key.scope, in: tree),
              destination.width > 0, destination.height > 0
        else {
            for each in left { if let kept = keptHolding(each.element) { release(kept.mount) } }
            refused?(element)
            return nil
        }
        let kept = keptHolding(source.element)
        if let kept { awaiting[kept.mount] = nil }
        let landsDrawn = Self.drawn(element.drawnTransform.bounds(of: destination), above: element, to: key.scope)
        return Pair(
            from: source.drawn, to: landsDrawn, setsOut: Self.undrawn(source.drawn, above: element, to: key.scope),
            lands: destination, scope: key.scope, leaving: source.element, kept: kept, corner: source.corner)
    }

    /// Whether `element` was made with a patch whose notes are kept: what came with a view setting out.
    func isNew(_ element: MountedElement) -> Bool { born.contains(element.mount) }

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
            for mount in awaiting.keys.sorted() { release(mount) }
            sources.removeAll()
            made.removeAll()
            born.removeAll()
        }
    }

    /// `rect`, drawn by `element`, as every view above it up to the scope `scope` draws it too - each one's
    /// transform about its own pivot, as its toolkit stands it, no transform in that.
    static func drawn(_ rect: Rect, above element: MountedElement, to scope: UInt64) -> Rect {
        holders(above: element, to: scope).reduce(rect) { drawn, holder in
            holder.transform.bounds(of: drawn, within: holder.frame)
        }
    }

    /// The rectangle `element` would draw for every view above it up to the scope `scope` to draw it as `rect`:
    /// the outermost one's transform undone first.
    static func undrawn(_ rect: Rect, above element: MountedElement, to scope: UInt64) -> Rect {
        holders(above: element, to: scope).reversed().reduce(rect) { drawn, holder in
            holder.transform.place(drawnAs: drawn, within: holder.frame)
        }
    }

    /// Each view above `element` up to `scope`, innermost first: how it is drawn and where its toolkit stands it.
    private static func holders(
        above element: MountedElement, to scope: UInt64
    ) -> [(transform: HostDrawingTransform, frame: Rect)] {
        var (holders, above) = ([(transform: HostDrawingTransform, frame: Rect)](), element.parent)
        while let holder = above, holder.mount != scope {
            if let frame = holder.native.frameNumbers(), frame.count >= 8 {
                holders.append((holder.drawnTransform, Rect(x: frame[4], y: frame[5], width: frame[2], height: frame[3])))
            }
            above = holder.parent
        }
        return holders
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
    /// the toolkit says. Nil where a place is not known yet - one a layout program places, made with this patch,
    /// that the program has shown none.
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

    /// Where `element` stands in what holds it: where a layout program places it, nowhere known if this patch made
    /// it and the program has shown it no place - its toolkit stands it across the layout's room until the program
    /// is asked - else where its toolkit draws it, where the program put it; else the place a layout's motion gave it.
    private func place(of element: MountedElement, in tree: MountedTree) -> Place {
        if element.parent?.layoutProgram != nil { return standsUnknown(element) ? .unknown : .toolkits }
        return tree.layoutMotion.placed(element.mount).map { .at($0.place) } ?? .toolkits
    }

    /// Whether `element` was made with the notes kept and a layout program places it that has shown no place for
    /// it yet: its toolkit holds it where the program has not been asked.
    private func standsUnknown(_ element: MountedElement) -> Bool {
        guard born.contains(element.mount), let layout = element.parent, layout.layoutProgram != nil else { return false }
        return !layout.hasPlaced(element)
    }
}
