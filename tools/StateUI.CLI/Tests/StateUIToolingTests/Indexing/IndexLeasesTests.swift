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

    /// An index another connection holds is left as it stands: cleaning takes away only what no other connection
    /// indexes, and says who holds the rest. A connection cleans what it holds itself.
    func testCleaningLeavesAnIndexAnotherConnectionHolds() async throws {
        let index = package.appendingPathComponent(".build/appkit/index-build")
        try FileManager.default.createDirectory(at: index, withIntermediateDirectories: true)
        let holder = IndexLeases(folder: state)
        _ = try await holder.acquire(.appkit, roots: [package])

        let cleaned = try await ToolingService(leases: IndexLeases(folder: state)).cleanIndex(in: [FileURI.string(package)])
        XCTAssertEqual(cleaned, IndexCleaning(removedUris: [], conflicts: [IndexConflict(rootUri: FileURI.string(package), host: .appkit)]))
        XCTAssertTrue(FileManager.default.fileExists(atPath: index.path), "another connection's index stands")

        let own = try await ToolingService(leases: holder).cleanIndex(in: [FileURI.string(package)])
        XCTAssertEqual(own, IndexCleaning(removedUris: [FileURI.string(index)]))
    }

    /// A package is one by whatever path names it: cleaning asked for a held package and for a link to it leaves
    /// the index and answers both as held.
    func testCleaningLeavesAHeldIndexNamedThroughALink() async throws {
        let index = package.appendingPathComponent(".build/appkit/index-build")
        try FileManager.default.createDirectory(at: index, withIntermediateDirectories: true)
        let link = package.deletingLastPathComponent().appendingPathComponent("Linked")
        try FileManager.default.createSymbolicLink(at: link, withDestinationURL: package)
        let holder = IndexLeases(folder: state)
        _ = try await holder.acquire(.appkit, roots: [package])

        let named = [FileURI.string(package), FileURI.string(link)]
        let cleaned = try await ToolingService(leases: IndexLeases(folder: state)).cleanIndex(in: named)
        XCTAssertEqual(cleaned, IndexCleaning(removedUris: [], conflicts: named.map { IndexConflict(rootUri: $0, host: .appkit) }))
        XCTAssertTrue(FileManager.default.fileExists(atPath: index.path), "another connection's index stands")
    }

    /// No connection takes a package while it is cleaned: cleaning holds the package's guard until what it removes
    /// is gone, and a connection asking for the package meanwhile gets it only then.
    func testNoConnectionTakesAPackageWhileItIsCleaned() async throws {
        let cleaner = IndexLeases(folder: state)
        let other = IndexLeases(folder: state)
        let package = try XCTUnwrap(self.package)
        let order = Order()
        let cleaning = Task {
            try await cleaner.cleaning([package]) { free in
                order.add("cleaning \(free.count)")
                Thread.sleep(forTimeInterval: 0.5)
                order.add("cleaned")
                return free
            }
        }
        while order.said.isEmpty { try await Task.sleep(for: .milliseconds(10)) }
        let lease = try await other.acquire(.appkit, roots: [package])
        order.add("acquired")
        let cleaned = try await cleaning.value

        XCTAssertNil(lease.conflict)
        XCTAssertEqual(cleaned.conflicts, [])
        XCTAssertEqual(order.said, ["cleaning 1", "cleaned", "acquired"])
    }
}

/// What happened, in the order it was said.
private final class Order: @unchecked Sendable {
    private let lock = NSLock()
    private var words: [String] = []

    func add(_ word: String) { lock.withLock { words.append(word) } }

    var said: [String] { lock.withLock { words } }
}
