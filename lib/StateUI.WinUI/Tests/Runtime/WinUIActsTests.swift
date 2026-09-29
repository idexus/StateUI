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

    /// A question stands over the window the user is in - the one activated last - not over the application's first.
    func testAQuestionStandsInTheWindowTheUserIsIn() throws {
        try onUIThread {
            let host = WinUIRenderer.running(application: { AskingApplication() })
            stateui_winui_button_invoke(try XCTUnwrap(host.views(WinUIButtonView.self).first).handle)
            for _ in 0..<30 where host.windows.count < 2 { host.step() }
            XCTAssertEqual(host.windows.count, 2)
            let (main, tool) = (host.windows[0].window, host.windows[1].window)
            WinUICallbacks.table.windowStateChanged(main.number, false, false)
            WinUICallbacks.table.windowStateChanged(tool.number, false, true)
            host.step()

            stateui_winui_button_invoke(try XCTUnwrap(host.views(WinUIButtonView.self).last).handle)
            host.settle(until: { Self.asks(tool) || Self.asks(main) })
            XCTAssertTrue(Self.asks(tool), "over the window the user is in")
            XCTAssertFalse(Self.asks(main))

            for window in [main, tool] where Self.asks(window) {
                _ = stateui_winui_answer(try XCTUnwrap(window.content).handle, 1, nil)
            }
            host.settle(until: { !Self.asks(tool) && !Self.asks(main) })
        }
    }

    /// Whether a question stands over `window`'s content.
    @MainActor
    private static func asks(_ window: WinUIWindow) -> Bool {
        window.content.map { stateui_winui_question($0.handle, nil, 0) >= 0 } ?? false
    }
}

/// An application whose main window opens a tool window, which asks the user something.
private struct AskingApplication: Application {
    var scene: any Scene { AskingScene() }
}

private struct AskingScene: Scene {
    var windows: Windows {
        Windows({ WindowGroup(WindowType("acts.tool")) { AskingToolWindow() } }, main: { AskingMainWindow() })
    }
}

private struct AskingMainWindow: Window {
    var page: any Page { AskingOpeningPage() }
}

private struct AskingOpeningPage: ContentView {
    @Environment private var scene: SceneSession

    var content: any View {
        let scene = self.scene
        return Button("Tool").onClicked { try await scene.openWindow(WindowType("acts.tool")) }
    }
}

private struct AskingToolWindow: Window {
    var page: any Page {
        Button("Ask").onClicked { try await Dialogs.alert("Saved", message: "The draft is safe") }
    }
}
