// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

import Foundation
@testable import StateUITooling
import XCTest

final class WinUIHeadTests: XCTestCase {
    /// The packages an application resolved, at every depth, each once by its path, the application itself not among them.
    func testTheDependenciesAreEveryResolvedPackagesFolder() throws {
        let json = Data("""
            {"identity": "gallery", "path": "C:/apps/Gallery", "dependencies": [
              {"identity": "stateui", "path": "C:/StateUI", "dependencies": [
                {"identity": "swift-collections", "path": "C:/apps/Gallery/.build/checkouts/swift-collections", "dependencies": []}]},
              {"identity": "webview.winui", "path": "C:/StateUI/lib/Backends/WebView.WinUI", "dependencies": [
                {"identity": "stateui", "path": "C:/StateUI", "dependencies": []}]}]}
            """.utf8)
        XCTAssertEqual(try WinUIHead.dependencies(in: json).map(\.lastPathComponent), ["StateUI", "WebView.WinUI", "swift-collections"])
    }

    /// A head carries its program, the libraries and the packages' resources SwiftPM laid, and nothing only a build
    /// reads.
    func testAHeadCarriesWhatItRunsWith() {
        let carried = ["GalleryWinUI.exe", "StateUI.dll", "StateUIWinUI.DLL", "Gallery_GalleryUI.resources"]
        let left = ["GalleryWinUI.pdb", "StateUI.lib", "Other.exe", "StateUI.swiftmodule", "GalleryWinUI.exp", "Modules"]
        XCTAssertEqual(carried.filter { WinUIHead.carried($0, product: "GalleryWinUI") }, carried)
        XCTAssertEqual(left.filter { WinUIHead.carried($0, product: "GalleryWinUI") }, [])
    }
}
