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
    /// platform and its tests, named by one solution, and built by the scripts
    /// under `.scripts/Maui`.
    func testTheMauiHostIsAHostPackageBesideAppKit() throws {
        let repository = Fixtures.repository
        for relative in [
            "lib/StateUI.AppKit/Package.swift",
            "lib/StateUI.Maui/Sources/StateUI.Maui.csproj",
            "lib/StateUI.Maui/Linux/StateUI.Maui.Linux.csproj",
            "lib/StateUI.Maui/Tests/StateUI.Maui.Tests.csproj",
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
        ])
    }

    /// The Android Views host is a Swift package beside AppKit's, with its Java
    /// layer, its tests in a package of their own and the scripts under
    /// `.scripts/Android`; and every native method the Java layer declares is
    /// one the host registers, by name - one left out is found only on a
    /// device, as an `UnsatisfiedLinkError`.
    func testTheAndroidViewsHostIsAHostPackageBesideAppKit() throws {
        let repository = Fixtures.repository
        let host = "lib/StateUI.Android"
        for relative in [
            "\(host)/Package.swift", "\(host)/Tests/Package.swift",
            "\(host)/Tests/Platforms/Android/build.gradle.kts",
            "\(host)/Java/stateui/android/StateUIActivity.java",
            ".scripts/Android/build-swift.sh", ".scripts/Android/run-app.sh",
            ".scripts/Android/test-android.sh", ".scripts/Android/devices.sh",
        ] {
            XCTAssertTrue(
                FileManager.default.fileExists(atPath: repository.appendingPathComponent(relative).path),
                "missing \(relative)")
        }

        func names(_ pattern: String, in relative: String) throws -> Set<String> {
            let text = try String(contentsOf: repository.appendingPathComponent(relative), encoding: .utf8)
            let expression = try NSRegularExpression(pattern: pattern)
            return Set(expression.matches(in: text, range: NSRange(text.startIndex..., in: text)).compactMap {
                Range($0.range(at: 1), in: text).map { String(text[$0]) }
            })
        }

        let declared = try names(#"static native \w+ (\w+)\("#, in: "\(host)/Java/stateui/android/StateUIHost.java")
        let registered = try names(
            #"\("(\w+)", "\("#, in: "\(host)/Sources/StateUIAndroid/Runtime/StateUIAndroid.swift")
        XCTAssertGreaterThan(declared.count, 3, "the walk read almost no native method")
        XCTAssertEqual(declared, registered, "the Java layer and the host disagree on the native methods")
    }

    /// Every ANDROID HEAD is a library Android loads, declared by the
    /// application's manifest exactly when a build says it is an Android one:
    /// its Gradle build, an Android manifest naming the host's activity and the
    /// head's library, and a `JNI_OnLoad` that names the application to the host.
    func testEveryAndroidHeadLoadsTheApplicationsModule() throws {
        var heads = 0

        for application in try Fixtures.applications() {
            let head = application.appendingPathComponent("Platforms/Android")
            guard FileManager.default.fileExists(atPath: head.path) else { continue }
            heads += 1
            let name = application.lastPathComponent
            func text(_ relative: String) throws -> String {
                try String(contentsOf: application.appendingPathComponent(relative), encoding: .utf8)
            }

            let manifest = try text("Package.swift")
            for shape in [
                "environment[\"STATEUI_ANDROID\"] == \"1\"", "hasAndroidHead ? [.define(\"ANDROID\")] : []",
                "name: \"\(name)Android\"", "name: \"StateUIAndroid\"", "path: \"Platforms/Android/Swift\"",
            ] {
                XCTAssertTrue(manifest.contains(shape), "\(name)'s Package.swift does not say \(shape)")
            }

            let android = try text("Platforms/Android/AndroidManifest.xml")
            XCTAssertTrue(android.contains("android:name=\"stateui.android.StateUIActivity\""))
            XCTAssertTrue(android.contains("android:value=\"\(name)Android\""))

            let entry = try text("Platforms/Android/Swift/\(name)Android.swift")
            for shape in ["@_cdecl(\"JNI_OnLoad\")", "stateui_app_register()", "StateUIAndroid.load("] {
                XCTAssertTrue(entry.contains(shape), "\(name)'s Android head does not say \(shape)")
            }

            XCTAssertTrue(try text("Platforms/Android/build.gradle.kts").contains("stated(\"stateui.libraries\")"))
        }

        XCTAssertGreaterThan(heads, 0, "no Android head found")
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
        func text(_ relative: String) throws -> String {
            try String(contentsOf: repository.appendingPathComponent(relative), encoding: .utf8)
        }

        for relative in ["apps/Gallery/Package.swift", "apps/HelloWorld/Package.swift"] {
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
            "docs/development.md", "docs/getting-started.md",
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

        XCTAssertFalse(
            try text(".vscode/tasks.json").contains("\"-DAPPKIT\""),
            ".vscode/tasks.json still gives -DAPPKIT, which the manifest now defines")
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
        func text(_ relative: String) throws -> String {
            try String(contentsOf: repository.appendingPathComponent(relative), encoding: .utf8)
        }

        for relative in [
            ".scripts/AppKit/build-gallery-appkit.sh", ".scripts/new-app.sh", ".scripts/test-native.sh",
            "docs/development.md", "docs/getting-started.md",
        ] {
            XCTAssertTrue(
                try text(relative).contains("STATEUI_APPKIT=1"),
                "\(relative) builds an AppKit head without telling the manifest there is one")
        }

        // A task sets it in the environment it runs the build in.
        let tasks = try text(".vscode/tasks.json").components(separatedBy: "\"label\"").filter { task in
            let lines = task.components(separatedBy: "\n").map { $0.trimmingCharacters(in: .whitespaces) }
            guard let product = lines.firstIndex(of: "\"--product\","), product + 1 < lines.count
            else { return false }
            return lines[product + 1].hasSuffix("AppKit\"")
        }

        XCTAssertFalse(tasks.isEmpty, ".vscode/tasks.json builds no AppKit head")

        for task in tasks {
            XCTAssertTrue(
                task.contains("\"STATEUI_APPKIT\": \"1\""),
                ".vscode/tasks.json builds an AppKit head without telling the manifest there is one")
        }
    }

    /// Every Android head shows the application's icon: the launcher's adaptive icon, drawn from
    /// `Resources/AppIcon` - the ground and the mark - as the head is built, and named in its manifest.
    func testEveryAndroidHeadShowsTheApplicationsIcon() throws {
        var heads = 0

        for application in try Fixtures.applications() {
            let head = application.appendingPathComponent("Platforms/Android")
            guard FileManager.default.fileExists(atPath: head.path) else { continue }
            heads += 1
            let name = application.lastPathComponent

            let manifest = try String(contentsOf: head.appendingPathComponent("AndroidManifest.xml"), encoding: .utf8)
            for shape in ["android:icon=\"@mipmap/appicon\"", "android:roundIcon=\"@mipmap/appicon\""] {
                XCTAssertTrue(manifest.contains(shape), "\(name)'s Android manifest does not say \(shape)")
            }
            let gradle = try String(contentsOf: head.appendingPathComponent("build.gradle.kts"), encoding: .utf8)
            XCTAssertTrue(gradle.contains("res.srcDir(stated(\"stateui.res\"))"), "\(name)'s head takes no drawn icon")
            for artwork in ["appicon_bkg.svg", "appicon_mark.svg"] {
                XCTAssertTrue(
                    FileManager.default.fileExists(
                        atPath: application.appendingPathComponent("Resources/AppIcon/\(artwork)").path),
                    "\(name) has no Resources/AppIcon/\(artwork) to draw its Android icon from")
            }
        }

        XCTAssertGreaterThan(heads, 0, "no Android head found")
        let tools = try String(
            contentsOf: Fixtures.repository.appendingPathComponent(".scripts/Android/tools.sh"), encoding: .utf8)
        XCTAssertTrue(
            tools.contains("draw-app-icon") && tools.contains("-Pstateui.res="),
            "an Android head is built without its icon being drawn")
    }

    /// Every application's AppKit head hands the host its icon on macOS's icon
    /// grid, found from its own source file rather than from the directory it
    /// was started in.
    ///
    /// A macOS icon is a 1024 canvas whose body is an 824-point rounded square
    /// 100 points in: artwork drawn edge to edge stands larger in the Dock than
    /// every icon beside it. And a head started by a debugger, a task or a
    /// terminal elsewhere would find no artwork at all, and show the bare
    /// executable's icon.
    func testEveryAppKitHeadShowsAnIconOnTheMacGridWhereverItIsStarted() throws {
        let applications = try Fixtures.applications()
        let icon = "Resources/AppIcon/appicon_macos.svg"
        var heads = 0

        for application in applications {
            let head = application.appendingPathComponent("Platforms/AppKit/main.swift")
            guard FileManager.default.fileExists(atPath: head.path) else { continue }
            heads += 1

            let relative = application.path.replacingOccurrences(of: Fixtures.repository.path + "/", with: "")
            let text = try String(contentsOf: head, encoding: .utf8)

            XCTAssertTrue(
                text.contains("applicationIcon:") && text.contains("appicon_macos.svg"),
                "\(relative)'s AppKit head does not hand the host \(icon)")
            XCTAssertFalse(
                text.contains("currentDirectoryPath"),
                "\(relative)'s AppKit head finds its artwork from the directory it was started in")

            let artwork = try String(contentsOf: application.appendingPathComponent(icon), encoding: .utf8)
            XCTAssertTrue(
                artwork.contains("viewBox=\"0 0 1024 1024\"")
                    && artwork.contains("x=\"100\" y=\"100\" width=\"824\" height=\"824\""),
                "\(relative)/\(icon) is not on macOS's icon grid: an 824 body, 100 in, on a 1024 canvas")
        }

        XCTAssertGreaterThan(heads, 1, "no AppKit head found")
        XCTAssertTrue(
            try String(
                contentsOf: Fixtures.repository.appendingPathComponent(".scripts/AppKit/build-gallery-appkit.sh"),
                encoding: .utf8
            ).contains("Resources/AppIcon/appicon_macos.svg"),
            "the Gallery's bundle makes its .icns from artwork off macOS's icon grid")
    }

    func testGalleryOwnsItsAcceptanceTests() {
        let repository = Fixtures.repository

        XCTAssertTrue(FileManager.default.fileExists(
            atPath: repository.appendingPathComponent("apps/Gallery/Tests/GalleryTests").path))
        XCTAssertFalse(FileManager.default.fileExists(
            atPath: repository.appendingPathComponent("lib/Tests").path))
    }
}
