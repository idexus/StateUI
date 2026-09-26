// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

#if os(macOS)
import Foundation
import XCTest
@_spi(Host) @testable import StateUI
@_spi(Host) @testable import StateUIHost
@testable import StateUIAppKit

/// The renderer every test here drives.
///
/// IT ANSWERS FOR THE MACHINE ITSELF, so no test reads what the machine
/// happens to be set to. `AppKitRenderer` asks macOS whether it should reduce
/// motion, and a machine that says yes snaps every described motion to its
/// destination: a test asserting the first frame of a journey then reads the
/// last one - measured as `("60.0") is not equal to ("40.0")` on a CI runner,
/// which is a virtual machine with Reduce Motion on, while the same test
/// passed on every desktop. A test that wants the other answer says so.
///
/// It also shows no window and keeps the machine's own defaults out of the
/// way - what a test wants of both, it says.
@MainActor
func testRenderer(
    resourceDirectory: URL? = nil,
    presentsWindows: Bool = false,
    eventSink: ((Int32, [HostValue]) -> Void)? = nil,
    preferences: UserDefaults = .standard,
    clock: (() -> Double)? = nil,
    reducesMotion: @escaping () -> Bool = { false }
) -> AppKitRenderer {
    AppKitRenderer(
        resourceDirectory: resourceDirectory,
        presentsWindows: presentsWindows,
        eventSink: eventSink,
        preferences: preferences,
        clock: clock,
        reducesMotion: reducesMotion)
}

/// The suite answers for the machine rather than reading it.
final class AppKitTestRendererTests: XCTestCase {
    /// EVERY TEST MAKES ITS RENDERER THROUGH `testRenderer`. The host's own
    /// initializer asks macOS whether it should reduce motion, and a machine
    /// that says yes - a CI runner is a virtual machine, and says yes - snaps
    /// every described motion to its destination. A test built on the
    /// initializer therefore passes on a desktop and fails on the runner, on
    /// the first frame of a journey, with nothing in the failure about the
    /// setting behind it.
    func testEveryTestMakesItsRendererThroughTheSuitesOwn() throws {
        var direct: [String] = []

        for (name, text) in try AppKitSources.tests()
        where name != URL(fileURLWithPath: #filePath).lastPathComponent {
            if text.contains("AppKitRenderer(") {
                direct.append(name)
            }
        }

        XCTAssertEqual(
            direct, [],
            "these make a renderer through AppKitRenderer, which reads the machine's own Reduce "
                + "Motion setting - make it with testRenderer, which answers for the machine")
    }
}
#endif
