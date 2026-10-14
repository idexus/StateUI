// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

import CStateUIGTK
@_spi(Host) import StateUI
@_spi(Host) import StateUIHost
@testable import StateUIGTK
@testable import StateUIGTKDriver
import XCTest

@MainActor
final class GTKImageViewTests: XCTestCase {
    /// The test's wide picture is an SVG, 40 by 20, of one colour.
    private static let wide: UInt32 = 0xFF33_6699

    /// An SVG is asked for by its PNG name, found, and drawn at the size it declares, in its colour.
    func testAnSVGAskedForByItsPNGNameIsDrawnAtItsOwnSize() throws {
        try onUIThread {
            let host = GTKRenderer.running {
                VStack { Image("test_wide.png") }
                    .horizontalAlignment(.start)
                    .verticalAlignment(.start)
            }
            let image = try XCTUnwrap(host.views(GTKImageView.self).first)
            XCTAssertTrue(image.found)
            host.settle { image.frame.width == 40 }

            XCTAssertTrue(image.frame == (0, 0, 40, 20), "\(image.frame)")
            XCTAssertEqual(image.pixels(at: [(20, 10)]), [Self.wide])
        }
    }

    /// A bitmap is its own size, however much room its layout offers.
    func testABitmapIsItsOwnSize() throws {
        try onUIThread {
            let host = GTKRenderer.running {
                VStack { Image("test_dot.png") }
                    .horizontalAlignment(.start)
                    .verticalAlignment(.start)
            }
            let image = try XCTUnwrap(host.views(GTKImageView.self).first)
            host.settle { image.frame.width == 6 }

            XCTAssertTrue(image.frame == (0, 0, 6, 4), "\(image.frame)")
            XCTAssertEqual(image.pixels(at: [(3, 2)]), [0xFFCC_3300])
        }
    }

    /// A picture read after its layouts were measured tells every layout above it, which grows around it.
    func testAPictureReadLateResizesTheLayoutsAboveIt() throws {
        try onUIThread {
            let host = GTKRenderer.running {
                VStack { HStack { Image("test_dot.png") } }
                    .horizontalAlignment(.start)
                    .verticalAlignment(.start)
            }
            let row = try XCTUnwrap(host.views(GTKStackView.self).last)
            host.settle { row.frame.width == 6 }

            XCTAssertTrue(row.frame == (0, 0, 6, 4), "\(row.frame)")
        }
    }

    /// Fitted, a wide picture is drawn whole across its room, with bands above and below.
    func testAFittedPictureIsDrawnWhole() throws {
        let colours = try drawn(.fit, width: 30, height: 30, at: [(15, 15), (15, 3), (15, 27)])
        XCTAssertEqual(colours, [Self.wide, 0, 0])
    }

    /// Filling, a wide picture covers its room, its sides cut off.
    func testAFillingPictureCoversItsRoom() throws {
        let colours = try drawn(.fill, width: 30, height: 30, at: [(1, 1), (15, 15), (28, 28)])
        XCTAssertEqual(colours, [Self.wide, Self.wide, Self.wide])
    }

    /// Stretched, a picture covers all of its room, whatever its own proportions.
    func testAStretchedPictureCoversItsRoom() throws {
        let colours = try drawn(.stretch, width: 30, height: 30, at: [(1, 1), (15, 28), (28, 1)])
        XCTAssertEqual(colours, [Self.wide, Self.wide, Self.wide])
    }

    /// Centred, a picture is drawn at its own size in the middle of its room.
    func testACentredPictureIsDrawnAtItsOwnSize() throws {
        let colours = try drawn(.center, width: 60, height: 60, at: [(30, 30), (12, 22), (5, 30), (30, 15)])
        XCTAssertEqual(colours, [Self.wide, Self.wide, 0, 0])
    }

    /// SVGs a second window shows cost it little: the pictures of the first window, shown again in another, add
    /// megabytes, each read at the size it stands at.
    func testASecondWindowShowingSVGsCostsLittle() throws {
        try onUIThread {
            let host = GTKRenderer.running(application: { PicturesApplication() })
            let open = try XCTUnwrap(host.views(GTKButtonView.self).first { $0.text == "Open" })
            host.settle { host.views(GTKImageView.self).allSatisfy { $0.frame.width > 0 } }
            let before = Self.privateBytes()

            open.click()
            host.settle { host.windows.count == 2 && host.views(GTKImageView.self).allSatisfy { $0.frame.width > 0 } }
            GTKTestHost.pump(0.5)
            let grown = Self.privateBytes() - before

            XCTAssertEqual(host.windows.count, 2)
            XCTAssertEqual(host.views(GTKImageView.self).count, 34)
            XCTAssertLessThan(grown, 200 << 20, "the second window took \(grown >> 20) MB")
        }
    }

    /// The bytes this process holds of its own: its private pages, clean and dirty.
    private static func privateBytes() -> Int {
        var contents: UnsafeMutablePointer<CChar>?
        guard g_file_get_contents("/proc/self/smaps_rollup", &contents, nil, nil) != 0, let contents else { return 0 }
        defer { g_free(contents) }
        let kilobytes = String(cString: contents).split(separator: "\n").reduce(0) { sum, line in
            let fields = line.split(separator: " ", omittingEmptySubsequences: true)
            guard fields.count == 3, fields[0] == "Private_Clean:" || fields[0] == "Private_Dirty:" else { return sum }
            return sum + (Int(fields[1]) ?? 0)
        }
        return kilobytes << 10
    }

    /// A picture the application does not have is found missing, and said so.
    func testAMissingPictureIsSaidMissing() throws {
        try onUIThread {
            let host = GTKRenderer.running { VStack { Image("nowhere.png") } }

            XCTAssertEqual(try XCTUnwrap(host.views(GTKImageView.self).first).found, false)
        }
    }

    /// Every icon stands in Adwaita, which holds the fewest of the themes: what it has no icon of, the host brings.
    func testEveryIconStandsInAdwaita() throws {
        try onUIThread {
            _ = GTKRenderer.running { VStack { Text("Icons") } }
            let theme = gtk_icon_theme_new()!
            defer { g_object_unref(UnsafeMutableRawPointer(theme)) }
            gtk_icon_theme_set_theme_name(theme, "Adwaita")
            for icon in Icon.allCases {
                let name = icon.name(in: theme)
                XCTAssertNotEqual(gtk_icon_theme_has_icon(theme, name), 0, "no \(name) for \(icon)")
            }
        }
    }

    /// Every icon is one the theme holds, by its symbolic name.
    func testEveryIconIsTheThemes() throws {
        try onUIThread {
            let host = GTKRenderer.running { VStack { Text("Icons") } }
            let text = try XCTUnwrap(host.views(GTKTextualView.self).first)
            let theme = gtk_icon_theme_get_for_display(gtk_widget_get_display(text.widget))
            for icon in Icon.allCases {
                let name = icon.name(in: theme)
                XCTAssertNotEqual(gtk_icon_theme_has_icon(theme, name), 0, "no \(name) for \(icon)")
            }
        }
    }

    /// An icon is the theme's symbolic one, filling its room in the colour of the words around it.
    func testAnIconIsDrawnInTheWordsColour() throws {
        try onUIThread {
            let host = GTKRenderer.running {
                VStack { Image(.icon(.add)).width(32).height(32) }
                    .horizontalAlignment(.start)
                    .verticalAlignment(.start)
            }
            let image = try XCTUnwrap(host.views(GTKImageView.self).first)
            host.settle { image.frame.width == 32 }

            var color = GdkRGBA()
            gtk_widget_get_color(image.widget, &color)
            // The icon's lines are thin: its most opaque pixel among a grid's, a pixel apart.
            var points: [(Double, Double)] = []
            for y in 0..<32 { for x in 0..<32 { points.append((Double(x), Double(y))) } }
            let drawn = image.pixels(at: points).max { $0 >> 24 < $1 >> 24 } ?? 0
            let alpha = Double(drawn >> 24)
            XCTAssertGreaterThan(alpha, 0, "the icon is drawn")
            // The pixel is premultiplied: each channel over its alpha is the words' own.
            for (shift, channel) in [(16, color.red), (8, color.green), (0, color.blue)] {
                let own = Double(drawn >> UInt32(shift) & 0xFF) / max(alpha, 1)
                XCTAssertEqual(own, Double(channel), accuracy: 0.03, String(drawn, radix: 16))
            }
        }
    }

    /// A button's icon, with its words or alone, is drawn in the colour written for the words.
    func testAButtonsIconTakesTheWordsWrittenColour() throws {
        try onUIThread {
            let host = GTKRenderer.running {
                VStack {
                    Button("Share").icon(.icon(.share)).textColor(Color("#FF0000"))
                    Button(icon: .icon(.settings)).textColor(Color("#FF0000"))
                }
                .horizontalAlignment(.start)
                .verticalAlignment(.start)
            }
            let buttons = host.views(GTKButtonView.self)
            host.settle { buttons.allSatisfy { ($0.picture?.frame.width ?? 0) > 0 } }

            for button in buttons {
                let picture = try XCTUnwrap(button.picture)
                var points: [(Double, Double)] = []
                for y in 0..<Int(picture.frame.height) { for x in 0..<Int(picture.frame.width) { points.append((Double(x), Double(y))) } }
                let drawn = picture.pixels(at: points).max { $0 >> 24 < $1 >> 24 } ?? 0
                let alpha = Double(drawn >> 24)
                XCTAssertGreaterThan(alpha, 0, "the icon is drawn")
                XCTAssertEqual(Double(drawn >> 16 & 0xFF) / max(alpha, 1), 1, accuracy: 0.03, String(drawn, radix: 16))
                XCTAssertEqual(Double(drawn & 0xFF) / max(alpha, 1), 0, accuracy: 0.03, String(drawn, radix: 16))
            }
        }
    }

    /// The colours at `points` of the test's wide picture drawn as `aspect` says in a room `width` by `height`,
    /// read from the layout holding it, from the room's corner.
    private func drawn(
        _ aspect: ContentMode, width: Double, height: Double, at points: [(Double, Double)]
    ) throws -> [UInt32] {
        try onUIThread {
            let host = GTKRenderer.running {
                VStack { Image("test_wide.png").contentMode(aspect).width(width).height(height) }
                    .horizontalAlignment(.start)
                    .verticalAlignment(.start)
            }
            let stack = try XCTUnwrap(host.views(GTKStackView.self).first)
            host.settle { stack.pixels(at: [(width / 2, height / 2)]) == [Self.wide] }
            return stack.pixels(at: points)
        }
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
            ForEach(Array(0..<17)) { _ in
                Image("test_wide.svg").width(177).height(248)
            }
        }
    }
}
