// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

#if os(macOS)
import AppKit
import XCTest
@_spi(Host) import StateUI
@testable import StateUIAppKit

@MainActor
final class AppKitIntegerBoundsTests: XCTestCase {
    func testATextsUnrepresentableLineLimitUsesItsUnboundedDefault() {
        let host = AppKitRenderer.running {
            VStack {
                Text("Unbounded").maximumLines(Int.max)
                Text("Three").maximumLines(3)
                Text("Negative").maximumLines(Int.min)
                Text("Truncated").lineBreak(.tailTruncation).maximumLines(Int.max)
            }
        }
        defer { host.finish() }
        let fields = host.nativeViews(AppKitTextView.self).compactMap {
            $0.subviews.compactMap { $0 as? NSTextField }.first
        }
        XCTAssertEqual(fields.count, 4)
        XCTAssertEqual(fields.map(\.maximumNumberOfLines), [0, 3, 0, 1])
    }
}
#endif
