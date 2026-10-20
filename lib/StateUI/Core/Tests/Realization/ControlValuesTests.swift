// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

import XCTest
@_spi(Host) @testable import StateUI

/// What an application's own control is handed whole: each value by its member, as the type its contract declares,
/// and which of them changed.
@MainActor
final class ControlValuesTests: XCTestCase {
    func testAControlReadsEachValueByItsMemberAndWhatChanged() {
        let values = ControlValues<WebViewContract>(ElementValues(
            changed: [WebViewContract.source.token],
            reading: { key in
                switch key {
                case WebViewContract.userAgent.token: .string("Probe/1")
                case WebViewContract.source.token: WebViewSource.url("https://example.com/").propValue
                default: nil
                }
            }))

        XCTAssertEqual(values[WebViewContract.userAgent], "Probe/1")
        XCTAssertEqual(values[WebViewContract.source], .url("https://example.com/"))
        XCTAssertTrue(values.changed(WebViewContract.source))
        XCTAssertFalse(values.changed(WebViewContract.userAgent))
    }
}
