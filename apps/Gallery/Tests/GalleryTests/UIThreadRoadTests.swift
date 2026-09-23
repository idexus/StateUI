// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

import Foundation
import XCTest

/// The UI thread has ONE actor: Swift's `MainActor`, on every platform.
///
/// `@MainThread` - the actor of StateUI's own that the UI thread had before
/// MainActor reached it everywhere - must NOT compile against the library's
/// public module, and `@MainActor` in the same place must. The pair is what
/// makes the refusal mean something: the two listings differ in that one
/// spelling, so a failure is the spelling's and never a typo's.
///
/// Compiled as an application compiles - a plain `import StateUI` - with the
/// compiler and the module the handbook's examples are checked against.
final class UIThreadRoadTests: XCTestCase {
    /// A listing of each spelling, as the body of a function an application
    /// could hold.
    private static let listings: [(spelling: String, compiles: Bool, body: String)] = [
        ("@MainThread", false, "Task { @MainThread in }"),
        ("@MainActor", true, "Task { @MainActor in }"),
    ]

    func testTheUIThreadsActorIsMainActorAlone() throws {
        guard let module = DocumentationExamplesTests.builtModuleDirectory() else {
            // Never a skip: a check that did not run reads as one that passed.
            return XCTFail("no StateUI.swiftmodule beside the test bundle - no spelling was checked")
        }
        let sdk = try DocumentationExamplesTests.sdkPath()
        let scratch = FileManager.default.temporaryDirectory
            .appendingPathComponent("stateui-uithread-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: scratch, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: scratch) }

        for (index, listing) in Self.listings.enumerated() {
            let file = scratch.appendingPathComponent("uithread_\(index).swift")
            let body = listing.body.split(separator: "\n").map { "    \($0)" }.joined(separator: "\n")
            try Data("import StateUI\n\nfunc road() {\n\(body)\n}\n".utf8).write(to: file)

            let output = DocumentationExamplesTests.typecheck(file, module: module, sdk: sdk)

            if listing.compiles {
                XCTAssertNil(output, "\(listing.spelling) does not compile:\n\(output ?? "")")
            } else {
                XCTAssertNotNil(output, "\(listing.spelling) compiles again - the UI thread's actor is MainActor")
            }
        }
    }
}
