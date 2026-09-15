// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

#if os(macOS)
import AppKit
import XCTest
@testable import StateUIAppKit

final class AppKitFrameClockTests: XCTestCase {
    /// The runtime has one frame signal and one timebase, and both are the
    /// frame clock's: no other file of the host takes a display link or reads
    /// the media clock.
    func testTheFrameClockIsTheOnlySignalAndTimebase() throws {
        let sources = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()    // Tests
            .deletingLastPathComponent()    // StateUI.AppKit
            .appendingPathComponent("Sources")
        let signals = ["CADisplayLink", "displayLink(target:", "CACurrentMediaTime"]
        var found: [String] = []

        let names = try FileManager.default.contentsOfDirectory(atPath: sources.path).sorted()
        for name in names where name.hasSuffix(".swift") && name != "AppKitFrameClock.swift" {
            let text = try String(contentsOf: sources.appendingPathComponent(name), encoding: .utf8)
            let lines = text.split(separator: "\n", omittingEmptySubsequences: false)

            for (number, line) in lines.enumerated()
            where !line.trimmingCharacters(in: .whitespaces).hasPrefix("//") {
                for signal in signals where line.contains(signal) {
                    found.append("\(name):\(number + 1): \(signal)")
                }
            }
        }

        XCTAssertEqual(found, [], "frames and time come from AppKitFrameClock alone")
    }

    /// Frames come only while something holds the clock, and a closing window
    /// hands the frames to the next one - holding as it was.
    @MainActor
    func testFramesComeOnlyWhileHeldAndFollowTheWindows() {
        let first = window()
        let second = window()
        let clock = AppKitFrameClock(now: { 0 })

        clock.attach(to: first)
        XCTAssertFalse(clock.isRunning, "nothing holds it yet")

        clock.held = true
        XCTAssertTrue(clock.isRunning)

        clock.held = false
        XCTAssertFalse(clock.isRunning, "a still page costs no frames")

        clock.held = true
        clock.release(second, next: nil)
        XCTAssertTrue(clock.window === first, "a window that gives no frames releases nothing")

        clock.release(first, next: second)
        XCTAssertTrue(clock.window === second)
        XCTAssertTrue(clock.isRunning, "the next window's frames keep the hold")

        clock.stop()
        XCTAssertNil(clock.window)
        XCTAssertFalse(clock.isRunning)
    }

    @MainActor
    private func window() -> NSWindow {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 200, height: 100),
            styleMask: [.titled],
            backing: .buffered,
            defer: false)
        window.isReleasedWhenClosed = false
        return window
    }
}
#endif
