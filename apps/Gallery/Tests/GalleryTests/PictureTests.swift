// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

import Foundation
import XCTest

/// The gallery's pictures, as every host's SVG renderer draws them.
final class PictureTests: XCTestCase {
    /// No picture writes its words as SVG text: WinUI's renderer draws no `<text>`, so a picture's words are outlines.
    func testNoPictureWritesItsWordsAsText() throws {
        let pictures = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
            .appendingPathComponent("Resources/Images")
        let files = try FileManager.default.contentsOfDirectory(atPath: pictures.path).filter { $0.hasSuffix(".svg") }
        XCTAssertFalse(files.isEmpty, "the pictures are found")
        for file in files.sorted() {
            let text = try String(contentsOf: pictures.appendingPathComponent(file), encoding: .utf8)
            XCTAssertNil(text.range(of: "<text"), "\(file) writes words as text")
        }
    }
}
