// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

import Foundation
import XCTest

final class ReleaseTests: XCTestCase {
    /// Every place that names the release names the one the editor
    /// extension's `package.json` states, the release's only home: the
    /// published-package line in the root's and each application's
    /// Package.swift, each Android head's version, the Gallery's AppKit
    /// bundle and the bug report's example. A reader copying any of them gets
    /// this release, not the one before.
    func testEveryMentionOfTheReleaseNamesThisOne() throws {
        let manifest = try JSONSerialization.jsonObject(
            with: Data(contentsOf: Fixtures.repository.appendingPathComponent("lib/StateUI.VSCode/package.json")))
        let release = try XCTUnwrap(
            (manifest as? [String: Any])?["version"] as? String, "package.json states no version.")

        var mentions: [(file: String, before: String, after: String)] = [
            ("Package.swift", "exact: \"", "\""),
            (".github/ISSUE_TEMPLATE/bug.yml", "placeholder: StateUI ", ","),
            (".scripts/AppKit/build-gallery-appkit.sh", "CFBundleShortVersionString -string ", " "),
            ("lib/StateUI.Android/Tests/Platforms/Android/build.gradle.kts", "versionName = \"", "\""),
        ]

        for application in try Fixtures.applications() {
            let name = application.lastPathComponent
            mentions.append(("apps/\(name)/Package.swift", "exact: \"", "\""))

            if FileManager.default.fileExists(atPath: application.appendingPathComponent("Platforms/Android").path) {
                mentions.append(("apps/\(name)/Platforms/Android/build.gradle.kts", "versionName = \"", "\""))
            }
        }

        for mention in mentions {
            let text = try String(
                contentsOf: Fixtures.repository.appendingPathComponent(mention.file), encoding: .utf8)
            XCTAssertEqual(
                text.occurrences(between: mention.before, and: mention.after), [release],
                "\(mention.file) names a release other than \(release).")
        }
    }
}
