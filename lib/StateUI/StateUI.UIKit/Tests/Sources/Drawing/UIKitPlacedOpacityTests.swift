// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI
@testable import StateUIUIKit
import UIKit
import XCTest

/// A view that counts what is written through its `alpha`.
private final class CountingView: UIView {
    var alphaWrites = 0

    override var alpha: CGFloat {
        get { super.alpha }
        set {
            alphaWrites += 1
            super.alpha = newValue
        }
    }
}

/// A placing layout's opacity moves every frame and stands on the layer; the element's own goes through the view.
@MainActor
final class UIKitPlacedOpacityTests: XCTestCase {
    /// A PLACING LAYOUT'S OPACITY TELLS THE FOCUS SYSTEM NOTHING: a view's `alpha` coming back from nothing tells UIKit
    /// a view appeared, and with a keyboard attached it maps the whole window again - 45 ms on an iPad, once a second
    /// while a hand turns a ring of cards. Shown by the layer, it is drawn, read and hit-tested alike.
    func testAPlacingLayoutsOpacityTellsTheFocusSystemNothing() {
        let parent = UIView(frame: CGRect(x: 0, y: 0, width: 100, height: 100))
        let view = CountingView(frame: CGRect(x: 0, y: 0, width: 100, height: 100))
        parent.addSubview(view)
        let drawing = UIKitViewDrawing(view)

        for opacity in [0.0, 0.4, 1.0, 0.0] { drawing.placedOpacity = opacity }

        XCTAssertEqual(view.alphaWrites, 0, "every frame's opacity went through the view")
        XCTAssertEqual(view.alpha, 0, accuracy: 0.001, "the view reads what its layer shows")
        XCTAssertTrue(parent.hitTest(CGPoint(x: 50, y: 50), with: nil) === parent, "a view shown at nothing takes no touch")

        drawing.placedOpacity = 0.7
        XCTAssertEqual(Double(view.layer.opacity), 0.7, accuracy: 0.001)
        XCTAssertTrue(parent.hitTest(CGPoint(x: 50, y: 50), with: nil) === view, "a view shown again takes the touch")
    }

    /// The element's own opacity - an author's appearing view - goes through the view, so UIKit hears of it.
    func testTheElementsOwnOpacityGoesThroughTheView() {
        let view = CountingView(frame: CGRect(x: 0, y: 0, width: 100, height: 100))
        let drawing = UIKitViewDrawing(view)
        drawing.placedOpacity = 0.5

        drawing.ownOpacity = 0.4

        XCTAssertEqual(view.alphaWrites, 1)
        XCTAssertEqual(view.alpha, 0.2, accuracy: 0.001, "the two opacities, multiplied")
    }
}
