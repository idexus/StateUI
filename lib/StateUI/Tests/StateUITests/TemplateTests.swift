// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

// The `dotnet new` template, and what is easy to break in it silently.
//
// lib/StateUI.Maui/Template/templates/StateUIStarter/ is a real application
// kept as one, so most of what can go wrong with it goes wrong the ordinary
// way - it stops building. What does not is the templating: a token that
// collides with something in the build, a condition over a symbol nobody
// declares, a file the engine rewrites on its way out, a version that no
// longer matches the package it names. Each of those gives a template that
// packs, installs and generates an application that is subtly wrong, with
// nothing said anywhere.
//
// These read the template's files, and where an option decides what is
// written they evaluate the file's conditional lines for that option. Running
// `dotnet new` itself needs a pack and an install, which belong in a build
// rather than in a suite that finishes in under a second.

import Foundation
import XCTest

final class TemplateTests: XCTestCase {
    /// The token `dotnet new` replaces with the application's name: the
    /// template application's directory, its project and its module.
    private let token = "StateUIStarter"

    /// `lib/StateUI.Maui/Template`, the project that packs the template.
    private var project: URL {
        Fixtures.repository.appendingPathComponent("lib/StateUI.Maui/Template")
    }

    /// The application the template writes out.
    private var template: URL { Fixtures.templateApplication }

    // MARK: - The application

    /// The template is a whole application plus what makes it a template:
    /// the engine's configuration, a solution naming the MAUI project, the
    /// editor's configuration, a README and a .gitignore - what an application
    /// made outside this repository needs beside its code. What `dotnet new`
    /// writes out is only ever what is here.
    func testTheTemplateIsAWholeApplication() throws {
        for file in [
            ".template.config/template.json",
            ".template.config/dotnetcli.host.json",
            "\(token).slnx",
            "README.md",
            ".gitignore",
            ".vscode/launch.json",
            ".vscode/tasks.json",
            ".vscode/settings.json",
            "Package.swift",
            "Platforms/AppKit/main.swift",
            "Platforms/Maui/\(token).csproj",
        ] {
            XCTAssertTrue(
                FileManager.default.fileExists(atPath: template.appendingPathComponent(file).path),
                "the template has no \(file) - an application made from it would be missing that too.")
        }

        XCTAssertEqual(
            try text(at: "\(token).slnx").occurrences(between: "<Project Path=\"", and: "\""),
            ["Platforms/Maui/\(token).csproj"],
            "the solution does not name the MAUI project where it is.")

        // The module MSBuild derives from the project name, declared as the
        // manifest's package, its library and its target, over Sources/.
        let manifest = try squeezed(text(at: "Package.swift"))

        for shape in [
            "Package(name:\"\(token)UI\"",
            ".library(name:\"\(token)UI\"",
            ".target(name:\"\(token)UI\"",
            "path:\"Sources\"",
        ] {
            XCTAssertTrue(manifest.contains(shape), "Package.swift does not say \(shape).")
        }
    }

    /// The template's application is apps/HelloWorld with the name changed:
    /// its Swift, its artwork and its MAUI head, file for file - every file
    /// but the project, which names the StateUI packages where HelloWorld names
    /// this repository's projects. `dotnet new` replaces the token in file
    /// names too, which is what pairs `Sources/StateUIStarterApp.swift` with
    /// `Sources/HelloWorldApp.swift`.
    ///
    /// One shape for what an application looks like, kept in one place.
    /// HelloWorld is an application the suites check and a person builds, so
    /// an API it can no longer express fails here the day the library changes,
    /// and this test needs to know nothing about windows or styles to say so.
    /// Whichever side is right, the other is made to match it.
    func testTheTemplatesApplicationIsHelloWorldsWithTheNameChanged() throws {
        let helloWorld = Fixtures.repository.appendingPathComponent("apps/HelloWorld")

        for part in ["Sources", "Resources", "Platforms/Maui"] {
            let written = Fixtures.files(under: template.appendingPathComponent(part))
                .filter { $0 != "\(token).csproj" }
            let model = Fixtures.files(under: helloWorld.appendingPathComponent(part))
                .filter { $0 != "HelloWorld.csproj" }

            XCTAssertFalse(model.isEmpty, "apps/HelloWorld/\(part) holds nothing to compare.")
            XCTAssertEqual(
                written, model.map { $0.replacingOccurrences(of: "HelloWorld", with: token) }.sorted(),
                "the template's \(part)/ and apps/HelloWorld/\(part)/ do not hold the same files.")

            for original in model {
                let relative = original.replacingOccurrences(of: "HelloWorld", with: token)

                // A file that is not there is named by the comparison above.
                guard let data = FileManager.default.contents(
                    atPath: template.appendingPathComponent("\(part)/\(relative)").path)
                else { continue }

                let source = try Data(
                    contentsOf: helloWorld.appendingPathComponent("\(part)/\(original)"))
                assertSameFile(
                    data, Fixtures.helloWorld(source, renamedTo: token),
                    "\(part)/\(relative) in the template and apps/HelloWorld/\(part)/\(original) "
                        + "have drifted. They are one file with one name substituted; whichever "
                        + "is right, make the other match it.")
            }
        }
    }

    /// An application made from the published packages reaches nothing
    /// outside itself. Every relative path its project states stays inside
    /// the application and names something the template ships; its C# half is
    /// the StateUI.Maui package and its Swift half StateUI by URL at a
    /// release; and nothing in it names a checkout, or the AppKit head that
    /// only a checkout brings. Anything else points at a directory that does
    /// not exist once the application is generated somewhere else.
    func testAnApplicationFromThePackagesReachesNothingOutsideItself() throws {
        let published: Set<String> = []
        let head = template.appendingPathComponent("Platforms/Maui")
        let root = template.standardizedFileURL.path + "/"
        let project = try generated("Platforms/Maui/\(token).csproj", options: published)

        XCTAssertFalse(
            project.contains("..\\"), "\(token).csproj: a backslash in a relative path breaks macOS.")

        let relatives = Fixtures.relativePaths(in: project)
        XCTAssertFalse(
            relatives.isEmpty,
            "the project states no relative path - its artwork and its build are named that way.")

        for relative in relatives {
            let target = head.appendingPathComponent(relative).standardizedFileURL

            guard target.path.hasPrefix(root) else {
                XCTFail("\(token).csproj points at \(relative), which is above the generated "
                    + "application.")
                continue
            }

            // The build is packed from the repository's .scripts, so that is
            // where it is looked for.
            let inside = String(target.path.dropFirst(root.count))
            let shipped = inside.hasPrefix(".scripts/")
                ? Fixtures.repository.appendingPathComponent(inside)
                : target

            XCTAssertTrue(
                Fixtures.resolves(shipped),
                "\(token).csproj points at \(relative), which the template does not ship.")
        }

        XCTAssertTrue(
            project.contains("<PackageReference Include=\"StateUI.Maui\" Version=\""),
            "the project does not reference the StateUI.Maui package.")
        XCTAssertTrue(
            project.contains("<PackageReference Include=\"StateUI.Maui.Linux\" Version=\""),
            "the project does not reference StateUI.Maui.Linux - the application has no Linux "
                + "platform under it.")
        XCTAssertFalse(
            project.contains("ProjectReference"),
            "the project references another project, which a generated application has no copy of.")
        XCTAssertFalse(project.contains("STATEUI_CHECKOUT"), "the project names a checkout nobody gave it.")

        let manifest = try generated("Package.swift", options: published)
        XCTAssertTrue(
            manifest.contains(".package(url: \"https://github.com/idexus/StateUI.git\", exact: \""),
            "Package.swift must name StateUI by URL at a release - a path dependency points into "
                + "a directory the application does not have.")
        XCTAssertFalse(manifest.contains("STATEUI_CHECKOUT"), "Package.swift names a checkout nobody gave it.")
        XCTAssertFalse(manifest.contains("#error("), "an application made from the packages refuses to build.")

        for file in ["Package.swift", ".vscode/launch.json", ".vscode/tasks.json"] {
            XCTAssertFalse(
                try generated(file, options: published).contains("\(token)AppKit"),
                "\(file) names the AppKit head, which an application made without --appkit does not have.")
        }
    }

    /// An application made with `--stateui-path` takes both halves of StateUI
    /// from that checkout, and with `--appkit` its AppKit host too: every
    /// project it references and every package it depends on by path is in
    /// the checkout, the build is told where the checkout is, and each of them
    /// names what a StateUI checkout holds - read against this repository,
    /// which is one. `--appkit` without a checkout refuses to build and says
    /// why.
    func testAnApplicationFromACheckoutTakesBothHalvesFromIt() throws {
        let checkout = "STATEUI_CHECKOUT"
        let variants: [Set<String>] = [["UseCheckout"], ["UseCheckout", "AppKit"]]

        // What a path in the checkout names, in this repository.
        func here(_ path: String) -> URL {
            let rest = String(path.dropFirst(checkout.count).drop(while: { $0 == "/" }))
            return rest.isEmpty ? Fixtures.repository : Fixtures.repository.appendingPathComponent(rest)
        }

        for options in variants {
            let said = "\(options.sorted())"
            let project = try generated("Platforms/Maui/\(token).csproj", options: options)
            let references = project.occurrences(between: "<ProjectReference Include=\"", and: "\"")

            XCTAssertFalse(references.isEmpty, "\(said): the project references nothing in the checkout.")

            for reference in references {
                XCTAssertTrue(
                    reference.hasPrefix(checkout + "/"),
                    "\(said): \(token).csproj references \(reference), which is not in the checkout.")
                XCTAssertTrue(
                    FileManager.default.fileExists(atPath: here(reference).path),
                    "\(said): \(token).csproj references \(reference), which a StateUI checkout "
                        + "does not hold.")
            }

            XCTAssertFalse(
                project.contains("<PackageReference Include=\"StateUI"),
                "\(said): the project takes StateUI from a package as well as from the checkout.")
            XCTAssertTrue(
                project.contains("<StateUIPackagePath>\(checkout)/</StateUIPackagePath>"),
                "\(said): the build is not told where the checkout is - a path dependency is never "
                    + "checked out, so the build finds no library sources.")

            let manifest = try generated("Package.swift", options: options)
            XCTAssertFalse(
                manifest.contains(".package(url:"),
                "\(said): Package.swift takes StateUI from its URL as well as from the checkout.")
            XCTAssertFalse(
                manifest.contains("#error("),
                "\(said): an application made from a checkout refuses to build.")

            let paths = manifest.split(separator: "\n")
                .filter { $0.contains(".package(") && !$0.drop(while: { $0 == " " }).hasPrefix("//") }
                .flatMap { String($0).occurrences(between: "path: \"", and: "\"") }

            XCTAssertFalse(paths.isEmpty, "\(said): Package.swift depends on nothing in the checkout.")

            for path in paths {
                XCTAssertTrue(
                    path.hasPrefix(checkout),
                    "\(said): Package.swift depends on \(path), which is not in the checkout.")
                XCTAssertTrue(
                    FileManager.default.fileExists(
                        atPath: here(path).appendingPathComponent("Package.swift").path),
                    "\(said): Package.swift depends on \(path), which is no package in a StateUI "
                        + "checkout.")
            }

            let appKit = options.contains("AppKit")
            XCTAssertEqual(
                squeezed(manifest).contains(".executable(name:\"\(token)AppKit\""), appKit,
                "\(said): Package.swift and --appkit disagree about the AppKit head.")
            XCTAssertEqual(
                try generated(".vscode/launch.json", options: options).contains("\"Debug app (AppKit)\""),
                appKit,
                "\(said): launch.json and --appkit disagree about the AppKit launch.")
        }

        XCTAssertTrue(
            try generated("Package.swift", options: ["AppKit"]).contains("#error("),
            "--appkit without --stateui-path builds, and fails later for want of the AppKit host.")
    }

    /// The Swift half of a compound waits for the application. A compound
    /// starts both its sessions at once, so an attach with nothing in front of
    /// it looks for a process the C# session has not launched yet - it is
    /// still building - and `process attach --name` fails at once: the
    /// compound comes up with only the C# debugger in it, which reads as "the
    /// Swift debugger does not attach" and says nothing about a race. The same
    /// configuration selected on its own, against an application already
    /// running, works either way, which is what hides the difference.
    ///
    /// The waiting task polls `pgrep -x` and `Get-Process -Name`, which match
    /// the executable's name: matching a command line would find the dotnet
    /// and msbuild processes building the application and return at once.
    func testTheSwiftHalfOfTheCompoundWaitsForTheApp() throws {
        let launch = try text(at: ".vscode/launch.json")
        let tasks = try text(at: ".vscode/tasks.json")

        // Every attaching configuration has something that puts an application
        // there first - the task that launches it, or the one that waits.
        let attaching = launch.components(separatedBy: "\"request\": \"attach\"")
        XCTAssertGreaterThan(attaching.count, 1, "launch.json has no attach configuration at all.")

        for (index, configuration) in attaching.dropFirst().enumerated() {
            XCTAssertTrue(
                configuration.contains("\"preLaunchTask\""),
                "attach configuration \(index + 1) has no preLaunchTask - in a compound it races "
                    + "the session that launches the application, and attaches to nothing.")
        }

        XCTAssertTrue(
            launch.contains("\"preLaunchTask\": \"Wait for app startup\""),
            "nothing waits for the application - the compound's Swift half needs the waiting task.")
        XCTAssertTrue(
            tasks.contains("\"label\": \"Wait for app startup\""),
            "launch.json names a task tasks.json does not declare.")
        XCTAssertTrue(
            tasks.contains("pgrep -x \(token)") && tasks.contains("Get-Process -Name \(token)"),
            "the waiting task does not match the application's executable name on both platforms.")

        // A process task: a shell task is re-quoted into a command line for the
        // login shell, and this one carries quotes of its own - the outer shell
        // closes the string early and runs a fragment of the message as a
        // command, the task dies with exit code 127, and the attach never
        // happens.
        let after = try XCTUnwrap(
            tasks.range(of: "\"label\": \"Wait for app startup\"").map { tasks[$0.upperBound...] })

        // This task and not whatever follows it, bounded at the next task
        // object: the comments above the next task sit before its label, so a
        // bound at the label would read them in as this task's.
        let waiting = after.range(of: "\n    {").map { after[..<$0.lowerBound] } ?? after

        XCTAssertTrue(
            waiting.prefix(200).contains("\"type\": \"process\""),
            "the waiting task is not a process task - a shell re-quotes the script it runs.")
        XCTAssertFalse(
            waiting.contains("'"),
            "the waiting task holds a single quote, which the shell's own quoting closes early.")
    }

    // MARK: - The templating

    /// The token appears nowhere in the build the template ships, which is
    /// why it is not simply `StateUIApp`: StateUI.targets is full of
    /// `$(StateUIAppModule)`, `$(StateUIAppSources)` and their kind - the
    /// build's own properties rather than any application's. A token that
    /// collided with them would be replaced in every file the engine
    /// processes that names one, leaving names the build does not read - a
    /// build that compiles no Swift and says nothing about why.
    func testTheTokenCollidesWithNothingInTheBuild() throws {
        let build = Fixtures.repository.appendingPathComponent(".scripts/Maui")
        let files = Fixtures.files(under: build)
        XCTAssertFalse(files.isEmpty, ".scripts/Maui holds no build to read.")

        for relative in files {
            guard let text = try? String(
                contentsOf: build.appendingPathComponent(relative), encoding: .utf8)
            else { continue }

            XCTAssertFalse(
                text.contains(token),
                ".scripts/Maui/\(relative) contains \(token), the token the template replaces - "
                    + "pick a token that appears in no build script.")
        }
    }

    /// The template ships no `Package.resolved`. A resolve file pins a
    /// revision, and SwiftPM prefers it to the version the manifest names - so
    /// one shipped in the template pins every application generated from it to
    /// whatever its author last resolved, and the library it compiles is not
    /// the release its manifest asks for.
    ///
    /// SwiftPM writes one beside any manifest it resolves, so this asks four
    /// places: the file is not there, the pack leaves it out, git ignores it,
    /// and the editor on this repository never resolves the template's
    /// manifest to write one.
    func testTheTemplateShipsNoResolvedRevisions() throws {
        XCTAssertFalse(
            FileManager.default.fileExists(
                atPath: template.appendingPathComponent("Package.resolved").path),
            "the template carries a Package.resolved - every application generated from it "
                + "compiles the library at whatever revision that file names, whatever release "
                + "Package.swift asks for.")

        XCTAssertTrue(
            try packageProject().contains("templates/**/Package.resolved"),
            "the pack does not exclude Package.resolved, so one written by a local build ships "
                + "in the next package.")

        let ignored = try String(
            contentsOf: Fixtures.repository.appendingPathComponent(".gitignore"), encoding: .utf8)
        XCTAssertTrue(
            ignored.contains("/lib/StateUI.Maui/Template/templates/*/Package.resolved"),
            "a Package.resolved written beside the template's manifest is not ignored, so it "
                + "gets committed.")

        let settings = try String(
            contentsOf: Fixtures.repository.appendingPathComponent(".vscode/settings.json"),
            encoding: .utf8)
        let unsearched = settings.occurrences(
            between: "\"swift.ignoreSearchingForPackagesInSubfolders\": [", and: "]").first ?? ""
        XCTAssertTrue(
            unsearched.contains("\"\(token)\""),
            "the editor resolves the template's manifest while this repository is open, and "
                + "writes a Package.resolved beside it.")
    }

    /// Every guard that fires on a missing Swift artifact honours
    /// `SkipSwiftBuild`. `-p:SkipSwiftBuild=true` builds the C# side without
    /// recompiling Swift, so an `<Error>` about a native library that build
    /// did not make answers a question nobody asked. Apple's pair, Android's
    /// one, and Windows' and Linux's pairs carry the condition; a guard added
    /// without it breaks the C#-only build on its platform alone, and only for
    /// whoever passes the flag.
    func testEveryMissingArtifactGuardHonoursSkipSwiftBuild() throws {
        let targets = try String(
            contentsOf: Fixtures.repository.appendingPathComponent(".scripts/Maui/StateUI.targets"),
            encoding: .utf8)

        // What a Swift build PRODUCES - an <Error> naming any of these is about
        // an artifact, which is what SkipSwiftBuild takes away. A guard about
        // the project's own consistency, like the module-name check, names none
        // of them and is right to fire either way.
        let produced = ["SwiftAppleDir", "AndroidNativeLibrary", "SwiftWindowsDir", "SwiftLinuxDir"]

        var checked = 0

        for element in targets.components(separatedBy: "<Error").dropFirst() {
            let condition = element.components(separatedBy: "Text=").first ?? element

            guard produced.contains(where: { condition.contains($0) }) else { continue }

            checked += 1

            XCTAssertTrue(
                condition.contains("'$(SkipSwiftBuild)' != 'true'"),
                "an <Error> about a missing Swift artifact does not honour SkipSwiftBuild, so a "
                    + "C#-only build fails on that platform: \(condition)")
        }

        XCTAssertEqual(
            checked, 7,
            "the artifact guards are Apple's pair, Android's one, and Windows' and Linux's pairs.")
    }

    /// The build the template ships is copied out byte for byte. The
    /// templating engine evaluates MSBuild `Condition` attributes in the files
    /// it processes: in StateUI.targets it reads `'@(x)' == ''` as false and
    /// takes the whole element away, and it strips `'@(x)' != ''` as true -
    /// and what goes are the `<Error>` guards that say a Swift build produced
    /// no native library, so an application packages silently with no Swift
    /// in it. An unconditional `copyOnly` over `.scripts/**` turns the
    /// processing off, and nothing there carries an application's name.
    func testTheBuildScriptsAreCopiedRatherThanProcessed() throws {
        let config = try configuration()

        XCTAssertEqual(
            config["sourceName"] as? String, token,
            "template.json's sourceName is not \(token), which everything here is named after.")

        let modifiers = (config["sources"] as? [[String: Any]] ?? [])
            .flatMap { $0["modifiers"] as? [[String: Any]] ?? [] }
        let copying = modifiers.filter {
            $0["condition"] == nil && ($0["copyOnly"] as? [String] ?? []).contains(".scripts/**")
        }

        XCTAssertFalse(
            copying.isEmpty,
            "template.json does not mark .scripts/** copyOnly for every application - the engine "
                + "rewrites StateUI.targets on its way out.")
    }

    /// The template ships the build this repository's applications use,
    /// packed from .scripts/Maui rather than kept as a second copy, and
    /// unpacked where the application's project imports it:
    /// `.scripts/Maui/StateUI.targets` beside `Platforms/`. The scripts that
    /// describe this repository rather than an application - new-app, which
    /// scaffolds into apps/, and the Gallery's AppKit bundler - stand outside
    /// .scripts/Maui, so the package never carries them.
    ///
    /// The copy the template project writes beside the template, for
    /// `dotnet new install <folder>`, is ignored by git, which keeps it from
    /// going stale against the original, and left out of the pack, so no file
    /// ships twice.
    func testTheTemplateShipsTheRepositorysOwnBuild() throws {
        let pack = try packageProject()
        let glob = try XCTUnwrap(
            pack.occurrences(
                between: "<_StateUIScript Include=\"$(MSBuildProjectDirectory)/", and: "\"").first,
            "the template no longer takes its build from the repository.")

        XCTAssertTrue(
            glob.hasSuffix("/**/*"), "the template packs \(glob) rather than a whole folder of the build.")

        let originals = project.appendingPathComponent(String(glob.dropLast("/**/*".count)))
            .standardizedFileURL
        let build = Fixtures.repository.appendingPathComponent(".scripts/Maui")
        XCTAssertEqual(
            originals.path, build.standardizedFileURL.path,
            "the template packs \(originals.path), which is not the repository's .scripts/Maui.")

        let shipped = Fixtures.files(under: build)
        XCTAssertTrue(shipped.contains("StateUI.targets"), ".scripts/Maui holds no StateUI.targets to ship.")

        for script in ["new-app.sh", "new-app.ps1", "build-gallery-appkit.sh"] {
            XCTAssertFalse(
                shipped.contains { $0.hasSuffix(script) },
                "\(script) is under .scripts/Maui, so every application made from the template "
                    + "ships it - and it describes this repository, not the application.")
        }

        XCTAssertTrue(
            pack.contains(
                "<PackagePath>templates/\(token)/.scripts/Maui/%(RecursiveDir)%(Filename)%(Extension)</PackagePath>"),
            "the pack does not put the build where the application's project imports it.")
        XCTAssertTrue(
            try text(at: "Platforms/Maui/\(token).csproj")
                .contains("<Import Project=\"../../.scripts/Maui/StateUI.targets\" />"),
            "the application's project does not import the build that ships beside it.")
        XCTAssertTrue(
            pack.contains("<PackageType>Template</PackageType>"),
            "the package is not a template, so the SDK installs no template from it.")

        let ignored = try String(
            contentsOf: Fixtures.repository.appendingPathComponent(".gitignore"), encoding: .utf8)
        XCTAssertTrue(
            ignored.contains("/lib/StateUI.Maui/Template/templates/*/.scripts/"),
            "the copied .scripts is not ignored - it gets committed and goes stale against the "
                + "original.")
        XCTAssertTrue(
            pack.contains("templates/**/.scripts/**"),
            "the pack takes the copied .scripts as well as the originals, so every build file "
                + "ships twice.")
    }

    /// Every condition in the template names a symbol template.json declares.
    /// A condition over a name nobody declares is false for every
    /// application: the block under it is never written - or always, under a
    /// `!` - whatever the options say, and the template packs, installs and
    /// generates without a word.
    func testEveryConditionNamesASymbolTheTemplateDeclares() throws {
        let config = try configuration()
        let symbols = config["symbols"] as? [String: Any] ?? [:]
        let declared = Set(symbols.keys.filter { !$0.hasPrefix("//") })

        var conditions: [(place: String, condition: String)] = []

        for relative in Fixtures.files(
            under: template, leavingOut: Fixtures.byproducts.union([".scripts"])) {
            guard let text = try? String(
                contentsOf: template.appendingPathComponent(relative), encoding: .utf8)
            else { continue }

            for line in text.split(separator: "\n") {
                guard let found = directive(in: line),
                      found.keyword == "if" || found.keyword == "elseif" || found.keyword == "elif"
                else { continue }

                conditions.append((place: relative, condition: found.condition))
            }
        }

        let modifiers = (config["sources"] as? [[String: Any]] ?? [])
            .flatMap { $0["modifiers"] as? [[String: Any]] ?? [] }

        for modifier in modifiers {
            if let condition = modifier["condition"] as? String {
                conditions.append((place: "template.json", condition: condition))
            }
        }

        for (name, value) in symbols {
            if let symbol = value as? [String: Any],
               (symbol["type"] as? String) == "computed",
               let expression = symbol["value"] as? String {
                conditions.append((place: "template.json, \(name)", condition: expression))
            }
        }

        XCTAssertFalse(
            conditions.isEmpty,
            "the template holds no condition - its AppKit head and its checkout are chosen by them.")

        for (place, condition) in conditions {
            for name in TemplateCondition.names(in: condition) {
                XCTAssertTrue(
                    declared.contains(name),
                    "\(place): \(condition) names \(name), which template.json does not declare - "
                        + "it is false for every application.")
            }
        }
    }

    /// Every option the template takes is offered under the name its command
    /// line takes, and spelled that way wherever the application's author
    /// reads about it: dotnetcli.host.json gives each parameter template.json
    /// declares its long name, the README names every one, and neither the
    /// README, the manifest's refusal nor the options' own descriptions spell
    /// an option that is not one.
    func testEveryOptionIsSpelledTheWayTheCommandLineTakesIt() throws {
        let symbols = try configuration()["symbols"] as? [String: Any] ?? [:]
        let parameters = symbols.compactMap { entry -> String? in
            ((entry.value as? [String: Any])?["type"] as? String) == "parameter" ? entry.key : nil
        }
        XCTAssertFalse(parameters.isEmpty, "template.json declares no option.")

        let host = try JSONSerialization.jsonObject(
            with: Data(contentsOf: template.appendingPathComponent(".template.config/dotnetcli.host.json")))
        let spelled = (host as? [String: Any])?["symbolInfo"] as? [String: Any] ?? [:]
        XCTAssertEqual(
            Set(spelled.keys), Set(parameters),
            "dotnetcli.host.json and template.json name different options.")

        var longNames: Set<String> = []

        for parameter in parameters {
            let long = try XCTUnwrap(
                (spelled[parameter] as? [String: Any])?["longName"] as? String,
                "\(parameter) has no long name on the command line.")
            longNames.insert(long)
        }

        let readme = try text(at: "README.md")

        for long in longNames.sorted() {
            XCTAssertTrue(readme.contains("--\(long)"), "README.md never says --\(long).")
        }

        for file in ["README.md", "Package.swift", ".template.config/template.json"] {
            for option in try options(in: text(at: file)) {
                XCTAssertTrue(
                    longNames.contains(option),
                    "\(file) spells --\(option), which the template does not take.")
            }
        }
    }

    /// The template is installed by one name and used by another, everywhere
    /// this repository tells somebody how: `dotnet new install` takes the
    /// package's id, and a new application is made with the template's short
    /// name. A README, a package description or a comment spelling either
    /// otherwise hands its reader a command that finds no template.
    ///
    /// The command is assembled here so this guard does not find itself.
    func testTheTemplateIsCalledOneThingEverywhere() throws {
        let command = "dotnet" + " new "
        let shortName = try XCTUnwrap(
            configuration()["shortName"] as? String, "template.json has no shortName.")
        let packageId = try XCTUnwrap(
            packageProject().occurrences(between: "<PackageId>", and: "<").first,
            "the template project names no package.")

        let repository = Fixtures.repository
        let copy = "lib/StateUI.Maui/Template/templates/\(token)/.scripts/"
        let leftOut = Fixtures.byproducts.union([".git", "_old", "artifacts", ".vs", "AGENTS.md", "CLAUDE.md"])

        var said = 0
        var wrong: [String] = []

        for relative in Fixtures.files(under: repository, leavingOut: leftOut) where !relative.hasPrefix(copy) {
            guard let text = try? String(
                contentsOf: repository.appendingPathComponent(relative), encoding: .utf8),
                text.contains(command)
            else { continue }

            for (number, line) in text.split(separator: "\n", omittingEmptySubsequences: false)
                .enumerated() {
                var rest = line

                while let found = rest.range(of: command) {
                    rest = rest[found.upperBound...]

                    let words = rest.split(separator: " ", maxSplits: 2)
                    guard let first = words.first else { continue }

                    let verb = String(first.prefix { $0.isLetter || $0.isNumber || $0 == "-" })
                    let ended = verb.count < first.count

                    switch verb {
                    case "", "list", "search", "update", "details":
                        continue
                    case "install", "uninstall":
                        guard !ended, words.count > 1 else { continue }

                        let package = String(words[1].prefix { !"`\"'".contains($0) })

                        guard !package.isEmpty, !package.contains("/"), !package.contains("\\"),
                              !package.hasSuffix(".nupkg"), !package.hasPrefix("<")
                        else { continue }

                        said += 1

                        if package != packageId {
                            wrong.append("\(relative):\(number + 1) installs \(package)")
                        }
                    default:
                        said += 1

                        if verb != shortName {
                            wrong.append("\(relative):\(number + 1) makes an application with \(verb)")
                        }
                    }
                }
            }
        }

        XCTAssertGreaterThan(
            said, 0, "nothing in the repository says how to install the template or use it.")
        XCTAssertEqual(
            wrong, [],
            "the template installs as \(packageId) and makes an application as \(shortName); "
                + "these say otherwise.")
    }

    // MARK: - The release

    /// The packages of one release and the pins the template is born with
    /// name one version: StateUI.Maui, StateUI.Maui.Linux, the template's
    /// references to both, and the git tag its Package.swift pins the Swift
    /// half to. They are released together, and a template naming a version
    /// that was never published fails at restore - in somebody else's project,
    /// with nothing pointing back here.
    ///
    /// The Swift pin can fail while every number here agrees: NuGet and the
    /// git tag are two publishings of one release, and this checks only that
    /// the numbers match. That the tag exists is the release's job, and
    /// SwiftPM refusing to resolve in a generated application is the symptom
    /// when it does not.
    ///
    /// The template package may add a fourth part to the release - `0.3.1.1`
    /// against `0.3.1` - because it can be wrong while every line of the
    /// library is right; it never names another release.
    func testEveryVersionAgrees() throws {
        let runtime = try version(of: "lib/StateUI.Maui/Sources/StateUI.Maui.csproj")
        let linux = try version(of: "lib/StateUI.Maui/Linux/StateUI.Maui.Linux.csproj")
        let templatePackage = try version(of: "lib/StateUI.Maui/Template/StateUI.Maui.Template.csproj")

        let application = try text(at: "Platforms/Maui/\(token).csproj")
        let referenced = application.occurrences(
            between: "Include=\"StateUI.Maui\" Version=\"", and: "\"")
        let referencedLinux = application.occurrences(
            between: "Include=\"StateUI.Maui.Linux\" Version=\"", and: "\"")
        let pinned = try text(at: "Package.swift").occurrences(between: "exact: \"", and: "\"")

        XCTAssertEqual(
            linux, runtime,
            "StateUI.Maui.Linux is \(linux) while StateUI.Maui is \(runtime) - one release, two "
                + "packages.")
        XCTAssertEqual(
            referenced, [runtime],
            "the template references StateUI.Maui \(referenced) while the package is \(runtime).")
        XCTAssertEqual(
            referencedLinux, [runtime],
            "the template references StateUI.Maui.Linux \(referencedLinux) while the package is "
                + "\(runtime) - a generated application does not restore on Linux.")
        XCTAssertEqual(
            pinned, [runtime],
            "the template's Package.swift pins the Swift half to \(pinned) while the C# half is "
                + "\(runtime) - a generated application builds two halves from different "
                + "releases, or fails to resolve the tag at all.")
        XCTAssertTrue(
            templatePackage == runtime || templatePackage.hasPrefix("\(runtime)."),
            "StateUI.Maui.Template is \(templatePackage) while StateUI.Maui is \(runtime); the "
                + "template may add a fourth part to a release, never name another one.")
    }

    /// Everything else in the repository that names the release names this
    /// one: the published-package line in the root's and every application's
    /// Package.swift, the version the bug report asks for, the Gallery's
    /// AppKit bundle, and the package file the template project's own
    /// instructions install. A reader copying any of them gets this release
    /// rather than the one before.
    func testEveryMentionOfTheReleaseNamesThisOne() throws {
        let runtime = try version(of: "lib/StateUI.Maui/Sources/StateUI.Maui.csproj")
        let templatePackage = try version(of: "lib/StateUI.Maui/Template/StateUI.Maui.Template.csproj")

        func read(_ relative: String) throws -> String {
            try String(
                contentsOf: Fixtures.repository.appendingPathComponent(relative), encoding: .utf8)
        }

        XCTAssertEqual(
            try read("Package.swift").occurrences(between: "exact: \"", and: "\""), [runtime],
            "the root Package.swift shows a published StateUI other than \(runtime).")

        for app in try Fixtures.applications() {
            let manifest = "apps/\(app.lastPathComponent)/Package.swift"

            for named in try read(manifest).occurrences(between: "exact: \"", and: "\"") {
                XCTAssertEqual(named, runtime, "\(manifest) shows StateUI \(named) while the release is \(runtime).")
            }
        }

        XCTAssertEqual(
            try read(".github/ISSUE_TEMPLATE/bug.yml").occurrences(
                between: "placeholder: StateUI ", and: ","),
            [runtime],
            "the bug report's example version is not \(runtime).")
        XCTAssertEqual(
            try read(".scripts/AppKit/build-gallery-appkit.sh").occurrences(
                between: "CFBundleShortVersionString -string ", and: " "),
            [runtime],
            "the Gallery's AppKit bundle is not versioned \(runtime).")
        XCTAssertEqual(
            try read("lib/StateUI.Maui/Template/StateUI.Maui.Template.csproj").occurrences(
                between: "/StateUI.Maui.Template.", and: ".nupkg"),
            [templatePackage],
            "the template project's instructions install a package other than the one it packs, "
                + "\(templatePackage).")
    }

    // MARK: - Helpers

    /// One of the template application's files, read as text.
    private func text(at relative: String) throws -> String {
        try String(contentsOf: template.appendingPathComponent(relative), encoding: .utf8)
    }

    /// `StateUI.Maui.Template.csproj`, the project that packs the template.
    private func packageProject() throws -> String {
        try String(
            contentsOf: project.appendingPathComponent("StateUI.Maui.Template.csproj"),
            encoding: .utf8)
    }

    /// template.json, read.
    private func configuration() throws -> [String: Any] {
        let data = try Data(
            contentsOf: template.appendingPathComponent(".template.config/template.json"))
        return try XCTUnwrap(
            JSONSerialization.jsonObject(with: data) as? [String: Any],
            "template.json is not a JSON object.")
    }

    /// The `<Version>` a project states.
    private func version(of relative: String) throws -> String {
        let project = try String(
            contentsOf: Fixtures.repository.appendingPathComponent(relative), encoding: .utf8)
        return try XCTUnwrap(
            project.occurrences(between: "<Version>", and: "<").first,
            "\(relative) states no <Version>.")
    }

    /// A text with every space and line break taken out, so a call wrapped
    /// over several lines reads as the one call it is.
    private func squeezed(_ text: String) -> String {
        text.components(separatedBy: .whitespacesAndNewlines).joined()
    }

    /// Every `--option` a text spells.
    private func options(in text: String) -> [String] {
        var found: [String] = []
        var rest = Substring(text)

        while let range = rest.range(of: "--") {
            rest = rest[range.upperBound...]
            let name = rest.prefix { $0.isLowercase || $0.isNumber || $0 == "-" }

            if let first = name.first, first.isLetter {
                found.append(String(name))
            }
        }

        return found
    }

    /// A template file as `dotnet new` writes it for a set of options: every
    /// conditional block kept or dropped by what it asks of the options, and
    /// the directive lines themselves gone.
    private func generated(_ relative: String, options: Set<String>) throws -> String {
        var written: [Substring] = []

        // One entry per open block: whether its current branch is written,
        // whether a branch of it already held, and whether the block itself
        // stands in written text.
        var blocks: [(writing: Bool, taken: Bool, inside: Bool)] = []

        for line in try text(at: relative).split(separator: "\n", omittingEmptySubsequences: false) {
            let inside = blocks.last?.writing ?? true

            guard let found = directive(in: line) else {
                if inside { written.append(line) }
                continue
            }

            switch found.keyword {
            case "if":
                let value = holds(found.condition, for: options, in: relative)
                blocks.append((writing: inside && value, taken: value, inside: inside))
            case "elseif", "elif":
                guard var block = blocks.popLast() else {
                    XCTFail("\(relative): \(line) continues no block.")
                    continue
                }

                let value = !block.taken && holds(found.condition, for: options, in: relative)
                block.writing = block.inside && value
                block.taken = block.taken || value
                blocks.append(block)
            case "else":
                guard var block = blocks.popLast() else {
                    XCTFail("\(relative): \(line) continues no block.")
                    continue
                }

                block.writing = block.inside && !block.taken
                block.taken = true
                blocks.append(block)
            case "endif":
                if blocks.popLast() == nil {
                    XCTFail("\(relative): \(line) closes no block.")
                }
            default:
                XCTFail("\(relative): \(line) is a directive this reader does not know.")
            }
        }

        XCTAssertTrue(blocks.isEmpty, "\(relative) leaves a conditional block open.")
        return written.joined(separator: "\n")
    }

    /// Whether a condition holds for a set of options - failing where the
    /// condition says more than this reader understands.
    private func holds(_ condition: String, for options: Set<String>, in relative: String) -> Bool {
        let result = TemplateCondition.holds(condition, for: options)
        XCTAssertTrue(
            result.understood,
            "\(relative): \(condition) says more than names under !, && and || - teach this "
                + "reader the rest before trusting what it writes.")
        return result.value
    }

    /// The template directive a line is, if it is one: its keyword and the
    /// condition after it. The template writes its directives behind `//#` in
    /// Swift and JSON, and between `<!--#` and `-->` in a project file.
    private func directive(in line: Substring) -> (keyword: String, condition: String)? {
        var rest = line.drop(while: { $0 == " " || $0 == "\t" })

        if rest.hasPrefix("//#") {
            rest = rest.dropFirst(3)
        } else if rest.hasPrefix("<!--#") {
            rest = rest.dropFirst(5)

            if let end = rest.range(of: "-->") {
                rest = rest[..<end.lowerBound]
            }
        } else {
            return nil
        }

        let keyword = rest.prefix { $0.isLetter }
        return (String(keyword), rest.dropFirst(keyword.count).trimmingCharacters(in: .whitespaces))
    }
}

/// A template condition, read the way the engine reads the ones this template
/// writes: names joined by `&&` and `||`, each perhaps under `!`, grouped by
/// parentheses. A name holds when it is among the options given.
private struct TemplateCondition {
    private var tokens: ArraySlice<String>
    private let options: Set<String>

    /// Whether a condition holds for a set of options, and whether it was read
    /// to its end - a condition saying more than this reader knows is not
    /// answered by it.
    static func holds(_ text: String, for options: Set<String>) -> (value: Bool, understood: Bool) {
        var condition = TemplateCondition(tokens: tokenized(text)[...], options: options)
        let value = condition.either()
        return (value, condition.tokens.isEmpty)
    }

    /// The symbols a condition names.
    static func names(in text: String) -> [String] {
        tokenized(text).filter { token in
            guard let first = token.first, first.isLetter || first == "_" else { return false }
            return token != "true" && token != "false"
        }
    }

    /// A condition cut into its names, operators, parentheses and quoted
    /// strings.
    private static func tokenized(_ text: String) -> [String] {
        var tokens: [String] = []
        var rest = Substring(text)

        while let character = rest.first {
            if character.isWhitespace {
                rest = rest.dropFirst()
            } else if let pair = ["&&", "||", "==", "!="].first(where: { rest.hasPrefix($0) }) {
                tokens.append(pair)
                rest = rest.dropFirst(2)
            } else if character == "\"" {
                let body = rest.dropFirst().prefix { $0 != "\"" }
                tokens.append("\"\(body)\"")
                rest = rest.dropFirst(body.count + 2)
            } else {
                let name = rest.prefix { $0.isLetter || $0.isNumber || $0 == "_" }
                let token = name.isEmpty ? String(character) : String(name)
                tokens.append(token)
                rest = rest.dropFirst(token.count)
            }
        }

        return tokens
    }

    private mutating func either() -> Bool {
        var value = both()

        while tokens.first == "||" {
            tokens.removeFirst()
            let right = both()
            value = value || right
        }

        return value
    }

    private mutating func both() -> Bool {
        var value = single()

        while tokens.first == "&&" {
            tokens.removeFirst()
            let right = single()
            value = value && right
        }

        return value
    }

    private mutating func single() -> Bool {
        guard let token = tokens.first else { return false }

        tokens.removeFirst()

        switch token {
        case "!":
            return !single()
        case "(":
            let value = either()

            if tokens.first == ")" {
                tokens.removeFirst()
            }

            return value
        default:
            return options.contains(token)
        }
    }
}
