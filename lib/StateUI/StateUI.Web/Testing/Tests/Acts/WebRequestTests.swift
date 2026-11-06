// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) @testable import StateUI
@_spi(Host) import StateUIHost
@testable import StateUIWeb
import XCTest

/// What the relay answers a request and a save whatever the browser does past its first step: every call answered
/// once, and a stop stopping it to its end. The browser's own `fetch` and save picker stand in for the network and
/// the disk, so the suite runs it in a browser (`test-web.sh --browser`).
@MainActor
final class WebRequestTests: XCTestCase {
    /// The host the relay tells what it heard - started for each test, as an application's is.
    private var host: WebRenderer?

    override func setUp() async throws {
        WebTestLoop.started
        WebRenderer.shared?.finish()
        host = WebRenderer.running { Text("Requests") }
        host?.step()
    }

    override func tearDown() async throws {
        host?.finish()
        host = nil
        try? WebBrowser.run("""
            if (globalThis.__fetch) { globalThis.fetch = globalThis.__fetch; delete globalThis.__fetch; }
            if (globalThis.__picker !== undefined) { globalThis.showSaveFilePicker = globalThis.__picker; delete globalThis.__picker; }
            if (globalThis.__holdsFiles !== undefined) { globalThis.stateui.holdsFiles = globalThis.__holdsFiles; delete globalThis.__holdsFiles; }
            """)
    }

    /// A request whose body breaks after its headers came is answered with why.
    func testABodyThatBreaksAnswersTheRequest() async throws {
        try WebBrowser.run("""
            globalThis.__fetch = globalThis.fetch;
            globalThis.fetch = () => Promise.resolve(new Response(new ReadableStream({
              start(controller) { controller.error(new Error("the connection broke")); } })));
            """)
        var answer: Result<HostResponse, ActFailure>?
        _ = WebNetwork().send(try request()) { answer = $0 }
        await settle { answer != nil }

        // The browser names a body that broke in its own words.
        guard case .failure(let failure) = answer else { return XCTFail("no failure answered: \(String(describing: answer))") }
        XCTAssertFalse(failure.reason.isEmpty, "a failure answered with no reason")
    }

    /// A request stopped while its body comes stops the browser's fetch, not only the waiting.
    func testAStopWhileTheBodyComesAbortsTheFetch() async throws {
        try WebBrowser.run("""
            globalThis.__fetch = globalThis.fetch;
            globalThis.fetch = (address, options) => { globalThis.__signal = options.signal;
              return Promise.resolve(new Response(new ReadableStream({ start() {} }))); };
            """)
        let stop = WebNetwork().send(try request()) { _ in }
        await settle { false }

        stop()
        XCTAssertTrue(try WebBrowser.truth("globalThis.__signal.aborted", on: 0), "the fetch went on reading")
    }

    /// A file the picker gave a place but that could not be written is answered as a failure, not a save and not
    /// the user's cancel.
    func testAFileThatCannotBeWrittenAnswersTheSave() async throws {
        try WebBrowser.run("""
            globalThis.__holdsFiles = globalThis.stateui?.holdsFiles; if (globalThis.stateui) globalThis.stateui.holdsFiles = false;
            globalThis.__picker = globalThis.showSaveFilePicker;
            globalThis.showSaveFilePicker = () => Promise.resolve({
              createWritable: () => Promise.reject(new DOMException("the disk is full", "AbortError")) });
            """)
        var answered: (kept: Bool, words: String)?
        WebRelay.saveFile([1, 2, 3], name: "notes.txt", kinds: [], WebRelay.once {
            answered = (WebRelay.fileKept, WebRelay.fileWords)
        })
        await settle { answered != nil }

        XCTAssertEqual(answered?.kept, false, "a write that failed is no save and no cancel: \(String(describing: answered))")
        XCTAssertTrue(answered?.words.contains("the disk is full") == true, String(describing: answered))
    }

    /// A GET of the page's own address, as the application sends it.
    private func request() throws -> HostRequest {
        try XCTUnwrap(HostRequest(HostActCall(
            act: .sendRequest, arguments: [.string("/held"), .name("GET"), .strings([]), .bytes([])], completion: 1)))
    }

    /// Lets the page go on, a bounded number of frames, until `done`: what the page tells settles in a task of the
    /// UI thread's, which each frame leaves its turn.
    private func settle(until done: () -> Bool) async {
        for _ in 0..<60 {
            if done() { return }
            host?.step()
            WebBrowser.pause()
            await Task.yield()
        }
    }
}
