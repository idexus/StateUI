// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

#if os(macOS)
import AppKit
@_spi(Host) import StateUI

/// The contracts this host realizes through the core's registry: how each
/// element's view is made and which of its members the view takes. Families
/// move here from `MountedNode`'s switch one at a time; an element no
/// registration answers is still made there.
@MainActor
enum AppKitRegistrations {
    /// The registry, built once.
    static let registry: Registry<NSView> = {
        let registry = Registry<NSView>()

        indicators(registry)

        return registry
    }()

    /// Progress and activity: one value each, and no event.
    private static func indicators(_ registry: Registry<NSView>) {
        registry.add(ProgressBarContract.self, create: { _ in AppKitProgressView() }) { bar in
            bar.property(ProgressBarContract.progress) { view, progress in
                view.apply(progress: progress ?? 0)
            }
        }

        registry.add(ActivityIndicatorContract.self, create: { _ in AppKitActivityIndicatorView() }) { activity in
            activity.property(ActivityIndicatorContract.isRunning) { view, running in
                view.apply(running: running ?? false)
            }
        }
    }
}
#endif
