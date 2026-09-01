// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

// State that outlives the process: what is hydrated, what is shared, what is saved.

import XCTest
@testable import StateUI

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
    @State(.count) var count = 0
}

private struct Footer {
    @State(.count) var count = 0
}

private struct Preferences {
    @State(.name) var name = "unnamed"
    @State(.loud) var loud = false
    @State(.level) var level = 0.5
    @State(.appearance) var appearance = Appearance.light
}

private struct KeepingWindow: Window {
    var content: Page { KeepingPage() }
}

private struct KeepingPage: ContentPage {
    var content: Element { Label("kept") }
}

/// An application that keeps two of its settings, in the platform's own store.
private struct KeepingApp: Application {
    var persistentKeys: [PersistentKey] { [.count, .name] }

    func createWindow() -> Window { KeepingWindow() }
}

/// An application that keeps its settings somewhere of its own.
private struct FiledApp: Application {
    var persistentStorage: PersistentStorage { PersistentStorage("Test.Json") }

    var persistentKeys: [PersistentKey] { [.loud] }

    func createWindow() -> Window { KeepingWindow() }
}

/// An application that keeps nothing, which is what most of them are.
private struct PlainApp: Application {
    func createWindow() -> Window { KeepingWindow() }
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
    /// last value - which is what keeps an Entry bound to kept state from
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

        storage.write(1) { _ in
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

        XCTAssertEqual(
            landed.wait(timeout: .now() + 2), .success,
            "and lands as soon as the hold ends")

        XCTAssertEqual(storage.value, 2)
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

    /// Saves ride the wire SORTED BY NAME, the determinism rule: one session
    /// writes the same bytes in every run, and a dictionary iterated into a
    /// message would not.
    func testSavesRideTheWireSortedByName() {
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
        Renderer.shared.send(.hideSoftInput, [], completion: nil)
        Sidebar().count = 3

        XCTAssertEqual(drainedActs().map(\.name), ["hideSoftInput", "persistValue"])
    }

    /// Assigning the same value still saves. The state is unchanged and the
    /// interface does not move, but the store may not hold it yet - a first
    /// run where the reader put the value back where it started.
    func testWritingTheValueItAlreadyHoldsStillReachesTheStore() {
        Sidebar().count = 0

        XCTAssertEqual(drainedActs().count, 1)
    }

    // MARK: - What the host is told

    /// The announcement carries the store and every key, names in full: it is
    /// the first thing either side says, before any message has announced a
    /// dictionary to number them against.
    func testTheAnnouncementCarriesTheStoreAndEveryKey() {
        Renderer.shared.setApplication(KeepingApp())

        var expected: [UInt8] = []
        expected.u8(Wire.version)
        expected.string("preferences")
        expected.u16(2)
        expected.string("test.count")
        expected.u8(UInt8(PersistentKind.integer.rawValue))
        expected.string("test.name")
        expected.u8(UInt8(PersistentKind.text.rawValue))

        XCTAssertEqual(Renderer.shared.persistentWire(), expected)
    }

    /// An application that keeps its state somewhere of its own says so in the
    /// same announcement - the host resolves the name against what it has
    /// registered.
    func testTheAnnouncementNamesAStoreOfTheApplicationsOwn() {
        Renderer.shared.setApplication(FiledApp())

        var expected: [UInt8] = []
        expected.u8(Wire.version)
        expected.string("Test.Json")
        expected.u16(1)
        expected.string("test.loud")
        expected.u8(UInt8(PersistentKind.boolean.rawValue))

        XCTAssertEqual(Renderer.shared.persistentWire(), expected)
    }

    /// An application that keeps nothing announces nothing, and the host then
    /// reads no store at all.
    func testAnApplicationThatKeepsNothingAnnouncesNothing() {
        Renderer.shared.setApplication(PlainApp())

        XCTAssertEqual(Renderer.shared.persistentWire(), [])
    }

    /// What the host read comes back through the same value encoding every
    /// other channel uses, and a key it did NOT find is simply absent.
    func testWhatTheHostFoundIsReadBackByName() {
        var buffer: [UInt8] = []
        buffer.u8(Wire.version)
        buffer.u16(2)
        buffer.string("test.count")
        buffer.value(.number(4))
        buffer.string("test.loud")
        buffer.value(.bool(true))

        let found = Wire.decodePersistent(buffer)

        XCTAssertEqual(found?.count, 2)
        XCTAssertEqual(found?.first?.name, "test.count")
        XCTAssertEqual(found?.first?.value, .number(4))
        XCTAssertEqual(found?.last?.value, .bool(true))
    }

    /// A truncated buffer is a refusal rather than a wrong value - the reader
    /// bounds-checks every step, as every channel here does.
    func testATruncatedHydrationIsRefused() {
        var buffer: [UInt8] = []
        buffer.u8(Wire.version)
        buffer.u16(2)
        buffer.string("test.count")
        buffer.value(.number(4))

        XCTAssertNil(Wire.decodePersistent(buffer))
    }
}
