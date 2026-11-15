// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif
@testable import StateUITooling
import StateUIToolingProtocol
import XCTest

final class PageServerTests: XCTestCase {
    /// A page's folder: its index, a module, a picture with a space in its name, and a link leading out of it.
    private func site() throws -> (site: URL, outside: URL) {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("site-\(UUID().uuidString)")
        addTeardownBlock { try? FileManager.default.removeItem(at: root) }
        let site = root.appendingPathComponent("site")
        try FileManager.default.createDirectory(at: site.appendingPathComponent("Images"), withIntermediateDirectories: true)
        try "<title>Notes</title>".write(to: site.appendingPathComponent("index.html"), atomically: true, encoding: .utf8)
        try Data([0, 97, 115, 109]).write(to: site.appendingPathComponent("NotesWeb.wasm"))
        try "<svg/>".write(to: site.appendingPathComponent("Images/a mark.svg"), atomically: true, encoding: .utf8)
        let outside = root.appendingPathComponent("secret.txt")
        try "secret".write(to: outside, atomically: true, encoding: .utf8)
        try FileManager.default.createSymbolicLink(at: site.appendingPathComponent("leak.txt"), withDestinationURL: outside)
        return (site, outside)
    }

    /// A path names a file within the folder - a folder its index, the query aside, percent-decoded - and nothing
    /// outside it, by `..` or by a link.
    func testAPathNamesAFileWithinThePageAlone() throws {
        let (site, _) = try site()
        let named = { (target: String) in PageRequests.file(for: target, in: site)?.lastPathComponent }
        XCTAssertEqual(named("/"), "index.html")
        XCTAssertEqual(named("/?STATEUI_TALLY=1"), "index.html")
        XCTAssertEqual(named("/NotesWeb.wasm?v=7"), "NotesWeb.wasm")
        XCTAssertEqual(named("/Images/a%20mark.svg"), "a mark.svg")
        XCTAssertNil(named("/../secret.txt"))
        XCTAssertNil(named("/Images/../../secret.txt"))
        XCTAssertNil(named("/leak.txt"))
        XCTAssertNil(named("/missing.js"))
        XCTAssertEqual(PageRequests.type(of: site.appendingPathComponent("NotesWeb.wasm")), "application/wasm")
        XCTAssertEqual(PageRequests.type(of: site.appendingPathComponent("a.svg")), "image/svg+xml")
        XCTAssertEqual(PageRequests.type(of: site.appendingPathComponent("a.js")), "text/javascript; charset=utf-8")
    }

    #if canImport(NIOPosix)
    private func answer(_ url: URL, method: String = "GET") async throws -> (status: Int, headers: [AnyHashable: Any], body: Data) {
        var request = URLRequest(url: url)
        request.httpMethod = method
        let (body, response) = try await URLSession.shared.data(for: request)
        let http = try XCTUnwrap(response as? HTTPURLResponse)
        return (http.statusCode, http.allHeaderFields, body)
    }

    /// The server answers GET and HEAD of the page's files with their type and no-store, a missing file 404 and
    /// another method 405; a port asked for that is in use is refused, the default one gives way to another.
    func testThePageIsServedAndAPortInUseIsRefused() async throws {
        let (site, _) = try site()
        let server = try await PageServer.start(site, port: 0, lan: false)
        let base = URL(string: "http://127.0.0.1:\(server.port)/")!

        let index = try await answer(base)
        XCTAssertEqual(index.status, 200)
        XCTAssertEqual(String(data: index.body, encoding: .utf8), "<title>Notes</title>")
        XCTAssertEqual(index.headers["Cache-Control"] as? String, "no-store")
        let head = try await answer(base.appendingPathComponent("NotesWeb.wasm"), method: "HEAD")
        XCTAssertEqual(head.status, 200)
        XCTAssertEqual(head.headers["Content-Type"] as? String, "application/wasm")
        XCTAssertEqual(head.body.count, 0)
        let missing = try await answer(base.appendingPathComponent("missing.js"))
        XCTAssertEqual(missing.status, 404)
        let posted = try await answer(base, method: "POST")
        XCTAssertEqual(posted.status, 405)

        do {
            _ = try await PageServer.start(site, port: server.port, lan: false)
            XCTFail("a port in use was served twice")
        } catch let error as ToolingError {
            XCTAssertEqual(error.code, .invalidConfiguration)
        }
        await server.stop()
    }
    #endif
}

final class BrowsersTests: XCTestCase {
    /// A desktop entry is a browser where it takes both https and HTML and is shown here; its name is the entry's.
    func testABrowserTakesBothAddressesAndPages() {
        let https = "MimeType=text/html;x-scheme-handler/http;x-scheme-handler/https;\nExec=firefox %u\n"
        XCTAssertEqual(Browsers.browser("[Desktop Entry]\nName=Firefox\n\(https)", on: ["GNOME"])?.name, "Firefox")
        XCTAssertNil(Browsers.browser("[Desktop Entry]\nName=Mail\nMimeType=x-scheme-handler/mailto;\nExec=mail\n", on: []))
        XCTAssertNil(Browsers.browser("[Desktop Entry]\nName=Viewer\nMimeType=text/html;\nExec=viewer\n", on: []))
        XCTAssertNil(Browsers.browser("[Desktop Entry]\nName=Hidden\nNoDisplay=true\n\(https)", on: []))
        XCTAssertNil(Browsers.browser("[Desktop Entry]\nName=Gone\nHidden=true\n\(https)", on: []))
        XCTAssertNil(Browsers.browser("[Desktop Entry]\nName=Kiosk\nOnlyShowIn=UbuntuFrame;\n\(https)", on: ["ubuntu", "GNOME"]))
        XCTAssertNotNil(Browsers.browser("[Desktop Entry]\nName=Here\nOnlyShowIn=KDE;GNOME;\n\(https)", on: ["ubuntu", "GNOME"]))
        XCTAssertNil(Browsers.browser("[Desktop Entry]\nName=Elsewhere\nNotShowIn=GNOME;\n\(https)", on: ["ubuntu", "GNOME"]))
        XCTAssertNil(Browsers.browser("[Desktop Entry]\nName=Nothing\nMimeType=text/html;x-scheme-handler/https;\n", on: []))
    }

    /// The program is the main group's `Exec`, never an action's; its first word, past `env` and its variables.
    func testTheProgramIsTheEntrysFirstWord() {
        let entry = "[Desktop Entry]\nName=Chromium\nMimeType=text/html;x-scheme-handler/https;\nExec=/snap/bin/chromium %U\n"
            + "\n[Desktop Action Incognito]\nExec=/snap/bin/chromium --incognito\n"
        XCTAssertEqual(Browsers.browser(entry, on: [])?.program, "/snap/bin/chromium")
        XCTAssertEqual(Browsers.program("env BAMF_DESKTOP_FILE_HINT=/x.desktop /snap/bin/firefox %u"), "/snap/bin/firefox")
        XCTAssertEqual(Browsers.program("\"/opt/My Browser/browser\" --new-window %U"), "/opt/My Browser/browser")
        XCTAssertEqual(Browsers.program("brave-browser"), "brave-browser")
        XCTAssertNil(Browsers.program(""))
    }
}
