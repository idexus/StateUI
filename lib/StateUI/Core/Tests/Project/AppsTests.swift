// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

// The applications under apps/ and their artwork.
//
// An application lives under apps/<Name>/ and states every connection to the
// repository as a relative path - to the library's Swift packages and to the
// hosts'. A path that no longer resolves fails late: SwiftPM cannot resolve,
// with a message about the symptom rather than the move that caused it. These
// tests read the paths out of the manifests and resolve them here, so a moved
// directory names the file that still points at the old place.
//
// What makes a new application - `stateui new` - is the tool's, tested in
// tools/StateUI.CLI (ApplicationMakerTests).

import Foundation
import XCTest

@MainActor
final class AppsTests: XCTestCase {
    // MARK: - The layout

    /// Every application under `apps/` is wired to the repository: its Swift
    /// manifest declares the application's module, `<Name>UI`, every package
    /// and target path the manifest names resolves, and the one export a host
    /// calls by name is declared under `Sources/`.
    ///
    /// A new application is checked the moment it exists, with nothing to
    /// remember.
    func testEveryAppUnderAppsIsWiredToTheRepo() throws {
        let applications = try SourceTree.applications()
        XCTAssertFalse(
            applications.isEmpty, "apps/ holds no application - the Gallery and HelloWorld live there.")

        for app in applications {
            let name = app.lastPathComponent

            // Finder reads a directory named Something.App as a bundle.
            XCTAssertFalse(name.contains("."), "\(name): an application's name holds no dot.")

            let manifestFile = app.appendingPathComponent("Package.swift")

            guard FileManager.default.fileExists(atPath: manifestFile.path) else {
                XCTFail("\(name): no Package.swift - SourceKit and every head read one.")
                continue
            }

            let manifest = try String(contentsOf: manifestFile, encoding: .utf8)

            // The TARGET, not merely the name somewhere in the file: a manifest
            // whose package and product were renamed and whose target was not
            // is refused by SwiftPM.
            XCTAssertTrue(
                squeezed(manifest).contains(".target(name:\"\(name)UI\""),
                "\(name): Package.swift declares no target called \(name)UI - SwiftPM refuses "
                    + "the package.")

            for (path, isPackage) in manifestPaths(in: manifest) {
                let directory = app.appendingPathComponent(path).standardizedFileURL
                let wanted = isPackage ? directory.appendingPathComponent("Package.swift") : directory

                XCTAssertTrue(
                    FileManager.default.fileExists(atPath: wanted.path),
                    "\(name): Package.swift names \(path), and \(wanted.path) does not exist.")
            }

            // Every head names the application to its host by its one public type, in Swift, before the host runs;
            // the manifest compiles Sources/ whole, so the file declaring it may sit anywhere under it - and the
            // listings cut from the code quote it.
            let sources = app.appendingPathComponent("Sources")
            let registering = try SourceTree.files(under: sources)
                .filter { $0.hasSuffix(".swift") && !$0.hasSuffix("Listings.swift") }
                .map { try String(contentsOf: sources.appendingPathComponent($0), encoding: .utf8) }
                .filter { $0.contains("public struct \(name)App: Application") }

            XCTAssertEqual(
                registering.count, 1,
                "\(name): Sources/ declares \(name)App \(registering.count) times - its heads name "
                    + "the application to their host by \(name)App.register()")
            XCTAssertFalse(
                registering.contains { $0.contains("@_cdecl(") },
                "\(name): the file naming the application exports a C function - a head calls it in Swift")
        }
    }

    // MARK: - The artwork

    /// Every SVG an application holds opens with its element. Linux ships the
    /// vectors under the names the other platforms rasterize to, and GTK
    /// decides what a file is by sniffing its first hundred or so bytes: a
    /// comment before `<svg` pushes the element out of that window, and the
    /// picture silently does not appear. A comment goes inside the element.
    func testEverySvgSaysWhatItIsInsideTheSniffWindow() throws {
        let window = 100

        for application in try SourceTree.applications() {
            let name = application.lastPathComponent
            let vectors = SourceTree.files(
                under: application, leavingOut: SourceTree.isByproduct)
                .filter { $0.hasSuffix(".svg") }

            XCTAssertFalse(
                vectors.isEmpty, "\(name) holds no SVG - an application without artwork has no icon.")

            for relative in vectors {
                let text = try String(
                    contentsOf: application.appendingPathComponent(relative), encoding: .utf8)

                guard let opening = text.range(of: "<svg") else {
                    XCTFail("\(name)/\(relative) has no <svg element at all.")
                    continue
                }

                let at = text.utf8.distance(from: text.utf8.startIndex, to: opening.lowerBound)
                XCTAssertLessThan(
                    at, window,
                    "\(name)/\(relative) opens its <svg element at byte \(at), past the "
                        + "~\(window) bytes GTK sniffs - the picture does not load on Linux. A "
                        + "comment goes inside the element.")
            }
        }
    }

    /// An application's artwork is one flat namespace, so no two files under
    /// its `Resources/` share a base name. The folders are the author's
    /// convenience: a platform gets `stateui_mark.png` from Images and
    /// `stateui_mark` from the icon side by side in one bundle, and Apple's
    /// build refuses the pair out loud while the vectors Linux copies under a
    /// rasterized name silently overwrite one another.
    ///
    /// The base name, not the whole file name: `mark.svg` and `mark.png` are
    /// one picture to everything downstream, an SVG being asked for as a PNG.
    func testNoTwoResourcesInOneAppShareAName() throws {
        for application in try SourceTree.applications() {
            let name = application.lastPathComponent
            let pictures = SourceTree.files(under: application.appendingPathComponent("Resources"))
                .filter { $0.hasSuffix(".svg") || $0.hasSuffix(".png") }

            XCTAssertFalse(pictures.isEmpty, "\(name) has no artwork under Resources/.")

            var seen: [String: String] = [:]

            for path in pictures {
                let stem = URL(fileURLWithPath: path).deletingPathExtension().lastPathComponent

                if let first = seen[stem] {
                    XCTFail("\(name): Resources/\(first) and Resources/\(path) are two files under "
                        + "one name - a platform sees them flat.")
                }

                seen[stem] = path
            }
        }
    }

    // MARK: - The AppKit head's artwork

    /// An AppKit head finds its artwork where what carries it put it - its bundle's `Resources`, which the stateui
    /// tool lays for every application (AppKitBundleTests), else the `Resources` beside an unbundled program - and
    /// never looks for it itself.
    func testAnAppKitHeadReadsItsArtworkFromWhatCarriesIt() throws {
        let carried = try SourceTree.runtimeSources().first { $0.path.hasSuffix("/CarriedArtwork.swift") }?.text ?? ""
        XCTAssertTrue(carried.contains("bundleResources") && carried.contains(#"appendingPathComponent("Resources", isDirectory: true)"#),
                      "the AppKit host reads its artwork from the bundle, else beside the program")
        let apps = SourceTree.repository.appendingPathComponent("apps")
        for app in try FileManager.default.contentsOfDirectory(atPath: apps.path).sorted() {
            let head = apps.appendingPathComponent("\(app)/Platforms/AppKit/main.swift")
            guard FileManager.default.fileExists(atPath: head.path) else { continue }
            let text = try String(contentsOf: head, encoding: .utf8)
            XCTAssertFalse(text.contains("Bundle.main") || text.contains("#filePath"),
                           "\(app)'s AppKit head finds its artwork itself")
        }
    }

    // MARK: - Helpers

    /// Every path a manifest names, and whether it names a package - a
    /// directory holding a Package.swift - rather than a target's own files.
    /// Comment lines are left out, and so is a path built from the build's
    /// host - `Platforms/\(host)` - whose head NativeProjectTests asks about
    /// host by host.
    private func manifestPaths(in manifest: String) -> [(path: String, isPackage: Bool)] {
        manifest.split(separator: "\n")
            .filter { !$0.drop(while: { $0 == " " }).hasPrefix("//") }
            .flatMap { line -> [(path: String, isPackage: Bool)] in
                let isPackage = line.contains(".package(")
                return String(line).occurrences(between: "path: \"", and: "\"")
                    .filter { !$0.contains("\\(") }
                    .map { (path: $0, isPackage: isPackage) }
            }
    }

    /// A text with every space and line break taken out, so a call wrapped
    /// over several lines reads as the one call it is.
    private func squeezed(_ text: String) -> String {
        text.components(separatedBy: .whitespacesAndNewlines).joined()
    }
}
