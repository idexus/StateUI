// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

import CStateUIWinUI
import Foundation
@_spi(Host) import StateUI
@_spi(Host) import StateUIHost
@testable import StateUIWinUI
@testable import StateUIWinUIDriver
import XCTest

final class WinUIActsTests: XCTestCase {
    /// The kept values' store reads back what it was given, whatever the words hold.
    func testTheStoreReadsBackWhatItKept() {
        onUIThread {
            let folder = FileManager.default.temporaryDirectory.appendingPathComponent("stateui-winui-store").path
            stateui_winui_set_store(folder)
            defer { stateui_winui_set_store("") }

            var kept = KeptValuesText("")
            kept.keep([.name("com.example.name"), .string("Zażółć\tgęślą\njaźń \\ end")])
            kept.keep([.name("com.example.on"), .bool(true)])
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
            for _ in 0..<30 {
                guard host.windows.count < 2 else { break }
                host.step()
            }
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

    /// A prompt's field holds its bound in characters, as a field of the tree does: WinUI's own counts UTF-16 units,
    /// in which two of these are four.
    func testAPromptsFieldHoldsItsBoundInCharacters() throws {
        try onUIThread {
            let host = WinUIRenderer.running {
                Text("Draft").onCreated { _ = try await WindowSession().prompt("Name", maximumLength: 3) }
            }
            let window = try XCTUnwrap(host.window)
            host.settle(until: { Self.asks(window) })
            let content = try XCTUnwrap(window.content).handle

            stateui_winui_prompt_write(content, "😀😀😀😀")
            host.settle(until: { Self.field(of: window) == "😀😀😀" })
            XCTAssertEqual(Self.field(of: window), "😀😀😀")

            _ = stateui_winui_answer(content, 1, nil)
            host.settle(until: { !Self.asks(window) })
        }
    }

    /// A question asked as its window's page is made, before WinUI has loaded the window, stands once it is loaded.
    func testAQuestionAskedAsItsWindowOpensStandsOverIt() throws {
        try onUIThread {
            let host = WinUIRenderer.running {
                Text("Draft").onCreated { try await WindowSession().alert("Saved", message: "The draft is safe") }
            }
            let window = try XCTUnwrap(host.window)
            host.settle(until: { Self.asks(window) })
            XCTAssertTrue(Self.asks(window), "over the window just opened")

            _ = stateui_winui_answer(try XCTUnwrap(window.content).handle, 1, nil)
            host.settle(until: { !Self.asks(window) })
        }
    }

    /// A question whose window goes before the user answered goes with it, answered as dismissed: nothing stands over
    /// the window the user is in, and no later question waits behind it.
    func testAQuestionWhoseWindowWentGoesWithIt() throws {
        try onUIThread {
            let host = WinUIRenderer.running(application: { ClosingApplication() })
            let main = try XCTUnwrap(host.window)
            stateui_winui_button_invoke(try XCTUnwrap(host.views(WinUIButtonView.self).first).handle)
            for _ in 0..<30 {
                guard host.windows.count < 2 else { break }
                host.step()
            }
            let tool = try XCTUnwrap(host.windows.last?.window)
            WinUICallbacks.table.windowStateChanged(main.number, false, false)
            WinUICallbacks.table.windowStateChanged(tool.number, false, true)
            host.settle(until: { Self.asks(tool) })
            XCTAssertTrue(Self.asks(tool), "over the tool window the user is in")
            stateui_winui_button_invoke(try XCTUnwrap(host.views(WinUIButtonView.self).last).handle)
            host.settle(until: { host.windows.count == 1 })
            host.step()
            XCTAssertFalse(Self.asks(main), "nothing stands over the window the user is in")
        }
    }

    /// A question WinUI could not show - another dialog stands over the window - fails its call with the reason; it
    /// is no answer of the user's.
    func testAQuestionWinUICouldNotShowFailsItsCall() throws {
        try onUIThread {
            let outcome = State(wrappedValue: "")
            let host = WinUIRenderer.running {
                VStack {
                    Text(outcome.wrappedValue)
                    Button("Ask").onClicked(gate: .ignoreWhileRunning) {
                        do {
                            outcome.wrappedValue = "answered \(try await WindowSession().confirm("Delete?", message: "The draft goes", accept: "Delete", cancel: "Keep"))"
                        } catch {
                            outcome.wrappedValue = "failed"
                        }
                    }
                }
            }
            let window = try XCTUnwrap(host.window)
            let content = try XCTUnwrap(window.content)
            host.settle { stateui_winui_is_loaded(content.handle) }
            "Standing".withCString { title in
                "OK".withCString { accept in
                    var other = StateUIQuestion(
                        kind: .alert, title: title, message: nil, accept: accept, cancel: nil, choices: nil, choiceCount: 0,
                        destructive: -1, placeholder: nil, maximumLength: 0, spellChecked: false, predicted: false,
                        scope: 0, initial: nil)
                    stateui_winui_ask(content.handle, -1, &other)
                }
            }
            host.settle { Self.asks(window) }

            try XCTUnwrap(host.views(WinUIButtonView.self).first).invoke()
            host.settle { !outcome.wrappedValue.isEmpty }
            XCTAssertEqual(outcome.wrappedValue, "failed", "no answer of the user's")

            _ = stateui_winui_answer(content.handle, 1, nil)
            host.settle { !Self.asks(window) }
        }
    }

    /// Whether a question stands over `window`'s content.
    @MainActor
    private static func asks(_ window: WinUIWindow) -> Bool {
        window.content.map { stateui_winui_question($0.handle, nil, 0) >= 0 } ?? false
    }

    /// The words in the field of the question showing over `window`; nil for none.
    @MainActor private static func field(of window: WinUIWindow) -> String? {
        guard let content = window.content?.handle else { return nil }
        let length = stateui_winui_question(content, nil, 0)
        guard length >= 0 else { return nil }
        var bytes = [CChar](repeating: 0, count: Int(length) + 1)
        _ = stateui_winui_question(content, &bytes, Int32(bytes.count))
        let words = String(decoding: bytes.prefix(Int(length)).map { UInt8(bitPattern: $0) }, as: UTF8.self)
        let parts = words.split(separator: "\u{1F}", omittingEmptySubsequences: false)
        return parts.count > 4 ? String(parts[4]) : nil
    }
}

/// An application whose first window opens a tool window, which asks the user something.
private struct AskingApplication: Application {
    var body: some Scene { AskingScene() }
}

private struct AskingScene: Scene {
    var body: some Scene {
        WindowGroup { AskingOpeningPage() }
        Window(WindowType("acts.tool")) { AskingToolPage() }
    }
}

/// An application whose first window opens a tool window, whose page asks the user something as it is made and
/// closes its window by its own button.
private struct ClosingApplication: Application {
    var body: some Scene { ClosingScene() }
}

private struct ClosingScene: Scene {
    var body: some Scene {
        WindowGroup { ClosingOpeningPage() }
        Window(WindowType("acts.closed")) { ClosedToolPage() }
    }
}

private struct ClosingOpeningPage: View {
    @Environment(\.application) private var application

    var body: some View {
        let application = self.application
        return Button("Tool").onClicked(gate: .ignoreWhileRunning) { try await application.openWindow(WindowType("acts.closed")) }
    }
}

private struct ClosedToolPage: View {
    @Environment(\.window) private var window
    @Environment(\.application) private var application

    var body: some View {
        let application = self.application
        return VStack {
            Text("Tool")
            Button("Close").onClicked(gate: .ignoreWhileRunning) { try await application.closeWindow(WindowType("acts.closed")) }
        }
        .onCreated { try await window.alert("Saved", message: "The draft is safe") }
    }
}

private struct AskingOpeningPage: View {
    @Environment(\.application) private var application

    var body: some View {
        let application = self.application
        return Button("Tool").onClicked(gate: .ignoreWhileRunning) { try await application.openWindow(WindowType("acts.tool")) }
    }
}

/// The tool window's page in `AskingApplication`: a button asking the user over its own window.
private struct AskingToolPage: View {
    @Environment(\.window) private var window

    var body: some View {
        let window = self.window
        return Button("Ask").onClicked(gate: .ignoreWhileRunning) { try await window.alert("Saved", message: "The draft is safe") }
    }
}
