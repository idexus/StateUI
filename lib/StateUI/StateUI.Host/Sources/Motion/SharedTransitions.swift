// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI

/// The shared transitions of one tree: a view dropped and a view made in one patch, wearing one transition id in
/// one scope on one page, are one - the made one enters from the rectangle the dropped one was drawn in.
/// Design: docs/design/host/motion.md#a-shared-presentation
@_spi(Host) @MainActor public final class SharedTransitions {
    /// A view's key: the page it is on, by its mount, and the numbers its transition id and the scope it names
    /// cross as - none for no scope.
    private struct Key: Hashable {
        let page: UInt64
        let id: Int
        let scope: Int?
    }

    /// What a view wearing a key was drawn as when it left - what the view of its key made next takes over: the
    /// patch that dropped it, the rectangle it was drawn in, in its window's coordinates, how fast that moved, its
    /// corner as drawn there, and where it stood.
    private struct Presence {
        let patch: Int
        let drawn: Rect
        let speed: RectSpeed
        let corner: Double?
        let window: UInt64?
        let page: UInt64?
        weak var element: MountedElement?
    }

    /// Two views made one: where the dropped one was drawn and the made one lands as drawn, in the scope; the
    /// same two as the made one's own place stands, what holds it undone; the scope they are one in, the view
    /// dropped - and the view kept for it as it left, should its holder keep one - how fast it was drawn moving,
    /// and its corner as drawn.
    struct Pair {
        let from: Rect
        let to: Rect
        let setsOut: Rect
        let lands: Rect
        let scope: UInt64
        weak var leaving: MountedElement?
        weak var kept: MountedElement?
        let speed: RectSpeed
        let corner: Double?
    }

    /// What each key's view was drawn as as it left, by its key: one each, else the key meets no single partner.
    private var presences: [Key: [Presence]] = [:]
    private var made: [Key: [(mount: UInt64, patch: Int)]] = [:]

    /// The presentations shared now, by the mount their run stands under - a number no element's - and the next.
    private var presentations: [UInt64: SharedPresentation] = [:]
    private var nextRun: UInt64 = 1 << 62

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
        presences.values.reduce(0) { $0 + $1.count } + made.values.reduce(0) { $0 + $1.count } + born.count
            + awaiting.count + presentations.count
    }

    /// A patch is about to be applied: what it drops and makes is its own.
    func patchBegins() {
        patch += 1
        if framesLeft == 0 { born.removeAll() }
    }

    /// `element` is dropped by the patch being applied, before it is let go: every view wearing a key in it or
    /// under it is noted under its key as it is drawn - its rectangle, how fast that moves, its corner. Whether one
    /// was.
    @discardableResult
    func dropped(_ element: MountedElement) -> Bool {
        var noted = false
        if let key = Self.key(of: element), let numbers = element.native.frameNumbers(), numbers.count >= 8 {
            let own = element.drawnTransform.bounds(of: Rect(x: numbers[4], y: numbers[5], width: numbers[2], height: numbers[3]))
            let drawn = Self.drawn(own, above: element, to: key.page)
            let scale = numbers[2] > 0 && numbers[3] > 0 ? (drawn.width / numbers[2] * drawn.height / numbers[3]).squareRoot() : 1
            presences[key, default: []].append(Presence(
                patch: patch, drawn: drawn, speed: element.drawnSpeed(to: key.page),
                corner: element.ownCorner.map { $0 * scale },
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
            let partnered = presences.contains { key, left in
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
    /// wearing its key was drawn, in its window's coordinates, and how fast, with where `element` is placed there -
    /// and that view, should it still be leaving. Nil where the patch dropped none wearing the key; nil too, and
    /// said, where it dropped or made more than one, they stood in other windows or pages, or where `element`
    /// stands is not known yet - and a view kept for it that sends no other keyed view along goes then.
    func source(for element: MountedElement, in tree: MountedTree) -> Pair? {
        guard let key = Self.key(of: element),
              let mine = made[key]?.first(where: { $0.mount == element.mount })?.patch,
              let left = presences[key]?.filter({ $0.patch == mine }), !left.isEmpty
        else { return nil }
        defer {
            presences[key]?.removeAll { $0.patch == mine }
            made[key]?.removeAll { $0.patch == mine }
        }
        guard let source = partner(of: element, key: key, patch: mine),
              let destination = placeInWindow(of: element, scope: key.page, in: tree),
              destination.width > 0, destination.height > 0
        else {
            for each in left {
                if let kept = keptHolding(each.element), kept.exitsRunning == 0 { release(kept.mount) }
            }
            if left.count > 1 || wearers(of: key, from: element) > 1 { Complaints.sayRepeatedTransitionID(key.id, scope: key.scope) }
            refused?(element)
            return nil
        }
        // The kept view stays awaiting: another key of its own may meet its partner in this patch too.
        let kept = keptHolding(source.element)
        let landsDrawn = Self.drawn(element.drawnTransform.bounds(of: destination), above: element, to: key.page)
        return Pair(
            from: source.drawn, to: landsDrawn, setsOut: Self.undrawn(source.drawn, above: element, to: key.page),
            lands: destination, scope: key.page, leaving: source.element, kept: kept, speed: source.speed,
            corner: source.corner)
    }

    /// Whether `element` was made with a patch whose notes are kept: what came with a view setting out.
    func isNew(_ element: MountedElement) -> Bool { born.contains(element.mount) }

    /// Whether a view made under `element`, by the patch that made it, sets out from its partner, as far as is known
    /// before it is placed: `element` then comes as it stands, as its fade would hide where that view sets out.
    /// Design: docs/design/host/motion.md#a-shared-presentation
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
    private func partner(of element: MountedElement, key: Key, patch: Int) -> Presence? {
        let left = (presences[key] ?? []).filter { $0.patch == patch }
        guard left.count == 1, let source = left.first, (made[key] ?? []).count(where: { $0.patch == patch }) == 1,
              source.drawn.width > 0, source.drawn.height > 0,
              source.window == element.enclosing(type: .window)?.mount,
              source.page == element.enclosing(type: .page)?.mount
        else { return nil }

        var above: MountedElement? = element
        while let view = above, view.mount != key.page {
            if standsUnknown(view) { return nil }
            above = view.parent
        }
        // The made view alone wears the key in its scope: one staying beside it makes the key no single view's.
        return wearers(of: key, from: element) == 1 ? source : nil
    }

    /// How many views of the scope `key` is worn in, `element` among them, wear it and are the application's.
    /// Design: docs/design/host/motion.md#a-shared-presentation
    private func wearers(of key: Key, from element: MountedElement) -> Int {
        var scope: MountedElement? = element
        while let view = scope, view.mount != key.page { scope = view.parent }
        var (count, walked) = (0, scope.map { [$0] } ?? [])
        while let view = walked.popLast() {
            if view.lifecycle == .active, Self.key(of: view) == key { count += 1 }
            walked.append(contentsOf: view.children)
        }
        return count
    }

    /// A display frame ended: the notes of a patch laid out by now are let go.
    func frameEnded() {
        guard framesLeft > 0 else { return born.removeAll() }

        framesLeft -= 1
        if framesLeft == 0 {
            // A kept view sending keyed views along goes as the last lands; one sending none goes now.
            for (mount, held) in awaiting.sorted(by: { $0.key < $1.key }) {
                if (held.root.element?.exitsRunning ?? 0) > 0 { awaiting[mount] = nil } else { release(mount) }
            }
            // A presentation whose view coming left with no partner of its own lands nowhere: it ends.
            for entry in presentations.values.sorted(by: { $0.runMount < $1.runMount })
            where entry.coming?.element?.lifecycle != .active {
                entry.finish()
            }
            presences.removeAll()
            made.removeAll()
            born.removeAll()
        }
    }

    /// The presentation whose run stands under `mount`; nil where none does.
    func entry(run mount: UInt64) -> SharedPresentation? { presentations[mount] }

    /// `entry` landed or ended: nothing is drawn from it any more.
    func finished(_ entry: SharedPresentation) { presentations[entry.runMount] = nil }

    /// `element`, given its first place, takes over from the view `pair` says its patch dropped wearing its id: the
    /// two are drawn from one presentation - the one that view was drawn from, sent on, else a new one - onto
    /// `element`'s place under `law`, the view kept for it lending its keyed view, should its holder keep one.
    /// Design: docs/design/host/motion.md#a-shared-presentation-drawn-by-both
    func present(
        _ pair: Pair, coming element: MountedElement, on view: some FadingView, under law: Motion?, in tree: MountedTree
    ) {
        guard let law else { return }
        let coming = SharedPresentation.Wearer(
            element: element, place: pair.lands, above: Self.holders(above: element, to: pair.scope),
            placing: element.placingTransform)
        let keyed = pair.kept == nil ? nil : pair.leaving
        let leaving = keyed.flatMap { keyed -> SharedPresentation.Wearer? in
            guard let numbers = keyed.native.frameNumbers(), numbers.count >= 8 else { return nil }
            return SharedPresentation.Wearer(
                element: keyed, place: Rect(x: numbers[4], y: numbers[5], width: numbers[2], height: numbers[3]),
                above: Self.holders(above: keyed, to: pair.scope), placing: keyed.placingTransform)
        }
        let entry = pair.leaving?.presentation.flatMap { $0.scope == pair.scope ? $0 : nil } ?? {
            let entry = SharedPresentation(runMount: nextRun, scope: pair.scope, tree: tree)
            nextRun += 1
            presentations[entry.runMount] = entry
            return entry
        }()
        let sent = entry.send(
            coming: coming, to: pair.to, from: pair.from, speed: pair.speed, cornerFrom: pair.corner,
            leaving: leaving, under: law)
        guard sent else {
            entry.finish()
            if pair.kept == nil { pair.leaving?.endExit(.interrupted, arranging: true) }
            return
        }
        element.presentation = entry
        if let keyed = leaving?.element, let kept = pair.kept {
            keyed.presentation = entry
            kept.lends(keyed, to: entry, under: law)
            keyed.drawKeptInFront(under: pair.scope, besides: element, leads: !entry.comingCrosses)
            keyed.native.presentFrame(Self.drawn(by: keyed, of: entry))
        } else {
            pair.leaving?.endExit(.interrupted, arranging: true)
        }
        element.drawInFront(under: pair.scope, runs: 1, besides: pair.kept, leads: entry.comingCrosses)
        // Drawn where it sets out from the frame its first place is given in, never at its place first.
        view.setOpacity(element.value(.opacity)?.number ?? 1)
        element.native.presentFrame(Self.drawn(by: element, of: entry).subtracting([.opacity]))
    }

    /// What `element`, drawn from `entry`, is drawn with: its move, scale and opacity, and its corner where one is
    /// carried.
    static func drawn(by element: MountedElement, of entry: SharedPresentation) -> Set<Prop> {
        var drawn = SharedPresentation.drawnProperties
        if entry.carriesACorner, let rounding = element.roundingProperty { drawn.insert(rounding) }
        return drawn
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
    static func holders(
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

    /// The key `element`'s presentation is shared by on its page; nil where it names no transition id.
    private static func key(of element: MountedElement) -> Key? {
        guard let id = element.value(ViewContract.transitionID.token)?.int, let page = element.presentationScope
        else { return nil }
        return Key(page: page.mount, id: id, scope: element.value(ViewContract.transitionScope.token)?.int)
    }

    /// Where `element` is placed, in its window's coordinates: the place its layout gave it, and each place a
    /// layout gave what holds it, up to its scope or to the first view no layout's motion placed - whose corner
    /// the toolkit says. Nil where a place is not known yet - one a layout program places, made with this patch,
    /// that the program has shown none.
    /// Design: docs/design/host/motion.md#a-shared-presentation
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
