// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI

/// The windows a platform restored itself, each with the native window or scene it came in, the same on every host
/// whose platform restores windows: each comes in as its kind for its value the moment it comes, and waits for the
/// window element it opened to take it.
/// Design: docs/design/host/runtime.md#restored-windows
@_spi(Host) @MainActor public final class RestoredWindows<Native: AnyObject> {
    /// A restored window: its record, and what it came in.
    public typealias Restored = (record: WindowRecord, native: Native)

    /// The windows waiting, in the order they came.
    private var waiting: [Restored] = []

    /// Nothing restored yet.
    public init() {}

    /// Whether no window waits.
    public var isEmpty: Bool { waiting.isEmpty }

    /// Takes a window the platform restored: it comes in as its kind for its value, its scene's values landing in
    /// the core and in `values` where the scene opens with it. Answers whether a scene declares it - the host closes
    /// one none does.
    public func accept(
        _ record: WindowRecord, native: Native, values: inout SceneValues, in runtime: HostRuntime
    ) -> Bool {
        guard let scene = runtime.connectWindow(kind: record.kind, value: record.value, restoring: record.kept)
        else { return false }

        values.opened(scene, keeping: record.kept)
        waiting.append((record, native))
        return true
    }

    /// The window the platform restored for `element`, where one waits: the first of its kind and its value - in the
    /// order they came, which is the order they opened. A kind is one scene's, so it names the scene too.
    public func take(for element: MountedElement) -> Restored? {
        let kind = element.value(.windowType)?.name
        let value = element.value(.windowValue)?.string
        guard let index = waiting.firstIndex(where: { $0.record.kind == kind && $0.record.value == value })
        else { return nil }

        return waiting.remove(at: index)
    }
}
