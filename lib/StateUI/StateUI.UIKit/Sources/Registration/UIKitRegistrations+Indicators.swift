// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

#if os(iOS)
import UIKit
@_spi(Host) import StateUI
@_spi(Host) import StateUIHost

extension UIKitRegistrations {
    /// A ProgressBar and an Spinner: how far the work went, whether it runs, and the tint it shows in.
    static func indicators(_ registry: Registry<UIView>) {
        registry.add(ProgressBarContract.self, create: { _ in UIKitProgressBarView() }) { bar in
            bar.property(ProgressBarContract.progress) { view, progress in
                view.bar.progress = Float(ValueArithmetic.share(progress ?? 0))
            }
            bar.property(TintElementContract.tint) { view, tint in
                view.bar.progressTintColor = tint.flatMap { UIColor(stateUI: $0.propValue) }
            }
        }
        registry.add(SpinnerContract.self, create: { _ in UIKitSpinnerView() }) { activity in
            activity.property(SpinnerContract.isAnimating) { view, running in view.setRunning(running ?? false) }
            activity.property(TintElementContract.tint) { view, tint in
                view.color = tint.flatMap { UIColor(stateUI: $0.propValue) }
            }
        }
    }
}
#endif
