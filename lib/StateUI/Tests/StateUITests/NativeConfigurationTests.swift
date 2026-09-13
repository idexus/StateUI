// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

import Foundation
import XCTest

final class NativeConfigurationTests: XCTestCase {
    private func object(at relative: String) throws -> [String: Any] {
        let data = try Data(contentsOf: Fixtures.repository.appendingPathComponent(relative))
        return try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
    }

    func testEveryLaunchNamesAnExistingNativeBuildTask() throws {
        let launch = try object(at: ".vscode/launch.json")
        let tasks = try object(at: ".vscode/tasks.json")
        let configurations = try XCTUnwrap(launch["configurations"] as? [[String: Any]])
        let declaredTasks = Set(try XCTUnwrap(tasks["tasks"] as? [[String: Any]])
            .compactMap { $0["label"] as? String })

        XCTAssertEqual(configurations.count, 4)
        for configuration in configurations {
            XCTAssertEqual(configuration["type"] as? String, "lldb-dap")
            let task = try XCTUnwrap(configuration["preLaunchTask"] as? String)
            XCTAssertTrue(declaredTasks.contains(task), "missing task \(task)")
        }
    }

    func testActiveEditorConfigurationContainsNoCompatibilityToolchain() throws {
        for relative in [".vscode/launch.json", ".vscode/tasks.json", ".vscode/settings.json"] {
            let value = try String(
                contentsOf: Fixtures.repository.appendingPathComponent(relative),
                encoding: .utf8).lowercased()
            for forbidden in ["dotnet", "maui", ".csproj", "stateui.runtime"] {
                XCTAssertFalse(value.contains(forbidden), "\(relative) still contains \(forbidden)")
            }
        }
    }

    func testTheSwiftExtensionDoesNotAppendRawExecutableLaunches() throws {
        let settings = try object(at: ".vscode/settings.json")
        XCTAssertEqual(settings["swift.autoGenerateLaunchConfigurations"] as? Bool, false)
    }

    func testNativeTestTaskKeepsCoreAndAppKitSeparate() throws {
        let tasks = try object(at: ".vscode/tasks.json")
        let labels = Set(try XCTUnwrap(tasks["tasks"] as? [[String: Any]])
            .compactMap { $0["label"] as? String })

        XCTAssertTrue(labels.contains("Test StateUI"))
        XCTAssertTrue(labels.contains("Test StateUI.AppKit"))
    }
}
