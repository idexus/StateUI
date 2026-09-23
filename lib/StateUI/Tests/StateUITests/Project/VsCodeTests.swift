// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

// The VS Code configurations and the ways they break with nothing said
// anywhere.
//
// Everything here is a NAME in one JSON file pointing at a name in another: a
// launch names its preLaunchTask, a task names a script, a Release launch
// becomes a field the MAUI extension only believes behind a setting. No build reads any of it, so a rename that misses a file does not
// fail - the button simply does nothing when pressed, which reads as "the
// debugger is broken" rather than as a stale string.

import Foundation
import XCTest

final class VsCodeTests: XCTestCase {
    /// The layouts that carry a .vscode: this repository's, and the one every
    /// application made from the template starts with. Read with its template
    /// lines in place - they are comments to JSON, and every launch holds
    /// whichever way they resolve.
    private var layouts: [(name: String, directory: URL)] {
        [("the repository", Fixtures.repository.appendingPathComponent(".vscode")),
         ("the template", Fixtures.templateApplication.appendingPathComponent(".vscode"))]
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

    /// The launches are the StateUI extension's: ONE Debug and ONE Release of
    /// type `stateui`, which the extension resolves into the chosen host's own
    /// debugger - AppKit, every MAUI platform, Linux's included. No launch
    /// names a host or an application of its own any more, so none can drift
    /// from the extension that chooses them.
    func testTheLaunchesAreTheExtensions() throws {
        for layout in layouts {
            let launch = try json(at: layout.directory.appendingPathComponent("launch.json"))
            let configurations = array(launch, "configurations")
            let stateUI = configurations.filter { ($0["type"] as? String) == "stateui" }

            XCTAssertEqual(
                stateUI.compactMap { $0["name"] as? String }, ["StateUI: Debug", "StateUI: Release"],
                "\(layout.name) does not offer exactly StateUI: Debug and StateUI: Release.")
            XCTAssertEqual(stateUI.compactMap { $0["configuration"] as? String }, ["debug", "release"])

            for entry in configurations {
                let name = entry["name"] as? String ?? "?"
                XCTAssertFalse(
                    ["lldb-dap", "maui"].contains(entry["type"] as? String),
                    "\(layout.name) launches \"\(name)\" itself - the extension resolves launches.")
            }
            XCTAssertTrue(array(launch, "compounds").isEmpty,
                          "\(layout.name) has a compound - C# with Swift is the extension's debugger.")

            let tasks = try String(
                contentsOf: layout.directory.appendingPathComponent("tasks.json"), encoding: .utf8)
            XCTAssertTrue(
                tasks.contains("\"net10.0\""),
                "\(layout.name): the target framework picker does not offer net10.0.")
        }
    }

    /// Every `preLaunchTask` names a task that exists. A launch whose task is
    /// missing fails with a picker about a task that "could not be found" -
    /// accurate, but nothing in it says a rename missed a file.
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

    /// THE RELEASE LAUNCH IS BELIEVED, which takes the extension and a setting
    /// agreeing: on MAUI "StateUI: Release" becomes a `maui` launch carrying
    /// `"configuration": "Release"`, which the MAUI extension reads only while
    /// `maui.configuration.useLaunchJsonConfigurations` is on - a setting that
    /// defaults to OFF, and with it off the Release launch quietly builds Debug.
    func testTheReleaseLaunchIsBelieved() throws {
        for layout in layouts {
            let launch = try json(at: layout.directory.appendingPathComponent("launch.json"))
            XCTAssertNotNil(
                array(launch, "configurations").first { ($0["configuration"] as? String) == "release" },
                "\(layout.name) has no launch against the Release build.")

            let settings = try json(at: layout.directory.appendingPathComponent("settings.json"))
            XCTAssertEqual(
                settings["maui.configuration.useLaunchJsonConfigurations"] as? Bool, true,
                "settings.json in \(layout.name) does not turn on "
                    + "maui.configuration.useLaunchJsonConfigurations.")
        }
    }

    /// AND ON WINDOWS IT FINDS THE EXECUTABLE: the MAUI extension works the
    /// executable out without the configuration, so the extension names the
    /// Release program - and the path it builds carries no architecture only
    /// because the project keeps the runtime identifier out of its output path.
    /// The extension's own suite asserts the path; this holds the project to it.
    func testTheWindowsReleaseExecutableHasTheExtensionsPath() throws {
        let debug = try String(
            contentsOf: Fixtures.repository.appendingPathComponent("lib/StateUI.VSCode/Sources/debug.ts"),
            encoding: .utf8)
        XCTAssertTrue(debug.contains("\"bin\", \"Release\", \"net10.0-windows10.0.19041.0\""),
                      "the extension no longer names the Windows Release executable.")

        let csproj = try String(
            contentsOf: Fixtures.repository.appendingPathComponent(
                "apps/Gallery/Platforms/Maui/Gallery.csproj"),
            encoding: .utf8)

        XCTAssertTrue(csproj.contains(
            "<AppendRuntimeIdentifierToOutputPath>false</AppendRuntimeIdentifierToOutputPath>"))
        XCTAssertTrue(csproj.contains("net10.0-windows10.0.19041.0"))
    }

    /// The Release task passes what the scripts read. run-app.sh takes its
    /// arguments by SHAPE, so the task says "Release" and the script has to
    /// recognize that word - and refuse one it does not recognize. The
    /// repository's task alone: an application made from the template keeps
    /// no scripts, and runs without a debugger through StateUI: Release.
    func testTheReleaseTaskSpeaksTheScriptsLanguage() throws {
        for layout in layouts.prefix(1) {
            let tasks = try json(at: layout.directory.appendingPathComponent("tasks.json"))
            let task = try XCTUnwrap(
                array(tasks, "tasks").first {
                    ($0["label"] as? String) == "Run app (Release, no debugger)"
                },
                "\(layout.name) has no \"Run app (Release, no debugger)\" task.")

            let osx = ((task["osx"] as? [String: Any])?["args"] as? [String]) ?? []
            XCTAssertTrue(osx.contains("Release"))

            let windows = ((task["windows"] as? [String: Any])?["args"] as? [String]) ?? []
            XCTAssertTrue(windows.contains("-Configuration") && windows.contains("Release"))
        }

        let scripts = Fixtures.repository.appendingPathComponent(".scripts/Maui")
        let sh = try String(contentsOf: scripts.appendingPathComponent("run-app.sh"), encoding: .utf8)
        XCTAssertTrue(sh.contains("[Rr]elease)"))
        XCTAssertTrue(sh.contains("unrecognized argument"))

        let ps = try String(contentsOf: scripts.appendingPathComponent("run-app.ps1"), encoding: .utf8)
        XCTAssertTrue(ps.contains("$Configuration = \"Debug\""))
    }

    /// THE CLEAN TASK TAKES EVERYTHING AND ASKS NOTHING, which is the only
    /// thing that makes an edited Info.plist take effect: MAUI merges the plist
    /// once and never again on an incremental build, and `obj/` is per
    /// configuration AND per framework, so every narrowing keeps a stale copy.
    func testTheCleanTaskTakesEverythingAndAsksNothing() throws {
        for layout in layouts {
            let tasks = try json(at: layout.directory.appendingPathComponent("tasks.json"))
            let task = try XCTUnwrap(
                array(tasks, "tasks").first { ($0["label"] as? String) == "Clean app (everything)" },
                "\(layout.name) has no \"Clean app (everything)\" task.")

            let args = (task["args"] as? [String] ?? []).joined(separator: " ")
            let windows = ((task["windows"] as? [String: Any])?["args"] as? [String] ?? [])
                .joined(separator: " ")

            for shell in [("rm", args), ("Remove-Item", windows)] {
                for wanted in ["obj", "bin", ".build"] {
                    XCTAssertTrue(
                        shell.1.contains("/\(wanted)'") || shell.1.contains("/\(wanted) ")
                            || shell.1.hasSuffix("/\(wanted)"),
                        "the clean task in \(layout.name) does not remove \(wanted)/ whole on "
                            + "its \(shell.0) side.")
                }

                XCTAssertFalse(
                    shell.1.contains("${input:"),
                    "the clean task in \(layout.name) asks a question on its \(shell.0) side.")
            }
        }
    }

    /// AND THE REPOSITORY CARRIES A SECOND, DEEPER CUT: the MAUI host builds in
    /// its own directories, so a clean named after the app rebuilds one half of
    /// a pair against a copy of the other from a different moment.
    func testTheRepositoryCanCleanTheLibraryToo() throws {
        let tasks = try json(at: Fixtures.repository.appendingPathComponent(".vscode/tasks.json"))
        let task = try XCTUnwrap(
            array(tasks, "tasks").first { ($0["label"] as? String) == "Clean all (app and library)" },
            "the repository has no \"Clean all (app and library)\" task.")

        let args = (task["args"] as? [String] ?? []).joined(separator: " ")
        let windows = ((task["windows"] as? [String: Any])?["args"] as? [String] ?? [])
            .joined(separator: " ")

        for shell in [("rm", args), ("Remove-Item", windows)] {
            for wanted in [
                "apps/Gallery/Platforms/Maui/obj",
                "apps/Gallery/Platforms/Maui/bin",
                "lib/StateUI.Maui/Sources/obj",
                "lib/StateUI.Maui/Sources/bin",
                "lib/StateUI.Maui/Linux/obj",
                "lib/StateUI.Maui/Linux/bin",
            ] {
                XCTAssertTrue(
                    shell.1.contains(wanted),
                    "the deep clean leaves \(wanted) standing on its \(shell.0) side.")
            }

            XCTAssertTrue(shell.1.contains("}/.build"))
        }
    }

    /// THE PICKER'S ORDER IS `presentation.order`, NOT THE ORDER IN THE FILE,
    /// and StateUI: Debug is the first launch offered.
    /// Two orders that collide are VS Code's to break however it likes.
    func testTheWidestLaunchIsFirstInItsGroup() throws {
        for layout in layouts {
            let launch = try json(at: layout.directory.appendingPathComponent("launch.json"))
            let all = array(launch, "configurations") + array(launch, "compounds")
            let entries = all.compactMap { entry -> (group: String, order: Int, name: String)? in
                guard let name = entry["name"] as? String,
                      let presentation = entry["presentation"] as? [String: Any],
                      let group = presentation["group"] as? String,
                      let order = presentation["order"] as? Int else { return nil }

                return (group, order, name)
            }

            XCTAssertEqual(
                entries.count, all.count,
                "something in \(layout.name) has no presentation group and order.")

            var seen: Set<String> = []
            for entry in entries {
                XCTAssertTrue(
                    seen.insert("\(entry.group)/\(entry.order)").inserted,
                    "\"\(entry.name)\" in \(layout.name) shares group \(entry.group) order "
                        + "\(entry.order) with another entry.")
            }

            func first(_ group: String) -> String? {
                entries.filter { $0.group == group }.min { $0.order < $1.order }?.name
            }

            XCTAssertEqual(first("0 StateUI"), "StateUI: Debug")
        }
    }

    /// The Swift extension appends no raw executable launches of its own, and
    /// no settings file decides the editor's host over the StateUI extension:
    /// every configuration here is deliberate.
    func testTheSwiftExtensionDoesNotAppendRawExecutableLaunches() throws {
        for layout in layouts {
            let settings = try json(at: layout.directory.appendingPathComponent("settings.json"))
            XCTAssertEqual(
                settings["swift.autoGenerateLaunchConfigurations"] as? Bool, false,
                "\(layout.name) lets the Swift extension add a Debug and a Release of every executable.")
            XCTAssertNil(
                settings["swift.swiftEnvironmentVariables"],
                "\(layout.name) sets the editor's host in settings, over the StateUI extension's choice.")
        }

        let recommended = try json(at: Fixtures.templateApplication.appendingPathComponent(".vscode/extensions.json"))
        XCTAssertTrue(
            (recommended["recommendations"] as? [String] ?? []).contains("idexus.stateui"),
            "an application made from the template does not recommend the extension its launches need.")
    }

    /// Each host's suite is a task of its own, beside the default that runs
    /// the Swift ones.
    func testEveryHostsSuiteIsATaskOfItsOwn() throws {
        let tasks = try json(at: Fixtures.repository.appendingPathComponent(".vscode/tasks.json"))
        let labels = Set(array(tasks, "tasks").compactMap { $0["label"] as? String })

        for label in ["Test StateUI", "Test StateUI.AppKit", "Test StateUI.Maui", "Test Gallery"] {
            XCTAssertTrue(labels.contains(label), "tasks.json declares no \"\(label)\"")
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
                while let inner = rest.first, inner != "\n" { rest = rest.dropFirst() }
            case ",":
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
        return try XCTUnwrap(object as? [String: Any], "\(url.lastPathComponent) is not a JSON object.")
    }

    /// The dictionaries under a key, or nothing - never a type error.
    private func array(_ object: [String: Any], _ key: String) -> [[String: Any]] {
        object[key] as? [[String: Any]] ?? []
    }
}
