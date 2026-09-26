// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

import CStateUIWinUI
import Foundation
@_spi(Host) import StateUI
@_spi(Host) import StateUIHost
@testable import StateUIWinUI
import XCTest

final class WinUIActsTests: XCTestCase {
    /// The kept values' store reads back what it was given, whatever the words hold.
    func testTheStoreReadsBackWhatItKept() {
        onUIThread {
            let folder = FileManager.default.temporaryDirectory.appendingPathComponent("stateui-winui-store").path
            stateui_winui_set_store(folder)
            defer { stateui_winui_set_store("") }

            let keys = [PersistentKey("com.example.name", of: String.self), PersistentKey("com.example.on", of: Bool.self)]
            var kept = KeptValuesText("")
            kept.keep([.name("com.example.name"), .string("Zażółć\tgęślą\njaźń \\ end")], keys: keys)
            kept.keep([.name("com.example.on"), .bool(true)], keys: keys)
            WinUIPersistence.write(kept)

            XCTAssertEqual(WinUIPersistence.read(), kept)
        }
    }
}
