// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

// State that outlives the process: what is read, what is shared, what is saved.

import XCTest
@_spi(Host) @testable import StateUI

/// An enum kept as the text it is spelled with - one line, which is the point.
private enum Appearance: String, PersistentValue {
    case light
    case dark
}

extension PersistentKey where Value == Int {
    fileprivate static let count = PersistentKey("test.count")
}

extension PersistentKey where Value == String {
    fileprivate static let name = PersistentKey("test.name")
}

extension PersistentKey where Value == Bool {
    fileprivate static let loud = PersistentKey("test.loud")
}

extension PersistentKey where Value == Double {
    fileprivate static let level = PersistentKey("test.level")
}

extension PersistentKey where Value == Appearance {
    fileprivate static let appearance = PersistentKey("test.appearance")
}

// A key of one type does not compile on a state of another:
// `@State(persistentKey: .count) var name = ""` - `PersistentKey<Int>` is no `PersistentKey<String>`.

/// Two different views declaring the SAME key - which is the case that has to
/// come out as one piece of state rather than two.
@MainActor
private struct Sidebar {
    @State(persistentKey: .count) var count = 0
}

@MainActor
private struct Footer {
    @State(persistentKey: .count) var count = 0
}

@MainActor
private struct Preferences {
    @State(persistentKey: .name) var name = "unnamed"
    @State(persistentKey: .loud) var loud = false
    @State(persistentKey: .level) var level = 0.5
    @State(persistentKey: .appearance) var appearance = Appearance.light
}

/// A MODEL that keeps two of its settings - the shape an application's own
/// settings object has, where the value belongs to the app rather than to any
/// one view.
@MainActor
private final class Settings {
    @State(persistentKey: .count) var count = 0
    @State(persistentKey: .appearance) var appearance = Appearance.light

    /// Kept by nobody, so it starts over every launch.
    @State var scratch = ""
}

/// What the host's store holds, and what the core asked it, each key's name and kind in turn.
@MainActor
private final class Store {
    var values: [String: PropValue]
    var asked: [String] = []

    init(_ values: [String: PropValue]) {
        self.values = values
    }

    /// Gives the core this store's reader, as a host does at its start.
    func read() {
        PersistentStore.shared.reads { [self] name, kind in
            asked.append("\(name) \(kind)")
            return values[name]
        }
    }
}

@MainActor
final class PersistenceTests: XCTestCase {
    override func setUp() async throws {

        // The store is one per process and the keys name values that whole
        // process shares, so a test that inherited the last one's would be
        // reading somebody else's state.
        PersistentStore.shared.forgetAll()
        _ = drainedActs()
    }

    override func tearDown() async throws {
        PersistentStore.shared.forgetAll()
        _ = drainedActs()
    }

    // MARK: - Coming back

    /// A state under a key reads the host's store as it is first made, by the key's name and the kind of its
    /// value - an enum's raw value's - once: a second state under the key shares the first's.
    func testAStateUnderAKeyReadsTheStoreAsItIsMade() {
        let store = Store(["test.count": .number(7), "test.name": .string("Ada"), "test.appearance": .string("dark")])
        store.read()

        XCTAssertEqual(Sidebar().count, 7)
        XCTAssertEqual(Footer().count, 7)
        let preferences = Preferences()
        XCTAssertEqual(preferences.name, "Ada")
        XCTAssertEqual(preferences.appearance, .dark)
        XCTAssertEqual(store.asked, [
            "test.count integer", "test.name text", "test.loud boolean", "test.level number", "test.appearance text",
        ])
    }

    /// An enum is kept as the thing it is spelled with, which is what makes
    /// conformance one line and keeps the store readable by anything else that
    /// opens it.
    func testAnEnumIsKeptAsItsRawValue() {
        XCTAssertEqual(Appearance.persistentKind, .text)
        XCTAssertEqual(Appearance.dark.persistentValue, .string("dark"))
        XCTAssertEqual(Appearance(persisted: .string("light")), .light)

        // A case removed since the value was written - the ordinary way an
        // application's vocabulary changes between releases.
        XCTAssertNil(Appearance(persisted: .string("sepia")))
    }

    /// The claim can come FIRST: an application's own keyed state is built as
    /// the app registers, before the host gives its reader, and the value
    /// still lands - as the reader comes, ahead of the first view.
    func testAKeyClaimedBeforeTheReaderCameReadsItThen() {
        let early = Sidebar()

        Store(["test.count": .number(9)]).read()

        XCTAssertEqual(early.count, 9)
        XCTAssertEqual(Footer().count, 9)
    }

    // MARK: - Kept state declared in a class

    /// A model's `@State` is kept exactly as a view's is: the key is the
    /// key, whoever declares it, so an application's settings object works
    /// without a view holding any of it.
    func testAKeptStateInAModelReadsTheStore() {
        Store(["test.count": .number(7), "test.appearance": .string("dark")]).read()

        let settings = Settings()

        XCTAssertEqual(settings.count, 7)
        XCTAssertEqual(settings.appearance, .dark)
        XCTAssertEqual(settings.scratch, "", "the one kept by nobody starts where it was declared")
    }

    /// And the claim can come first here too - a settings model is usually
    /// built as the application registers, which is before the host has given
    /// its reader.
    func testAModelBuiltBeforeTheReaderStillTakesTheStoredValue() {
        let early = Settings()

        Store(["test.count": .number(9)]).read()

        XCTAssertEqual(early.count, 9)
    }

    /// A write inside a model reaches the store as any other kept write does.
    func testWritingAKeptStateInAModelSendsItToTheStore() {
        let settings = Settings()
        settings.count = 3

        let acts = drainedActs()

        XCTAssertEqual(acts.count, 1)
        XCTAssertEqual(acts.first?.name, "persistValue")
        XCTAssertEqual(acts.first?.arguments, [.name("test.count"), .number(3)])
    }

    /// One key is ONE storage, so two models declaring it hold one value
    /// between them - the same rule two views under one key follow.
    func testTwoModelsUnderOneKeyAreOnePieceOfState() {
        let mine = Settings()
        let yours = Settings()

        mine.count = 5

        XCTAssertEqual(yours.count, 5)
    }

    /// A key the store had nothing under leaves the state holding the value
    /// written beside it - which is what puts the default where it can be seen.
    func testAKeyTheStoreHadNothingUnderKeepsTheDeclaredValue() {
        XCTAssertEqual(Sidebar().count, 0)
        XCTAssertEqual(Preferences().name, "unnamed")
        XCTAssertEqual(Preferences().appearance, .light)
    }

    /// An entry the store held as something else - written by an older version
    /// of the application under the same name - is ignored rather than
    /// force-fitted, and the state starts over at its declared value.
    func testAValueTheStoreHeldAsSomethingElseIsIgnored() {
        Store(["test.count": .string("seven")]).read()

        XCTAssertEqual(Sidebar().count, 0)
    }

    /// Two views declaring one key are ONE piece of state: they share the
    /// storage itself, so a write in either is a write both read - and the
    /// ordinary invalidation, which keys on storage identity, rebuilds both.
    func testTwoStatesUnderOneKeyAreOnePieceOfState() {
        let sidebar = Sidebar()
        let footer = Footer()

        sidebar.count = 12

        XCTAssertEqual(footer.count, 12)
        XCTAssertIdentical(sidebar.$count.lender, footer.$count.lender)
    }

    // MARK: - Going out

    /// A write reaches the store by itself - one act, carrying the key as a
    /// NAME and the value as the kind it was declared with.
    func testWritingAKeptStateSendsItToTheStore() {
        let preferences = Preferences()
        preferences.name = "Grace"

        let acts = drainedActs()

        XCTAssertEqual(acts.count, 1)
        XCTAssertEqual(acts.first?.name, "persistValue")
        XCTAssertEqual(acts.first?.arguments, [.name("test.name"), .string("Grace")])

        // Nothing is waiting on a save: the value is already in state, and the
        // store is only where it goes to survive the process.
        XCTAssertNil(acts.first?.completion)
    }

    /// A kept state is saved whoever writes it: a control through the state's binding...
    func testAKeptStateWrittenThroughItsBindingSendsItToTheStore() {
        let preferences = Preferences()
        preferences.$name.wrappedValue = "Ada"

        XCTAssertEqual(drainedActs().first?.arguments, [.name("test.name"), .string("Ada")])
    }

    /// ...and the host, reporting what the user typed into the field that carries it.
    func testAKeptStateTheHostReportsIsSentToTheStore() throws {
        let preferences = Preferences()
        let patch = Renders().render(TextField(preferences.$name).node)
        guard case .replace(let driven)? = patch.driven else { return XCTFail("expected the field's state") }
        _ = drainedActs()

        XCTAssertTrue(HostBoundary.report(.text("Grace"), through: try XCTUnwrap(driven[.text])))

        XCTAssertEqual(drainedActs().first?.arguments, [.name("test.name"), .string("Grace")])
    }

    /// A key written many times between two drains is saved ONCE, holding the
    /// last value - which is what keeps a TextField bound to kept state from
    /// saving on every letter.
    func testAKeyWrittenManyTimesIsSavedOnceHoldingTheLastValue() {
        let preferences = Preferences()

        for text in ["G", "Gr", "Gra", "Grac", "Grace"] {
            preferences.name = text
        }

        let acts = drainedActs()

        XCTAssertEqual(acts.count, 1)
        XCTAssertEqual(acts.first?.arguments, [.name("test.name"), .string("Grace")])
    }

    /// Saves reach the host SORTED BY NAME, the determinism rule: one session
    /// hands over the same acts in every run, and a dictionary iterated into
    /// the queue would not.
    func testSavesReachTheHostSortedByName() {
        let preferences = Preferences()
        preferences.level = 0.25
        preferences.name = "Ada"
        preferences.loud = true

        let names = drainedActs().compactMap { act -> String? in
            guard case .name(let key)? = act.arguments.first else { return nil }
            return key
        }

        XCTAssertEqual(names, ["test.level", "test.loud", "test.name"])
    }

    /// The saves come AFTER whatever the handlers queued, so an act a handler
    /// awaited is not held up behind a store.
    func testSavesComeAfterTheActsTheHandlersQueued() {
        Renderer.shared.send(.hideOnScreenKeyboard, [], completion: nil)
        Sidebar().count = 3

        XCTAssertEqual(drainedActs().map(\.name), ["hideOnScreenKeyboard", "persistValue"])
    }

    /// Assigning the same value still saves. The state is unchanged and the
    /// interface does not move, but the store may not hold it yet - a first
    /// run where the user put the value back where it started.
    func testWritingTheValueItAlreadyHoldsStillReachesTheStore() {
        Sidebar().count = 0

        XCTAssertEqual(drainedActs().count, 1)
    }
}
