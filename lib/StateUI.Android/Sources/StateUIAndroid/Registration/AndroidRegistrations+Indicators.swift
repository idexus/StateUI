// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI
@_spi(Host) import StateUIHost

extension AndroidRegistrations {
    /// Progress and activity: one value each, a colour, and no event.
    static func indicators(_ registry: Registry<AndroidView>) {
        registry.add(ProgressBarContract.self, create: { _ in AndroidProgressBarView() }) { bar in
            bar.property(ProgressBarContract.progress) { view, progress in view.setProgress(progress ?? 0) }
            bar.property(TintElementContract.tint) { view, tint in view.setTint(tint?.propValue) }
        }

        registry.add(ActivityIndicatorContract.self, create: { _ in AndroidActivityIndicatorView() }) { activity in
            activity.property(ActivityIndicatorContract.isRunning) { view, running in view.setRunning(running ?? false) }
            activity.property(TintElementContract.tint) { view, tint in view.setTint(tint?.propValue) }
        }
    }
}
