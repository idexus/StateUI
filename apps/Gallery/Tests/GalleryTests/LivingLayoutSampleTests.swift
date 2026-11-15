// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@testable import GalleryUI
import StateUI
import StateUITesting
import Synchronization
import XCTest

/// The moving layout sample used as its user uses it: rows added past every name it has, shuffled and removed.
@MainActor
final class LivingLayoutSampleTests: XCTestCase {
    /// Every row added is a row of its own: added past the names the sample cycles through, no two rows share an
    /// identity, as the library would say.
    func testEveryRowAddedIsARowOfItsOwn() async throws {
        let said = Mutex<[String]>([])
        Complaints.route { words in said.withLock { $0.append(words) } }
        defer { Complaints.route(to: nil) }
        let window = try await TestWindow(motion: .none) { LivingLayoutSample() }

        for _ in 0..<9 { try await window.element("living.add").perform(.activate) }
        try await window.element("living.shuffle").perform(.activate)
        try await window.element("living.remove").perform(.activate)

        XCTAssertEqual(said.withLock { $0 }.filter { $0.contains("share the identity") }, [])
    }
}
