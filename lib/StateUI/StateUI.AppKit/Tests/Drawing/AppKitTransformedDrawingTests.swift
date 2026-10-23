// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

#if os(macOS)
import AppKit
@_spi(Host) @testable import StateUI
@_spi(Host) @testable import StateUIHost
@testable import StateUIAppKit
import XCTest

/// AppKit draws a layer-backed view only where it is visible, and measures that without its layers' transforms.
@MainActor
final class AppKitTransformedDrawingTests: XCTestCase {
    /// A VIEW UNDER A TRANSFORM DRAWS WHOLE: a card turned past the edge of what clips it would be drawn only where
    /// its unturned frame shows - a corner cut along the card - so it takes the whole of itself as visible; a card
    /// standing straight past the same edge draws only what shows.
    func testAViewUnderATransformDrawsWhole() throws {
        let renderer = AppKitRenderer.running {
            ZStack {
                LayoutEngine(["turned", "straight"]) { _ in
                    Rectangle()
                        .fill(.red)
                } placements: { room, _ in
                    [
                        Placement(Rect(room.width - 40, 10, 80, 80), transform: .rotate(30)),
                        Placement(Rect(room.width - 40, 110, 80, 80)),
                    ]
                }
            }
            .clipsContent(true)
            .width(200)
            .height(200)
        }
        defer { renderer.closeForTesting() }

        let shapes = try placed(renderer)
        let (turned, straight) = (shapes[0], shapes[1])

        // What AppKit draws of a view: what of its bounds it takes for visible.
        func drawn(_ view: NSView) -> NSRect { view.visibleRect.intersection(view.bounds) }

        XCTAssertEqual(drawn(turned), turned.bounds, "the turned card, whole")
        XCTAssertEqual(drawn(straight).width, 40, accuracy: 0.5, "the straight one, as far as it shows")
    }

    /// The layout's two shapes, once the run has placed them.
    private func placed(_ renderer: AppKitRenderer) throws -> [AppKitShapeView] {
        let deadline = Date(timeIntervalSinceNow: 2)
        var shapes: [AppKitShapeView] = []
        while Date() < deadline {
            renderer.nativeViews(AppKitZStackView.self).first?.window?.contentView?.layoutSubtreeIfNeeded()
            renderer.displayFrameForTesting()
            renderer.runtime.pump.turn()
            shapes = renderer.nativeViews(AppKitShapeView.self)
            if shapes.count == 2, shapes[0].frame.width == 80 { return shapes }
            RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.02))
        }
        XCTFail("the run placed no shapes: \(shapes.map(\.frame))")
        return shapes
    }
}
#endif
