// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

// The apps/ directory and the scaffolder that fills it.
//
// An application lives under apps/<Name>/ and states every connection to the
// repository as a relative path - to the runtime project, to the build targets,
// to the library's Swift package. A path that no longer resolves fails LATE and
// platform by platform: NuGet cannot restore, or SwiftPM cannot resolve, or the
// build imports nothing - each with a message about the symptom rather than the
// move that caused it. These tests read the paths out of the files and resolve
// them here, so a moved directory names the file that still points at the old
// place.
//
// The scaffolder (.scripts/new-app.sh, .scripts/new-app.ps1 and the "New app" task
// in .vscode/tasks.json) is covered the same way everything else here is: run
// it for real, into a temporary directory, and read what it made. Only the bash
// half can run where these tests run; the PowerShell half is held to agreement
// on the pieces both must name.

import Foundation
import XCTest
@testable import StateUI

final class AppsTests: XCTestCase {
    private var apps: URL { Fixtures.repository.appendingPathComponent("apps") }

    // MARK: - The layout

    /// Every application under apps/ is wired to the repository: its project
    /// file is named after its directory, every relative path it states
    /// resolves, its Swift manifest names the module MSBuild will derive
    /// (NameUI), the library dependency points at a real package, and the one
    /// export the host calls by name is there.
    ///
    /// This is what makes the scaffolder's output covered for free: a new app
    /// is checked the moment it exists, with nothing to remember.
    func testEveryAppUnderAppsIsWiredToTheRepo() throws {
        let names = try appNames()
        XCTAssertFalse(names.isEmpty, "apps/ has no applications - the gallery should be there.")

        for name in names {
            let app = apps.appendingPathComponent(name)

            // The Finder trap: a directory named Something.App reads as a
            // bundle on macOS, so no dots anywhere in a project name.
            XCTAssertFalse(name.contains("."), "\(name): an app project name must not contain a dot.")

            let csproj = app.appendingPathComponent("\(name).csproj")
            XCTAssertTrue(
                FileManager.default.fileExists(atPath: csproj.path),
                "\(name): no \(name).csproj - the project file is named after its directory.")

            let project = try String(contentsOf: csproj, encoding: .utf8)

            // Forward slashes, always: MSBuild accepts them on Windows, while a
            // backslash on macOS is an ordinary character in a file name.
            XCTAssertFalse(project.contains("..\\"), "\(name).csproj: backslashes in a relative path break macOS.")

            // The title is the project's name, so the bundle, the process and
            // the project are one word. A title of `StateUI` on the gallery
            // builds a StateUI.app around a Gallery executable,
            // which reads as if the LIBRARY were the application - and makes
            // AppInfo.Name answer the bundle on Apple and the assembly on
            // Windows, two different names for one app. The scaffolders set
            // this correctly; nothing until now read it back afterwards.
            XCTAssertTrue(
                project.contains("<ApplicationTitle>\(name)</ApplicationTitle>"),
                "\(name).csproj: ApplicationTitle must be \(name), the project's own name.")

            // Every relative path the project states, resolved from its own
            // directory: the runtime reference, the targets import, the assets.
            for relative in attributeValues(in: project) where relative.hasPrefix("../") {
                let target = URL(fileURLWithPath: relative, relativeTo: app).standardizedFileURL
                XCTAssertTrue(
                    FileManager.default.fileExists(atPath: target.path),
                    "\(name).csproj points at \(relative), and \(target.path) does not exist.")
            }

            // The Swift package: present, naming the module MSBuild derives
            // from the project name, and depending on a package that is there.
            // Beside the project file, not inside Swift/: SwiftPM writes
            // .build/ and Package.resolved next to the manifest, and those
            // belong where bin/ and obj/ are rather than among the sources.
            let manifest = app.appendingPathComponent("Package.swift")
            XCTAssertTrue(
                FileManager.default.fileExists(atPath: manifest.path),
                "\(name): no Package.swift beside the project - SourceKit and the Android build both need one.")

            let manifestText = try String(contentsOf: manifest, encoding: .utf8)
            XCTAssertTrue(
                manifestText.contains("\"\(name)UI\""),
                "\(name): Package.swift does not name \(name)UI, the module MSBuild expects.")

            // The TARGET, not merely the name somewhere in the file. A copied
            // app whose package and product were renamed and whose target was
            // not builds perfectly on Apple - build-apple.sh globs the sources
            // and never reads the manifest - and fails only through SwiftPM,
            // which is Android and the editor: "target 'XUI' referenced in
            // product 'XUI' could not be found". Measured on a real one.
            XCTAssertTrue(
                manifestText.contains(".target(\n            name: \"\(name)UI\"")
                    || manifestText.contains(".target(name: \"\(name)UI\""),
                "\(name): Package.swift declares no target called \(name)UI - SwiftPM refuses the package.")

            for path in values(of: ".package(path: \"", in: manifestText) {
                let package = URL(fileURLWithPath: path, relativeTo: app)
                    .standardizedFileURL
                    .appendingPathComponent("Package.swift")
                XCTAssertTrue(
                    FileManager.default.fileExists(atPath: package.path),
                    "\(name): the manifest depends on \(path), and \(package.path) does not exist.")
            }

            // The one line an app cannot lose: nothing in its module runs until
            // the host calls this export by name. Swift/ whole, because that is
            // what the manifest compiles - path: "Swift" - so the file
            // declaring it may sit anywhere under it.
            let sources = try swiftSources(under: app.appendingPathComponent("Swift"))
            XCTAssertTrue(
                sources.contains { $0.contains("@_cdecl(\"stateui_app_register\")") },
                "\(name): nothing under Swift/ declares stateui_app_register - the app can never start.")

            // The C# side lives in Host/, which is what keeps the project root
            // to the project file and the folders every app has.
            for file in ["Host/App.cs", "Host/MauiProgram.cs"] {
                XCTAssertTrue(
                    FileManager.default.fileExists(atPath: app.appendingPathComponent(file).path),
                    "\(name): no \(file) - the C# side of an app lives in Host/.")
            }
        }
    }

    /// THE LIBRARY ARMS EVERY GAP, not the application. Each
    /// `src/StateUI.Runtime.Linux/Linux*.cs` answers one hole in the GTK4
    /// backend, and a forgotten Install fails at runtime on that platform
    /// alone - a tap heard by no one, a label wearing one property, an app
    /// dead at its first battery reading, a navigation that corrupts the heap.
    /// They are installed from one place, which is what an application's
    /// single `UseStateUIApp` call reaches.
    func testTheLinuxPlatformArmsEveryGap() throws {
        let platform = Fixtures.repository.appendingPathComponent("src/StateUI.Runtime.Linux")
        let host = try String(
            contentsOf: platform.appendingPathComponent("LinuxHost.cs"), encoding: .utf8)

        let gaps = try FileManager.default
            .contentsOfDirectory(at: platform, includingPropertiesForKeys: nil)
            .map(\.lastPathComponent)
            .filter { $0.hasPrefix("Linux") && $0.hasSuffix(".cs") && $0 != "LinuxHost.cs" }
            .map { String($0.dropLast(3)) }
            .sorted()

        XCTAssertFalse(gaps.isEmpty, "a Linux platform with no Linux*.cs answers nothing.")

        for gap in gaps {
            XCTAssertTrue(
                host.contains("\(gap).Install("),
                "\(gap) is never installed from LinuxHost - its gap is open on Linux.")
        }
    }

    /// An application's Linux head is TWO THINGS and nothing else: the one
    /// hosting call, and an entry point that is the library's own application.
    /// Anything more was a file every app had to copy - and the synchronization
    /// context the entry point needs is `StateUIApplication.Start`'s, without
    /// which an await continuation resumes on the thread pool and whatever it
    /// calls next enters GTK off the thread that owns it.
    func testTheLinuxHeadIsHostingAndAnEntryPoint() throws {
        for name in try appNames() {
            let app = apps.appendingPathComponent(name)
            let linux = app.appendingPathComponent("Platforms/Linux")
            guard FileManager.default.fileExists(atPath: linux.path) else { continue }

            let host = try String(
                contentsOf: app.appendingPathComponent("Host/MauiProgram.cs"), encoding: .utf8)
            XCTAssertTrue(
                host.contains("UseStateUIApp<App>()"),
                "\(name): MauiProgram never says UseStateUIApp - on Linux that is the whole "
                    + "platform, and on every other head it is UseMauiApp.")

            let entry = try String(
                contentsOf: linux.appendingPathComponent("Program.cs"), encoding: .utf8)
            XCTAssertTrue(
                entry.contains(": StateUIApplication") && entry.contains("Start<Program>(args)"),
                "\(name): the Linux entry point is not the library's application - the GTK loop "
                    + "then runs with no synchronization context under it.")

            let strays = try FileManager.default
                .contentsOfDirectory(at: linux, includingPropertiesForKeys: nil)
                .map(\.lastPathComponent)
                .filter { $0 != "Program.cs" }
                .sorted()
            XCTAssertTrue(
                strays.isEmpty,
                "\(name): Platforms/Linux holds \(strays.joined(separator: ", ")) - what answers "
                    + "this platform belongs to StateUI.Linux, where every app gets it.")
        }
    }

    /// EVERY SVG OPENS WITH ITS ELEMENT. Linux ships the vectors under the
    /// names the other platforms rasterize to, and GTK decides what a file is
    /// by SNIFFING its first bytes - about a hundred of them. A documentation
    /// comment before `<svg` pushes the element out of that window, and the
    /// picture then silently does not appear: measured on the starter app,
    /// whose image was a one-unit sliver with nothing to say why.
    func testEverySvgSaysWhatItIsInsideTheSniffWindow() throws {
        let window = 100

        for root in ["apps", "src/StateUI.Template/templates"] {
            let base = Fixtures.repository.appendingPathComponent(root)

            guard let walk = FileManager.default.enumerator(atPath: base.path) else { continue }

            for case let name as String in walk {
                let path = name.replacingOccurrences(of: "\\", with: "/")

                guard path.hasSuffix(".svg") else { continue }
                guard !path.contains("/bin/"), !path.contains("/obj/"),
                      !path.contains("/.build/") else { continue }

                let text = try String(
                    contentsOf: base.appendingPathComponent(name), encoding: .utf8)

                guard let opening = text.range(of: "<svg") else {
                    XCTFail("\(root)/\(path) has no <svg element at all.")
                    continue
                }

                let at = text.distance(from: text.startIndex, to: opening.lowerBound)
                XCTAssertLessThan(
                    at, window,
                    "\(root)/\(path) opens its <svg element at byte \(at), past the ~\(window) "
                        + "bytes GTK sniffs - the picture will not load on Linux. A comment goes "
                        + "INSIDE the element.")
            }
        }
    }

    /// AN APPLICATION'S ARTWORK IS ONE FLAT NAMESPACE, so no two files under
    /// its `Resources/` may share a base name. The folders are the author's
    /// convenience: what a platform gets is `stateui_mark.png` from Images and
    /// `stateui_mark` from the icon, side by side in one bundle, and Apple's
    /// build refuses the pair out loud while the vectors this platform copies
    /// under a rasterized name would silently overwrite one another.
    ///
    /// The base name, not the whole file name: `mark.svg` and `mark.png` are
    /// the same picture to everything downstream, an SVG being asked for as
    /// a PNG.
    func testNoTwoResourcesInOneAppShareAName() throws {
        var projects = try appNames().map { apps.appendingPathComponent($0) }
        projects.append(
            Fixtures.repository.appendingPathComponent(
                "src/StateUI.Template/templates/StateUIStarter"))

        for project in projects {
            let resources = project.appendingPathComponent("Resources")

            guard let walk = FileManager.default.enumerator(atPath: resources.path) else { continue }

            var seen: [String: String] = [:]

            for case let name as String in walk {
                let path = name.replacingOccurrences(of: "\\", with: "/")

                guard path.hasSuffix(".svg") || path.hasSuffix(".png") else { continue }

                let base = (path as NSString).lastPathComponent
                let stem = (base as NSString).deletingPathExtension

                if let first = seen[stem] {
                    XCTFail(
                        "\(project.lastPathComponent): Resources/\(first) and Resources/\(path) "
                            + "are two files under one name - a platform sees them flat.")
                }

                seen[stem] = path
            }
        }
    }

    /// THE ICON'S NAME IS THE SAME IN FOUR PLACES. Resizetizer names what it
    /// builds after the MauiIcon's own file, and the platform heads then name
    /// that: an asset catalog entry in both Apple plists and a mipmap in the
    /// Android manifest. Rename the file and miss one and the app builds with
    /// no icon, or does not build at all - and only on the platform that was
    /// missed.
    func testTheAppIconIsCalledTheSameEverywhere() throws {
        var projects = try appNames().map { apps.appendingPathComponent($0) }
        projects.append(
            Fixtures.repository.appendingPathComponent(
                "src/StateUI.Template/templates/StateUIStarter"))

        for project in projects {
            let name = project.lastPathComponent
            let csproj = project.appendingPathComponent("\(name).csproj")

            guard let project0 = try? String(contentsOf: csproj, encoding: .utf8),
                  let declared = values(of: "<MauiIcon Include=\"", in: project0).first
            else { continue }

            let icon = ((declared as NSString).lastPathComponent as NSString).deletingPathExtension

            for (head, spelling) in [
                ("Platforms/iOS/Info.plist", "Assets.xcassets/\(icon).appiconset"),
                ("Platforms/MacCatalyst/Info.plist", "Assets.xcassets/\(icon).appiconset"),
                ("Platforms/Android/AndroidManifest.xml", "@mipmap/\(icon)"),
            ] {
                let file = project.appendingPathComponent(head)

                guard let text = try? String(contentsOf: file, encoding: .utf8) else { continue }

                XCTAssertTrue(
                    text.contains(spelling),
                    "\(name)/\(head) does not say \(spelling) - the icon is called \(icon) "
                        + "in the project file, and this head names another.")
            }
        }
    }

    // MARK: - The scaffolder

    /// The scaffolder's Swift IS `apps/HelloWorld`'s, with the name
    /// substituted - every file, checked character for character.
    ///
    /// One shape for what an application looks like, in one place, so the two
    /// cannot drift. They did, twice over and unnoticed for ten days:
    /// `Window` became a PROTOCOL and HelloWorld moved to
    /// `struct MainWindow: Window` while the template went on writing
    /// `Window(MainPage())`, constructing a protocol; and `Style` lost its
    /// builder-closure form while the template went on writing
    /// `Style<Label> { $0 … }`. Either one alone means every app either
    /// scaffolder produces cannot compile, on any platform.
    ///
    /// Comparing against HelloWorld rather than restating the expected text is
    /// the point: HelloWorld is an app the suites already check and a person
    /// already builds, so an API it can no longer express fails HERE on the day
    /// the library changes - and this test needs to know nothing about windows
    /// or styles to say so.
    func testTheScaffoldersSwiftIsHelloWorldsWithTheNameChanged() throws {
        // Template -> the file it is a template OF. HelloWorld's own Swift/ is
        // the whole of an application's skeleton, so this is the complete set;
        // a file added to one and not the other fails the count below.
        let pairs = [
            ("App.swift.template", "HelloWorldApp.swift"),
            ("AppStyles.swift.template", "Styles/AppStyles.swift"),
            ("MainPage.swift.template", "MainPage.swift"),
        ]

        let templates = Fixtures.repository.appendingPathComponent(".scripts/new-app-template")
        let helloWorld = Fixtures.repository.appendingPathComponent("apps/HelloWorld/Swift")

        for (template, source) in pairs {
            let written = try String(
                contentsOf: templates.appendingPathComponent(template), encoding: .utf8)
            let real = try String(
                contentsOf: helloWorld.appendingPathComponent(source), encoding: .utf8)

            XCTAssertEqual(
                written.replacingOccurrences(of: "__NAME__", with: "HelloWorld"),
                real,
                ".scripts/new-app-template/\(template) and apps/HelloWorld/Swift/\(source) "
                    + "have drifted. They are one file with one name substituted; whichever "
                    + "is right, make the other match it.")
        }

        // And the SET, so a file added to HelloWorld without a template - or a
        // template with nothing to check it against - is named here rather than
        // discovered by scaffolding an app that half exists.
        let swiftTemplates = try FileManager.default
            .contentsOfDirectory(atPath: templates.path)
            .filter { $0.hasSuffix(".swift.template") }
            .sorted()

        XCTAssertEqual(
            swiftTemplates, pairs.map(\.0).sorted(),
            ".scripts/new-app-template holds Swift templates this test does not pair with a "
                + "file under apps/HelloWorld/Swift, or the other way round.")

        let sources = try swiftSources(under: helloWorld)
        XCTAssertEqual(
            sources.count, pairs.count,
            "apps/HelloWorld/Swift holds \(sources.count) Swift files against \(pairs.count) "
                + "templates - the scaffolder would produce an app missing one of them.")
    }

    /// Runs new-app.sh into a temporary directory and reads what it made: the
    /// full file set, the rename complete in every file, the gallery's samples
    /// left behind, and the solution untouched when the destination is not the
    /// real apps/.
    func testTheScaffolderMakesACompleteApp() throws {
        let slnx = Fixtures.repository.appendingPathComponent("StateUI.slnx")
        let solutionBefore = try String(contentsOf: slnx, encoding: .utf8)

        let made = try scaffold(name: "Probe")
        defer { try? FileManager.default.removeItem(at: made.root) }

        XCTAssertEqual(made.status, 0, "new-app.sh failed:\n\(made.output)")

        let app = made.root.appendingPathComponent("Probe")
        let expected = [
            "Probe.csproj",
            "Host/App.cs",
            "Host/MauiProgram.cs",
            "Package.swift",
            "Swift/ProbeApp.swift",
            "Swift/MainPage.swift",
            "Swift/Styles/AppStyles.swift",
            "Platforms/Android/MainActivity.cs",
            "Platforms/Android/Resources/values-night/maui_colors.xml",
            "Platforms/iOS/Info.plist",
            "Platforms/MacCatalyst/Info.plist",
            "Platforms/Windows/App.xaml",
            "Properties/launchSettings.json",
            "Resources/AppIcon/appicon_bkg.svg",
            "Resources/AppIcon/appicon_mark.svg",
            "Resources/Splash/splash.svg",
            "Resources/Images/stateui_mark.svg",
            "Resources/Images/stateui_tile.svg",
        ]
        for file in expected {
            XCTAssertTrue(
                FileManager.default.fileExists(atPath: app.appendingPathComponent(file).path),
                "the scaffolder did not create \(file)")
        }

        // The rename is COMPLETE: a file still saying Gallery is a
        // project that builds under one name and runs under another - or does
        // not build at all - and __NAME__ is the template's placeholder.
        for file in try allFiles(under: app) {
            guard let text = try? String(contentsOf: file, encoding: .utf8) else { continue }

            for leftover in ["Gallery", "gallery", "__NAME__"] {
                XCTAssertFalse(
                    text.contains(leftover),
                    "\(file.lastPathComponent) still says \(leftover) - the rename missed it.")
            }
        }

        let project = try String(contentsOf: app.appendingPathComponent("Probe.csproj"), encoding: .utf8)
        XCTAssertTrue(project.contains("<ApplicationTitle>Probe</ApplicationTitle>"))
        XCTAssertTrue(project.contains("<ApplicationId>com.example.probe</ApplicationId>"))

        // The tile is drawn big, so the scaffolder gives it a BaseSize of its
        // own - without one the wildcard's 24x24 wins and the page's image is
        // rasterized blurry. This is the line the insert has to land.
        XCTAssertTrue(
            project.contains("<MauiImage Update=\"Resources/Images/stateui_tile.svg\" BaseSize=\"128,128\" />"),
            "the tile's BaseSize did not land in the project file.")

        let manifest = try String(contentsOf: app.appendingPathComponent("Package.swift"), encoding: .utf8)
        XCTAssertTrue(manifest.contains("\"ProbeUI\""), "the manifest does not name ProbeUI.")

        let page = try String(contentsOf: app.appendingPathComponent("Swift/ProbeApp.swift"), encoding: .utf8)
        XCTAssertTrue(page.contains("@_cdecl(\"stateui_app_register\")"))
        XCTAssertTrue(page.contains("stateUIUseApp(ProbeApp())"))

        // What makes the gallery the gallery stays behind.
        XCTAssertFalse(FileManager.default.fileExists(atPath: app.appendingPathComponent("Swift/Samples").path))
        XCTAssertFalse(FileManager.default.fileExists(atPath: app.appendingPathComponent("Swift/Gallery").path))

        // The title is the app's own, whatever the gallery calls itself - the
        // rename would otherwise carry the gallery's title into every new app.
        XCTAssertTrue(project.contains("<ApplicationTitle>Probe</ApplicationTitle>"))
        let images = try FileManager.default.contentsOfDirectory(
            atPath: app.appendingPathComponent("Resources/Images").path)
        XCTAssertEqual(
            images.sorted(), ["stateui_mark.svg", "stateui_tile.svg"],
            "the mark and its tile travel; the shell icons are the gallery's.")

        // A temporary destination never touches the solution. Compared whole
        // against the snapshot from before the run, not searched for the name -
        // a Probe legitimately created in apps/ would fail a search while the
        // scaffold under test still behaved.
        let solutionAfter = try String(contentsOf: slnx, encoding: .utf8)
        XCTAssertEqual(solutionAfter, solutionBefore, "a scaffold outside apps/ must leave StateUI.slnx alone.")
    }

    /// The names the scaffolder must refuse, each with the reason it would
    /// break: a dot reads as a bundle to Finder, a leading digit is not an
    /// identifier, and StateUI is the library. An existing directory is
    /// refused rather than written into.
    func testTheScaffolderRefusesANameItCannotBuild() throws {
        for bad in ["My.App", "1Fish", "StateUI", "has space"] {
            let made = try scaffold(name: bad)
            defer { try? FileManager.default.removeItem(at: made.root) }

            XCTAssertNotEqual(made.status, 0, "'\(bad)' should have been refused: \(made.output)")
        }

        // A directory that is already there is not clobbered.
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("stateui-newapp-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: root) }

        let taken = root.appendingPathComponent("Taken")
        try FileManager.default.createDirectory(at: taken, withIntermediateDirectories: true)
        let marker = taken.appendingPathComponent("keep.txt")
        try "still here".write(to: marker, atomically: true, encoding: .utf8)

        let made = try scaffold(name: "Taken", into: root)
        XCTAssertNotEqual(made.status, 0, "an existing directory should be refused.")
        XCTAssertEqual(try String(contentsOf: marker, encoding: .utf8), "still here")
        XCTAssertFalse(FileManager.default.fileExists(atPath: taken.appendingPathComponent("Taken.csproj").path))
    }

    /// The PowerShell half cannot run where these tests do, so it is held to
    /// agreement instead: both scripts must name the same validation rule, the
    /// same template, the same artwork and the same source project - the pieces
    /// that drift first when one is edited without the other.
    func testTheWindowsScaffolderKeepsStep() throws {
        let sh = try String(
            contentsOf: Fixtures.repository.appendingPathComponent(".scripts/new-app.sh"), encoding: .utf8)
        let ps = try String(
            contentsOf: Fixtures.repository.appendingPathComponent(".scripts/new-app.ps1"), encoding: .utf8)

        for piece in [
            "^[A-Za-z][A-Za-z0-9]*$",
            "App.swift.template",
            "stateui_mark.svg",
            "stateui_tile.svg",
            "AppStyles.swift.template",
            "AppIcon",
            "Splash",
            "__NAME__",
            "Gallery.csproj",
            "gallery",
            "StateUI.slnx",
        ] {
            XCTAssertTrue(sh.contains(piece), "new-app.sh no longer mentions \(piece)")
            XCTAssertTrue(ps.contains(piece), "new-app.ps1 no longer mentions \(piece)")
        }
    }

    // MARK: - Helpers

    /// The application directories under apps/.
    private func appNames() throws -> [String] {
        try FileManager.default.contentsOfDirectory(atPath: apps.path)
            .filter { name in
                var isDirectory: ObjCBool = false
                let path = apps.appendingPathComponent(name).path
                return !name.hasPrefix(".")
                    && FileManager.default.fileExists(atPath: path, isDirectory: &isDirectory)
                    && isDirectory.boolValue
            }
            .sorted()
    }

    /// Runs .scripts/new-app.sh with a temporary destination and collects what it
    /// said. Skipped where bash is not there to run it - Windows has
    /// new-app.ps1, held to agreement by the test above.
    private func scaffold(
        name: String, into destination: URL? = nil
    ) throws -> (root: URL, status: Int32, output: String) {
        let bash = URL(fileURLWithPath: "/bin/bash")
        guard FileManager.default.fileExists(atPath: bash.path) else {
            throw XCTSkip("no /bin/bash here; the PowerShell half is checked by agreement instead.")
        }

        let root = destination
            ?? FileManager.default.temporaryDirectory
                .appendingPathComponent("stateui-newapp-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)

        let process = Process()
        process.executableURL = bash
        process.arguments = [
            Fixtures.repository.appendingPathComponent(".scripts/new-app.sh").path,
            name,
            root.path,
        ]

        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe
        try process.run()
        process.waitUntilExit()

        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        return (root, process.terminationStatus, String(data: data, encoding: .utf8) ?? "")
    }

    /// Every Include="…" and Project="…" value in a project file.
    private func attributeValues(in project: String) -> [String] {
        values(of: "Include=\"", in: project) + values(of: "Project=\"", in: project)
    }

    /// Every piece of text between an opening marker and the next quote.
    private func values(of opening: String, in text: String) -> [String] {
        var found: [String] = []
        var rest = Substring(text)

        while let start = rest.range(of: opening) {
            rest = rest[start.upperBound...]

            guard let end = rest.range(of: "\"") else { break }

            found.append(String(rest[..<end.lowerBound]))
            rest = rest[end.upperBound...]
        }

        return found
    }

    /// The text of every .swift file under a directory, recursively.
    private func swiftSources(under directory: URL) throws -> [String] {
        try allFiles(under: directory)
            .filter { $0.pathExtension == "swift" }
            .compactMap { try? String(contentsOf: $0, encoding: .utf8) }
    }

    /// Every file under a directory, recursively.
    private func allFiles(under directory: URL) throws -> [URL] {
        guard let walk = FileManager.default.enumerator(atPath: directory.path) else { return [] }

        var found: [URL] = []
        for case let name as String in walk {
            let url = directory.appendingPathComponent(name)
            var isDirectory: ObjCBool = false
            if FileManager.default.fileExists(atPath: url.path, isDirectory: &isDirectory), !isDirectory.boolValue {
                found.append(url)
            }
        }

        return found
    }
}
