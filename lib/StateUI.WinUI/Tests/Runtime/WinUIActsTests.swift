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

    /// A write that fails keeps what the store kept: the whole store is written aside first, and takes the old one's
    /// place only once it is written - here the place aside cannot be written.
    func testAFailedWriteKeepsWhatWasKept() throws {
        try onUIThread {
            let folder = FileManager.default.temporaryDirectory.appendingPathComponent("stateui-winui-store-failing")
            try? FileManager.default.removeItem(at: folder)
            stateui_winui_set_store(folder.path)
            defer {
                stateui_winui_set_store("")
                try? FileManager.default.removeItem(at: folder)
            }
            let kept = KeptValuesText("com.example.name\tAda\n")
            WinUIPersistence.write(kept)
            let aside = folder.appendingPathComponent(WinUIPersistence.valuesFile + ".writing")
            try FileManager.default.createDirectory(at: aside, withIntermediateDirectories: true)

            XCTAssertFalse(stateui_winui_store(WinUIPersistence.valuesFile, "com.example.name\tGrace\n"))
            XCTAssertEqual(WinUIPersistence.read(), kept, "the old store stands")
        }
    }
}
