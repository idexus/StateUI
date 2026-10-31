// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUIFoundation
import XCTest

/// The process's environment, read by name.
final class EnvironmentVariableTests: XCTestCase {
    private static let name = "STATEUI_FOUNDATION_TEST"

    /// A VARIABLE THE PROCESS HOLDS IS READ, and one it does not hold is nil.
    func testAVariableIsReadAndAnAbsentOneIsNil() {
        set(Self.name, "on")
        XCTAssertEqual(environmentVariable(Self.name), "on")

        set(Self.name, nil)
        XCTAssertNil(environmentVariable(Self.name))
    }

    private func set(_ name: String, _ value: String?) {
        #if os(Windows)
        _ = _putenv_s(name, value ?? "")
        #else
        if let value { setenv(name, value, 1) } else { unsetenv(name) }
        #endif
    }
}
