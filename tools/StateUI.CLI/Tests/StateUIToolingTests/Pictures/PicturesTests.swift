// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

import Foundation
@testable import StateUITooling
import StateUIToolingProtocol
import XCTest

/// The pictures every head is given, drawn by the machine's resvg of the pinned release - skipped where it has none.
final class PicturesTests: XCTestCase {
    private let svg = #"<svg xmlns="http://www.w3.org/2000/svg" width="20" height="10"><rect width="20" height="10" fill="blue"/></svg>"#

    private func pictures() async throws -> Pictures {
        do {
            return Pictures(renderer: try await Resvg.find())
        } catch {
            throw XCTSkip("no resvg \(Resvg.release) here: \(error)")
        }
    }

    private func folder() throws -> URL {
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent("pictures-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        addTeardownBlock { try? FileManager.default.removeItem(at: folder) }
        return folder
    }

    /// A PNG's size in pixels and whether it holds an alpha channel, read from its header.
    private func header(_ png: URL) throws -> (width: Int, height: Int, alpha: Bool) {
        let bytes = [UInt8](try Data(contentsOf: png).prefix(26))
        let number = { (at: Int) in bytes[at..<at + 4].reduce(0) { $0 << 8 | Int($1) } }
        return (number(16), number(20), bytes[25] == 6 || bytes[25] == 4)
    }

    /// An SVG is drawn at a scale of its own size; a folder's SVGs become `@3x` PNGs, its other pictures are copied,
    /// and what left the folder leaves the drawn one.
    func testAFoldersSVGsAreDrawnAndItsOtherPicturesCarried() async throws {
        let pictures = try await pictures()
        let root = try folder()
        let images = root.appendingPathComponent("Images")
        try FileManager.default.createDirectory(at: images, withIntermediateDirectories: true)
        try svg.write(to: images.appendingPathComponent("mark.svg"), atomically: true, encoding: .utf8)
        let target = root.appendingPathComponent("drawn")

        try await pictures.draw(images.appendingPathComponent("mark.svg"), scale: 2, to: root.appendingPathComponent("mark.png"))
        XCTAssertTrue(try header(root.appendingPathComponent("mark.png")) == (40, 20, true))

        try FileManager.default.copyItem(at: root.appendingPathComponent("mark.png"), to: images.appendingPathComponent("photo.png"))
        try Data("not a picture".utf8).write(to: images.appendingPathComponent("notes.txt"))
        try FileManager.default.createDirectory(at: target, withIntermediateDirectories: true)
        try Data().write(to: target.appendingPathComponent("gone@3x.png"))
        try await pictures.draw(images, into: target)

        XCTAssertEqual(try FileManager.default.contentsOfDirectory(atPath: target.path).sorted(), ["mark@3x.png", "photo.png"])
        XCTAssertTrue(try header(target.appendingPathComponent("mark@3x.png")) == (60, 30, true))
    }

    /// A macOS icon set holds the ten pictures `iconutil` reads, each its own size in pixels.
    func testAnIconSetHoldsEverySizeAtOneAndTwoPixelsAPoint() async throws {
        let pictures = try await pictures()
        let root = try folder()
        let source = root.appendingPathComponent("icon.svg")
        try svg.write(to: source, atomically: true, encoding: .utf8)
        let iconset = root.appendingPathComponent("StateUI.iconset")

        try await pictures.drawIconSet(source, into: iconset)

        XCTAssertEqual(try FileManager.default.contentsOfDirectory(atPath: iconset.path).count, 10)
        XCTAssertEqual(try header(iconset.appendingPathComponent("icon_16x16.png")).width, 16)
        XCTAssertEqual(try header(iconset.appendingPathComponent("icon_512x512@2x.png")).height, 1024)
    }

    /// An iOS icon is one 1024-pixel square in an asset catalog, the mark over the background, with no alpha on a Mac,
    /// and drawn again only where its artwork changed.
    func testAnIOSIconIsTheMarkOverTheBackgroundOpaque() async throws {
        let pictures = try await pictures()
        let root = try folder()
        let background = root.appendingPathComponent("appicon_bkg.svg")
        let mark = root.appendingPathComponent("appicon_mark.svg")
        try svg.write(to: background, atomically: true, encoding: .utf8)
        try #"<svg xmlns="http://www.w3.org/2000/svg" width="20" height="10"><rect x="5" width="10" height="10" fill="red"/></svg>"#
            .write(to: mark, atomically: true, encoding: .utf8)
        let catalog = root.appendingPathComponent("Assets.xcassets")

        try await pictures.drawAppIcon(background: background, mark: mark, into: catalog)

        let png = catalog.appendingPathComponent("AppIcon.appiconset/appicon.png")
        let drawn = try header(png)
        XCTAssertEqual(drawn.width, 1024)
        XCTAssertEqual(drawn.height, 1024)
        #if canImport(ImageIO)
        XCTAssertFalse(drawn.alpha, "an iOS icon carries no alpha")
        #endif
        XCTAssertTrue(FileManager.default.fileExists(atPath: catalog.appendingPathComponent("AppIcon.appiconset/Contents.json").path))

        let written = try FileManager.default.attributesOfItem(atPath: png.path)[.modificationDate] as? Date
        try await pictures.drawAppIcon(background: background, mark: mark, into: catalog)
        XCTAssertEqual(try FileManager.default.attributesOfItem(atPath: png.path)[.modificationDate] as? Date, written)
    }

    /// An Android launcher icon is adaptive: its background and its foreground at every density, each a 108 dp canvas
    /// in pixels, and the XML naming them - the foreground its monochrome layer too.
    func testAnAndroidIconIsAdaptiveAtEveryDensity() async throws {
        let pictures = try await pictures()
        let root = try folder()
        let background = root.appendingPathComponent("appicon_bkg.svg")
        let mark = root.appendingPathComponent("appicon_mark.svg")
        try svg.write(to: background, atomically: true, encoding: .utf8)
        try svg.write(to: mark, atomically: true, encoding: .utf8)
        let res = root.appendingPathComponent("res")

        try await pictures.drawAdaptiveIcon(background: background, mark: mark, into: res)

        for (folder, side) in [("mipmap-mdpi", 108), ("mipmap-hdpi", 162), ("mipmap-xhdpi", 216), ("mipmap-xxhdpi", 324), ("mipmap-xxxhdpi", 432)] {
            for layer in ["appicon_background", "appicon_foreground"] {
                let drawn = try header(res.appendingPathComponent("\(folder)/\(layer).png"))
                XCTAssertTrue(drawn.width == side && drawn.height == side, "\(folder)/\(layer)")
            }
        }
        let xml = try String(contentsOf: res.appendingPathComponent("mipmap-anydpi-v26/appicon.xml"), encoding: .utf8)
        XCTAssertTrue(xml.contains("<monochrome android:drawable=\"@mipmap/appicon_foreground\" />"))
    }

    /// The layers stand stretched over their fraction of the square about its middle, every path written as XML.
    func testLayersStandAboutTheMiddle() {
        let held = Pictures.layered([(URL(fileURLWithPath: "/a & b/bkg.svg"), 1), (URL(fileURLWithPath: "/m.svg"), 0.5)], size: 100)
        XCTAssertTrue(held.contains(#"xlink:href="/a &amp; b/bkg.svg" x="0.0" y="0.0" width="100.0" height="100.0""#), held)
        XCTAssertTrue(held.contains(#"xlink:href="/m.svg" x="25.0" y="25.0" width="50.0" height="50.0""#), held)
    }

    /// CI installs the pinned release where a suite draws pictures: the workflows of the UIKit and Android hosts,
    /// whose test applications carry images, take it from the action that downloads that release.
    func testCIInstallsThePinnedRelease() throws {
        let github = ProjectReaderTests.repository.appendingPathComponent(".github")
        let action = try String(contentsOf: github.appendingPathComponent("actions/resvg/action.yml"), encoding: .utf8)
        XCTAssertTrue(action.contains("/download/v\(Resvg.release)/"), "the action downloads resvg \(Resvg.release)")
        for workflow in ["uikit.yml", "android.yml"] {
            let text = try String(contentsOf: github.appendingPathComponent("workflows/\(workflow)"), encoding: .utf8)
            XCTAssertTrue(text.contains("uses: ./.github/actions/resvg"), "\(workflow) installs resvg")
        }
    }

    /// Another release of resvg than the pinned one is refused, with how to get the pinned one.
    func testAnotherReleaseIsRefused() async throws {
        #if os(Windows)
        throw XCTSkip("a stand-in program is a shell script")
        #else
        let root = try folder()
        let stand = root.appendingPathComponent("resvg")
        try "#!/bin/sh\necho 0.49.0\n".write(to: stand, atomically: true, encoding: .utf8)
        try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: stand.path)
        do {
            _ = try await Resvg.find(environment: ["STATEUI_RESVG": stand.path])
            XCTFail("another release drew")
        } catch let error as ToolingError {
            XCTAssertEqual(error.code, .missingToolchain)
            XCTAssertTrue(error.message.contains("not \(Resvg.release)"), error.message)
        }
        #endif
    }
}
