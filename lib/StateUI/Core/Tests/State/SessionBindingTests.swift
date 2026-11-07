// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

import XCTest
@_spi(Host) @testable import StateUI

@MainActor
final class SessionBindingTests: XCTestCase {
    func testAThemeBindingOutlivesItsSession() {
        _ = drainedActs()
        var session: ApplicationSession? = ApplicationSession()
        weak let released = session
        let binding = session!.$colorScheme
        session = nil
        XCTAssertNil(released)
        binding.wrappedValue = .dark
        XCTAssertEqual(binding.wrappedValue, .dark)
        XCTAssertTrue(drainedActs().isEmpty, "a departed session performs no host effect")
    }

    func testAnAccentBindingOutlivesItsSession() {
        _ = drainedActs()
        var session: ApplicationSession? = ApplicationSession()
        weak let released = session
        let binding = session!.$accentColor
        session = nil
        XCTAssertNil(released)
        binding.wrappedValue = .red
        XCTAssertEqual(binding.wrappedValue, .red)
        XCTAssertTrue(drainedActs().isEmpty, "a departed session performs no host effect")
    }

    func testAnOrdinaryBindingOutlivesItsModel() {
        @MainActor final class Model {
            @State var value = ColorScheme.light
        }
        var model: Model? = Model()
        weak let released = model
        let binding = model!.$value
        model = nil
        XCTAssertNil(released)
        binding.wrappedValue = .dark
        XCTAssertEqual(binding.wrappedValue, .dark)
    }
}
