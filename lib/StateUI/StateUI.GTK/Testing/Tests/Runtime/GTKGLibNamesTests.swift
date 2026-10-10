// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

import Foundation
import XCTest

/// GLib marks its flags as flag enumerations from 2.86, and Swift then imports them as option sets naming their
/// members itself: a GLib flag Swift names by GLib's own constant builds on one GLib and not on the next.
@MainActor
final class GTKGLibNamesTests: XCTestCase {
    /// The GLib enumerations no flags are made of, whose constants Swift names as GLib does.
    private static let plainEnumerations = ["G_PRIORITY_", "G_BUS_TYPE_", "G_NETWORK_CONNECTIVITY_"]

    /// Every GLib constant Swift names is one of a plain enumeration: a flag stands in CStateUIGTK.h under a name of
    /// the host's, which C resolves on every GLib, and a set of flags made of a number is made by `rawValue:`.
    func testSwiftNamesNoGLibFlag() throws {
        let tests = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
        let testing = tests.deletingLastPathComponent()
        let host = testing.deletingLastPathComponent()
        let roots = [host.appendingPathComponent("Sources"), testing.appendingPathComponent("Sources"), tests,
                     host.appendingPathComponent("../../../apps/Gallery/Platforms/GTK").standardized,
                     host.appendingPathComponent("../../../apps/Gallery/Sources").standardized,
                     host.appendingPathComponent("../../Backends").standardized]
        // A GLib constant by its name, or a flag made of a bare number: an option set takes only `rawValue:`.
        let pattern = try NSRegularExpression(pattern: #"\bG_[A-Z][A-Z_]*\b|\bG[A-Z][A-Za-z]*Flags\((?!rawValue:)"#)
        var named: [String] = []
        for root in roots {
            let files = FileManager.default.enumerator(at: root, includingPropertiesForKeys: nil)?
                .compactMap { $0 as? URL }.filter { $0.pathExtension == "swift" } ?? []
            for file in files {
                let text = try String(contentsOf: file, encoding: .utf8)
                for match in pattern.matches(in: text, range: NSRange(text.startIndex..., in: text)) {
                    let name = String(text[Range(match.range, in: text)!])
                    if !Self.plainEnumerations.contains(where: name.hasPrefix) { named.append("\(file.lastPathComponent): \(name)") }
                }
            }
        }

        XCTAssertEqual(named, [], "a GLib flag named in Swift: give it a name of the host's in CStateUIGTK.h")
    }
}
