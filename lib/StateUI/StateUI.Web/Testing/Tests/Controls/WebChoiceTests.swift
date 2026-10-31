// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI
@_spi(Host) import StateUIHost
@testable import StateUIWeb
import XCTest

/// What the user chooses in the browser's own choice controls reaches the tree, and what follows it runs with no
/// other event to carry it. The browser raises the events, so the suite runs it in a browser (`test-web.sh --browser`).
@MainActor
final class WebChoiceTests: XCTestCase {
    override func setUp() async throws {
        WebTestLoop.started
    }

    /// A page built as a reader's summary - a Grid of a list and its count, filters over it - shows what an
    /// awaiting handler following the chosen filter loaded, with no other event after the choice.
    func testAChoiceLoadsWhatAPageShowsWithNoOtherEvent() throws {
        let host = WebRenderer.running {
            SplitView {
                Text("Menu").title("Parcels")
            } detail: {
                NavigationStack(State(wrappedValue: [Int]()).projectedValue) {
                    SummaryPage()
                } destination: { _ in Text("Parcel") }
            }
            .showsSidebar(State(wrappedValue: true).projectedValue)
        }
        let picker = try XCTUnwrap(host.views(WebPickerView.self).first)
        let count = "[...document.querySelectorAll('.stateui-window *')].find((e) => e.children.length === 0 "
            + "&& e.textContent.startsWith('Parcels: '))?.textContent ?? ''"
        host.settle { (try? WebBrowser.evaluate(count, on: 0)) == "Parcels: 1" }

        try WebBrowser.run("e.selectedIndex = 3; e.dispatchEvent(new Event('input', { bubbles: true })); "
            + "e.dispatchEvent(new Event('change', { bubbles: true }))", on: picker.node)
        for _ in 0..<200 {
            guard (try? WebBrowser.evaluate(count, on: 0)) != "Parcels: 3" else { break }
            WebBrowser.pause()
        }

        XCTAssertEqual(try WebBrowser.evaluate(count, on: 0), "Parcels: 3")
    }
}

/// A filter a summary chooses.
private enum Range: String, CaseIterable, Hashable {
    case one, two, three
}

/// A summary: a filter, a list of what it loaded and their count, loaded as the page appears and as the filter
/// changes.
private struct SummaryPage: View {
    @State private var range = Range.one
    @State private var parcels: [Int] = []

    @Environment(\.application) private var application

    var body: some View {
        Grid {
            HStack { Picker(Range.allCases, selection: $range) { $0.rawValue }.width(200) }
            ItemsView(parcels, id: \.self) { Text("Parcel \($0)") }.gridRow(1)
            Text("Parcels: \(parcels.count)").gridRow(2)
        }
        .rows(.auto, .fill, .auto)
        .toolbar { ToolbarButton("Report").showsText(true) }
        .title("Summary")
        .onAppearing(.cancelPrevious) { await load() }
        .onChanged(range, policy: .cancelPrevious) { await load() }
    }

    private func load() async {
        _ = try? await application.send(HTTPRequest("stateui-web.css"))
        parcels = Array(0..<(Range.allCases.firstIndex(of: range)! + 1))
    }
}
