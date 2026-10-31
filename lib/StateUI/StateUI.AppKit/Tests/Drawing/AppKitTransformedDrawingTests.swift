// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

#if os(macOS)
import AppKit
@_spi(Host) @testable import StateUI
@_spi(Host) @testable import StateUIHost
@testable import StateUIAppKit
import XCTest

/// A view that counts each time it is marked for display.
private final class MarkCountingView: NSView {
    var marks = 0

    override var needsDisplay: Bool {
        get { super.needsDisplay }
        set {
            if newValue { marks += 1 }
            super.needsDisplay = newValue
        }
    }
}

/// AppKit draws a layer-backed view only where it is visible, and measures that without its layers' transforms.
@MainActor
final class AppKitTransformedDrawingTests: XCTestCase {
    /// A VIEW UNDER A TRANSFORM DRAWS WHOLE: a card turned past the edge of what clips it would be drawn only where
    /// its unturned frame shows - a corner cut along the card - so it takes the whole of itself as visible; a card
    /// standing straight past the same edge draws only what shows.
    func testAViewUnderATransformDrawsWhole() throws {
        let renderer = AppKitRenderer.running {
            ZStack {
                MotionLayout(["turned", "straight"], parameters: State(wrappedValue: 0.0).projectedValue) { _ in
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

    /// THE SAME BOX AGAIN DRAWS NOTHING ANEW: a run places its layout every frame and hands it its box each time; the
    /// same box marks nothing for display, a box that changed draws again.
    func testTheSameBoxAgainDrawsNothingAnew() {
        let view = MarkCountingView(frame: NSRect(x: 0, y: 0, width: 100, height: 100))
        let decoration = AppKitDecoration()
        let rounded = ContainerShape.roundedRectangle(12).propValue
        decoration.apply(background: nil, stroke: nil, lineWidth: nil, shape: rounded, clips: true, to: view)
        let drawn = view.marks
        XCTAssertGreaterThan(drawn, 0, "the first box draws")

        decoration.apply(background: nil, stroke: nil, lineWidth: nil, shape: rounded, clips: true, to: view)
        XCTAssertEqual(view.marks, drawn, "the same box marked the layout for display")

        decoration.apply(
            background: nil, stroke: nil, lineWidth: nil, shape: ContainerShape.roundedRectangle(20).propValue,
            clips: true, to: view)
        XCTAssertGreaterThan(view.marks, drawn, "a box that changed draws again")
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
