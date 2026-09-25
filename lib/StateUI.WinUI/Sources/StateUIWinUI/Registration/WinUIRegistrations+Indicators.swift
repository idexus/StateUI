// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI

extension WinUIRegistrations {
    /// What shows work: a ProgressBar, how far along, and an ActivityIndicator, whether it turns - each in its tint.
    static func indicators(_ registry: Registry<WinUIView>) {
        registry.add(ProgressBarContract.self, create: { _ in WinUIProgressBarView() }) { bar in
            bar.property(ProgressBarContract.progress) { view, progress in view.setProgress(progress ?? 0) }
            bar.property(TintElementContract.tint) { view, tint in view.setTint(tint?.propValue) }
        }
        registry.add(ActivityIndicatorContract.self, create: { _ in WinUIActivityIndicatorView() }) { activity in
            activity.property(ActivityIndicatorContract.isRunning) { view, running in view.setRunning(running ?? false) }
            activity.property(TintElementContract.tint) { view, tint in view.setTint(tint?.propValue) }
        }
    }
}
