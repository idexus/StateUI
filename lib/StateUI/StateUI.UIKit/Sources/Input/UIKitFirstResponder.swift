// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

#if os(iOS)
import UIKit

/// The responder holding the keyboard, found as UIKit finds the target of an action sent to none.
@MainActor
enum UIKitFirstResponder {
    private static weak var found: UIResponder?

    /// The responder holding the keyboard; nil where none does.
    static func find() -> UIResponder? {
        found = nil
        UIApplication.shared.sendAction(#selector(UIResponder.reportAsFirstResponder(_:)), to: nil, from: nil, for: nil)
        return found
    }

    /// Whether a field holding the keyboard is being typed into.
    static var isTyping: Bool {
        find() is UITextInput
    }

    fileprivate static func report(_ responder: UIResponder) {
        found = responder
    }
}

extension UIResponder {
    /// The action the first responder answers, telling who it is.
    @objc fileprivate func reportAsFirstResponder(_ sender: Any?) {
        UIKitFirstResponder.report(self)
    }
}
#endif
