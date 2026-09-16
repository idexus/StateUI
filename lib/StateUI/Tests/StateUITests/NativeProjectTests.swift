// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

import Foundation
import XCTest

final class NativeProjectTests: XCTestCase {
    /// Every application is one Swift package shared by one head per host: the
    /// AppKit executable in `Platforms/AppKit` and the MAUI project in
    /// `Platforms/Maui`, both compiling the same `Sources/`.
    func testEveryApplicationSharesItsSourcesBetweenItsHostHeads() throws {
        for name in ["Gallery", "HelloWorld"] {
            let app = Fixtures.repository.appendingPathComponent("apps/\(name)")
            for relative in [
                "Package.swift", "Sources", "Resources", "Platforms/AppKit/main.swift",
                "Platforms/Maui/\(name).csproj", "Platforms/Maui/Host/App.cs",
                "Platforms/Maui/Host/MauiProgram.cs", "Platforms/Maui/Android/MainActivity.cs",
                "Platforms/Maui/iOS/AppDelegate.cs", "Platforms/Maui/MacCatalyst/AppDelegate.cs",
                "Platforms/Maui/Windows/App.xaml.cs", "Platforms/Maui/Linux/Program.cs",
            ] {
                XCTAssertTrue(
                    FileManager.default.fileExists(
                        atPath: app.appendingPathComponent(relative).path),
                    "\(name) is missing \(relative)")
            }

            let manifest = try String(
                contentsOf: app.appendingPathComponent("Package.swift"),
                encoding: .utf8)
            XCTAssertTrue(manifest.contains("name: \"\(name)UI\""))
            XCTAssertTrue(manifest.contains("name: \"\(name)AppKit\""))
            XCTAssertTrue(manifest.contains("name: \"StateUIAppKit\""))

            let entry = try String(
                contentsOf: app.appendingPathComponent("Platforms/AppKit/main.swift"),
                encoding: .utf8)
            XCTAssertTrue(entry.contains("import StateUIAppKit"))
            XCTAssertTrue(entry.contains("StateUIAppKit.run("))

            // The MAUI head compiles the same module: StateUI.targets names it
            // after the project - Gallery becomes GalleryUI - and finds it in
            // the application's Sources/, two directories up.
            let project = try String(
                contentsOf: app.appendingPathComponent("Platforms/Maui/\(name).csproj"),
                encoding: .utf8)
            XCTAssertTrue(project.contains(
                "<Import Project=\"../../../../.scripts/Maui/StateUI.targets\" />"))
            XCTAssertTrue(project.contains(
                "../../../../lib/StateUI.Maui/Sources/StateUI.Maui.csproj"))
            XCTAssertTrue(project.contains("<AndroidProjectFolder>Android/</AndroidProjectFolder>"))

            let registration = try String(
                contentsOf: app.appendingPathComponent("Sources/\(name)App.swift"),
                encoding: .utf8)
            XCTAssertTrue(
                registration.contains("@_cdecl(\"stateui_app_register\")"),
                "\(name)'s module does not register the application for the MAUI head")
        }
    }

    /// The MAUI host is a host package beside AppKit's: its runtime, its Linux
    /// platform, its tests and its template, named by one solution, and built
    /// by the scripts under `.scripts/Maui`.
    func testTheMauiHostIsAHostPackageBesideAppKit() throws {
        let repository = Fixtures.repository
        for relative in [
            "lib/StateUI.AppKit/Package.swift",
            "lib/StateUI.Maui/Sources/StateUI.Maui.csproj",
            "lib/StateUI.Maui/Linux/StateUI.Maui.Linux.csproj",
            "lib/StateUI.Maui/Tests/StateUI.Maui.Tests.csproj",
            "lib/StateUI.Maui/Template/StateUI.Maui.Template.csproj",
            ".scripts/Maui/StateUI.targets",
            ".scripts/Maui/build-apple.sh",
            ".scripts/Maui/build-android.sh",
            ".scripts/Maui/build-linux.sh",
            ".scripts/Maui/build-windows.ps1",
            ".scripts/AppKit/build-gallery-appkit.sh",
        ] {
            XCTAssertTrue(
                FileManager.default.fileExists(
                    atPath: repository.appendingPathComponent(relative).path),
                "missing \(relative)")
        }

        let solution = try String(
            contentsOf: repository.appendingPathComponent("StateUI.slnx"), encoding: .utf8)
        let projects = solution.components(separatedBy: "<Project Path=\"").dropFirst()
            .compactMap { $0.components(separatedBy: "\"").first }

        XCTAssertEqual(Set(projects), [
            "apps/Gallery/Platforms/Maui/Gallery.csproj",
            "apps/HelloWorld/Platforms/Maui/HelloWorld.csproj",
            "lib/StateUI.Maui/Sources/StateUI.Maui.csproj",
            "lib/StateUI.Maui/Linux/StateUI.Maui.Linux.csproj",
            "lib/StateUI.Maui/Tests/StateUI.Maui.Tests.csproj",
            "lib/StateUI.Maui/Template/StateUI.Maui.Template.csproj",
        ])
    }

    /// The code every host runs names no host. Swift written for one host alone
    /// stands under the condition named for it - `#if MAUI`, which every MAUI
    /// build defines, and `#if APPKIT`, which every AppKit build of an
    /// application defines; see the two tests below - and such a block, up to
    /// its `#else` or `#endif`, is the one place the library and each
    /// application's `Sources/` may name that host.
    ///
    /// The words are assembled here so this guard does not find itself.
    func testTheSharedSourcesNameAHostOnlyUnderItsCondition() throws {
        let repository = Fixtures.repository
        var roots = [repository.appendingPathComponent("lib/StateUI/Sources")]
        let apps = try FileManager.default.contentsOfDirectory(
            at: repository.appendingPathComponent("apps"), includingPropertiesForKeys: nil)
        roots += apps.map { $0.appendingPathComponent("Sources") }

        var offenders: [String] = []
        for word in ["ma" + "ui", "app" + "kit"] {
            let condition = "#if " + word.uppercased()
            for root in roots {
                guard let walk = FileManager.default.enumerator(at: root, includingPropertiesForKeys: nil)
                else { continue }

                for case let file as URL in walk where file.pathExtension == "swift" {
                    let text = try String(contentsOf: file, encoding: .utf8)
                    // Zero outside the condition's block, one directly inside
                    // it, more inside a block nested in it.
                    var depth = 0
                    for (number, line) in text.split(separator: "\n", omittingEmptySubsequences: false)
                        .enumerated() {
                        let directive = line.trimmingCharacters(in: .whitespaces)
                        if depth > 0 {
                            if directive.hasPrefix("#if") {
                                depth += 1
                            } else if directive.hasPrefix("#endif") {
                                depth -= 1
                            } else if depth == 1 && directive.hasPrefix("#else") {
                                // What follows is compiled for every other host.
                                depth = 0
                            }
                            continue
                        }

                        if directive == condition {
                            depth = 1
                        } else if line.lowercased().contains(word) {
                            let relative = String(file.path.dropFirst(repository.path.count + 1))
                            offenders.append("\(relative):\(number + 1)")
                        }
                    }
                }
            }
        }

        XCTAssertEqual(offenders, [], "these name a host in code every host runs")
    }

    /// Every Swift module the MAUI host compiles is compiled with the MAUI
    /// condition - the library and the application alike, on every platform -
    /// so no block under `#if MAUI` is left out of one of its builds.
    func testEveryMauiSwiftBuildDefinesTheMauiCondition() throws {
        let scripts = Fixtures.repository.appendingPathComponent(".scripts/Maui")

        // Each command of a script on one line: a shell line continued with a
        // backslash, and a PowerShell one with a backtick, joined back up.
        func commands(_ name: String) throws -> [String] {
            try String(contentsOf: scripts.appendingPathComponent(name), encoding: .utf8)
                .replacingOccurrences(of: "\\\n", with: " ")
                .replacingOccurrences(of: "`\n", with: " ")
                .components(separatedBy: "\n")
        }

        // SwiftPM compiles the library and the application in one build.
        for name in ["build-android.sh", "build-linux.sh"] {
            let builds = try commands(name).filter { $0.contains("\"$SWIFT_BIN\" build") }
            XCTAssertFalse(builds.isEmpty, "\(name) runs no swift build")
            for build in builds {
                XCTAssertTrue(build.contains("-Xswiftc -DMAUI"), "\(name) builds without MAUI: \(build)")
            }
        }

        // swiftc compiles each module with one set of arguments.
        let apple = try String(
            contentsOf: scripts.appendingPathComponent("build-apple.sh"), encoding: .utf8)
        let compileArgs = apple.components(separatedBy: "COMPILE_ARGS=(").dropFirst().first?
            .components(separatedBy: "\n)").first ?? ""
        XCTAssertTrue(compileArgs.contains("-D MAUI"), "build-apple.sh compiles without MAUI")
        XCTAssertTrue(apple.contains("swiftc \"${COMPILE_ARGS[@]}\""))

        let windows = try commands("build-windows.ps1")
            .filter { $0.contains("& swiftc") && $0.contains(" -c ") }
        XCTAssertEqual(windows.count, 1, "build-windows.ps1 has one compile step")
        XCTAssertTrue(windows.allSatisfy { $0.contains("-D MAUI") }, "build-windows.ps1 compiles without MAUI")
    }

    /// Every application DEFINES THE APPKIT CONDITION IN ITS MANIFEST, for
    /// every module it compiles, exactly when a build says it is an AppKit one.
    ///
    /// One variable says both things - that the build has an AppKit head, and
    /// that code under `#if APPKIT` compiles - so a build and an editor that
    /// set it agree, and the editor completes that code like any other. The
    /// flag it replaced, `-Xswiftc -DAPPKIT`, is refused wherever a build is
    /// written down: a second spelling of the same switch is how the two
    /// drift apart.
    func testEveryApplicationDefinesTheAppKitConditionInItsManifest() throws {
        let repository = Fixtures.repository
        let template = "lib/StateUI.Maui/Template/templates/StateUIStarter"
        func text(_ relative: String) throws -> String {
            try String(contentsOf: repository.appendingPathComponent(relative), encoding: .utf8)
        }

        for relative in ["apps/Gallery/Package.swift", "apps/HelloWorld/Package.swift", "\(template)/Package.swift"] {
            let manifest = try text(relative)

            XCTAssertTrue(
                manifest.contains("hasAppKitHead ? [.define(\"APPKIT\")] : []"),
                "\(relative) does not define APPKIT for an AppKit build")

            // No module is left compiling without it.
            let settings = manifest.components(separatedBy: "swiftSettings:").dropFirst()
            XCTAssertFalse(settings.isEmpty, "\(relative) declares no target")
            for setting in settings {
                XCTAssertTrue(
                    setting.trimmingCharacters(in: .whitespaces).hasPrefix("settings"),
                    "\(relative) compiles a module with settings of its own")
            }
        }

        for relative in [
            ".scripts/AppKit/build-gallery-appkit.sh", ".scripts/new-app.sh", ".scripts/test-native.sh",
            "\(template)/README.md", "docs/development.md", "docs/getting-started.md",
        ] {
            let commands = try text(relative)
                .replacingOccurrences(of: "\\\n", with: " ")
                .components(separatedBy: "\n")
                .map { $0.trimmingCharacters(in: .whitespaces) }
                .filter { Self.runsSwift($0) }

            for command in commands {
                XCTAssertFalse(
                    command.contains("-DAPPKIT"),
                    "\(relative) still gives -DAPPKIT, which the manifest now defines: \(command)")
            }
        }

        for relative in [".vscode/tasks.json", "\(template)/.vscode/tasks.json"] {
            XCTAssertFalse(
                try text(relative).contains("\"-DAPPKIT\""),
                "\(relative) still gives -DAPPKIT, which the manifest now defines")
        }
    }

    /// Whether a line RUNS SwiftPM, read past any variables it sets first.
    ///
    /// An AppKit head needs one set - see the test below - and a command that
    /// sets it inline is still that command, so the name is looked for after
    /// each leading `NAME=value`. Without this, prefixing a command would drop
    /// it out of the list above and the guard would stop asking anything of it.
    private static func runsSwift(_ line: String) -> Bool {
        var rest = line

        while let space = rest.firstIndex(of: " ") {
            let first = String(rest[rest.startIndex..<space])

            guard first.contains("="), !first.contains("/"), !first.contains("\"") else { break }

            rest = String(rest[rest.index(after: space)...]).trimmingCharacters(in: .whitespaces)
        }

        return rest.hasPrefix("swift build") || rest.hasPrefix("swift run")
            || rest.contains("$(swift build")
    }

    /// Every build of an application's AppKit head TELLS ITS MANIFEST there is
    /// one.
    ///
    /// An application declares that target, the product it makes and the
    /// StateUIAppKit dependency only when `STATEUI_APPKIT` is set, so that
    /// `swift test` compiles no part of one host's half. A build that leaves
    /// the variable out asks for a product the manifest never declared, and a
    /// page that leaves it out hands a reader a command that cannot work.
    ///
    /// Asked of the FILE rather than of each command, because a script may
    /// export it once above the builds it runs.
    func testEveryAppKitBuildTellsTheManifestItHasAnAppKitHead() throws {
        let repository = Fixtures.repository
        let template = "lib/StateUI.Maui/Template/templates/StateUIStarter"
        func text(_ relative: String) throws -> String {
            try String(contentsOf: repository.appendingPathComponent(relative), encoding: .utf8)
        }

        for relative in [
            ".scripts/AppKit/build-gallery-appkit.sh", ".scripts/new-app.sh", ".scripts/test-native.sh",
            "\(template)/README.md", "docs/development.md", "docs/getting-started.md",
        ] {
            XCTAssertTrue(
                try text(relative).contains("STATEUI_APPKIT=1"),
                "\(relative) builds an AppKit head without telling the manifest there is one")
        }

        // A task sets it in the environment it runs the build in.
        for relative in [".vscode/tasks.json", "\(template)/.vscode/tasks.json"] {
            let tasks = try text(relative).components(separatedBy: "\"label\"").filter { task in
                let lines = task.components(separatedBy: "\n").map { $0.trimmingCharacters(in: .whitespaces) }
                guard let product = lines.firstIndex(of: "\"--product\","), product + 1 < lines.count
                else { return false }
                return lines[product + 1].hasSuffix("AppKit\"")
            }

            XCTAssertFalse(tasks.isEmpty, "\(relative) builds no AppKit head")

            for task in tasks {
                XCTAssertTrue(
                    task.contains("\"STATEUI_APPKIT\": \"1\""),
                    "\(relative) builds an AppKit head without telling the manifest there is one")
            }
        }
    }

    func testGalleryOwnsItsAcceptanceTests() {
        let repository = Fixtures.repository

        XCTAssertTrue(FileManager.default.fileExists(
            atPath: repository.appendingPathComponent("apps/Gallery/Tests/GalleryTests").path))
        XCTAssertFalse(FileManager.default.fileExists(
            atPath: repository.appendingPathComponent("lib/Tests").path))
    }
}
