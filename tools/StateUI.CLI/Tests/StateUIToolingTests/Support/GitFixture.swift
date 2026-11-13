// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

import Foundation
import StateUITooling
import XCTest

/// A StateUI repository of a test's own: a checkout's marks and HelloWorld, committed and tagged, read as a
/// `file://` repository - releases with no network.
enum GitFixture {
    /// A repository tagged with `tags`, its URL as Git reads it.
    static func repository(tagged tags: [String]) async throws -> (folder: URL, url: String) {
        let folder = FileManager.default.temporaryDirectory
            .appendingPathComponent("stateui-cli-tests-\(UUID().uuidString)").appendingPathComponent("origin")
        let files = FileManager.default
        try files.createDirectory(at: folder.appendingPathComponent("lib/StateUI.Head"), withIntermediateDirectories: true)
        try "".write(to: folder.appendingPathComponent("Package.swift"), atomically: true, encoding: .utf8)
        try "".write(to: folder.appendingPathComponent("lib/StateUI.Head/Package.swift"), atomically: true, encoding: .utf8)
        try copy(ProjectReaderTests.repository.appendingPathComponent("apps/HelloWorld"), to: folder.appendingPathComponent("apps/HelloWorld"))

        try await git(["init", "-q"], in: folder)
        try await git(["add", "-A"], in: folder)
        try await git(["-c", "user.name=test", "-c", "user.email=test@example.com", "commit", "-q", "-m", "release"], in: folder)
        for tag in tags { try await git(["tag", tag], in: folder) }
        return (folder, folder.absoluteURL.absoluteString)
    }

    /// Runs Git in `folder`; skips the test where Git cannot be found.
    static func git(_ arguments: [String], in folder: URL) async throws {
        let request = ProcessRequest(.name("git"), arguments: ["-C", folder.path] + arguments, timeout: .seconds(120))
        do {
            let outcome = try await ProcessRunner().run(request)
            XCTAssertTrue(outcome.succeeded, "git \(arguments.joined(separator: " ")) failed")
        } catch ProcessFailure.notFound {
            throw XCTSkip("no git here")
        }
    }

    private static func copy(_ source: URL, to target: URL) throws {
        let files = FileManager.default
        try files.createDirectory(at: target, withIntermediateDirectories: true)
        for entry in try files.contentsOfDirectory(atPath: source.path) where !entry.hasPrefix(".") {
            var isFolder: ObjCBool = false
            if files.fileExists(atPath: source.appendingPathComponent(entry).path, isDirectory: &isFolder), isFolder.boolValue {
                try copy(source.appendingPathComponent(entry), to: target.appendingPathComponent(entry))
            } else {
                try files.copyItem(at: source.appendingPathComponent(entry), to: target.appendingPathComponent(entry))
            }
        }
    }
}
