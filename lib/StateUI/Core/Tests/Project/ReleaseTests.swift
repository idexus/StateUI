// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

import Foundation
import XCTest

@MainActor
final class ReleaseTests: XCTestCase {
    /// Every place that names the release names the one the editor
    /// extension's `package.json` states, the release's only home: the
    /// published-package line in the root's Package.swift, the library's own
    /// `application.info.libraryVersion`, each Android head's version, the Gallery's AppKit
    /// bundle, every UIKit bundle, the bug report's example, and the newest section of the changes. A reader copying
    /// any of them gets this release, not the one before.
    func testEveryMentionOfTheReleaseNamesThisOne() throws {
        let manifest = try JSONSerialization.jsonObject(
            with: Data(contentsOf: SourceTree.repository.appendingPathComponent("editors/VSCode/package.json")))
        let release = try XCTUnwrap(
            (manifest as? [String: Any])?["version"] as? String, "package.json states no version.")

        var mentions: [(file: String, before: String, after: String)] = [
            ("Package.swift", "exact: \"", "\""),
            ("lib/StateUI/Core/Sources/Types/Environment/ApplicationInfo.swift", "libraryVersion = \"", "\""),
            (".github/ISSUE_TEMPLATE/bug.yml", "placeholder: StateUI ", ","),
            (".scripts/AppKit/build-gallery-appkit.sh", "CFBundleShortVersionString -string ", " "),
            (".scripts/UIKit/tools.sh", "CFBundleShortVersionString -string ", " "),
            ("lib/StateUI/StateUI.Android/Tests/Platforms/Android/build.gradle.kts", "versionName = \"", "\""),
        ]

        for application in try SourceTree.applications() {
            let name = application.lastPathComponent
            if FileManager.default.fileExists(atPath: application.appendingPathComponent("Platforms/Android").path) {
                mentions.append(("apps/\(name)/Platforms/Android/build.gradle.kts", "versionName = \"", "\""))
            }
        }

        for mention in mentions {
            let text = try String(
                contentsOf: SourceTree.repository.appendingPathComponent(mention.file), encoding: .utf8)
            XCTAssertEqual(
                text.occurrences(between: mention.before, and: mention.after), [release],
                "\(mention.file) names a release other than \(release).")
        }

        let changes = try String(contentsOf: SourceTree.repository.appendingPathComponent("CHANGELOG.md"), encoding: .utf8)
        XCTAssertEqual(
            changes.occurrences(between: "\n## ", and: " ").first, release,
            "CHANGELOG.md says nothing of \(release) above the releases before it.")
    }

    /// What the newest release says is gone is gone: no name its section lists before "is gone" or "are gone"
    /// stands in the public API's record. A name a later change brought back makes the release's word untrue.
    func testWhatTheNewestReleaseSaysIsGoneIsNotInTheAPI() throws {
        let changes = try String(contentsOf: SourceTree.repository.appendingPathComponent("CHANGELOG.md"), encoding: .utf8)
        let record = try APISurfaceTests.recorded()
        let declared = Set(record.split(separator: "\n").compactMap { line -> String? in
            guard let space = line.firstIndex(of: " "), let colon = line.range(of: ": ") else { return nil }
            return String(line[line.index(after: space)..<colon.lowerBound])
        })

        let newest = changes.components(separatedBy: "\n## ").dropFirst().first ?? ""
        let gone = ReleaseText.namesSaidGone(in: newest)
        XCTAssertFalse(gone.isEmpty, "The guard reads no name the newest release says is gone.")
        for name in gone where ReleaseText.isDeclared(name, among: declared) {
            XCTFail("CHANGELOG.md's newest release says `\(name)` is gone, but the public API declares it.")
        }
    }
}

/// How the changes' prose names what a release took away.
private enum ReleaseText {
    /// The names in backticks a section lists before "is gone" or "are gone" - a list joined by commas and "and",
    /// a rename's target (`a` is `b`) left out - each `.member` given the owner named before it.
    static func namesSaidGone(in section: String) -> [String] {
        let text = section.split(whereSeparator: \.isWhitespace).joined(separator: " ")
        var names: [String] = []
        var searched = text.startIndex
        while let said = text.range(of: #" (is|are) gone"#, options: .regularExpression, range: searched..<text.endIndex) {
            searched = said.upperBound
            var before = Substring(text[..<said.lowerBound])
            var found: [String] = []
            while true {
                let trimmed = before.trimmingSuffix(\.isWhitespace)
                if trimmed.hasSuffix("`"), let opening = trimmed.dropLast().lastIndex(of: "`") {
                    found.append(String(trimmed[trimmed.index(after: opening)..<trimmed.index(before: trimmed.endIndex)]))
                    before = trimmed[..<opening]
                    continue
                }
                if let joint = [",", " and", " the", " its", " of", " events"].first(where: { trimmed.hasSuffix($0) }) {
                    before = trimmed.dropLast(joint.count)
                    continue
                }
                if trimmed.hasSuffix(" is") || trimmed.hasSuffix(" are"), !found.isEmpty {
                    found.removeLast()
                }
                break
            }
            // A member written `.name` in a list belongs to the owner named before it: `Motion.law`, `.curve`.
            var owner: Substring?
            for name in found.reversed() {
                if name.hasPrefix("."), let owner {
                    names.append("\(owner)\(name)")
                } else {
                    names.append(name)
                    owner = name.firstIndex(of: "(") == nil ? name.lastIndex(of: ".").map { name[..<$0] } : nil
                }
            }
        }
        return names
    }

    /// Whether the record declares `name`: a signature written with its labels (`Binding(get:set:)`,
    /// `.magnification(throwing:)`) matched whole, a bare name (`showsMenuArrow`, `Motion.law`) by its base;
    /// code and labels (`Button().icon(_:)`, `sync:`) are no name.
    static func isDeclared(_ name: String, among declared: Set<String>) -> Bool {
        var name = Substring(name)
        while name.first == "." { name = name.dropFirst() }
        if name.hasSuffix(":") || name.contains(" ") || name.contains("{") || name.contains("$") { return false }
        if let parenthesis = name.firstIndex(of: "("), name[parenthesis...].contains(".") { return false }

        let call = name.firstIndex(of: "(")
        let head = call.map { name[..<$0] } ?? name
        var owner: Substring? = head.lastIndex(of: ".").map { head[..<$0] }
        let base = head.lastIndex(of: ".").map { head[head.index(after: $0)...] } ?? head
        if let given = owner, given.first?.isLowercase == true { owner = nil }

        let arguments = call.map { name[name.index(after: $0)..<name.index(before: name.endIndex)] }
        let labels = arguments.map { $0.allSatisfy { $0.isLetter || $0 == "_" || $0 == ":" } } ?? false

        return declared.contains { path in
            let components = path.split(separator: ".")
            guard let last = components.last else { return false }
            if let owner, components.count < 2 || components[components.count - 2] != owner { return false }
            if labels, let arguments {
                if owner == nil, base.first?.isUppercase == true {
                    return path == "\(base).init(\(arguments))"
                }
                return last == "\(base)(\(arguments))"
            }
            return last.prefix { $0 != "(" } == base
        }
    }
}

private extension Substring {
    /// The text with whatever trailing characters `drop` names taken off.
    func trimmingSuffix(_ drop: (Character) -> Bool) -> Substring {
        var text = self
        while let last = text.last, drop(last) { text = text.dropLast() }
        return text
    }
}
