// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI
@_spi(Host) import StateUIHost
@_spi(Host) import StateUIConformance
import Foundation
import XCTest
@testable import StateUIWinUIDriver

/// An act the WinUI driver does by telling the host what the relay would report - no WinUI control touched - is the
/// host's own (`byHost`), so its verdict says ✓ and never ✅.
final class WinUIByHostTests: XCTestCase {
    /// The acts the driver tells the host as the relay's reports, each on an element it is done on.
    static let told: [(act: String, element: String)] = [
        ("toggle", "SplitView"), ("goBack", "NavigationStack"), ("goBack", "Window"), ("close", "Page"),
        ("close", "Popover"), ("activate", "ToolbarButton"), ("activate", "ToolbarToggle"),
        ("minimize", "Window"), ("restore", "Window"), ("switchAway", "Window"), ("switchBack", "Window"),
        ("bringToFront", "Window"), ("openLink", "Link"), ("dragAndDrop", "Text"), ("dropFiles", "VStack"),
        ("pressDown", "Rectangle"), ("drag", "Rectangle"), ("lift", "Rectangle"), ("hover", "Rectangle"),
        ("leave", "Rectangle"), ("tap", "Rectangle"), ("hold", "Rectangle"), ("pan", "Rectangle"),
        ("sweep", "MotionLayout"), ("pinch", "Rectangle"), ("rotate", "Rectangle"), ("answerShare", "Window"),
    ]

    /// Every act the table names is the host's own to the driver.
    func testEveryActTheDriverTellsIsTheHosts() {
        let unmarked = onUIThread {
            let driver = WinUIDriver()
            return Self.told.filter { driver.byHost("\($0.act) on \($0.element)") == nil }.map { "\($0.act) on \($0.element)" }
        }
        XCTAssertEqual(unmarked, [], "an act the driver tells as the relay would, marked as WinUI's own")
    }

    /// Every branch of the driver's `perform` that tells a report of the relay's - its callbacks, a bar's choice, a
    /// window's state, a view hearing input - is an act of the table.
    func testEveryActTheDriverTellsStandsInTheTable() throws {
        let source = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
            .deletingLastPathComponent().appendingPathComponent("Sources/StateUIWinUIDriver/Driver/WinUIDriver.swift")
        let text = try String(contentsOf: source, encoding: .utf8)
        let start = try XCTUnwrap(text.range(of: "    func perform(_ act: UserAct, on element: MountedElement) throws {"))
        let body = text[start.upperBound...]
        let perform = body[..<(body.range(of: "\n    }\n")?.lowerBound ?? body.endIndex)]
        let tells = ["WinUICallbacks.table", ".chose(", "state(of: element", ".heard"]
        var acts: Set<String> = []
        for branch in perform.components(separatedBy: "\n        case (.").dropFirst() {
            guard tells.contains(where: branch.contains) else { continue }
            acts.insert(String(branch.prefix { $0.isLetter }))
        }
        XCTAssertGreaterThan(acts.count, 10, "the scan found almost no branch")
        XCTAssertEqual(acts.subtracting(Self.told.map(\.act)), [], "a branch telling a report the table does not name")
    }
}
