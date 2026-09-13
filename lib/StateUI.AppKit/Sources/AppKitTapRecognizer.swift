// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

#if os(macOS)
import AppKit

/// A native click recognizer whose mutable configuration follows the current
/// StateUI patch while its identity remains attached to one mounted view.
@MainActor
final class AppKitTapRecognizer: NSClickGestureRecognizer {
    private let report: () -> Void

    init(report: @escaping () -> Void) {
        self.report = report
        super.init(target: nil, action: nil)
        target = self
        action = #selector(recognized(_:))
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("AppKitTapRecognizer is created in code")
    }

    /// Applies a valid native click count; StateUI treats zero and negative
    /// counts as one tap rather than creating a recognizer that cannot fire.
    func apply(numberOfTapsRequired: Int) {
        numberOfClicksRequired = max(1, numberOfTapsRequired)
    }

    @objc private func recognized(_ sender: NSClickGestureRecognizer) {
        fire()
    }

    func fire() {
        report()
    }
}

#endif
