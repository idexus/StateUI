// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

/// How an element's view is drawn over where its layout put it, the same on every host.
/// Design: docs/design/host/tree.md#drawn-over-its-place
extension MountedElement {
    /// The properties that move, turn and scale the view where its layout put it.
    public static let transformProperties: Set<Prop> = [
        .translationX, .translationY, .rotation, .rotationX, .rotationY, .scale, .scaleX, .scaleY, .pivotX, .pivotY,
    ]

    /// How the view is moved, turned and scaled: `scale` multiplies both axes on top of `scaleX` and `scaleY`, and
    /// it turns about its middle where the tree says no pivot.
    public var drawingTransform: HostDrawingTransform {
        let scale = number(.scale) ?? 1
        return HostDrawingTransform(
            translationX: number(.translationX) ?? 0,
            translationY: number(.translationY) ?? 0,
            rotation: number(.rotation) ?? 0,
            rotationX: number(.rotationX) ?? 0,
            rotationY: number(.rotationY) ?? 0,
            scaleX: scale * (number(.scaleX) ?? 1),
            scaleY: scale * (number(.scaleY) ?? 1),
            pivotX: number(.pivotX) ?? 0.5,
            pivotY: number(.pivotY) ?? 0.5)
    }

    /// The layout's own placing run, where a state drives one: it moves the children without changing what the
    /// layout measures.
    public var ownPlacementRun: Set<Prop> {
        driven[.area]?.kind == .placement ? [.area] : []
    }

    /// The places an engine gives the layout's children, one each; nil while no state drives them.
    public var placement: HostPlacementRun? {
        guard !ownPlacementRun.isEmpty, let carried = carriedValue(.area) else { return nil }
        return StateUIHost.placements(from: carried)
    }
}
