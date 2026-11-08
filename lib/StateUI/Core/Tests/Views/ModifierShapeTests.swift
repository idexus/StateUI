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

    /// A state only the platform writes - registered `.in`, or set from an event - is handed `into:`, and a state
    /// handed `into:` is one only the platform writes: the label gives the direction.
    func testAStateOnlyThePlatformWritesIsHandedInto() throws {
        var offenders: [String] = []
        var feeds = 0

        for source in try Self.views() {
            let lines = source.text.split(separator: "\n", omittingEmptySubsequences: false)
            for (index, line) in lines.enumerated() {
                guard let declared = line.firstMatch(of: /public func (\w+)\((_|into) state: Binding</) else { continue }
                let body = lines[(index + 1)...].prefix { !$0.hasPrefix("    }") }.joined(separator: "\n")
                let platformWrites = body.contains("mode: .in)") || body.contains("mode: .in,") || body.contains("as: .feed)")
                    || (body.contains("onEvent(") && body.contains("state.wrappedValue = "))
                if platformWrites { feeds += 1 }
                if platformWrites != (declared.2 == "into") {
                    offenders.append("\(source.path):\(index + 1) \(declared.1)")
                }
            }
        }

        XCTAssertGreaterThanOrEqual(feeds, 5, "the walk found almost no feed")
        XCTAssertEqual(offenders, [], "a state only the platform writes is handed `into:`, and no other")
    }

    /// A handler's policy is written `policy:`, as a gate is `gate:`, after every argument of the event's own, which
    /// may be left out before it: each event is heard three ways - plainly, with a policy, through a gate - so a
    /// policy is never spelled two ways for one event.
    func testAPolicyIsWrittenWithItsWord() throws {
        var unlabeled: [String] = []
        var forms: [String: (plain: Int, policy: Int, gate: Int)] = [:]

        for source in try Self.views() {
            for found in source.text.matches(of: /public func (on\w+)(?:<[^>]*>)?\(([^{]*?)\)\s*->/) {
                let parameters = found.2.split(separator: "\n").map { $0.trimmingCharacters(in: .whitespaces) }
                    .joined(separator: " ")
                let name = String(found.1)
                if parameters.contains("_ policy: GatePolicy") { unlabeled.append("\(source.path) \(name)") }
                var counted = forms[name] ?? (0, 0, 0)
                if parameters.contains("policy: GatePolicy") {
                    counted.policy += 1
                } else if parameters.contains("gate: Gate") {
                    counted.gate += 1
                } else {
                    counted.plain += 1
                }
                forms[name] = counted
            }
        }
        let uneven = forms.filter { $0.value.policy > 0 && ($0.value.policy != $0.value.plain || $0.value.policy != $0.value.gate) }

        XCTAssertGreaterThan(forms.values.filter { $0.policy > 0 }.count, 30, "the walk found almost no policy")
        XCTAssertEqual(unlabeled, [], "a policy is written `policy:`")
        XCTAssertEqual(uneven.keys.sorted(), [], "an event heard with a policy in more forms than plainly or through a gate")
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
    private static let entry = "an entry of a menu, a bar or a map that wears no tier, so has no `Modified`"

    private static let configuresItself: [String: String] = [
        "GalleryView": composed, "ItemsView": composed, "MotionLayout": composed, "PositionDots": composed,
        "Section": "a list's group, which is no view",
        "Window": scene, "WindowGroup": scene,
        "Menu": entry, "MenuSeparator": entry, "Marker": entry, "ToolbarGroup": entry,
    ]

    /// The sources under `Views`.
    private static func views() throws -> [(path: String, text: String)] {
        try SourceTree.allSources().filter { $0.path.hasPrefix("Views/") }
    }
}
