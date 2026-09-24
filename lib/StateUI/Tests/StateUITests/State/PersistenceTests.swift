// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

// State that outlives the process: what is hydrated, what is shared, what is saved.

import XCTest
@_spi(Host) @testable import StateUI

/// An enum kept as the text it is spelled with - one line, which is the point.
private enum Appearance: String, PersistentValue {
    case light
    case dark
}

extension PersistentKey {
    fileprivate static let count = PersistentKey("test.count", of: Int.self)
    fileprivate static let name = PersistentKey("test.name", of: String.self)
    fileprivate static let loud = PersistentKey("test.loud", of: Bool.self)
    fileprivate static let level = PersistentKey("test.level", of: Double.self)
    fileprivate static let appearance = PersistentKey("test.appearance", of: Appearance.self)
}

/// Two different views declaring the SAME key - which is the case that has to
/// come out as one piece of state rather than two.
private struct Sidebar {
    @State(persistentKey: .count) var count = 0
}

private struct Footer {
    @State(persistentKey: .count) var count = 0
}

private struct Preferences {
    @State(persistentKey: .name) var name = "unnamed"
    @State(persistentKey: .loud) var loud = false
    @State(persistentKey: .level) var level = 0.5
    @State(persistentKey: .appearance) var appearance = Appearance.light
}

private struct KeepingWindow: Window {
    var page: any Page { KeepingPage() }
}

private struct KeepingPage: ContentView {
    var content: any View { Label("kept") }
}

/// A MODEL that keeps two of its settings - the shape an application's own
/// settings object has, where the value belongs to the app rather than to any
/// one view.
private final class Settings {
    @State(persistentKey: .count) var count = 0
    @State(persistentKey: .appearance) var appearance = Appearance.light

    /// Kept by nobody, so it starts over every launch.
    @State var scratch = ""
}

/// An application that keeps two of its settings, in the platform's own store -
/// said as it is made, which is when the host asks for them.
private struct KeepingApp: Application {
    @Environment private var application: ApplicationSession

    init() {
        application.persistentKeys = [.count, .name]
    }

    var scene: any Scene { KeepingWindow() }
}

/// An application that keeps nothing, which is what most of them are.
private struct PlainApp: Application {
    var scene: any Scene { KeepingWindow() }
}

final class PersistenceTests: XCTestCase {
    override func setUp() {
        super.setUp()

        // The store is one per process and the keys name values that whole
        // process shares, so a test that inherited the last one's would be
        // reading somebody else's state.
        PersistentStore.shared.forgetAll()
        _ = drainedActs()
    }

    override func tearDown() {
        PersistentStore.shared.forgetAll()
        _ = drainedActs()
        super.tearDown()
    }

    // MARK: - What a key is

    /// A key's kind comes from the Swift type it was declared with, so
    /// `of: Int.self` and `var count = 0` are the same word twice.
    func testAKeyTakesItsKindFromTheTypeItWasDeclaredWith() {
        XCTAssertEqual(PersistentKey.count.kind, .integer)
        XCTAssertEqual(PersistentKey.name.kind, .text)
        XCTAssertEqual(PersistentKey.loud.kind, .boolean)
        XCTAssertEqual(PersistentKey.level.kind, .number)
    }

    /// An enum is kept as the thing it is spelled with, which is what makes
    /// conformance one line and keeps the store readable by anything else that
    /// opens it.
    func testAnEnumIsKeptAsItsRawValue() {
        XCTAssertEqual(PersistentKey.appearance.kind, .text)
        XCTAssertEqual(Appearance.dark.persistentValue, .string("dark"))
        XCTAssertEqual(Appearance(persisted: .string("light")), .light)

        // A case removed since the value was written - the ordinary way an
        // application's vocabulary changes between releases.
        XCTAssertNil(Appearance(persisted: .string("sepia")))
    }

    // MARK: - Coming back

    /// The value the host read out of the store is what the state holds the
    /// first time anything looks at it - no load to await, nothing to put back.
    func testAStateUnderAKeyTakesWhatTheHostHydrated() {
        PersistentStore.shared.hydrate([
            (name: "test.count", value: .number(7)),
            (name: "test.name", value: .string("Ada")),
        ])

        XCTAssertEqual(Sidebar().count, 7)
        XCTAssertEqual(Preferences().name, "Ada")
    }

    /// The claim can come FIRST: an application's own keyed state is built as
    /// the app registers, before the host pushes the store, and the value
    /// still lands - at `hydrate`, ahead of the first view.
    func testAKeyClaimedBeforeHydrationStillTakesTheStoredValue() {
        let early = Sidebar()

        PersistentStore.shared.hydrate([(name: "test.count", value: .number(9))])

        XCTAssertEqual(early.count, 9)
        XCTAssertEqual(Footer().count, 9)
    }

    // MARK: - Kept state declared in a class

    /// A model's `@State` is kept exactly as a view's is: the key is the
    /// key, whoever declares it, so an application's settings object works
    /// without a view holding any of it.
    func testAKeptStateInAModelTakesWhatTheHostHydrated() {
        PersistentStore.shared.hydrate([
            (name: "test.count", value: .number(7)),
            (name: "test.appearance", value: .string("dark")),
        ])

        let settings = Settings()

        XCTAssertEqual(settings.count, 7)
        XCTAssertEqual(settings.appearance, .dark)
        XCTAssertEqual(settings.scratch, "", "the one kept by nobody starts where it was declared")
    }

    /// And the claim can come first here too - a settings model is usually
    /// built as the application registers, which is before the host has
    /// pushed the store.
    func testAModelBuiltBeforeHydrationStillTakesTheStoredValue() {
        let early = Settings()

        PersistentStore.shared.hydrate([(name: "test.count", value: .number(9))])

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
        PersistentStore.shared.hydrate([(name: "test.count", value: .string("seven"))])

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

    /// A key written many times between two drains is saved ONCE, holding the
    /// last value - which is what keeps a TextField bound to kept state from
    /// saving on every letter.
    /// A write and the record beside it happen under ONE hold, so no other
    /// write can land between them.
    ///
    /// Both halves are separately thread-safe and that is NOT enough: two
    /// tasks writing at once could settle the value in one order and reach the
    /// store in the other, leaving the state holding the newer value and the
    /// store holding the older - which is then what the next launch reads. The
    /// window is a few instructions wide, so it would surface as a rare wrong
    /// value after a restart, which is the kind of thing nobody reproduces.
    ///
    /// Held by construction rather than by hammering two tasks and hoping: the
    /// second write is started from INSIDE the first one's record, where it
    /// must not be able to land.
    func testAWriteAndItsRecordCannotBeSplitByAnotherWrite() {
        let storage = State<Int>.Storage { 0 }
        let landed = DispatchSemaphore(value: 0)

        storage.keep = { _ in
            DispatchQueue.global().async {
                storage.value = 2
                landed.signal()
            }

            // Parked on the very hold this closure runs under. The timeout IS
            // the assertion: with the value and the record apart, that write
            // lands here, in between the two.
            XCTAssertEqual(
                landed.wait(timeout: .now() + 0.2), .timedOut,
                "another write must not land between the value and its record")
        }

        storage.write(1)

        XCTAssertEqual(
            landed.wait(timeout: .now() + 2), .success,
            "and lands as soon as the hold ends")

        XCTAssertEqual(storage.value, 2)
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
        let patch = Renders().render(TextField(preferences.$name).body)
        guard case .replace(let driven)? = patch.driven else { return XCTFail("expected the field's state") }
        _ = drainedActs()

        XCTAssertTrue(StateUIHost.report(.text("Grace"), through: try XCTUnwrap(driven[.text])))

        XCTAssertEqual(drainedActs().first?.arguments, [.name("test.name"), .string("Grace")])
    }

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

    // MARK: - What the host is told

    /// The host is told every key with its kind, names in full, before the
    /// first render - what it reads the platform's settings store with.
    func testTheHostIsToldEveryKey() {
        Renderer.shared.setApplication(KeepingApp())

        XCTAssertEqual(StateUIHost.persistentKeys, [.count, .name])
    }

    /// An application that keeps nothing names no key, and the host then reads
    /// no store at all.
    func testAnApplicationThatKeepsNothingNamesNoKey() {
        Renderer.shared.setApplication(PlainApp())

        XCTAssertEqual(StateUIHost.persistentKeys, [])
    }
}
