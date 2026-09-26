// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

#if os(iOS)
import UIKit
@_spi(Host) import StateUI
@_spi(Host) import StateUIHost

extension UIKitRegistrations {
    /// A ProgressBar and an ActivityIndicator: how far the work went, whether it runs, and the tint it shows in.
    static func indicators(_ registry: Registry<UIView>) {
        registry.add(ProgressBarContract.self, create: { _ in UIKitProgressBarView() }) { bar in
            bar.property(ProgressBarContract.progress) { view, progress in view.progress = Float(progress ?? 0) }
            bar.property(TintElementContract.tint) { view, tint in
                view.progressTintColor = tint.flatMap { UIColor(stateUI: $0.propValue) }
            }
        }
        registry.add(ActivityIndicatorContract.self, create: { _ in UIKitActivityIndicatorView() }) { activity in
            activity.property(ActivityIndicatorContract.isRunning) { view, running in view.setRunning(running ?? false) }
            activity.property(TintElementContract.tint) { view, tint in
                view.color = tint.flatMap { UIColor(stateUI: $0.propValue) }
            }
        }
    }
}
#endif
