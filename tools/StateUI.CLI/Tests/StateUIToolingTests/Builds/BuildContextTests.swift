// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

import Foundation
import StateUITooling
import StateUIToolingProtocol
import XCTest

final class BuildContextTests: XCTestCase {
    private func context(
        compiler: String = "Swift version 6.4.2", architecture: Architecture = .arm64,
        configuration: BuildConfiguration = .debug, library: String = "/StateUI"
    ) -> BuildContext {
        BuildContext(
            application: URL(fileURLWithPath: "/Apps/Notes"), product: "NotesAppKit", host: .appkit,
            configuration: configuration, architecture: architecture, compiler: compiler, sdk: "macosx 26.4",
            library: URL(fileURLWithPath: library))
    }

    /// A build writes `.build/<host>/<architecture>-<key>`: the same identity the same folder on every run, another
    /// compiler, architecture or library another folder - and debug and release one, SwiftPM keeping them apart.
    func testABuildsScratchFolderIsItsIdentitys() {
        let debug = context()
        XCTAssertEqual(debug.scratch.path, "/Apps/Notes/.build/appkit/\(debug.key)")
        XCTAssertTrue(debug.key.hasPrefix("arm64-"))
        XCTAssertEqual(debug.key.count, "arm64-".count + 12)
        XCTAssertEqual(debug.key, context().key)
        XCTAssertEqual(debug.key, context(configuration: .release).key)
        XCTAssertNotEqual(debug.key, context(compiler: "Swift version 6.5").key)
        XCTAssertNotEqual(debug.key, context(library: "/Other/StateUI").key)
        XCTAssertTrue(context(architecture: .x86_64).key.hasPrefix("x86_64-"))
    }
}
