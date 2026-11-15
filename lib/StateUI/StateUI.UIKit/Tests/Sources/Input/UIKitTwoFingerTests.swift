// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

import UIKit
@_spi(Host) import StateUI
@_spi(Host) import StateUIHost
@testable import StateUIUIKit
import XCTest

/// What a view's pinches and rotations told, phase by phase.
@MainActor
private final class Told {
    var pinches: [(GesturePhase, Double)] = []
    var rotations: [(GesturePhase, Double)] = []
}

/// A pinch or a rotation UIKit takes away - cancelled, or failed - as UIKit tells it.
@MainActor
final class UIKitTwoFingerTests: XCTestCase {
    /// A gesture taken away ends cancelled, not ended, at the total it reached, and the next begins afresh.
    func testAPinchOrARotationTakenAwayEndsCancelled() throws {
        let told = Told()
        let host = UIKitRenderer.running(reducesMotion: false) {
            Text("Two fingers")
                .onPinchUpdated { told.pinches.append(($0.phase, $0.scale)) }
                .onRotationUpdated { told.rotations.append(($0.phase, $0.angle)) }
        }
        defer { host.finish() }
        let view = try XCTUnwrap(host.views(UIKitTextView.self).first)
        let listening = try XCTUnwrap((host.runtime.tree.root?.first(type: .text)?.native as? UIKitElement)?.listening)
        let pinch = DrivenPinch(on: view), rotation = DrivenRotation(on: view)

        for taken in [UIGestureRecognizer.State.cancelled, .failed] {
            told.pinches = []
            told.rotations = []
            for (state, scale, degrees) in [(UIGestureRecognizer.State.began, 1.0, 0.0), (.changed, 2.0, 30), (taken, 2.0, 30),
                                            (.began, 1.0, 0), (.changed, 1.5, 10), (.ended, 1.5, 10)] {
                (pinch.driven, pinch.drivenScale) = (state, scale)
                (rotation.driven, rotation.drivenRotation) = (state, degrees * .pi / 180)
                listening.pinched(pinch)
                listening.rotated(rotation)
            }
            host.settle { told.pinches.count == 6 && told.rotations.count == 6 }

            XCTAssertEqual(told.pinches.map(\.0), [.began, .changed, .cancelled, .began, .changed, .ended], "\(taken)")
            XCTAssertEqual(told.pinches.map(\.1), [1, 2, 2, 1, 1.5, 1.5], "each gesture's total, the next from its start")
            XCTAssertEqual(told.rotations.map(\.0), [.began, .changed, .cancelled, .began, .changed, .ended])
            XCTAssertEqual(told.rotations.map(\.1), [0, 30, 30, 0, 10, 10], accuracy: 1e-9)
        }
    }
}

private func XCTAssertEqual(_ one: [Double], _ other: [Double], accuracy: Double, file: StaticString = #filePath,
                            line: UInt = #line) {
    XCTAssertEqual(one.count, other.count, file: file, line: line)
    for (a, b) in zip(one, other) { XCTAssertEqual(a, b, accuracy: accuracy, file: file, line: line) }
}
