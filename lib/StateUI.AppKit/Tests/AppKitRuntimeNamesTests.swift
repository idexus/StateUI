// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

#if os(macOS)
import Foundation
import XCTest

final class AppKitRuntimeNamesTests: XCTestCase {
    /// The runtime's types keep the architecture's reserved words: no type of
    /// the runtime is an ENGINE - that word is the application's frame code -
    /// and a CHANNEL is only the state channel, one per `@State`.
    func testTheRuntimesTypesKeepTheReservedWords() throws {
        let declaration = try NSRegularExpression(
            pattern: #"\b(?:class|struct|enum|protocol|actor|typealias)\s+(\w+)"#)
        var found: [String] = []

        for (name, text) in try AppKitSources.all() {
            let matches = declaration.matches(in: text, range: NSRange(text.startIndex..., in: text))

            for match in matches {
                guard let range = Range(match.range(at: 1), in: text) else { continue }
                let type = String(text[range])
                if type.hasSuffix("Engine")
                    || (type.contains("Channel") && !type.hasPrefix("AppKitStateChannel")) {
                    found.append("\(name): \(type)")
                }
            }
        }

        XCTAssertEqual(found, [], "an engine is application code, and a channel is a state's")
    }
}
#endif
