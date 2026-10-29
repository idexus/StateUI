// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI

/// How an element's view is drawn over where its layout put it, the same on every host.
/// Design: docs/design/host/tree.md#drawn-over-its-place
extension MountedElement {
    /// The properties that move, turn and scale the view where its layout put it.
    public static let transformProperties: Set<Prop> = [
        .translationX, .translationY, .rotation, .rotationX, .rotationY, .scale, .scaleX, .scaleY, .pivotX, .pivotY,
    ]

    /// What is drawn over the view and read by nothing it holds - its opacity, its drawing, its transform: a frame
    /// moving them alone arranges none of its children.
    /// Design: docs/design/host/tree.md#a-frame-arranges-what-moved
    public static let drawnOverProperties = transformProperties.union([.opacity, .drawing])

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

    /// The property carrying the layout's own placing run, where a state drives one: the run moves the children
    /// without changing what the layout measures.
    public var ownPlacementRun: Set<Prop> {
        driven[.area]?.kind == .placement ? [.area] : []
    }

    /// The places an engine gives the layout's children, one each, standing in the run's direction; nil while no
    /// state drives them.
    public var placement: HostPlacementRun? {
        guard !ownPlacementRun.isEmpty, let carried = carriedValue(.area),
              let run = HostBoundary.placements(from: carried) else { return nil }
        return HostPlacementRun(placements: run.placements, direction: runDirection)
    }

    /// The direction a phase layout's run and the hand over it stand in: right to left only where the layout mirrors
    /// (`PhaseLayoutContract.mirrorsRightToLeft`) and lays out right to left - as written otherwise.
    /// Design: docs/design/host/layout.md#right-to-left
    public var runDirection: LayoutDirection {
        value(.mirrorsRightToLeft)?.bool == true ? layoutDirection : .leftToRight
    }
}
