// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

// The VS Code configurations, in the two places they live - this repository's
// .vscode/ and the template's - and the ways they break with nothing said
// anywhere.
//
// Everything here is a NAME in one JSON file pointing at a name in another: a
// launch names its preLaunchTask, a compound names its configurations, a
// Release launch names a field the MAUI extension only believes behind a
// setting. No build reads any of it, so a rename that misses a file does not
// fail - the button simply does nothing when pressed, which reads as "the
// debugger is broken" rather than as a stale string. The renames of 2026-08-06
// left exactly such strings behind twice, both found by grep after the fact;
// these tests read the files so the next one is found first.

import Foundation
import XCTest
@testable import StateUI

final class VsCodeTests: XCTestCase {
    /// The two layouts that carry a .vscode: the repository itself, and the
    /// template - a real application whose copy every generated app receives.
    private var layouts: [(name: String, directory: URL)] {
        [
            ("the repository", Fixtures.repository.appendingPathComponent(".vscode")),
            (
                "the template",
                Fixtures.repository.appendingPathComponent(
                    "src/StateUI.Template/templates/StateUIStarter/.vscode")
            ),
        ]
    }

    /// The files parse as JSON once the comments are gone. A quote or bracket
    /// broken by a hand edit shows up as VS Code silently offering none of the
    /// launches - there is no build to fail - so the suite says it instead.
    func testEveryVsCodeFileIsJsonUnderItsComments() throws {
        for layout in layouts {
            for file in ["launch.json", "tasks.json", "settings.json"] {
                XCTAssertNoThrow(
                    try json(at: layout.directory.appendingPathComponent(file)),
                    "\(file) in \(layout.name) does not parse - VS Code would offer none of it.")
            }
        }
    }

    /// BOTH LAYOUTS OFFER LINUX'S THREE LAUNCHES, and this is a drift test.
    ///
    /// The repository grew them first, against the gallery, and the template did
    /// not follow - so an app from `dotnet new` had F5 for four platforms and
    /// nothing for the fifth, with the picker simply one entry shorter and
    /// nothing saying why. Neither file can be derived from the other (their
    /// paths differ, and the repository carries test launches an app has no use
    /// for), so what is held here is the NAMES and the task they both lean on.
    ///
    /// The MAUI extension's launch type cannot serve this platform - it wants a
    /// workload and a device picker, and the Linux head is a plain net10.0
    /// executable - which is why these are separate entries rather than
    /// something the existing ones could grow. It is also why the CONFIGURATION
    /// is one of them rather than a field: with no extension reading a
    /// `configuration` and no status bar to pick one from, a Release run is a
    /// launch of its own, with a build task and a program path to match.
    func testBothLayoutsLaunchTheLinuxHead() throws {
        for layout in layouts {
            let launch = try String(
                contentsOf: layout.directory.appendingPathComponent("launch.json"), encoding: .utf8)
            let tasks = try String(
                contentsOf: layout.directory.appendingPathComponent("tasks.json"), encoding: .utf8)

            for name in [
                "Debug app (Linux)", "Debug app (Swift, Linux)", "Launch app (Release, Linux)",
            ] {
                XCTAssertTrue(
                    launch.contains("\"name\": \"\(name)\""),
                    "\(layout.name) has no \"\(name)\" - F5 offers nothing on that platform.")
            }

            for label in ["Build app (Linux)", "Build app (Release, Linux)"] {
                XCTAssertTrue(
                    tasks.contains("\"label\": \"\(label)\""),
                    "\(layout.name) declares no \"\(label)\", which a launch above names as "
                        + "its preLaunchTask.")
            }

            // The one framework a Linux host builds, so a picker that cannot
            // offer it leaves Ctrl+Shift+B building something this host has no
            // head for.
            XCTAssertTrue(
                tasks.contains("\"net10.0\""),
                "\(layout.name): the target framework picker does not offer net10.0.")
        }
    }

    /// Every `preLaunchTask` names a task that exists. A launch whose task is
    /// missing fails with a picker about a task that "could not be found" -
    /// accurate, but nothing in it says a rename missed a file, and the
    /// configuration worked yesterday.
    func testEveryPreLaunchTaskIsATaskThatExists() throws {
        for layout in layouts {
            let launch = try json(at: layout.directory.appendingPathComponent("launch.json"))
            let tasks = try json(at: layout.directory.appendingPathComponent("tasks.json"))

            let labels = Set(array(tasks, "tasks").compactMap { $0["label"] as? String })
            XCTAssertFalse(labels.isEmpty, "tasks.json in \(layout.name) declares no tasks at all.")

            for configuration in array(launch, "configurations") {
                guard let task = configuration["preLaunchTask"] as? String else { continue }
                let name = configuration["name"] as? String ?? "an unnamed configuration"

                XCTAssertTrue(
                    labels.contains(task),
                    "\"\(name)\" in \(layout.name) names preLaunchTask \"\(task)\", which "
                        + "tasks.json does not declare - the launch stops before it starts.")
            }
        }
    }

    /// Every configuration a compound names exists in the same launch.json. A
    /// member VS Code cannot find starts nothing, and the compound comes up
    /// with only its other half - the same face as the attach race the
    /// preLaunchTask exists to prevent, pointing away from the real cause.
    func testEveryCompoundMemberIsAConfigurationThatExists() throws {
        for layout in layouts {
            let launch = try json(at: layout.directory.appendingPathComponent("launch.json"))
            let names = Set(array(launch, "configurations").compactMap { $0["name"] as? String })

            let compounds = array(launch, "compounds")
            XCTAssertFalse(
                compounds.isEmpty,
                "\(layout.name) has no compound - \"Debug app (C# + Swift, Mac Catalyst)\" is one.")

            for compound in compounds {
                let members = compound["configurations"] as? [String] ?? []
                let name = compound["name"] as? String ?? "an unnamed compound"

                XCTAssertGreaterThan(
                    members.count, 1,
                    "compound \"\(name)\" in \(layout.name) has fewer than two members.")

                for member in members {
                    XCTAssertTrue(
                        names.contains(member),
                        "compound \"\(name)\" in \(layout.name) names \"\(member)\", which is "
                            + "no configuration in its launch.json.")
                }
            }
        }
    }

    /// THE RELEASE LAUNCH IS BELIEVED, which takes two files agreeing.
    ///
    /// `"configuration": "Release"` is the MAUI extension's own field, and the
    /// extension reads it only while `maui.configuration.useLaunchJsonConfigurations`
    /// is on - a setting that defaults to OFF. With it off, the extension
    /// replaces the value with its active configuration and builds Debug,
    /// saying so nowhere but the "-p:Configuration=Debug" in the task terminal.
    /// Measured on extension 1.16.88, and hit for real: the Release button
    /// built Debug until settings.json turned the flag on. Losing EITHER line
    /// brings that back, so both are pinned, in both layouts.
    func testTheReleaseLaunchIsBelieved() throws {
        for layout in layouts {
            let launch = try json(at: layout.directory.appendingPathComponent("launch.json"))
            let release = array(launch, "configurations").first {
                ($0["configuration"] as? String) == "Release"
            }

            XCTAssertNotNil(
                release, "\(layout.name) has no launch against the Release build.")
            XCTAssertEqual(
                release?["type"] as? String, "maui",
                "the Release launch in \(layout.name) is not the MAUI type, the one that "
                    + "reads the \"configuration\" field.")

            let settings = try json(at: layout.directory.appendingPathComponent("settings.json"))
            XCTAssertEqual(
                settings["maui.configuration.useLaunchJsonConfigurations"] as? Bool, true,
                "settings.json in \(layout.name) does not turn on "
                    + "maui.configuration.useLaunchJsonConfigurations - without it the MAUI "
                    + "extension replaces \"Release\" with its active configuration and the "
                    + "Release launch quietly builds Debug.")
        }
    }

    /// AND ON WINDOWS IT FINDS THE EXECUTABLE, which takes a second field and
    /// a line in the .csproj.
    ///
    /// The MAUI extension works out the BUILD and the PATH TO THE EXECUTABLE in
    /// two different places, and only the first reads the configuration: the
    /// build task appends `-p:Configuration=Release`, while the path comes from
    /// a second `dotnet` of the extension's own - `build -t:_GetTargetPath
    /// -f:<tfm> …` - carrying no Configuration at all. MSBuild defaults to
    /// Debug, so a launch that BUILT Release is pointed at `bin/Debug` and
    /// stops with "program … does not exist" before the app starts. Measured on
    /// extension 1.16.88. An explicit `program` is honoured, which is the whole
    /// fix, and nothing on this side can mend the probe - it never says which
    /// configuration it wants, so a different MSBuild default would break the
    /// Debug launch by the same mechanism.
    ///
    /// THE PATH CARRIES NO ARCHITECTURE, and that is the half in the .csproj:
    /// `AppendRuntimeIdentifierToOutputPath` is false for Windows, so the
    /// executable is not under a `win-arm64` or `win-x64` folder whose name
    /// only the host knows. Losing that property leaves a path that is right on
    /// one machine and wrong on the next - and a generated app is written on a
    /// machine this repository never sees.
    func testTheReleaseLaunchFindsTheExecutableOnWindows() throws {
        // The layouts in the order `layouts` gives them, each with the project
        // that produces what its Release launch starts.
        let projects = [
            (project: "apps/Gallery/Gallery.csproj", name: "Gallery", prefix: "apps/Gallery/"),
            (
                project: "src/StateUI.Template/templates/StateUIStarter/StateUIStarter.csproj",
                name: "StateUIStarter", prefix: ""
            ),
        ]

        for (layout, app) in zip(layouts, projects) {
            let launch = try json(at: layout.directory.appendingPathComponent("launch.json"))
            let release = try XCTUnwrap(
                array(launch, "configurations").first {
                    ($0["configuration"] as? String) == "Release"
                },
                "\(layout.name) has no launch against the Release build.")

            let program = try XCTUnwrap(
                (release["windows"] as? [String: Any])?["program"] as? String,
                "the Release launch in \(layout.name) has no \"windows\": { \"program\" } - "
                    + "the MAUI extension then works the path out itself, without the "
                    + "configuration, and points at bin/Debug.")

            XCTAssertEqual(
                program, "${workspaceFolder}/\(app.prefix)bin/Release/"
                    + "net10.0-windows10.0.19041.0/\(app.name).exe",
                "the Release program in \(layout.name) is not where the Windows build puts "
                    + "the executable.")

            for rid in ["win-arm64", "win-x64", "win10-"] {
                XCTAssertFalse(
                    program.contains(rid),
                    "the Release program in \(layout.name) names \(rid) - a path with an "
                        + "architecture in it is right on one machine and wrong on the next.")
            }

            let csproj = try String(
                contentsOf: Fixtures.repository.appendingPathComponent(app.project),
                encoding: .utf8)

            XCTAssertTrue(
                csproj.contains(
                    "<AppendRuntimeIdentifierToOutputPath>false</AppendRuntimeIdentifierToOutputPath>"),
                "\(app.project) appends the RID to the output path again, so the executable "
                    + "moves under a win-arm64 or win-x64 folder and the Release launch above "
                    + "points at nothing.")

            // The framework in the path is the one the project builds for
            // Windows. A bump here that misses launch.json is the same dialog
            // with a different reason behind it.
            XCTAssertTrue(
                csproj.contains("net10.0-windows10.0.19041.0"),
                "\(app.project) no longer builds net10.0-windows10.0.19041.0, which the "
                    + "Release program in \(layout.name) still names.")
        }
    }

    /// The Release task passes what the scripts read. run-app.sh takes its
    /// arguments by SHAPE, so the task says "Release" and the script has to
    /// recognize that word - and refuse one it does not recognize, because a
    /// mistyped argument taken for a project path was reported as a missing
    /// .csproj, which points at the wrong thing entirely. One copy of each
    /// script serves both layouts: the template takes .scripts/ from the
    /// repository when it is packed.
    func testTheReleaseTaskSpeaksTheScriptsLanguage() throws {
        for layout in layouts {
            let tasks = try json(at: layout.directory.appendingPathComponent("tasks.json"))
            let task = try XCTUnwrap(
                array(tasks, "tasks").first {
                    ($0["label"] as? String) == "Run app (Release, no debugger)"
                },
                "\(layout.name) has no \"Run app (Release, no debugger)\" task.")

            let osx = ((task["osx"] as? [String: Any])?["args"] as? [String]) ?? []
            XCTAssertTrue(
                osx.contains("Release"),
                "the Release task in \(layout.name) does not pass Release to run-app.sh - "
                    + "it would build Debug under a Release label.")

            let windows = ((task["windows"] as? [String: Any])?["args"] as? [String]) ?? []
            XCTAssertTrue(
                windows.contains("-Configuration") && windows.contains("Release"),
                "the Release task in \(layout.name) does not pass -Configuration Release "
                    + "to run-app.ps1.")
        }

        let scripts = Fixtures.repository.appendingPathComponent(".scripts")
        let sh = try String(
            contentsOf: scripts.appendingPathComponent("run-app.sh"), encoding: .utf8)
        XCTAssertTrue(
            sh.contains("[Rr]elease)"),
            "run-app.sh no longer reads a Release argument - the Release task would refuse or misread it.")
        XCTAssertTrue(
            sh.contains("unrecognized argument"),
            "run-app.sh no longer refuses an argument it cannot place - a mistyped one "
                + "becomes the project path and fails as a missing .csproj.")

        let ps = try String(
            contentsOf: scripts.appendingPathComponent("run-app.ps1"), encoding: .utf8)
        XCTAssertTrue(
            ps.contains("$Configuration = \"Debug\""),
            "run-app.ps1 no longer takes -Configuration defaulting to Debug.")
    }

    /// THE CLEAN TASK TAKES EVERYTHING AND ASKS NOTHING, which is the only
    /// thing that makes an edited Info.plist take effect.
    ///
    /// MAUI merges the plist once and never again on an incremental build, and
    /// `obj/` is per configuration AND per framework - so a Debug build that
    /// picked up a new key says nothing about the Release one. It has been
    /// measured four times, the last a Release Mac Catalyst build with no scene
    /// manifest silently refusing a second window while Debug opened it. Every
    /// narrowing is a way to keep that failure: a clean that takes one
    /// configuration, one framework, or asks the person to pick either leaves
    /// exactly the stale copy that is about to be run. So the three directories
    /// a fresh clone does not have go WHOLE, and a prompt in this task is
    /// itself the failure.
    /// THE REPOSITORY'S CLEAN TAKES THE LIBRARY TOO, and the template's does not
    /// have one to take. The app's Swift compiles into the app's own obj/, but
    /// the C# runtime builds in src/StateUI.Runtime/ and the macro plugin in
    /// the library package's .build/ - neither of which a clean named after the
    /// app would touch, leaving one half of a pair rebuilt against the other
    /// from a different moment. A generated app has the library as a package,
    /// so its .build/ beside the project is the whole of it.
    func testTheCleanTaskTakesEverythingAndAsksNothing() throws {
        for layout in layouts {
            let tasks = try json(at: layout.directory.appendingPathComponent("tasks.json"))
            let task = try XCTUnwrap(
                array(tasks, "tasks").first {
                    ($0["label"] as? String) == "Clean app (everything)"
                },
                "\(layout.name) has no \"Clean app (everything)\" task - an edited "
                    + "Info.plist then needs a path typed by hand to take effect.")

            let args = (task["args"] as? [String] ?? []).joined(separator: " ")
            let windows =
                ((task["windows"] as? [String: Any])?["args"] as? [String] ?? [])
                .joined(separator: " ")

            for shell in [("rm", args), ("Remove-Item", windows)] {
                for wanted in ["obj", "bin", ".build"] {
                    // The directory WHOLE: the path ends there, with a quote, a
                    // space or the end of the command behind it. A slash after
                    // it is a configuration or a framework inside it, which is
                    // the narrowing this test exists to refuse.
                    XCTAssertTrue(
                        shell.1.contains("/\(wanted)'") || shell.1.contains("/\(wanted) ")
                            || shell.1.hasSuffix("/\(wanted)"),
                        "the clean task in \(layout.name) does not remove \(wanted)/ whole on "
                            + "its \(shell.0) side - what it leaves behind is the stale copy "
                            + "the next run picks up.")
                }

                XCTAssertFalse(
                    shell.1.contains("${input:"),
                    "the clean task in \(layout.name) asks a question on its \(shell.0) side - "
                        + "an answer narrows the clean, and the copy it then misses is the "
                        + "one that was stale.")

            }
        }
    }

    /// AND THE REPOSITORY CARRIES A SECOND, DEEPER CUT.
    ///
    /// The app's Swift compiles into the app's own `obj/`, but the C# runtime
    /// builds in `src/StateUI.Runtime/`, the Linux platform in
    /// `src/StateUI.Runtime.Linux/`, and the macro plugin in the library
    /// package's `.build/` - so a clean named after the app rebuilds one half of
    /// a pair against a copy of the other from a different moment, which is the
    /// shape that parks every `await` that crosses and reports nothing. A
    /// generated app has neither directory: the library reaches it as a package,
    /// so its own `.build/` is the whole of it and "Clean app" is the deepest cut
    /// there is. Hence two tasks here and one there.
    func testTheRepositoryCanCleanTheLibraryToo() throws {
        let tasks = try json(
            at: Fixtures.repository.appendingPathComponent(".vscode/tasks.json"))

        let task = try XCTUnwrap(
            array(tasks, "tasks").first {
                ($0["label"] as? String) == "Clean all (app and library)"
            },
            "the repository has no \"Clean all (app and library)\" task - the library's "
                + "halves then survive every clean the buttons offer.")

        let args = (task["args"] as? [String] ?? []).joined(separator: " ")
        let windows =
            ((task["windows"] as? [String: Any])?["args"] as? [String] ?? [])
            .joined(separator: " ")

        for shell in [("rm", args), ("Remove-Item", windows)] {
            for wanted in [
                "apps/Gallery/obj",
                "apps/Gallery/bin",
                "src/StateUI.Runtime/obj",
                "src/StateUI.Runtime/bin",
                "src/StateUI.Runtime.Linux/obj",
                "src/StateUI.Runtime.Linux/bin",
            ] {
                XCTAssertTrue(
                    shell.1.contains(wanted),
                    "the deep clean leaves \(wanted) standing on its \(shell.0) side.")
            }

            XCTAssertTrue(
                shell.1.contains("}/.build"),
                "the deep clean leaves the library package's .build/ standing on its "
                    + "\(shell.0) side, which is where the macro plugin is built.")
        }
    }

    /// THE PICKER'S ORDER IS `presentation.order`, NOT THE ORDER IN THE FILE -
    /// and the widest-reaching launch is first.
    ///
    /// "Debug app (C#)" is the one that runs on every platform and every
    /// device, so it is what F5 offers before anything has been chosen. A
    /// compound written last in the file and carrying `order: 1` would hold
    /// that place - which is exactly the mistake this reads for: a
    /// configuration moved in the file changes nothing, and a number changed
    /// by hand changes everything, with the two looking equally deliberate.
    ///
    /// Two orders that COLLIDE are the same failure quieter: VS Code then
    /// breaks the tie however it likes, and the first entry stops being
    /// anybody's decision.
    func testTheWidestLaunchIsFirstInThePicker() throws {
        for layout in layouts {
            let launch = try json(at: layout.directory.appendingPathComponent("launch.json"))

            // A compound is sorted in AMONG the configurations, so both lists
            // are read - which is the whole reason the compound could be first
            // while nothing in the configurations said so.
            let entries = (array(launch, "configurations") + array(launch, "compounds"))
                .compactMap { entry -> (group: String, order: Int, name: String)? in
                    guard let name = entry["name"] as? String,
                          let presentation = entry["presentation"] as? [String: Any],
                          let group = presentation["group"] as? String,
                          let order = presentation["order"] as? Int else { return nil }

                    return (group, order, name)
                }

            XCTAssertEqual(
                entries.count,
                array(launch, "configurations").count + array(launch, "compounds").count,
                "something in \(layout.name) has no presentation group and order, so where "
                    + "it lands in the picker is not this file's decision.")

            var seen: Set<String> = []

            for entry in entries {
                XCTAssertTrue(
                    seen.insert("\(entry.group)/\(entry.order)").inserted,
                    "\"\(entry.name)\" in \(layout.name) shares group \(entry.group) order "
                        + "\(entry.order) with another entry - VS Code breaks that tie itself.")
            }

            let first = entries
                .filter { $0.group == "1 app" }
                .min { $0.order < $1.order }?
                .name

            XCTAssertEqual(
                first, "Debug app (C#)",
                "the app group in \(layout.name) offers \"\(first ?? "nothing")\" first. "
                    + "\"Debug app (C#)\" belongs there: it is the only one that works on "
                    + "every platform and every device, and it is what F5 runs before "
                    + "anything is chosen.")
        }
    }

    // MARK: - Helpers

    /// JSON with comments, which is what VS Code writes, reduced to the JSON
    /// underneath: line comments go, and so does a trailing comma before a
    /// closing bracket - the two things VS Code tolerates and
    /// JSONSerialization does not. String-aware, because "https://" inside a
    /// value is not a comment and a comma inside an argument string is not
    /// trailing anything.
    private func json(at url: URL) throws -> [String: Any] {
        let text = try String(contentsOf: url, encoding: .utf8)
        var scrubbed = ""
        var rest = Substring(text)

        while let character = rest.first {
            switch character {
            case "\"":
                // Copy the whole string literal, escapes included.
                scrubbed.append(character)
                rest = rest.dropFirst()
                var escaped = false
                while let inner = rest.first {
                    scrubbed.append(inner)
                    rest = rest.dropFirst()
                    if escaped {
                        escaped = false
                    } else if inner == "\\" {
                        escaped = true
                    } else if inner == "\"" {
                        break
                    }
                }
            case "/" where rest.hasPrefix("//"):
                // A line comment: gone to the end of its line.
                while let inner = rest.first, inner != "\n" { rest = rest.dropFirst() }
            case ",":
                // A trailing comma: dropped when nothing but whitespace sits
                // between it and the closing bracket.
                var ahead = rest.dropFirst()
                while let inner = ahead.first, inner.isWhitespace { ahead = ahead.dropFirst() }
                if ahead.first == "}" || ahead.first == "]" {
                    rest = rest.dropFirst()
                } else {
                    scrubbed.append(character)
                    rest = rest.dropFirst()
                }
            default:
                scrubbed.append(character)
                rest = rest.dropFirst()
            }
        }

        let object = try JSONSerialization.jsonObject(with: Data(scrubbed.utf8))
        return try XCTUnwrap(
            object as? [String: Any], "\(url.lastPathComponent) is not a JSON object.")
    }

    /// The dictionaries under a key, or nothing - never a type error.
    private func array(_ object: [String: Any], _ key: String) -> [[String: Any]] {
        object[key] as? [[String: Any]] ?? []
    }
}
