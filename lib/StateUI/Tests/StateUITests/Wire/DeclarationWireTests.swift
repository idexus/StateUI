// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

// A host declaration encoded as the AppKit and Android suites still write it
// beside its text in `exports/`.

import XCTest
@_spi(Host) @testable import StateUI

final class DeclarationWireTests: XCTestCase {
    /// A declaration crosses and reads back whole.
    func testADeclarationReadsBackAsItWasWritten() {
        XCTAssertEqual(Wire.decodeDeclaration(Wire.encodeDeclaration(Self.sample)), Self.sample)
    }

    /// The bytes are the same whatever order it was gathered in: sets are
    /// written sorted, the wire's rule.
    func testTheSameDeclarationIsTheSameBytes() {
        let same = HostDeclaration(elements: [
            "Slider": HostDeclaration.Element(
                members: ["value", "minimum", "maximum"], events: ["valueChanged"]),
            "Label": HostDeclaration.Element(members: ["maximumLines", "fontSize"]),
        ])

        XCTAssertEqual(Wire.encodeDeclaration(same), Wire.encodeDeclaration(Self.sample))
    }

    /// A buffer that will not read is refused whole rather than half read.
    func testAnUnreadableBufferIsRefused() {
        XCTAssertNil(Wire.decodeDeclaration([99, 1, 2, 3]))
        XCTAssertNil(Wire.decodeDeclaration(Array(Wire.encodeDeclaration(Self.sample).dropLast())))
        XCTAssertNil(Wire.decodeDeclaration(Wire.encodeDeclaration(Self.sample) + [0]))
    }

    private static let sample = HostDeclaration(elements: [
        "Label": HostDeclaration.Element(members: ["fontSize", "maximumLines"]),
        "Slider": HostDeclaration.Element(
            members: ["maximum", "minimum", "value"], events: ["valueChanged"]),
    ])
}
