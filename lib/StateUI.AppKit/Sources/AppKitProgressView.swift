// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

#if os(macOS)
import AppKit

/// AppKit's determinate rendering of StateUI's unit progress value.
@MainActor
final class AppKitProgressView: NSProgressIndicator {
    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        style = .bar
        isIndeterminate = false
        minValue = 0
        maxValue = 1
        controlSize = .regular
    }

    convenience init() {
        self.init(frame: .zero)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("AppKitProgressView is created in code")
    }

    func apply(progress: Double) {
        doubleValue = min(max(progress.isFinite ? progress : 0, 0), 1)
    }
}

/// AppKit's indeterminate indicator, visible exactly while work is running.
@MainActor
final class AppKitActivityIndicatorView: NSProgressIndicator {
    private(set) var isRunningForTesting = false

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        style = .spinning
        isIndeterminate = true
        isDisplayedWhenStopped = false
        controlSize = .regular
        isHidden = true
    }

    convenience init() {
        self.init(frame: .zero)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("AppKitActivityIndicatorView is created in code")
    }

    func apply(running: Bool) {
        guard running != isRunningForTesting else { return }
        isRunningForTesting = running
        isHidden = !running
        if running {
            startAnimation(nil)
        } else {
            stopAnimation(nil)
        }
    }
}

#endif
