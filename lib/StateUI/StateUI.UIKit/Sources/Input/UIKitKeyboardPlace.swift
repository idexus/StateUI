// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

#if os(iOS)
import UIKit

/// The keyboard docked at a screen's foot, as UIKit tells where it goes: the pages following it lay themselves out
/// again within its own animation. It holds no window and no view strongly.
/// Design: docs/design/platforms/uikit/pages.md#the-keyboard
@MainActor
enum UIKitKeyboardPlace {
    /// Where the keyboard goes, in its screen's coordinates; nil before it ever moved.
    private static var frame: CGRect?

    /// The views laid out again as the keyboard moves.
    private static let followers = NSHashTable<UIView>.weakObjects()

    /// What hears the keyboard move, made with the first follower.
    private static var observer: NSObjectProtocol?

    /// Has `view` laid out again each time the keyboard moves, within the keyboard's animation.
    static func follow(_ view: UIView) {
        followers.add(view)
        guard observer == nil else { return }
        observer = NotificationCenter.default.addObserver(
            forName: UIResponder.keyboardWillChangeFrameNotification, object: nil, queue: .main
        ) { note in
            let info = note.userInfo ?? [:]
            let end = (info[UIResponder.keyboardFrameEndUserInfoKey] as? NSValue)?.cgRectValue
            let duration = info[UIResponder.keyboardAnimationDurationUserInfoKey] as? Double ?? 0
            let curve = info[UIResponder.keyboardAnimationCurveUserInfoKey] as? UInt ?? 0
            MainActor.assumeIsolated { moved(to: end, duration: duration, curve: curve) }
        }
    }

    /// How far the keyboard docked at the foot of `view`'s screen stands over `view`'s foot; nought while none does -
    /// one gone below the screen, or floating over it.
    static func height(over view: UIView) -> CGFloat {
        guard let frame, let screen = view.window?.screen else { return 0 }
        let foot = screen.bounds.maxY
        guard frame.minY < foot, frame.maxY >= foot - 1 else { return 0 }
        return max(0, view.bounds.maxY - view.convert(frame, from: screen.coordinateSpace).minY)
    }

    /// The keyboard goes to `end`, and every follower lays itself out within its move.
    private static func moved(to end: CGRect?, duration: Double, curve: UInt) {
        frame = end
        let views = followers.allObjects
        views.forEach { $0.setNeedsLayout() }
        UIView.animate(withDuration: duration, delay: 0, options: UIView.AnimationOptions(rawValue: curve << 16)) {
            views.forEach { $0.layoutIfNeeded() }
        }
    }
}
#endif
