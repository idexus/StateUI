// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

// The `dotnet new` template, and the one thing it is easy to break silently.
//
// src/StateUI.Template/templates/StateUIStarter/ is a REAL application kept
// as one, so most of what could go wrong with it goes wrong the ordinary way -
// it stops building. What does not is everything about the TEMPLATING: a token
// that collides with something in the build, a file the engine rewrites on its
// way out, a version that no longer matches the package it names. Each of those
// produces a template that packs, installs and generates an app that is subtly
// wrong, with nothing said anywhere.
//
// These read the template's files rather than running `dotnet new`, which needs
// a pack and an install and belongs in a build rather than in a suite that
// finishes in under a second.

import Foundation
import XCTest
@testable import StateUI

final class TemplateTests: XCTestCase {
    /// The token `dotnet new` replaces, which is also the template directory's
    /// name and the name of the project inside it.
    private let token = "StateUIStarter"

    private var project: URL {
        Fixtures.repository.appendingPathComponent("src/StateUI.Template")
    }

    private var template: URL {
        project.appendingPathComponent("templates").appendingPathComponent(token)
    }

    // MARK: - The layout

    /// The template is a complete application plus the two files that make it a
    /// template: what `dotnet new` writes out is only ever what is here.
    func testTheTemplateIsAWholeApplication() throws {
        for file in [
            ".template.config/template.json",
            "\(token).csproj",
            "README.md",
            ".gitignore",
            "Host/App.cs",
            "Host/MauiProgram.cs",
            "Package.swift",
            "Swift/\(token)App.swift",
            "Swift/MainPage.swift",
            "Swift/Styles/AppStyles.swift",
            "Platforms/Android/AndroidManifest.xml",
            "Platforms/iOS/Info.plist",
            "Platforms/MacCatalyst/Info.plist",
            "Platforms/Windows/App.xaml",
            "Properties/launchSettings.json",
            "Resources/AppIcon/stateui_bkg.svg",
            "Resources/AppIcon/stateui_mark.svg",
            "Resources/Splash/splash.svg",
            "Resources/Images/stateui_mark.svg",
            "Resources/Images/stateui_tile.svg",
            ".vscode/launch.json",
            ".vscode/tasks.json",
            ".vscode/settings.json",
        ] {
            XCTAssertTrue(
                FileManager.default.fileExists(atPath: template.appendingPathComponent(file).path),
                "the template has no \(file) - an app made from it would be missing that too.")
        }

        // The one line an app cannot lose: nothing in its Swift module runs
        // until the host calls this export by name.
        let application = try text(at: "Swift/\(token)App.swift")
        XCTAssertTrue(application.contains("@_cdecl(\"stateui_app_register\")"))
        XCTAssertTrue(application.contains("stateUIUseApp(\(token)App())"))

        // The module MSBuild derives from the project name, in the manifest that
        // has to agree with it.
        let manifest = try text(at: "Package.swift")
        for shape in ["name: \"\(token)UI\"", "targets: [\"\(token)UI\"]"] {
            XCTAssertTrue(manifest.contains(shape), "Package.swift does not say \(shape).")
        }
    }

    /// Nothing in the template reaches OUTSIDE the app. This is the whole
    /// difference from an app under apps/, which states relative paths to the
    /// runtime project, the build targets and the repository's own files - none
    /// of which exists once the app has been generated somewhere else.
    func testTheTemplateReachesForNothingAboveItself() throws {
        let project = try text(at: "\(token).csproj")

        for relative in values(of: "Include=\"", in: project) + values(of: "Project=\"", in: project)
        where relative.hasPrefix("../") || relative.hasPrefix("..\\") {
            XCTFail("\(token).csproj points at \(relative), which is above the generated app.")
        }

        XCTAssertTrue(
            project.contains("<Import Project=\".scripts/StateUI.targets\" />"),
            "the project does not import the .scripts beside it.")
        XCTAssertTrue(
            project.contains("<PackageReference Include=\"StateUI\""),
            "the project does not reference the StateUI package.")
        XCTAssertFalse(
            project.contains("ProjectReference"),
            "the project references another project, which a generated app has no copy of.")

        // And the Swift half likewise: a path dependency would point at nothing.
        let manifest = try text(at: "Package.swift")
        XCTAssertTrue(
            manifest.contains(".package(url:"),
            "Package.swift must name StateUI by URL - a path dependency points inside this repository.")
    }

    /// THE SWIFT HALF OF A COMPOUND WAITS FOR THE APP.
    ///
    /// A compound starts both its sessions at once, so an `attach` with no
    /// `preLaunchTask` looks for a process the C# session has not launched yet -
    /// it is still building - and `process attach --name` fails immediately.
    /// What that looks like is the compound coming up with only the C# debugger
    /// in it, which reads as "the Swift debugger does not attach" and says
    /// nothing about a race. Selecting the same configuration on its own,
    /// against an app already running, works either way - which is exactly what
    /// makes the difference easy to miss, and why this is a test.
    ///
    /// The task itself polls `pgrep -x` / `Get-Process -Name`, which match the
    /// EXECUTABLE name: matching a command line would find the dotnet and
    /// msbuild processes building the app and return at once.
    func testTheSwiftHalfOfTheCompoundWaitsForTheApp() throws {
        let launch = try text(at: ".vscode/launch.json")
        let tasks = try text(at: ".vscode/tasks.json")

        // Every attaching configuration has something that puts an app there
        // first - either the one that launches it, or the one that waits.
        let attaching = launch.components(separatedBy: "\"request\": \"attach\"")
        XCTAssertGreaterThan(attaching.count, 1, "launch.json has no attach configuration at all.")

        for (index, configuration) in attaching.dropFirst().enumerated() {
            XCTAssertTrue(
                configuration.contains("\"preLaunchTask\""),
                "attach configuration \(index + 1) has no preLaunchTask - in a compound it would "
                    + "race the session that launches the app, and attach to nothing.")
        }

        XCTAssertTrue(
            launch.contains("\"preLaunchTask\": \"Wait for app startup\""),
            "nothing waits for the app - the compound's Swift half needs the waiting task.")
        XCTAssertTrue(
            tasks.contains("\"label\": \"Wait for app startup\""),
            "launch.json names a task tasks.json does not declare.")
        XCTAssertTrue(
            tasks.contains("pgrep -x \(token)") && tasks.contains("Get-Process -Name \(token)"),
            "the waiting task does not match the app's executable name on both platforms.")

        // A PROCESS task, and this is the second thing that went wrong here. A
        // shell task is re-quoted into a command line for the login shell, and
        // this one carries quotes of its own - measured, the outer shell closed
        // the string early and ran a fragment of the message as a command, so
        // the task died with exit code 127 and the attach never happened.
        let after = try XCTUnwrap(
            tasks.range(of: "\"label\": \"Wait for app startup\"").map { tasks[$0.upperBound...] })

        // THIS task and not whatever follows it, bounded at the next task
        // OBJECT - the one thing that ends a task, since the comments above the
        // next one are already past this one. A fixed window of characters read
        // a neighbour in as this task; so did stopping at the next label, the
        // comment above it being on the wrong side of that line.
        let waiting = after.range(of: "\n    {").map { after[..<$0.lowerBound] } ?? after

        XCTAssertTrue(
            waiting.prefix(200).contains("\"type\": \"process\""),
            "the waiting task is not a process task - a shell would re-quote the script it runs.")
        XCTAssertFalse(
            waiting.contains("'"),
            "the waiting task contains a single quote, which is what broke it once already.")
    }

    // MARK: - The templating

    /// THE TOKEN MUST APPEAR NOWHERE IN THE BUILD SCRIPTS, and this is the
    /// reason it is not simply `StateUIApp`: StateUI.targets is full of
    /// $(StateUIAppModule), $(StateUIAppSources) and their kind, which are
    /// the BUILD's properties rather than any application's. A token that
    /// collided with them would be replaced there too, leaving a scaffolded app
    /// whose targets refer to properties nothing sets - a build that compiles no
    /// Swift and says nothing about why.
    func testTheTokenCollidesWithNothingInTheBuild() throws {
        let scripts = Fixtures.repository.appendingPathComponent(".scripts")

        for file in try allFiles(under: scripts) {
            guard let text = try? String(contentsOf: file, encoding: .utf8) else { continue }

            XCTAssertFalse(
                text.contains(token),
                "\(file.lastPathComponent) contains \(token), the token dotnet new replaces - "
                    + "pick a token that appears in no build script.")
        }
    }

    /// THE TEMPLATE SHIPS NO `Package.resolved`.
    ///
    /// A resolve file PINS a revision, and SwiftPM prefers it to the branch the
    /// manifest names - so one shipped in a template pins every application ever
    /// generated from it to whenever its author last resolved. Measured
    /// 2026-08-16: the committed one named a revision from 6 August, 151 commits
    /// behind `main`, and a freshly scaffolded app failed to compile the library
    /// with `cannot find type 'StyleSheet' in scope` and `inheritance from
    /// non-protocol type 'Window'` - the library from before `Window` became a
    /// protocol. It reads as the branch being stale and it is not: the branch is
    /// current and the pin overrides it.
    ///
    /// SwiftPM writes one beside any manifest it resolves, so this asks the
    /// repository rather than the packed output - and the file is gitignored and
    /// excluded from the pack, which are the other two halves.
    func testTheTemplateShipsNoResolvedRevisions() throws {
        let resolved = template.appendingPathComponent("Package.resolved")

        XCTAssertFalse(
            FileManager.default.fileExists(atPath: resolved.path),
            "the template carries a Package.resolved - every app generated from it would "
                + "compile the library at whatever revision that file names, whatever "
                + "branch Package.swift asks for.")

        let pack = try String(
            contentsOf: project.appendingPathComponent("StateUI.Template.csproj"), encoding: .utf8)
        XCTAssertTrue(
            pack.contains("templates/**/Package.resolved"),
            "the pack does not exclude Package.resolved, so one written by a local build "
                + "would ship in the next package.")

        let ignored = try String(
            contentsOf: Fixtures.repository.appendingPathComponent(".gitignore"), encoding: .utf8)
        XCTAssertTrue(
            ignored.contains("/src/StateUI.Template/templates/*/Package.resolved"),
            "a Package.resolved written beside the template's manifest is not ignored, so "
                + "it would be committed again.")
    }

    /// EVERY GUARD THAT FIRES ON A MISSING SWIFT ARTIFACT HONOURS
    /// `SkipSwiftBuild`.
    ///
    /// `-p:SkipSwiftBuild=true` is documented as skipping the Swift compile
    /// entirely, so a build that ran it has no native library to package - and
    /// an `<Error>` saying one is missing is answering a question nobody asked.
    /// Apple's guard and both of Windows' carry the condition; Android's did
    /// not, which broke the documented C#-only build on that platform and
    /// nowhere else. Nothing else in the repository reads these files, so
    /// without this the next guard added has the same hole and no build fails
    /// until somebody passes the flag.
    func testEveryMissingArtifactGuardHonoursSkipSwiftBuild() throws {
        let targets = try String(
            contentsOf: Fixtures.repository.appendingPathComponent(".scripts/StateUI.targets"),
            encoding: .utf8)

        // What a Swift build PRODUCES - an <Error> naming any of these is about
        // an artifact, which is the thing SkipSwiftBuild takes away. A guard
        // about the project's own consistency, like the module-name check,
        // names none of them and is right to fire either way.
        let produced = [
            "SwiftAppleDir",
            "AndroidNativeLibrary",
            "SwiftWindowsDir",
        ]

        var checked = 0

        for element in targets.components(separatedBy: "<Error").dropFirst() {
            let condition = element.components(separatedBy: "Text=").first ?? element

            guard produced.contains(where: { condition.contains($0) }) else { continue }

            checked += 1

            XCTAssertTrue(
                condition.contains("'$(SkipSwiftBuild)' != 'true'"),
                "an <Error> about a missing Swift artifact does not honour "
                    + "SkipSwiftBuild, so a C#-only build fails on that platform: \(condition)")
        }

        XCTAssertEqual(checked, 5, "the artifact guards are Apple's pair, Android's one and Windows' pair")
    }

    /// The build scripts are copied out BYTE FOR BYTE.
    ///
    /// The templating engine evaluates MSBuild `Condition` attributes in what it
    /// writes: measured on StateUI.targets, `Condition="'@(x)' == ''"` read as
    /// false and took its whole element away, while `'@(x)' != ''` read as true
    /// and had the attribute stripped. What went were the two `<Error>` guards
    /// that say a Swift build produced no native library - so an app would
    /// package silently with no Swift in it, which is the one failure this
    /// project cannot see. The .csproj beside them came through untouched, which
    /// is what made it look like nothing had happened.
    ///
    /// `copyOnly` is what turns the processing off, and nothing under .scripts/
    /// carries an application's name anyway.
    func testTheBuildScriptsAreCopiedRatherThanProcessed() throws {
        let config = try text(at: ".template.config/template.json")

        XCTAssertTrue(
            config.contains("\"copyOnly\""),
            "template.json no longer marks anything copyOnly.")
        XCTAssertTrue(
            config.contains("\".scripts/**\""),
            "template.json does not mark .scripts/** copyOnly - dotnet new will rewrite StateUI.targets.")
        XCTAssertTrue(
            config.contains("\"sourceName\": \"\(token)\""),
            "template.json's sourceName is not \(token), which is what everything here is named after.")
    }

    /// The template's Swift IS `apps/HelloWorld`'s, with the name substituted -
    /// every file, checked character for character. `dotnet new` replaces
    /// `sourceName` in file NAMES too, which is what pairs
    /// `Swift/StateUIStarterApp.swift` with `Swift/HelloWorldApp.swift`.
    ///
    /// The same guard the scaffolder has in AppsTests
    /// (testTheScaffoldersSwiftIsHelloWorldsWithTheNameChanged), for the same
    /// reason: one shape for what an application looks like, in one place, so
    /// the two cannot drift. HelloWorld is an app the suites already check and
    /// a person already builds, so an API it can no longer express fails on the
    /// day the library changes - and this test needs to know nothing about
    /// windows or styles to say so.
    func testTheTemplatesSwiftIsHelloWorldsWithTheNameChanged() throws {
        let templateSwift = template.appendingPathComponent("Swift")
        let helloWorldSwift = Fixtures.repository.appendingPathComponent("apps/HelloWorld/Swift")

        let templated = try relativeFiles(under: templateSwift)
        XCTAssertFalse(templated.isEmpty, "the template's Swift/ holds no files to compare.")

        for relative in templated {
            let source = relative.replacingOccurrences(of: token, with: "HelloWorld")
            let real = helloWorldSwift.appendingPathComponent(source)

            XCTAssertTrue(
                FileManager.default.fileExists(atPath: real.path),
                "the template's Swift/\(relative) has no counterpart at "
                    + "apps/HelloWorld/Swift/\(source).")

            guard FileManager.default.fileExists(atPath: real.path) else { continue }

            let written = try String(
                contentsOf: templateSwift.appendingPathComponent(relative), encoding: .utf8)
            let expected = try String(contentsOf: real, encoding: .utf8)

            XCTAssertEqual(
                written.replacingOccurrences(of: token, with: "HelloWorld"),
                expected,
                "src/StateUI.Template/templates/\(token)/Swift/\(relative) and "
                    + "apps/HelloWorld/Swift/\(source) have drifted. They are one file with "
                    + "one name substituted; whichever is right, make the other match it.")
        }

        // And the SET, both ways round, so a file added to HelloWorld without a
        // templated copy - or a templated file with nothing to check it
        // against - is named here rather than discovered as a generated app
        // that half exists.
        let sources = try relativeFiles(under: helloWorldSwift)
            .map { $0.replacingOccurrences(of: "HelloWorld", with: token) }
            .sorted()
        XCTAssertEqual(
            templated, sources,
            "the template's Swift/ and apps/HelloWorld/Swift/ do not hold the same files.")
    }

    /// The template ships the SAME build as this repository uses, taken from
    /// .scripts/ rather than kept as a second copy - and it leaves out the
    /// scaffolder, which makes an app under apps/ and is what `dotnet new`
    /// replaces everywhere else.
    func testTheTemplateShipsTheRepositorysOwnBuild() throws {
        let pack = try String(
            contentsOf: project.appendingPathComponent("StateUI.Template.csproj"), encoding: .utf8)

        XCTAssertTrue(pack.contains("/../../.scripts/**/*"), "the template no longer takes .scripts from the repository.")
        XCTAssertTrue(pack.contains("new-app."), "the template no longer leaves the scaffolder out.")
        XCTAssertTrue(pack.contains("<PackageType>Template</PackageType>"))

        // A copy on disk is what makes `dotnet new install <folder>` work. It is
        // gitignored, so it is only there once this project has been built -
        // which is why this asks the .gitignore rather than the filesystem.
        let ignored = try String(
            contentsOf: Fixtures.repository.appendingPathComponent(".gitignore"), encoding: .utf8)
        XCTAssertTrue(
            ignored.contains("/src/StateUI.Template/templates/*/.scripts/"),
            "the copied .scripts is not ignored - it would be committed and go stale against the original.")
    }

    /// The FOUR versions that have to agree: the runtime package, the reference
    /// to it in the template, the template package itself, and the GIT TAG the
    /// template's Package.swift pins the Swift half to. They are released
    /// together, and a template naming a version that was never published fails
    /// at restore - in somebody else's project, with nothing pointing back here.
    ///
    /// The Swift pin is the one that can fail while everything here is right:
    /// NuGet and the git tag are two different publishings of one release, so
    /// the number that resolves on the C# side says nothing about whether
    /// `git tag 0.2.0` was ever pushed. This checks only that the two numbers
    /// MATCH - that the tag exists is the release's job, and the symptom if it
    /// does not is SwiftPM refusing to resolve in a generated app.
    func testEveryVersionAgrees() throws {
        let runtime = try version(of: "src/StateUI.Runtime/StateUI.Runtime.csproj")
        let templatePackage = try version(of: "src/StateUI.Template/StateUI.Template.csproj")

        let project = try text(at: "\(token).csproj")
        let referenced = values(of: "Include=\"StateUI\" Version=\"", in: project).first

        let manifest = try text(at: "Package.swift")
        let pinned = values(of: "exact: \"", in: manifest).first

        XCTAssertEqual(
            referenced, runtime,
            "the template references StateUI \(referenced ?? "nothing") while the package is \(runtime).")
        XCTAssertEqual(
            templatePackage, runtime,
            "StateUI.Template is \(templatePackage) while StateUI is \(runtime); they ship together.")
        XCTAssertEqual(
            pinned, runtime,
            "the template's Package.swift pins the Swift half to \(pinned ?? "nothing") while "
                + "the C# half is \(runtime) - a generated app would build two halves from "
                + "different releases, or fail to resolve the tag at all.")
    }

    // MARK: - Helpers

    private func text(at relative: String) throws -> String {
        try String(contentsOf: template.appendingPathComponent(relative), encoding: .utf8)
    }

    private func version(of relative: String) throws -> String {
        let project = try String(
            contentsOf: Fixtures.repository.appendingPathComponent(relative), encoding: .utf8)
        return values(of: "<Version>", in: project, until: "<").first ?? ""
    }

    /// Every piece of text between an opening marker and the next closing one.
    private func values(of opening: String, in text: String, until closing: String = "\"") -> [String] {
        var found: [String] = []
        var rest = Substring(text)

        while let start = rest.range(of: opening) {
            rest = rest[start.upperBound...]

            guard let end = rest.range(of: closing) else { break }

            found.append(String(rest[..<end.lowerBound]))
            rest = rest[end.upperBound...]
        }

        return found
    }

    /// Every file under a directory, as its path relative to that directory,
    /// sorted, with forward slashes on every platform - the walk yields
    /// backslashes on Windows, and a caller substitutes these into paths.
    private func relativeFiles(under directory: URL) throws -> [String] {
        guard let walk = FileManager.default.enumerator(atPath: directory.path) else { return [] }

        var found: [String] = []
        for case let name as String in walk {
            var isDirectory: ObjCBool = false
            if FileManager.default.fileExists(
                atPath: directory.appendingPathComponent(name).path, isDirectory: &isDirectory),
                !isDirectory.boolValue {
                found.append(name.replacingOccurrences(of: "\\", with: "/"))
            }
        }

        return found.sorted()
    }

    /// Every file under a directory, recursively.
    private func allFiles(under directory: URL) throws -> [URL] {
        guard let walk = FileManager.default.enumerator(atPath: directory.path) else { return [] }

        var found: [URL] = []
        for case let name as String in walk {
            let url = directory.appendingPathComponent(name)
            var isDirectory: ObjCBool = false
            if FileManager.default.fileExists(atPath: url.path, isDirectory: &isDirectory),
               !isDirectory.boolValue {
                found.append(url)
            }
        }

        return found
    }
}
