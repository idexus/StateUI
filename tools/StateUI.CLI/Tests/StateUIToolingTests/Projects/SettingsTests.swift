// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

import Foundation
@testable import StateUITooling
import StateUIToolingProtocol
import XCTest

/// What was chosen on this machine stands in the project's `.stateui/`, out of git: the workspace's application to
/// start, the application's host and each host's device - read and made through the tool, and taken by a build that
/// names none.
final class SettingsTests: XCTestCase {
    private static let mark = #"{"build":1,"identifier":"com.example.demo","schemaVersion":1,"version":"1.0.0"}"#

    /// A workspace of `One` (an AppKit head) and `b/Two` (an Android head).
    private func workspace() throws -> URL {
        let root = RealPath.of(FileManager.default.temporaryDirectory)
            .appendingPathComponent("stateui-settings-\(UUID().uuidString)")
        addTeardownBlock { try? FileManager.default.removeItem(at: root) }
        for (path, text) in [
            "One/Package.swift": "", "One/stateui.json": Self.mark, "One/Platforms/AppKit/Package.swift": "",
            "b/Two/Package.swift": "", "b/Two/stateui.json": Self.mark, "b/Two/Platforms/Android/Package.swift": "",
        ] {
            let file = root.appendingPathComponent(path)
            try FileManager.default.createDirectory(at: file.deletingLastPathComponent(), withIntermediateDirectories: true)
            try text.write(to: file, atomically: true, encoding: .utf8)
        }
        try WorkspaceFile(projects: ["One", "b/Two"]).write(to: root.appendingPathComponent(WorkspaceFile.name))
        return root
    }

    /// Nothing chosen: a workspace of several applications means none. Then the one to start, its host and that
    /// host's device are chosen, written in the two files, and a build naming nothing takes them.
    func testChoicesAreMadeReadAndTaken() throws {
        let root = try workspace()
        let service = ToolingService()
        XCTAssertEqual(try service.settings(in: root, application: nil), Settings(workspaceUri: FileURI.string(root)))

        _ = try service.changeSettings(SettingsChange(startup: "Two"), in: root)
        _ = try service.changeSettings(SettingsChange(devices: ["web": "Safari"]), in: root)
        let chosen = try service.changeSettings(SettingsChange(host: .android, devices: ["android": "emulator-5554"]), in: root)

        let two = root.appendingPathComponent("b/Two")
        XCTAssertEqual(chosen, Settings(
            workspaceUri: FileURI.string(root), startup: "Two", applicationUri: FileURI.string(two), host: .android,
            devices: ["android": "emulator-5554", "web": "Safari"]))
        XCTAssertEqual(try WorkspaceSettings.read(in: root).startup, "b/Two")
        XCTAssertEqual(
            try ApplicationSettings.read(in: two), ApplicationSettings(host: .android, devices: ["android": "emulator-5554", "web": "Safari"]))
        let request = try ApplicationBuilder.chosen(BuildRequest(), in: root)
        XCTAssertEqual([request.host?.rawValue, request.device], ["android", "emulator-5554"])
        XCTAssertEqual(try ApplicationBuilder.chosen(BuildRequest(device: "Pixel"), in: root).device, "Pixel")
    }

    /// A choice the project cannot take is refused and nothing is written: an application the workspace does not
    /// list, a host the application has no head for, a device for what is no host.
    func testAChoiceTheProjectCannotTakeIsRefused() throws {
        let root = try workspace()
        let service = ToolingService()
        for change in [
            SettingsChange(startup: "Three"), SettingsChange(application: "One", host: .android),
            SettingsChange(application: "One", devices: ["maui": "iPhone 18 Pro"]),
        ] {
            XCTAssertThrowsError(try service.changeSettings(change, in: root), "\(change)") {
                XCTAssertEqual(($0 as? ToolingError)?.code, .invalidConfiguration)
            }
        }
        XCTAssertFalse(FileManager.default.fileExists(atPath: root.appendingPathComponent(".stateui").path))
        XCTAssertFalse(FileManager.default.fileExists(atPath: root.appendingPathComponent("One/.stateui").path))
    }

    /// An application's settings file choosing a device for no host is refused by what and where; one choosing no
    /// device leaves `devices` out, read back as none.
    func testASettingsFileIsReadWhole() throws {
        let root = try workspace()
        let file = ApplicationSettings.file(in: root.appendingPathComponent("One"))
        try ApplicationSettings(host: .appkit).write(to: file)
        XCTAssertEqual(try String(contentsOf: file, encoding: .utf8), "{\n  \"host\" : \"appkit\",\n  \"schemaVersion\" : 1\n}\n")
        XCTAssertEqual(try ApplicationSettings.read(in: root.appendingPathComponent("One")), ApplicationSettings(host: .appkit))
        try #"{"devices":{"maui":"x"},"schemaVersion":1}"#.write(to: file, atomically: true, encoding: .utf8)
        XCTAssertThrowsError(try ApplicationSettings.read(in: root.appendingPathComponent("One"))) {
            XCTAssertTrue(($0 as? ToolingError)?.message.contains("maui") == true, "\($0)")
        }
    }
}
