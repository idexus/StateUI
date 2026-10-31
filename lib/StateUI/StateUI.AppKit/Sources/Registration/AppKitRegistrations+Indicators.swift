// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

#if os(macOS)
import AppKit
@_spi(Host) import StateUI
@_spi(Host) import StateUIHost

extension AppKitRegistrations {
    /// Progress and activity: one value each, and no event.
    static func indicators(_ registry: Registry<NSView>) {
        registry.add(ProgressBarContract.self, create: { _ in AppKitProgressView() }) { bar in
            bar.property(ProgressBarContract.progress) { view, progress in
                view.apply(progress: progress ?? 0)
            }
        }

        registry.add(SpinnerContract.self, create: { _ in AppKitSpinnerView() }) { activity in
            activity.property(SpinnerContract.isAnimating) { view, running in
                view.apply(running: running ?? false)
            }
        }
    }
}

#endif
