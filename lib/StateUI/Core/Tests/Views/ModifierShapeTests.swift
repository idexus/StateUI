// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

import Foundation
import XCTest

/// Every modifier reads alike in the editor's hint: a state it borrows is named `state`, and a modifier of what
/// carries properties - a control, a tier, a style - gives back `Modified`. What configures itself gives back `Self`,
/// each kind of it listed here with why.
/// Design: docs/design/views/modifiers.md#one-shape
@MainActor
final class ModifierShapeTests: XCTestCase {
    /// A binding handed to a modifier or an initializer is named `state`, whatever the property it carries.
    func testEveryStateAViewBorrowsIsNamedState() throws {
        var offenders: [String] = []
        var read = 0

        for source in try Self.views() {
            for (index, line) in source.text.split(separator: "\n", omittingEmptySubsequences: false).enumerated() {
                guard line.range(of: #"public (func \w+|init)(<[^>]*>)?\(_ \w+: Binding<"#, options: .regularExpression)
                    != nil
                else { continue }
                read += 1
                if !line.contains("(_ state: Binding<") { offenders.append("\(source.path):\(index + 1)") }
            }
        }

        XCTAssertGreaterThan(read, 100, "the walk read almost no binding")
        XCTAssertEqual(offenders, [], "a binding a view borrows is named `state`")
    }

    /// A public modifier gives back `Modified` - its own type, for a control - where what it modifies carries
    /// properties; what configures itself gives back `Self` and is listed with why, and a type listed that gives back
    /// nothing so is said.
    func testAModifierGivesBackModifiedOrSaysWhy() throws {
        var offenders: [String] = []
        var configuring: Set<String> = []

        for source in try Self.views() {
            var type: String?
            for (index, line) in source.text.split(separator: "\n", omittingEmptySubsequences: false).enumerated() {
                if let declared = line.firstMatch(of: /^(?:public |@MainActor public |@MainActor )?(?:struct|extension|enum|final class|class|protocol) (\w+)/) {
                    type = String(declared.1)
                }
                guard line.contains(") -> Self {"), line.contains("public func "), !line.contains("func modified(")
                else { continue }
                if let type, Self.configuresItself[type] != nil {
                    configuring.insert(type)
                } else {
                    offenders.append("\(source.path):\(index + 1) \(type ?? "?")")
                }
            }
        }

        let stale = Self.configuresItself.keys.filter { !configuring.contains($0) }.sorted()
        XCTAssertEqual(offenders, [], "a modifier of what carries properties gives back `Modified`")
        XCTAssertEqual(stale, [], "listed as configuring itself, and giving back no `Self`")
    }

    // MARK: - Where `Self` is right, and why

    private static let composed = "a composed view: its modifiers configure the view, which builds its own content"
    private static let scene = "a scene's declaration, which carries no properties"
    private static let entry = "an entry of a menu or a map that wears no tier, so has no `Modified`"

    private static let configuresItself: [String: String] = [
        "GalleryView": composed, "ItemsView": composed, "LayoutEngine": composed, "PositionIndicator": composed,
        "Section": "a list's group, which is no view",
        "Window": scene, "WindowGroup": scene,
        "Menu": entry, "MenuSeparator": entry, "Marker": entry,
    ]

    /// The sources under `Views`.
    private static func views() throws -> [(path: String, text: String)] {
        try SourceTree.allSources().filter { $0.path.hasPrefix("Views/") }
    }
}
