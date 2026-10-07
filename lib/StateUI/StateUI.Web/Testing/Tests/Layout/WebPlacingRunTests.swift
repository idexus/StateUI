// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) @testable import StateUI
@_spi(Host) import StateUIHost
@testable import StateUIWeb
import XCTest

/// A ZStack whose children a placing run stands draws each as the run says, about the middle of the place it gives.
@MainActor
final class WebPlacingRunTests: XCTestCase {
    private func run(width: Double, height: Double, shade: Double = 0) -> HostPlacementRun {
        HostPlacementRun(placements: [
            HostPlacement(
                bounds: Rect(x: 0, y: 0, width: width, height: height), translationX: 0, translationY: 0, rotation: 90,
                scaleX: 1, scaleY: 1, opacity: 1, zIndex: 0, shade: shade),
        ], motion: .none)
    }

    /// The same turn at a new size is drawn about the new size's middle: the matrix's pivot is the place's, so a run
    /// that first placed a card in a room not yet measured leaves it where the next one puts it.
    func testTheSameTurnAtANewSizeTurnsAboutItsNewMiddle() {
        let layout = WebLayoutView(arrangement: .layers)
        let card = WebLayoutView(arrangement: .single)
        defer { for view in [layout, card] { view.detach() } }
        layout.setItems([(card, LayoutValues())])

        layout.setPlacement(run(width: 10, height: 10))
        let small = WebPage.style(of: card.node, "transform")
        layout.setPlacement(run(width: 100, height: 200))
        let large = WebPage.style(of: card.node, "transform")

        // A quarter turn about (50, 100) moves the corner by (150, 50): x = 50 + 100, y = 100 - 50.
        XCTAssertNotEqual(small, large, "the matrix is written again for the new size")
        let numbers = large.dropFirst("matrix3d(".count).dropLast().split(separator: ",").compactMap {
            Double($0.trimmingPrefix(" "))
        }
        XCTAssertEqual(numbers.count, 16)
        XCTAssertEqual(numbers.count == 16 ? numbers[12] : 0, 150, accuracy: 1e-9, "turned about the middle of 100 x 200")
        XCTAssertEqual(numbers.count == 16 ? numbers[13] : 0, 50, accuracy: 1e-9, "turned about the middle of 100 x 200")
    }

    /// A card the run places wears the run's shade on its second layer - the dark over a far card - and none on its
    /// face: the shade drawn whole would stand as a black card behind the face.
    func testACardsSecondLayerWearsTheRunsShade() {
        let layout = WebLayoutView(arrangement: .layers)
        let card = WebLayoutView(arrangement: .grid)
        let (face, shade) = (WebLayoutView(arrangement: .single), WebLayoutView(arrangement: .single))
        defer { for view in [layout, card, face, shade] { view.detach() } }
        card.setItems([(face, LayoutValues()), (shade, LayoutValues())])
        layout.setItems([(card, LayoutValues())])

        layout.setPlacement(run(width: 100, height: 140, shade: 0.4))
        XCTAssertEqual(WebPage.style(of: shade.node, "opacity"), "0.4", "the far card's shade")
        XCTAssertEqual(WebPage.style(of: face.node, "opacity"), "", "and its face whole")

        layout.setPlacement(run(width: 100, height: 140, shade: 0))
        XCTAssertEqual(WebPage.style(of: shade.node, "opacity"), "0", "the front card wears none")
    }
}
