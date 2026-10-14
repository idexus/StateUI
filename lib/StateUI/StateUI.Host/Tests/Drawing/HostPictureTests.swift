// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) @testable import StateUI
@_spi(Host) @testable import StateUIHost
import XCTest

/// A picture's value read as a file, an icon or bytes - and none for nothing to show.
@MainActor
final class HostPictureTests: XCTestCase {
    func testAPictureIsAFileAnIconOrBytes() {
        XCTAssertEqual(HostPicture(ImageSource("dot.png").propValue), .file("dot.png"))
        XCTAssertEqual(HostPicture(ImageSource.icon(.share).propValue), .icon(.share))
        XCTAssertEqual(HostPicture(ImageSource(bytes: [137, 80, 78, 71]).propValue), .bytes([137, 80, 78, 71]))
        for source in [ImageSource("dot.png"), .icon(.share), ImageSource(bytes: [1, 2])] {
            XCTAssertEqual(HostPicture(source.propValue)?.value, source.propValue, "a picture names itself again")
        }
    }

    func testNothingToShowIsNoPicture() {
        XCTAssertNil(HostPicture(nil))
        XCTAssertNil(HostPicture(ImageSource("").propValue))
        XCTAssertNil(HostPicture(ImageSource(bytes: []).propValue))
        XCTAssertNil(HostPicture(.enumeration(999)), "no icon of that number")
    }

    /// A file stands for its theme's; a picture's identity tells it from another, the same bytes alike.
    func testAFileStandsForItsThemeAndAPictureForItself() {
        let themed = ImageSource(light: "sun.png", dark: "moon.png")
        XCTAssertEqual(HostPicture(themed, dark: false), .file("sun.png"))
        XCTAssertEqual(HostPicture(themed, dark: true), .file("moon.png"))
        XCTAssertEqual(HostPicture(.icon(.star), dark: true), .icon(.star))

        XCTAssertEqual(HostPicture.bytes([1, 2]).identity, HostPicture.bytes([1, 2]).identity)
        XCTAssertNotEqual(HostPicture.bytes([1, 2]).identity, HostPicture.bytes([2, 1]).identity)
        XCTAssertEqual(HostPicture.icon(.star).identity, "icon:star")
    }

    /// Bytes in base64: three bytes in four characters, the last padded with `=`.
    func testBytesAreWrittenInBase64() {
        XCTAssertEqual(Base64.encoded([]), "")
        XCTAssertEqual(Base64.encoded(Array("Man".utf8)), "TWFu")
        XCTAssertEqual(Base64.encoded(Array("Ma".utf8)), "TWE=")
        XCTAssertEqual(Base64.encoded(Array("M".utf8)), "TQ==")
        XCTAssertEqual(Base64.encoded([0xFF, 0xFE, 0xFD, 0x00]), "//79AA==")
    }
}
