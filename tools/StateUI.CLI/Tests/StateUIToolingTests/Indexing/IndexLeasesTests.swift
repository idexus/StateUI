// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

import Foundation
@testable import StateUITooling
import StateUIToolingProtocol
import XCTest

final class IndexLeasesTests: XCTestCase {
    private var state: URL!
    private var package: URL!

    override func setUpWithError() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("leases-\(UUID().uuidString)")
        state = root.appendingPathComponent("state")
        package = root.appendingPathComponent("Notes")
        try FileManager.default.createDirectory(at: package, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: state.deletingLastPathComponent())
    }

    /// Two connections share a package as one host; another host is refused while the first lives, its own lease
    /// kept, and taken once the connection holding the package as the first host has ended.
    func testOnePackageIsIndexedAsOneHostAtATime() async throws {
        let first = IndexLeases(folder: state)
        var second: IndexLeases? = IndexLeases(folder: state)
        let uri = FileURI.string(package)

        let held = try await first.acquire(.appkit, roots: [package, package])
        XCTAssertEqual(held, IndexLease(host: .appkit, rootUris: [uri, uri]))
        let shared = try await second!.acquire(.appkit, roots: [package])
        XCTAssertNil(shared.conflict, "one host is shared")

        let refused = try await first.acquire(.uikit, roots: [package])
        XCTAssertEqual(refused.conflict, IndexConflict(rootUri: uri, host: .appkit))
        XCTAssertEqual(refused.rootUris, [])

        let plain = try await IndexLeases(folder: state).acquire(nil, roots: [package])
        XCTAssertEqual(plain.conflict?.host, .appkit, "plain Swift is another context")

        second = nil
        let taken = try await first.acquire(.uikit, roots: [package])
        XCTAssertNil(taken.conflict, "a lease whose connection ended goes")
        let files = try FileManager.default.contentsOfDirectory(atPath: state.path).flatMap { folder in
            (try? FileManager.default.contentsOfDirectory(atPath: state.appendingPathComponent(folder).path)) ?? []
        }
        XCTAssertEqual(files.filter { $0.hasSuffix(".lock") }.map { $0.prefix { $0 != "-" } }, ["uikit"])
    }
}
