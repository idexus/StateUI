// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI
@_spi(Host) import StateUIHost

extension WebRegistrations {
    /// A ProgressBar and an ActivityIndicator: the share of the work done, whether work goes on, and their colour.
    static func indicators(_ registry: Registry<WebDOMView>) {
        registry.add(ProgressBarContract.self, create: { _ in WebProgressView() }) { bar in
            bar.property(ProgressBarContract.progress) { view, progress in view.setProgress(progress ?? 0) }
            bar.property(TintElementContract.tint) { view, tint in view.setTint(tint?.propValue) }
        }
        registry.add(ActivityIndicatorContract.self, create: { _ in WebActivityView() }) { activity in
            activity.property(ActivityIndicatorContract.isAnimating) { view, running in view.setRunning(running ?? false) }
            activity.property(TintElementContract.tint) { view, tint in view.setTint(tint?.propValue) }
        }
    }
}
