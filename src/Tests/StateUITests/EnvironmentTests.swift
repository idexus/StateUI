// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

// An object provided above, resolved below - and the rebuilds landing exactly
// where the reads are.
//
// The mechanism is in Core/Environment.swift (the wrapper and the slots),
// Core/Diff.swift (the scope, kept through both walks, and the memo's
// environment snapshot) and Core/Stateful.swift (the slots collected beside
// the state boxes, and the structural `built` path). The promises pinned
// here, each proven to fail without its half of the mechanism:
//
//   - a child resolves the NEAREST provided object of its type, and a nearer
//     `.environment()` overrides for its own branch;
//   - a write IN the object rebuilds the readers and never the provider;
//   - replacing the object itself rebuilds the branch, which then resolves
//     the new one - through the clean walk, deep under clean ancestors;
//   - an unchanged memo token does not carry a subtree past a provider
//     replacement (`RenderedNode.seen` is what the skip compares);
//   - `$context.property` lends one property on, writes included.

import XCTest
@testable import StateUI

@StateClass
private final class Session {
    var name = "guest"
    var visits = 0
}

/// A second context type: types are independent domains, and a write to one
/// must never rebuild the other's readers.
@StateClass
private final class Theme {
    var accent = "violet"
}

/// Counts how often a body ran. A class, so the Mirror walk that collects
/// state boxes and environment slots leaves it alone.
private final class Builds {
    var count = 0
}

/// Reads one property of the session - the view a write should rebuild.
private struct NameLabel: ContentView {
    let builds: Builds
    @Environment var session: Session

    var content: Element {
        builds.count += 1
        return label(session.name)
    }
}

/// Reads the theme - the other domain's reader.
private struct AccentLabel: ContentView {
    let builds: Builds
    @Environment var theme: Theme

    var content: Element {
        builds.count += 1
        return label(theme.accent)
    }
}

/// Owns the session, provides it, and never reads a property of it.
private struct Provider: ContentView {
    let builds: Builds
    let reader: Builds
    @State var session = Session()

    var content: Element {
        builds.count += 1
        return stack([NameLabel(builds: reader).environment(session).body])
    }
}

/// A handler writing through the environment - what an application's button
/// does. The closure captures the view, whose wrapper resolves at fire time
/// to what the walk that built this render filled in.
private struct VisitButton: ContentView {
    @Environment var session: Session

    var content: Element {
        Button("visits \(session.visits)").onClicked { session.visits += 1 }
    }
}

/// A handler lending one property on: `$session.name` is a `Binding<String>`
/// writing through the object, the model rule.
private struct RenameButton: ContentView {
    @Environment var session: Session

    var content: Element {
        Button("rename").onClicked {
            let name: Binding<String> = $session.name
            name.wrappedValue = "typed"
        }
    }
}

/// A provider whose branch holds a MEMOIZED reader - the skip must follow a
/// provider replacement the token cannot see.
private struct MemoHolder: ContentView {
    let reader: Builds
    @State var session = Session()
    @State var title = "t"

    var content: Element {
        VStack {
            Label(title)
            NameLabel(builds: reader).memoized(by: "fixed").id("m")
        }
        .environment(session)
    }
}

final class EnvironmentTests: XCTestCase {
    override func setUp() {
        super.setUp()
        Renderer.shared.clearInvalidation()
    }

    private var changed: Set<ObjectIdentifier> { Renderer.shared.pendingChanges }

    // MARK: - Resolution

    func testAChildResolvesWhatAnAncestorProvided() {
        let renders = Renders()
        let provider = Provider(builds: Builds(), reader: Builds())

        let patch = renders.render(stack([provider.body], id: "root"))

        XCTAssertEqual(
            patch.child(.auto(1))?.child(.auto(2))?.props["text"], .string("guest"))
    }

    func testANearerProviderWinsForItsBranch() {
        let renders = Renders()
        let outer = Session(), inner = Session()
        outer.name = "outer"
        inner.name = "inner"

        struct Pair: ContentView {
            let outer: Session
            let inner: Session

            var content: Element {
                VStack {
                    NameLabel(builds: Builds())
                    NameLabel(builds: Builds()).environment(inner)
                }
                .environment(outer)
            }
        }

        Renderer.shared.clearInvalidation()
        let patch = renders.render(stack([Pair(outer: outer, inner: inner).body], id: "root"))

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
        let tree = stack([provider.body], id: "root").built

        XCTAssertEqual(tree.children[0].children[0].props[.text], .string("guest"))
    }

    // MARK: - Who rebuilds

    func testAWriteInTheObjectRebuildsTheReaderAndNotTheProvider() {
        let renders = Renders()
        let owner = Builds(), reader = Builds()
        let provider = Provider(builds: owner, reader: reader)

        renders.render(stack([provider.body], id: "root"))
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

        struct Both: ContentView {
            let names: Builds
            let accents: Builds
            let session: Session
            let theme: Theme

            var content: Element {
                VStack {
                    NameLabel(builds: names)
                    AccentLabel(builds: accents)
                }
                .environment(session)
                .environment(theme)
            }
        }

        let view = Both(names: names, accents: accents, session: session, theme: theme)
        renders.render(stack([view.body], id: "root"))

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

        renders.render(stack([provider.body], id: "root"))

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
            stack([VisitButton().environment(session).body], id: "root"))
        let id = first.child(.auto(1))?.events?["clicked"]
        XCTAssertNotNil(id)

        XCTAssertTrue(renders.fire(id!))
        XCTAssertEqual(session.visits, 1, "the handler resolved the provided object")

        let patch = renders.revisit(changed: changed)
        XCTAssertEqual(patch.child(.auto(1))?.props["text"], .string("visits 1"))
    }

    func testTheProjectedValueLendsOnePropertyOn() {
        let renders = Renders()
        let session = Session()

        let first = renders.render(
            stack([RenameButton().environment(session).body], id: "root"))
        let id = first.child(.auto(1))?.events?["clicked"]

        XCTAssertTrue(renders.fire(id!))
        XCTAssertEqual(session.name, "typed",
                       "$session.name writes through the object, the model rule")
    }

    // MARK: - The memo's snapshot

    func testAnUnchangedMemoStillFollowsAProviderReplacement() {
        let renders = Renders()
        let reader = Builds()
        let holder = MemoHolder(reader: reader)

        renders.render(stack([holder.body], id: "root"))
        XCTAssertEqual(reader.count, 1)

        let fresh = Session()
        fresh.name = "fresh"
        holder.session = fresh

        let patch = renders.revisit(changed: changed)

        // The token is unchanged and says nothing about the provider; the
        // environments the differ saw at the memo are what tells them apart.
        XCTAssertEqual(reader.count, 2, "an unchanged token must not carry a replaced provider")
        XCTAssertEqual(
            patch.child(.auto(1))?.child("m")?.props["text"], .string("fresh"))
    }

    func testAnUnchangedMemoUnderTheSameProviderStillSkips() {
        let renders = Renders()
        let reader = Builds()
        let holder = MemoHolder(reader: reader)

        renders.render(stack([holder.body], id: "root"))

        // The holder rebuilds for its own state; the provider object is the
        // same one, so the memo's whole saving - not building - survives.
        holder.title = "T"
        renders.revisit(changed: changed)

        XCTAssertEqual(reader.count, 1, "the same provider is not a reason to build the memo")
    }
}
