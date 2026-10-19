// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

import QuartzCore
import UIKit
@testable import StateUIUIKit
import XCTest

/// The frame clock: the display's frames, every one it draws.
final class UIKitFrameClockTests: XCTestCase {
    /// A MOTION RUNS AT THE DISPLAY'S FULL RATE: the clock asks the 120 frames a second a ProMotion display draws,
    /// and the application's Info.plist lets an iPhone give them - without it, an iPhone gives sixty.
    @MainActor
    func testAMotionRunsAtTheDisplaysFullRate() throws {
        let clock = UIKitFrameClock()
        defer { clock.stop() }

        let asked = try XCTUnwrap(clock.link?.preferredFrameRateRange)
        XCTAssertEqual(asked.maximum, 120)
        XCTAssertEqual(asked.preferred, 120)
        XCTAssertEqual(
            Bundle.main.object(forInfoDictionaryKey: "CADisableMinimumFrameDurationOnPhone") as? Bool, true,
            "the application lets an iPhone draw past sixty")
    }
}
