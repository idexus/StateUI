// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

import UIKit
@_spi(Host) import StateUI
@_spi(Host) import StateUIHost
@testable import StateUIUIKit
import XCTest

/// A field's outline on UIKit.
@MainActor
final class UIKitFieldOutlineTests: XCTestCase {
    /// A field outlined in place of its own frame stands as tall as a field in it, holding words or none, and sets
    /// its words in from its edge as its own frame does.
    func testAnOutlinedFieldStandsAsAFieldInItsOwnFrame() throws {
        let words = State(wrappedValue: "")
        let host = UIKitRenderer.running {
            VStack {
                TextField(words.projectedValue)
                TextField(words.projectedValue).stroke(.red).lineWidth(1.5).shape(.capsule)
            }
        }
        defer { host.finish() }
        let fields = host.views(UIKitTextFieldView.self)
        host.settle { fields.count == 2 && fields.allSatisfy { $0.frame.height > 0 } }
        let inset = { (field: UIKitTextFieldView) in field.textRect(forBounds: field.bounds).minX }

        XCTAssertEqual(fields[1].frame.height, fields[0].frame.height, accuracy: 0.5, "as tall, holding none")
        XCTAssertGreaterThanOrEqual(inset(fields[1]), inset(fields[0]) - 0.5, "its words set in")

        words.wrappedValue = "Dddddd"
        host.settle { fields.allSatisfy { $0.text == "Dddddd" } }
        fields.forEach { $0.superview?.layoutIfNeeded() }
        XCTAssertEqual(fields[1].frame.height, fields[0].frame.height, accuracy: 0.5, "as tall, holding words")
    }
}
