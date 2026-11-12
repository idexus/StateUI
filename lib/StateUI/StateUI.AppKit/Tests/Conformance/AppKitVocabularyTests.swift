// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

#if os(macOS)
@_spi(Host) import StateUI
@_spi(Host) import StateUIHost
@_spi(Host) import StateUIConformance
import XCTest

/// The AppKit driver whose host says one line as each start's page first steps - its log, as every driver's, the
/// lines since the host started: an older one held before the first.
@MainActor
private final class SayingOnceEachStart: HostDriver {
    let driver = AppKitDriver()
    private var lines = ["a line from before"]
    private var started = false
    var host: String { driver.host }
    var register: HostRegister { driver.register }
    var cannot: [String: String] { driver.cannot }

    func start(
        clock: TestClock?, reducesMotion: Bool, @ViewBuilder _ page: @escaping @MainActor () -> any View
    ) -> MountedTree {
        (lines, started) = ([], true)
        return driver.start(clock: clock, reducesMotion: reducesMotion, page)
    }

    func step() {
        driver.step()
        if started { (lines, started) = (lines + ["said"], false) }
    }

    func logged() throws -> [String] { lines }
    func perform(_ act: UserAct, on element: MountedElement) throws { try driver.perform(act, on: element) }
    func held(_ property: Prop, on element: MountedElement) throws -> HostValue? { try driver.held(property, on: element) }
    func place(of element: MountedElement) throws -> Rect { try driver.place(of: element) }
    func close() { driver.close() }
    func turn() { driver.turn() }
    func frame() { driver.frame() }
    func served() throws -> String { try driver.served() }
    func held() throws -> (taken: Int, stopped: Int) { try driver.held() }
}

final class AppKitVocabularyTests: XCTestCase {
    /// Every case of every closed vocabulary, written to each element wearing it, is taken: the page stands and the
    /// log says nothing.
    @MainActor
    func testEveryCaseOfEveryClosedVocabularyIsTaken() throws {
        let driver = AppKitDriver()
        defer { driver.renderer?.finish() }
        XCTAssertEqual(try ClosedVocabularies.untaken(on: driver), [])
    }

    /// What each element's host says is heard, the log counted from its own start: a line said after every start
    /// is one line an element, the first element's after a line held from before.
    @MainActor
    func testEachStartsLogIsHeardFromItsStart() throws {
        let driver = SayingOnceEachStart()
        defer { driver.driver.renderer?.finish() }
        let elements = Array(ClosedVocabularies.walked.prefix(2))
        let untaken = try ClosedVocabularies.untaken(on: driver, elements)

        XCTAssertEqual(untaken.filter { $0.hasSuffix(": said") }.map { $0.prefix { $0 != ":" } },
                       elements.map { Substring($0) })
    }
}

#endif
