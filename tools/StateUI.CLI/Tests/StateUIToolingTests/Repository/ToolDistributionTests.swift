// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

import Foundation
@testable import StateUITooling
import StateUIToolingProtocol
import XCTest

final class ToolDistributionTests: XCTestCase {
    /// SHA-256 gives FIPS 180-4's own examples, across a block's edge too.
    func testSHA256GivesTheStandardsExamples() {
        XCTAssertEqual(SHA256.hex(Data()), "e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855")
        XCTAssertEqual(SHA256.hex(Data("abc".utf8)), "ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad")
        XCTAssertEqual(SHA256.hex(Data("abcdbcdecdefdefgefghfghighijhijkijkljklmklmnlmnomnopnopq".utf8)),
                       "248d6a61d20638b8e5c026930c3e6039a33ce45964ff2167f6ecedd419db06c1")
    }

    /// An archive is named by the release, the system and the architecture, and holds the program with its license,
    /// NOTICE and notices.
    func testAnArchiveIsNamedForItsMachine() {
        XCTAssertEqual(ToolDistribution.name(of: Machine(system: "linux", architecture: "x86_64")), "stateui-\(Release.version)-linux-x86_64")
        XCTAssertEqual(ToolDistribution.contents, ["LICENSE", "NOTICE", "THIRD-PARTY-NOTICES", "bin/\(ToolDistribution.program)"])
    }

    /// The notices name every package pinned, in order, each with its license and notice files; one with none is
    /// refused.
    func testTheNoticesCarryEveryPackagesLicense() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("notices-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: root) }
        let checkouts = root.appendingPathComponent("checkouts")
        for (package, files) in [("swift-nio", ["LICENSE.txt", "NOTICE.txt", "README.md"]), ("swift-argument-parser", ["LICENSE.txt"])] {
            try FileManager.default.createDirectory(at: checkouts.appendingPathComponent(package), withIntermediateDirectories: true)
            for file in files {
                try Data("\(package) \(file)\n".utf8).write(to: checkouts.appendingPathComponent("\(package)/\(file)"))
            }
        }
        let resolved = root.appendingPathComponent("Package.resolved")
        try Data(#"{"pins":[{"identity":"swift-nio","location":"https://github.com/apple/swift-nio","state":{"version":"2.103.0"}},{"identity":"swift-argument-parser","location":"https://github.com/apple/swift-argument-parser","state":{"version":"1.8.2"}}]}"#.utf8)
            .write(to: resolved)

        let text = try ToolDistribution.notices(resolved: resolved, checkouts: checkouts)
        let parser = try XCTUnwrap(text.range(of: "swift-argument-parser 1.8.2 - https://github.com/apple/swift-argument-parser"))
        let nio = try XCTUnwrap(text.range(of: "swift-nio 2.103.0 - https://github.com/apple/swift-nio"))
        XCTAssertLessThan(parser.lowerBound, nio.lowerBound)
        XCTAssertTrue(text.contains("swift-nio LICENSE.txt") && text.contains("swift-nio NOTICE.txt") && !text.contains("README"))

        try FileManager.default.removeItem(at: checkouts.appendingPathComponent("swift-nio/LICENSE.txt"))
        try FileManager.default.removeItem(at: checkouts.appendingPathComponent("swift-nio/NOTICE.txt"))
        XCTAssertThrowsError(try ToolDistribution.notices(resolved: resolved, checkouts: checkouts))
    }
}
