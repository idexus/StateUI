// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI
@_spi(Host) import StateUIHost

extension GTKRegistrations {
    /// A ProgressBar and an ActivityIndicator: how far the work went, whether it runs, and the tint it shows in.
    static func indicators(_ registry: Registry<GTKView>) {
        registry.add(ProgressBarContract.self, create: { _ in GTKProgressBarView() }) { bar in
            bar.property(ProgressBarContract.progress) { view, progress in view.setProgress(progress ?? 0) }
            bar.property(TintElementContract.tint) { view, tint in view.setTint(tint?.propValue) }
        }
        registry.add(ActivityIndicatorContract.self, create: { _ in GTKActivityIndicatorView() }) { activity in
            activity.property(ActivityIndicatorContract.isRunning) { view, running in view.setRunning(running ?? false) }
            activity.property(TintElementContract.tint) { view, tint in view.setTint(tint?.propValue) }
        }
    }
}
