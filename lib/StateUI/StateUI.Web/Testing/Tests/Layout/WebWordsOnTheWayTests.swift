// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI
@_spi(Host) import StateUIHost
@testable import StateUIWeb
import StateUIConformance
import XCTest

/// Words on the way, in a browser's own layout: a view laying out words stands no narrower than they need while its
/// place travels, to a place read at the size the browser gives it.
@MainActor
final class WebWordsOnTheWayTests: XCTestCase {
    override func setUp() async throws {
        WebTestLoop.started
    }

    /// A child's place is read at the size the browser lays it out at, a fraction of a pixel included.
    func testAPlaceIsReadAtItsOwnFractionalSize() throws {
        let host = WebRenderer.running {
            VStack {
                Rectangle().width(82.3).height(10.6).horizontalAlignment(.start).id("box")
            }
            .id("stack")
        }
        let node = { (id: String) in
            (host.runtime.tree.root?.first(id: .manual(id))?.native as? WebElement)?.view?.node
        }
        host.settle { node("box") != nil && node("stack") != nil }
        let pair = (try XCTUnwrap(node("stack")), try XCTUnwrap(node("box")))
        let place = try XCTUnwrap(WebRelay.places([pair]).first ?? nil)

        XCTAssertEqual(place.width, 82.3, accuracy: 0.01)
        XCTAssertEqual(place.height, 10.6, accuracy: 0.01)
    }

    /// A sidebar's entries, the chosen one bold: as the choice moves, the words losing their weight - and those
    /// taking it - stand on one line in every frame of their travel.
    func testWordsLosingTheirWeightStandOnOneLineOnTheWay() throws {
        let clock = TestClock()
        let chosen = State(wrappedValue: 3)
        let names = ["Parcels", "Summary", "Operations", "Users", "Reasons", "Settings", "Użytkownicy", "Powody wad"]
        let host = WebRenderer.running(clock: clock) {
            VStack {
                ForEach(names.indices) { index in
                    HStack {
                        Rectangle().width(20).height(20)
                        Text(names[index]).fontSize(14).fontWeight(chosen.wrappedValue == index ? .bold : .regular)
                            .id("words\(index)")
                    }
                    .spacing(10)
                    .padding(horizontal: 12, vertical: 8)
                    .background(chosen.wrappedValue == index ? Color.lightGray : .transparent)
                }
            }
            .spacing(2)
            .width(240)
        }
        let nodes = { names.indices.compactMap { index in
            (host.runtime.tree.root?.first(id: .manual("words\(index)"))?.native as? WebElement)?.view?.node
        } }
        host.settle { nodes().count == names.count }
        let lines = """
            (() => {
              const range = document.createRange();
              range.selectNodeContents(e);
              return new Set([...range.getClientRects()].map((line) => Math.round(line.top))).size;
            })()
            """
        var broken: [String] = []
        for next in [0, 6, 7, 1, 2, 4, 5, 3] {
            chosen.wrappedValue = next
            host.step()
            for frame in 0..<30 {
                clock.now += 16
                host.frame()
                for (index, node) in nodes().enumerated() where try WebBrowser.number(lines, on: node) != 1 {
                    broken.append("\(names[index]) at frame \(frame) choosing \(names[next])")
                }
            }
        }

        XCTAssertEqual(broken, [], "every entry on one line")
    }
}
