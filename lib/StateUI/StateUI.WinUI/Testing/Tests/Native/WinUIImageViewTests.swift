// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

import CStateUIWinUI
import Foundation
import WinSDK
@_spi(Host) import StateUI
@_spi(Host) import StateUIHost
@testable import StateUIWinUI
@testable import StateUIWinUIDriver
import XCTest

final class WinUIImageViewTests: XCTestCase {
    /// SVGs a second window shows cost it little: the pictures of the first window, shown again in another, add
    /// megabytes, not the gigabytes of shared surfaces an SVG read from memory took.
    func testASecondWindowShowingSVGsCostsLittle() throws {
        try onUIThread {
            let host = WinUIRenderer.running(application: { PicturesApplication() })
            let open = try XCTUnwrap(host.views(WinUIButtonView.self).first { $0.text == "Open" })
            WinUITestHost.pump(2)
            let before = Self.privateBytes()

            open.invoke()
            host.settle(until: { host.windows.count == 2 })
            WinUITestHost.pump(4)
            let grown = Self.privateBytes() - before

            XCTAssertLessThan(grown, 200 << 20, "the second window took \(grown >> 20) MB")
        }
    }

    /// Every SVG a window shows - a picture, one stretched, a button's - is read by its file's address: one read from
    /// memory costs a surface the window's size, gigabytes for a page of pictures.
    func testEverySVGIsReadByItsFilesAddress() throws {
        try onUIThread {
            let host = WinUIRenderer.running {
                VStack {
                    Image("test_wide.svg").width(80).height(40)
                    Image("test_halves.svg").contentMode(.stretch).width(60).height(60)
                    Button("Go").icon("test_wide.svg")
                }
            }
            let content = try XCTUnwrap(host.window?.content)
            var counts = [Int32](repeating: 0, count: 2)
            host.settle {
                stateui_winui_svgs_read(content.handle, &counts)
                return counts[0] + counts[1] >= 3
            }

            XCTAssertEqual(counts[1], 0, "an SVG read from memory")
            XCTAssertEqual(counts[0], 3, "every picture read by its address")
        }
    }

    /// The bytes this process holds of its own.
    private static func privateBytes() -> Int {
        let size = DWORD(MemoryLayout<PROCESS_MEMORY_COUNTERS_EX>.size)
        var counters = PROCESS_MEMORY_COUNTERS_EX()
        counters.cb = size
        _ = withUnsafeMutablePointer(to: &counters) {
            $0.withMemoryRebound(to: PROCESS_MEMORY_COUNTERS.self, capacity: 1) {
                K32GetProcessMemoryInfo(GetCurrentProcess(), $0, size)
            }
        }
        return Int(counters.PrivateUsage)
    }

    /// A picture read after its layouts were measured tells every layout above it, which grows around it.
    func testAPictureReadLateResizesTheLayoutsAboveIt() throws {
        try onUIThread {
            let host = WinUIRenderer.running {
                VStack { HStack { Image("test_dot.png") } }
                    .horizontalAlignment(.start)
                    .verticalAlignment(.start)
            }
            let row = try XCTUnwrap(host.views(WinUIStackView.self).last)
            host.settle { row.frame.width == 6 }

            XCTAssertTrue(row.frame == (0, 0, 6, 4), "\(row.frame)")
        }
    }

    /// An SVG stands at the size it declares: its width and height, the one it leaves out taken from its viewBox's
    /// proportions, or its viewBox alone.
    func testAnSVGStandsAtTheSizeItDeclares() throws {
        try onUIThread {
            let folder = FileManager.default.temporaryDirectory.appendingPathComponent("stateui-winui-svg")
            try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
            let figure = "<rect width=\"10\" height=\"10\" fill=\"red\"/></svg>"
            let pictures: [(name: String, tag: String, width: Double, height: Double)] = [
                ("sized.svg", "width=\"30\" height=\"20\" viewBox=\"0 0 3 2\"", 30, 20),
                ("boxed.svg", "viewBox=\"0 0 40 10\"", 40, 10),
                ("wide.svg", "width=\"60\" viewBox=\"0,0,40,10\"", 60, 15),
                ("tall.svg", "height=\"30pt\" viewBox=\"0 0 10 20\"", 20, 40),
            ]
            for picture in pictures {
                try "<svg xmlns=\"http://www.w3.org/2000/svg\" \(picture.tag)>\(figure)".write(
                    to: folder.appendingPathComponent(picture.name), atomically: true, encoding: .utf8)
            }
            stateui_winui_set_pictures(folder.path)
            defer { stateui_winui_set_pictures("") }

            for picture in pictures {
                let host = WinUIRenderer.running {
                    VStack { HStack { Image(ImageSource(picture.name)) } }
                        .horizontalAlignment(.start)
                        .verticalAlignment(.start)
                }
                let row = try XCTUnwrap(host.views(WinUIStackView.self).last)
                host.settle { row.frame.width == picture.width }

                XCTAssertTrue(row.frame == (0, 0, picture.width, picture.height), "\(picture.name): \(row.frame)")
            }
        }
    }
}

extension WinUIImageViewTests {
    /// An icon is its Segoe Fluent Icons glyph, in a FontIcon; the words assistive technology meets of the picture
    /// stay as it turns from an icon to a file and back.
    func testAnIconIsAGlyphAndKeepsThePicturesWords() throws {
        try onUIThread {
            let icon = State(wrappedValue: true)
            let host = WinUIRenderer.running {
                VStack {
                    Image(icon.wrappedValue ? .icon(.add) : ImageSource("test_dot.png")).accessibilityLabel("Add")
                    Button("Flip").onClicked { icon.wrappedValue.toggle() }
                }
            }
            let image = try XCTUnwrap(host.views(WinUIImageView.self).first)
            let flip = try XCTUnwrap(host.views(WinUIButtonView.self).first)
            XCTAssertEqual(Self.held(image, "source"), "glyph:E710")
            XCTAssertEqual(image.automationWords.name, "Add")

            flip.invoke()
            host.settle { Self.held(image, "source") == "test_dot.png" }
            XCTAssertEqual(Self.held(image, "source"), "test_dot.png")
            XCTAssertEqual(image.automationWords.name, "Add")

            flip.invoke()
            host.settle { Self.held(image, "source") == "glyph:E710" }
            XCTAssertEqual(Self.held(image, "source"), "glyph:E710")
            XCTAssertEqual(image.automationWords.name, "Add")
        }
    }

    /// What WinUI holds of `view`'s property named `what`, by the relay's reader.
    @MainActor private static func held(_ view: WinUIView, _ what: String) -> String {
        let length = stateui_winui_read(view.handle, what, nil, 0)
        guard length >= 0 else { return "" }
        var bytes = [CChar](repeating: 0, count: Int(length) + 1)
        _ = stateui_winui_read(view.handle, what, &bytes, Int32(bytes.count))
        return String(decoding: bytes.prefix(Int(length)).map { UInt8(bitPattern: $0) }, as: UTF8.self)
    }
}

/// An application whose first window shows a run of SVGs and opens a second window showing them again.
private struct PicturesApplication: Application {
    var body: some Scene { PicturesScene() }
}

private struct PicturesScene: Scene {
    var body: some Scene {
        WindowGroup { PicturesPage(opens: true) }
        Window(WindowType("pictures.again")) { PicturesPage(opens: false) }
    }
}

private struct PicturesPage: View {
    let opens: Bool

    @Environment(\.application) private var application

    var body: some View {
        let application = self.application
        return VStack {
            if opens {
                Button("Open").onClicked(gate: .ignoreWhileRunning) { try await application.openWindow(WindowType("pictures.again")) }
            }
            ForEach(Array(0..<17)) { index in
                Image(index.isMultiple(of: 2) ? "test_wide.svg" : "test_halves.svg").width(177).height(248)
            }
        }
    }
}
