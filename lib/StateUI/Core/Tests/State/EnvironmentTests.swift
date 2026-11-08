// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

// An object provided above, resolved below - and the rebuilds landing exactly
// where the reads are.
//
// The mechanism is in Environment.swift (the wrapper and the slots),
// Differ.swift and Differ+Element.swift (the scope, kept through both walks,
// and the memo's environment snapshot) and Stateful.swift (the slots collected
// beside the state boxes, and the structural `built` path). The promises pinned
// here, each proven to fail without its half of the mechanism:
//
//   - a child resolves the NEAREST provided object of its type, and a nearer
//     `.environment()` overrides for its own branch;
//   - a write IN the object rebuilds the readers and never the provider;
//   - replacing the object itself rebuilds the branch, which then resolves
//     the new one - through the clean walk, deep under clean ancestors;
//   - an unchanged memo token does not carry a subtree past a provider
//     replacement (`RenderedNode.seen` is what the skip compares);
//   - a provided object's `@State` is handed on by its own binding,
//     `context.$property` - an `@Environment` has no projected value.

import XCTest
@_spi(Host) @testable import StateUI

@MainActor
private final class Session {
    @State var name = "guest"
    @State var visits = 0
}

/// A second context type: types are independent domains, and a write to one
/// must never rebuild the other's readers.
@MainActor
private final class Theme {
    @State var accent = "violet"
}

/// Counts how often a body ran. A class, so the Mirror walk that collects
/// state boxes and environment slots leaves it alone.
private final class Builds {
    var count = 0
}

/// Reads one property of the session - the view a write should rebuild.
private struct NameLabel: View {
    let builds: Builds
    @Environment var session: Session

    var body: some View {
        builds.count += 1
        return AnyView(node: label(session.name))
    }
}

/// Reads the theme - the other domain's reader.
private struct AccentLabel: View {
    let builds: Builds
    @Environment var theme: Theme

    var body: some View {
        builds.count += 1
        return AnyView(node: label(theme.accent))
    }
}

/// Owns the session, provides it, and never reads a property of it.
private struct Provider: View {
    let builds: Builds
    let reader: Builds
    @State var session = Session()

    var body: some View {
        builds.count += 1
        return AnyView(node: stack([NameLabel(builds: reader).environment(session).node]))
    }
}

/// A handler writing through the environment - what an application's button
/// does. The closure captures the view, whose wrapper resolves at fire time
/// to what the walk that built this render filled in.
private struct VisitButton: View {
    @Environment var session: Session

    var body: some View {
        Button("visits \(session.visits)").onClicked { session.visits += 1 }
    }
}

/// A handler captioned by the provided object, so a test can tell which place's button it fires.
private struct NameButton: View {
    @Environment var session: Session

    var body: some View {
        Button(session.name).onClicked { session.visits += 1 }
    }
}

/// Whether a peek reads its environment - off, so a test can look at the slot after the provider left without
/// the read reporting it.
@MainActor
private final class Peeking {
    var reads = true
}

/// A reader that reads only while told to, and shows its slot.
private struct Peek: View {
    let peeking: Peeking
    @Environment var session: Session

    var slot: AnyObject? { _session.filled }

    var body: some View {
        AnyView(node: label(peeking.reads ? session.name : "-"))
    }
}

/// A handler handing on one property of a provided object: `session.$name`,
/// the `Binding` of the `@State` the class declares.
private struct RenameButton: View {
    @Environment var session: Session

    var body: some View {
        Button("rename").onClicked {
            let name: Binding<String> = session.$name
            name.wrappedValue = "typed"
        }
    }
}

/// A provider whose branch holds a reader built with constant inputs - a
/// carry must still follow a provider replacement, which no input can see.
private struct Holder: View {
    let reader: Builds
    @State var session = Session()
    @State var title = "t"

    var body: some View {
        VStack {
            Text(title)
            NameLabel(builds: reader).id("m")
        }
        .environment(session)
    }
}

/// One value of a view held outside the tree, so every place of it is the same value - with the one slot.
@MainActor
private final class Shared {
    let button = NameButton()
}

/// A place of the shared button under what the parent provides, counting its builds: carried, it stands as built.
private struct Placing: View {
    let shared: Shared
    let builds: Builds

    var body: some View {
        builds.count += 1
        return VStack { shared.button }
    }
}

/// What a place provides, held as state: a write of it reaches that place alone on the clean walk.
@MainActor
private final class Providing {
    @State var session: Session

    init(_ session: Session) { _session = State(wrappedValue: session) }
}

/// A place of the shared button under the session its providing holds.
private struct Placed: View {
    let shared: Shared
    let providing: Providing

    var body: some View { VStack { shared.button }.environment(providing.session) }
}

@MainActor
final class EnvironmentTests: XCTestCase {
    override func setUp() async throws {
        Renderer.shared.clearInvalidation()
    }

    private var changed: Set<ObjectIdentifier> { Renderer.shared.pendingChanges }

    /// The handlers of the buttons captioned `caption` that `patch` says, in walk order.
    private func clicks(_ caption: String, in patch: HostPatch) -> [Int] {
        patch.subtree
            .filter { $0.type == .button && $0.props[.text] == .string(caption) }
            .compactMap { $0.events?[.clicked] }
    }

    /// The anchors `patch` puts where a view stood - what a refused place shows.
    private func anchors(in patch: HostPatch) -> [ElementID] {
        patch.subtree.filter { $0.type == .anchor }.map(\.id)
    }

    // MARK: - Resolution

    func testAChildResolvesWhatAnAncestorProvided() {
        let renders = Renders()
        let provider = Provider(builds: Builds(), reader: Builds())

        let patch = renders.render(stack([provider.node], id: "root"))

        XCTAssertEqual(
            patch.child(.auto(1))?.child(.auto(2))?.props["text"], .string("guest"))
    }

    func testANearerProviderWinsForItsBranch() {
        let renders = Renders()
        let outer = Session(), inner = Session()
        outer.name = "outer"
        inner.name = "inner"

        struct Pair: View {
            let outer: Session
            let inner: Session

            var body: some View {
                VStack {
                    NameLabel(builds: Builds())
                    NameLabel(builds: Builds()).environment(inner)
                }
                .environment(outer)
            }
        }

        Renderer.shared.clearInvalidation()
        let patch = renders.render(stack([Pair(outer: outer, inner: inner).node], id: "root"))

        // A composed view adds no element of its own: the placeholder IS the
        // VStack it unwraps to, and each NameLabel is its label.
        let row = patch.child(.auto(1))

        XCTAssertEqual(row?.child(.auto(2))?.props["text"], .string("outer"))
        XCTAssertEqual(row?.child(.auto(3))?.props["text"], .string("inner"))
    }

    func testAStructuralReadResolvesTheEnvironment() {
        let provider = Provider(builds: Builds(), reader: Builds())

        // `.built` is what a structural test reads - no differ involved, so
        // it keeps a scope of its own. See Node.built(within:).
        let tree = stack([provider.node], id: "root").built

        XCTAssertEqual(tree.children[0].children[0].props[.text], .string("guest"))
    }

    // MARK: - Who rebuilds

    func testAWriteInTheObjectRebuildsTheReaderAndNotTheProvider() {
        let renders = Renders()
        let owner = Builds(), reader = Builds()
        let provider = Provider(builds: owner, reader: reader)

        renders.render(stack([provider.node], id: "root"))
        XCTAssertEqual(owner.count, 1)
        XCTAssertEqual(reader.count, 1)

        provider.session.name = "anna"

        let patch = renders.revisit(changed: changed)

        XCTAssertEqual(owner.count, 1, "the provider passes a reference and reads no property")
        XCTAssertEqual(reader.count, 2, "the reader's build read what moved")
        XCTAssertEqual(
            patch.child(.auto(1))?.child(.auto(2))?.props["text"], .string("anna"))
    }

    func testContextTypesAreIndependentDomains() {
        let renders = Renders()
        let names = Builds(), accents = Builds()
        let session = Session(), theme = Theme()

        struct Both: View {
            let names: Builds
            let accents: Builds
            let session: Session
            let theme: Theme

            var body: some View {
                VStack {
                    NameLabel(builds: names)
                    AccentLabel(builds: accents)
                }
                .environment(session)
                .environment(theme)
            }
        }

        let view = Both(names: names, accents: accents, session: session, theme: theme)
        renders.render(stack([view.node], id: "root"))

        theme.accent = "orange"
        let patch = renders.revisit(changed: changed)

        XCTAssertEqual(names.count, 1, "the session's reader has no business with the theme")
        XCTAssertEqual(accents.count, 2)
        XCTAssertEqual(
            patch.child(.auto(1))?.child(.auto(3))?.props["text"], .string("orange"))
    }

    func testReplacingTheProvidedObjectReachesTheBranch() {
        let renders = Renders()
        let owner = Builds(), reader = Builds()
        let provider = Provider(builds: owner, reader: reader)

        renders.render(stack([provider.node], id: "root"))

        let old = provider.session
        let fresh = Session()
        fresh.name = "fresh"
        provider.session = fresh

        let patch = renders.revisit(changed: changed)

        XCTAssertEqual(owner.count, 2, "replacing the object writes the @State box the provider reads")
        XCTAssertEqual(reader.count, 2, "a rebuilt provider rebuilds what it writes")
        XCTAssertEqual(
            patch.child(.auto(1))?.child(.auto(2))?.props["text"], .string("fresh"))

        // The reader's reads were re-recorded against the NEW object, so the
        // old one's changes are nobody's business now.
        Renderer.shared.clearInvalidation()
        old.name = "stale"
        let silent = renders.revisit(changed: changed)

        XCTAssertEqual(reader.count, 2, "nothing shown reads the replaced object")
        XCTAssertTrue(silent.isEmpty)
    }

    // MARK: - Handlers

    func testAHandlerWritesThroughTheEnvironment() {
        let renders = Renders()
        let session = Session()

        let first = renders.render(
            stack([VisitButton().environment(session).node], id: "root"))
        let id = first.child(.auto(1))?.events?["clicked"]
        XCTAssertNotNil(id)

        XCTAssertTrue(renders.fire(id!))
        XCTAssertEqual(session.visits, 1, "the handler resolved the provided object")

        let patch = renders.revisit(changed: changed)
        XCTAssertEqual(patch.child(.auto(1))?.props["text"], .string("visits 1"))
    }

    /// One view value standing in two places, each under its own provider: the first place's handler writes the
    /// object provided THERE, and the second place shows nothing, said once - a value's slot belongs to one place.
    func testAValueStandingTwiceKeepsTheFirstPlacesEnvironmentForItsHandler() throws {
        let renders = Renders()
        let a = Session(), b = Session()
        a.name = "a"
        b.name = "b"
        let button = NameButton()

        let patch = renders.render(
            stack([button.environment(a).node, button.environment(b).node], id: "root"))

        XCTAssertEqual(patch.child(.auto(1))?.props["text"], .string("a"))
        XCTAssertTrue(renders.fire(try XCTUnwrap(patch.child(.auto(1))?.events?["clicked"])))
        XCTAssertEqual(a.visits, 1, "the first place's handler writes the object provided there")
        XCTAssertEqual(b.visits, 0, "the sibling's object is untouched")
        XCTAssertEqual(patch.child(.auto(2))?.type, .anchor, "the second place shows nothing")
        XCTAssertTrue(hasComplained("NameButton value stands in two places under different environments"))
    }

    /// One view value standing in two places under ONE provider resolves the same object at both, so both stand.
    func testAValueStandingTwiceUnderOneProviderStandsTwice() throws {
        let renders = Renders()
        let session = Session()
        session.name = "same"
        let button = NameButton()

        let patch = renders.render(
            stack([button.environment(session).node, button.environment(session).node], id: "root"))

        XCTAssertEqual(patch.child(.auto(1))?.props["text"], .string("same"))
        XCTAssertEqual(patch.child(.auto(2))?.props["text"], .string("same"))
        XCTAssertTrue(renders.fire(try XCTUnwrap(patch.child(.auto(2))?.events?["clicked"])))
        XCTAssertEqual(session.visits, 1)
    }

    /// A slot keeps no provider from a walk before: rendered again with none, a kept view value holds nothing, and
    /// the provider that left is released.
    func testAProviderThatLeftIsNotKeptByTheSlot() {
        let renders = Renders(), peeking = Peeking()
        let peek = Peek(peeking: peeking)
        var session: Session? = Session()
        weak let gone = session

        renders.render(stack([peek.environment(session!).node], id: "root"))
        XCTAssertTrue(peek.slot === session)

        peeking.reads = false
        renders.render(stack([peek.node], id: "root"))
        session = nil

        XCTAssertNil(peek.slot, "a slot nobody provides for holds nothing")
        XCTAssertNil(gone, "the provider that left is released")
    }

    /// A place carried as it was built keeps its environment: beside it, the value's other place built again under
    /// another provider is the one refused, and the carried place's handler writes the object provided there.
    func testAProviderReplacedBesideACarriedPlaceLeavesItsHandlerAlone() throws {
        let renders = Renders(), shared = Shared(), first = Builds(), second = Builds()
        let a = Session(), b = Session()
        a.name = "a"
        b.name = "b"
        func tree(_ provider: Session) -> Node {
            stack([
                Placing(shared: shared, builds: first).environment(a).node,
                Placing(shared: shared, builds: second).environment(provider).node,
            ], id: "root")
        }

        let patch = renders.render(tree(a))
        let clicked = try XCTUnwrap(clicks("a", in: patch).first)
        let again = renders.render(tree(b))

        XCTAssertEqual(first.count, 1, "the first place is carried")
        XCTAssertEqual(anchors(in: again).count, 1, "the second, built again under another provider, shows nothing")
        XCTAssertTrue(renders.fire(clicked))
        XCTAssertEqual(a.visits, 1, "the carried place's handler writes the object provided there")
        XCTAssertEqual(b.visits, 0)
    }

    /// The clean walk alike: the place whose provider moved is built again and refused, the kept place untouched.
    func testTheCleanWalkRefusesThePlaceWhoseProviderMovedBesideAKeptOne() throws {
        let renders = Renders(), shared = Shared()
        let a = Session(), b = Session()
        a.name = "a"
        b.name = "b"
        let left = Providing(a), right = Providing(a)
        let patch = renders.render(stack([
            Placed(shared: shared, providing: left).node,
            Placed(shared: shared, providing: right).node,
        ], id: "root"))
        let clicked = try XCTUnwrap(clicks("a", in: patch).first)

        right.session = b
        let walked = renders.revisit(changed: changed)

        XCTAssertEqual(anchors(in: walked).count, 1, "the place whose provider moved shows nothing")
        XCTAssertTrue(renders.fire(clicked))
        XCTAssertEqual(a.visits, 1)
        XCTAssertEqual(b.visits, 0)
    }

    /// The first place in the tree wins whichever provider moved: the first, built again under another provider,
    /// stands, and the second, carried, is built again as nothing - its handler would read the first's object.
    func testAProviderReplacedAtTheFirstPlaceRefusesTheCarriedSecond() throws {
        let renders = Renders(), shared = Shared(), first = Builds(), second = Builds()
        let a = Session(), b = Session()
        a.name = "a"
        b.name = "b"
        func tree(_ provider: Session) -> Node {
            stack([
                Placing(shared: shared, builds: first).environment(provider).node,
                Placing(shared: shared, builds: second).environment(a).node,
            ], id: "root")
        }

        let patch = renders.render(tree(a))
        let clicked = try XCTUnwrap(clicks("a", in: patch).first)
        let again = renders.render(tree(b))

        XCTAssertEqual(second.count, 1, "the second place's holder is carried")
        XCTAssertEqual(anchors(in: again).count, 1, "and its button shows nothing")
        XCTAssertEqual(clicks("b", in: again), [], "the first place's button keeps its handler")
        XCTAssertTrue(renders.fire(clicked))
        XCTAssertEqual(b.visits, 1, "which writes the object provided there now")
        XCTAssertEqual(a.visits, 0)
    }

    /// A refused place is asked again on every walk: once the first place comes to its provider, it stands - the
    /// clean walk builds it again, though it read nothing that moved.
    func testARefusedPlaceStandsOnceTheFirstPlaceComesToItsProvider() throws {
        let renders = Renders(), shared = Shared()
        let a = Session(), b = Session()
        a.name = "a"
        b.name = "b"
        let left = Providing(a), right = Providing(b)
        let patch = renders.render(stack([
            Placed(shared: shared, providing: left).node,
            Placed(shared: shared, providing: right).node,
        ], id: "root"))
        XCTAssertEqual(anchors(in: patch).count, 1)
        let first = try XCTUnwrap(clicks("a", in: patch).first)

        left.session = b
        let walked = renders.revisit(changed: changed)
        let second = try XCTUnwrap(clicks("b", in: walked).first, "the refused place stands under the provider both have")

        XCTAssertTrue(renders.fire(first))
        XCTAssertTrue(renders.fire(second))
        XCTAssertEqual(b.visits, 2, "both places' handlers write the one object")
        XCTAssertEqual(a.visits, 0)
    }

    /// The tree's order decides which place stands, not the walk that placed the value first: the places swapped,
    /// the one now first stands and the other is refused; the first place gone, the one left stands.
    func testThePlacesOrderInTheTreeDecides() throws {
        let renders = Renders(), shared = Shared()
        let a = Session(), b = Session()
        a.name = "a"
        b.name = "b"
        func tree(_ places: [(Session, String)]) -> Node {
            stack(places.map { shared.button.environment($0.0).id($0.1).node }, id: "root")
        }

        let patch = renders.render(tree([(a, "under a"), (b, "under b")]))
        XCTAssertEqual(clicks("a", in: patch).count, 1)
        XCTAssertEqual(anchors(in: patch).count, 1)

        let swapped = renders.render(tree([(b, "under b"), (a, "under a")]))
        XCTAssertEqual(clicks("b", in: swapped).count, 1, "first in the tree now, the place under b stands")
        XCTAssertEqual(anchors(in: swapped).count, 1, "and the place under a is the one refused")

        let alone = renders.render(tree([(a, "under a")]))
        let clicked = try XCTUnwrap(clicks("a", in: alone).first, "the one place left stands")
        XCTAssertTrue(renders.fire(clicked))
        XCTAssertEqual(a.visits, 1)
        XCTAssertEqual(b.visits, 0)
    }

    func testAProvidedObjectsStateIsHandedOnByItsOwnBinding() {
        let renders = Renders()
        let session = Session()

        let first = renders.render(
            stack([RenameButton().environment(session).node], id: "root"))
        let id = first.child(.auto(1))?.events?["clicked"]

        XCTAssertTrue(renders.fire(id!))
        XCTAssertEqual(session.name, "typed",
                       "session.$name is the state the object declares")
    }

    // MARK: - What a carried view compares beside its inputs

    func testAReplacedProviderReachesACarriedView() {
        let renders = Renders()
        let reader = Builds()
        let holder = Holder(reader: reader)

        renders.render(stack([holder.node], id: "root"))
        XCTAssertEqual(reader.count, 1)

        let fresh = Session()
        fresh.name = "fresh"
        holder.session = fresh
        let patch = renders.revisit(changed: changed)

        // The label's inputs are unchanged and say nothing about the
        // provider; the object its `@Environment` resolved to is what tells
        // the two renders apart.
        XCTAssertEqual(reader.count, 2, "a carried view must not keep a replaced provider")
        XCTAssertEqual(
            patch.child(.auto(1))?.child("m")?.props["text"], .string("fresh"))
    }

    func testTheSameProviderLeavesACarriedViewAlone() {
        let renders = Renders()
        let reader = Builds()
        let holder = Holder(reader: reader)

        renders.render(stack([holder.node], id: "root"))

        // The holder rebuilds for its own state; the provider object is the
        // same one, so the label under it is carried.
        holder.title = "T"
        renders.revisit(changed: changed)
        XCTAssertEqual(reader.count, 1, "the same provider is not a reason to build the view")
    }

    // MARK: - By name

    /// What the library offers is read by name, each of its objects under one name of `EnvironmentValues`; read by
    /// its type, it is refused with that name, while an application's own object is read by its type.
    func testTheLibrarysObjectsAreReadByName() {
        XCTAssertEqual(
            StandardEnvironment.scope.compactMap { StandardEnvironment.names[$0.key] }.sorted(),
            ["application", "device", "locale", "scene", "window"])
        XCTAssertEqual(StandardEnvironment.names.count, StandardEnvironment.scope.count, "every name names an object")
        XCTAssertEqual(
            Environment<WindowSession>.refusal,
            "WindowSession is the library's: read it by its name, @Environment(\\.window) private var window.")
        XCTAssertEqual(Environment<Device>.refusal?.contains("@Environment(\\.device)"), true)
        XCTAssertNil(Environment<Session>.refusal, "an application's own object is read by its type")
    }

    /// Read by its type, the library's object is said once with the name it is read by - and is the object that
    /// name reads: the program goes on.
    func testALibraryObjectReadByItsTypeIsSaidOnceAndRead() {
        let byType = Environment<LocaleInfo>()

        XCTAssertTrue(hasComplained("LocaleInfo is the library's: read it by its name, @Environment(\\.locale)"))
        XCTAssertTrue(byType.wrappedValue === Environment<LocaleInfo>(\.locale).wrappedValue)
    }
}
