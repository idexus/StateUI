// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

// The VS Code configurations and the ways they break with nothing said
// anywhere.
//
// Everything here is a NAME in one JSON file pointing at a name in another: a
// launch names its preLaunchTask, a task names a script. No build reads any of
// it, so a rename that misses a file does not fail - the button simply does
// nothing when pressed, which reads as "the debugger is broken" rather than as
// a stale string.

import Foundation
import XCTest

final class VsCodeTests: XCTestCase {
    /// The repository's `.vscode`.
    private var directory: URL {
        SourceTree.repository.appendingPathComponent(".vscode")
    }

    /// The files parse as JSON once the comments are gone. A quote or bracket
    /// broken by a hand edit shows up as VS Code silently offering none of the
    /// launches - there is no build to fail - so the suite says it instead.
    func testEveryVsCodeFileIsJsonUnderItsComments() throws {
        for file in ["launch.json", "tasks.json", "settings.json"] {
            XCTAssertNoThrow(
                try json(at: directory.appendingPathComponent(file)),
                "\(file) does not parse - VS Code would offer none of it.")
        }
    }

    /// The launches are the StateUI extension's: ONE Debug and ONE Release of
    /// type `stateui`, which the extension resolves into the chosen host's own
    /// debugger - AppKit's or Android's. No launch names a host or an
    /// application of its own, so none can drift from the extension that
    /// chooses them.
    func testTheLaunchesAreTheExtensions() throws {
        let launch = try json(at: directory.appendingPathComponent("launch.json"))
        let configurations = array(launch, "configurations")
        let stateUI = configurations.filter { ($0["type"] as? String) == "stateui" }

        XCTAssertEqual(
            stateUI.compactMap { $0["name"] as? String }, ["StateUI: Debug", "StateUI: Release"],
            "launch.json does not offer exactly StateUI: Debug and StateUI: Release.")
        XCTAssertEqual(stateUI.compactMap { $0["configuration"] as? String }, ["debug", "release"])

        for entry in configurations {
            let name = entry["name"] as? String ?? "?"
            XCTAssertFalse(
                ["lldb-dap", "maui"].contains(entry["type"] as? String),
                "launch.json launches \"\(name)\" itself - the extension resolves launches.")
        }
        XCTAssertTrue(array(launch, "compounds").isEmpty,
                      "launch.json has a compound - a launch is the extension's to resolve.")
    }

    /// Every `preLaunchTask` names a task that exists. A launch whose task is
    /// missing fails with a picker about a task that "could not be found" -
    /// accurate, but nothing in it says a rename missed a file.
    func testEveryPreLaunchTaskIsATaskThatExists() throws {
        let launch = try json(at: directory.appendingPathComponent("launch.json"))
        let tasks = try json(at: directory.appendingPathComponent("tasks.json"))

        let labels = Set(array(tasks, "tasks").compactMap { $0["label"] as? String })
        XCTAssertFalse(labels.isEmpty, "tasks.json declares no tasks at all.")

        for configuration in array(launch, "configurations") {
            guard let task = configuration["preLaunchTask"] as? String else { continue }
            let name = configuration["name"] as? String ?? "an unnamed configuration"

            XCTAssertTrue(
                labels.contains(task),
                "\"\(name)\" names preLaunchTask \"\(task)\", which tasks.json does not declare - "
                    + "the launch stops before it starts.")
        }
    }

    /// The editor runs no .NET: no task, launch or setting names a MAUI head,
    /// the MAUI extension or `dotnet`. A head is run by the StateUI extension,
    /// on AppKit or Android.
    func testTheEditorRunsNoDotNet() throws {
        for file in ["launch.json", "tasks.json", "settings.json"] {
            let text = try String(contentsOf: directory.appendingPathComponent(file), encoding: .utf8)

            for spelling in [
                "Platforms/Maui", "\"maui.", "\"type\": \"maui\"", ".scripts/Maui", "dotnet", "coreclr", "StateUI.Maui",
            ] {
                XCTAssertFalse(text.contains(spelling), "\(file) still says \(spelling).")
            }
        }
    }

    /// THE PICKER'S ORDER IS `presentation.order`, NOT THE ORDER IN THE FILE,
    /// and StateUI: Debug is the first launch offered.
    /// Two orders that collide are VS Code's to break however it likes.
    func testTheWidestLaunchIsFirstInItsGroup() throws {
        let launch = try json(at: directory.appendingPathComponent("launch.json"))
        let all = array(launch, "configurations") + array(launch, "compounds")
        let entries = all.compactMap { entry -> (group: String, order: Int, name: String)? in
            guard let name = entry["name"] as? String,
                  let presentation = entry["presentation"] as? [String: Any],
                  let group = presentation["group"] as? String,
                  let order = presentation["order"] as? Int else { return nil }

            return (group, order, name)
        }

        XCTAssertEqual(entries.count, all.count, "something in launch.json has no presentation group and order.")

        var seen: Set<String> = []
        for entry in entries {
            XCTAssertTrue(
                seen.insert("\(entry.group)/\(entry.order)").inserted,
                "\"\(entry.name)\" shares group \(entry.group) order \(entry.order) with another entry.")
        }

        func first(_ group: String) -> String? {
            entries.filter { $0.group == group }.min { $0.order < $1.order }?.name
        }

        XCTAssertEqual(first("0 StateUI"), "StateUI: Debug")
    }

    /// The Swift extension appends no raw executable launches of its own, and
    /// no settings file decides the editor's host over the StateUI extension:
    /// every configuration here is deliberate.
    func testTheSwiftExtensionDoesNotAppendRawExecutableLaunches() throws {
        let settings = try json(at: directory.appendingPathComponent("settings.json"))
        XCTAssertEqual(
            settings["swift.autoGenerateLaunchConfigurations"] as? Bool, false,
            "settings.json lets the Swift extension add a Debug and a Release of every executable.")
        XCTAssertNil(
            settings["swift.swiftEnvironmentVariables"],
            "settings.json sets the editor's host, over the StateUI extension's choice.")
    }

    /// Each host's suite is a task of its own, beside the default that runs
    /// the Swift ones.
    func testEveryHostsSuiteIsATaskOfItsOwn() throws {
        let tasks = try json(at: directory.appendingPathComponent("tasks.json"))
        let labels = Set(array(tasks, "tasks").compactMap { $0["label"] as? String })

        for label in ["Test StateUI", "Test StateUI.AppKit", "Test Gallery"] {
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
