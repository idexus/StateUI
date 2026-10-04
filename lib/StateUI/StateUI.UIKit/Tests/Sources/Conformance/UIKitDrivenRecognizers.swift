// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

import UIKit
import UIKit.UIGestureRecognizerSubclass

/// A recognizer as UIKit's own recognition hands it to its target: in the state the driver gives it, its touch at
/// a point of the view it listens on. UIKit makes no touch a test can send, so the driver hands the view's
/// listening what its recognizers would.
/// Design: docs/design/platforms/uikit/conformance.md#what-the-driver-does
protocol UIKitDrivenRecognizer: UIGestureRecognizer {
    var driven: UIGestureRecognizer.State { get set }
    var point: CGPoint { get set }
    var on: UIView { get }
}

extension UIKitDrivenRecognizer {
    /// Where the touch is in `other`'s points - the window's where none is named.
    func placed(in other: UIView?) -> CGPoint {
        on.convert(point, to: other ?? on.window)
    }
}

final class DrivenTap: UITapGestureRecognizer, UIKitDrivenRecognizer {
    var driven = UIGestureRecognizer.State.ended
    var point = CGPoint.zero
    let on: UIView
    init(on view: UIView) {
        on = view
        super.init(target: nil, action: nil)
    }
    override var state: UIGestureRecognizer.State {
        get { driven }
        set { driven = newValue }
    }
    override func location(in view: UIView?) -> CGPoint { placed(in: view) }
}

final class DrivenHover: UIHoverGestureRecognizer, UIKitDrivenRecognizer {
    var driven = UIGestureRecognizer.State.began
    var point = CGPoint.zero
    let on: UIView
    init(on view: UIView) {
        on = view
        super.init(target: nil, action: nil)
    }
    override var state: UIGestureRecognizer.State {
        get { driven }
        set { driven = newValue }
    }
    override func location(in view: UIView?) -> CGPoint { placed(in: view) }
}

final class DrivenPress: UILongPressGestureRecognizer, UIKitDrivenRecognizer {
    var driven = UIGestureRecognizer.State.began
    var point = CGPoint.zero
    let on: UIView
    init(on view: UIView) {
        on = view
        super.init(target: nil, action: nil)
    }
    override var state: UIGestureRecognizer.State {
        get { driven }
        set { driven = newValue }
    }
    override func location(in view: UIView?) -> CGPoint { placed(in: view) }
}

final class DrivenPan: UIPanGestureRecognizer, UIKitDrivenRecognizer {
    var driven = UIGestureRecognizer.State.began
    var point = CGPoint.zero
    /// Where the press went down, in the view's points.
    var start = CGPoint.zero
    let on: UIView
    init(on view: UIView) {
        on = view
        super.init(target: nil, action: nil)
    }
    override var state: UIGestureRecognizer.State {
        get { driven }
        set { driven = newValue }
    }
    override func location(in view: UIView?) -> CGPoint { placed(in: view) }
    override func translation(in view: UIView?) -> CGPoint {
        let from = on.convert(start, to: view ?? on.window)
        let to = placed(in: view)
        return CGPoint(x: to.x - from.x, y: to.y - from.y)
    }
}

final class DrivenPinch: UIPinchGestureRecognizer, UIKitDrivenRecognizer {
    var driven = UIGestureRecognizer.State.began
    var point = CGPoint.zero
    var drivenScale = 1.0
    let on: UIView
    init(on view: UIView) {
        on = view
        super.init(target: nil, action: nil)
    }
    override var state: UIGestureRecognizer.State {
        get { driven }
        set { driven = newValue }
    }
    override var scale: CGFloat {
        get { drivenScale }
        set { drivenScale = newValue }
    }
    override func location(in view: UIView?) -> CGPoint { placed(in: view) }
}
