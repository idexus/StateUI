// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

import CStateUIGTK
@_spi(Host) import StateUIHost
@testable import StateUIGTK
@testable import StateUIGTKDriver
import XCTest

@MainActor
final class GTKFrameClockTests: XCTestCase {
    /// Whether the window went.
    nonisolated(unsafe) private static var went = false

    /// The clock holds the window it ticks with: a window closed and let go of by its controller while the clock is
    /// held stands until the clock moves on, which takes its tick off a window still there.
    func testTheClockHoldsTheWindowItTicksWith() {
        onUIThread {
            _ = GTKTestHost.application
            let current = GTKFrameClock.current
            defer { GTKFrameClock.current = current }
            Self.went = false
            let clock = GTKFrameClock()
            // Held as a window's controller holds it.
            let window = gtk_window_new()!
            g_object_ref(window)
            g_object_weak_ref(window.of(GObject.self), { _, _ in GTKFrameClockTests.went = true }, nil)
            clock.widget = window
            clock.held = true

            gtk_window_destroy(window.of(GtkWindow.self))
            g_object_unref(window)
            XCTAssertFalse(Self.went, "the window the clock ticks with went under it")
            guard !Self.went else { return }

            clock.widget = nil
            XCTAssertTrue(Self.went, "the clock let go of the window as it moved on")
        }
    }
}
