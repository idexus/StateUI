// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

import UIKit
@_spi(Host) import StateUI
@_spi(Host) import StateUIHost
@testable import StateUIUIKit
import XCTest

/// A stack's swipe back from within its page, beside what the page's own views listen for.
final class UIKitSwipeBackTests: XCTestCase {
    /// A view's own drag comes before the stack's swipe back from within its page: the swipe back waits for the drag
    /// to fail, and never recognizes with it.
    @MainActor
    func testAViewsDragComesBeforeTheStacksSwipeBack() throws {
        let host = UIKitRenderer.running(reducesMotion: true) {
            NavigationStack(State(wrappedValue: [1]).projectedValue) { Label("Root") }
                destination: { _ in Label("Drag me").onPanUpdated { _ in } }
        }
        defer { host.finish() }
        let label = try XCTUnwrap(host.views(UIKitLabelView.self).first { $0.window != nil && $0.gestureRecognizers?.isEmpty == false })
        let pan = try XCTUnwrap(label.gestureRecognizers?.first { $0 is UIPanGestureRecognizer })
        let navigation = try XCTUnwrap(Self.navigation(around: label))
        let swipeBack = try XCTUnwrap(navigation.interactiveContentPopGestureRecognizer)
        let delegate = try XCTUnwrap(pan.delegate)

        XCTAssertEqual(delegate.gestureRecognizer?(pan, shouldBeRequiredToFailBy: swipeBack), true, "the swipe waits")
        XCTAssertEqual(delegate.gestureRecognizer?(pan, shouldRecognizeSimultaneouslyWith: swipeBack), false)
    }

    /// The navigation controller whose page `view` stands in.
    private static func navigation(around view: UIView) -> UINavigationController? {
        var responder: UIResponder? = view
        while let each = responder {
            if let navigation = each as? UINavigationController { return navigation }
            responder = each.next
        }
        return nil
    }
}
