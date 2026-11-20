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
        let own = HostDrawingTransform(
            translationX: number(.translationX) ?? 0,
            translationY: number(.translationY) ?? 0,
            rotation: number(.rotation) ?? 0,
            rotationX: number(.rotationX) ?? 0,
            rotationY: number(.rotationY) ?? 0,
            scaleX: scale * (number(.scaleX) ?? 1),
            scaleY: scale * (number(.scaleY) ?? 1),
            pivotX: number(.pivotX) ?? 0.5,
            pivotY: number(.pivotY) ?? 0.5)
        // What the hand does to the view itself is laid over its own transform here where no layout program
        // places it; one that does lays it over the view's place.
        // Design: docs/design/host/interaction.md#a-views-own-press-and-drag
        guard !local.isIdle, programPlacing == nil else { return own }

        let held = local.held ?? .zero
        return own.under(HostDrawingTransform(
            translationX: local.pressed.translation.x + held.x, translationY: local.pressed.translation.y + held.y,
            rotation: local.pressed.rotation, rotationX: 0, rotationY: 0, scaleX: local.pressed.scaleX,
            scaleY: local.pressed.scaleY, pivotX: 0.5, pivotY: 0.5))
    }

    /// The property a layout's own placing run is presented under, where the element runs a layout program: the
    /// run moves the children without changing what the layout measures.
    public var ownPlacementRun: Set<Prop> {
        layoutProgram != nil ? [.area] : []
    }

    /// The places the layout program gives the element's children, one each, standing in the run's direction; nil
    /// where the element runs none.
    public var placement: HostPlacementRun? {
        guard layoutProgram != nil else { return nil }
        return HostPlacementRun(placements: programPlaces, direction: runDirection)
    }

    /// The direction a motion layout's run and the hand over it stand in: right to left only where the layout mirrors
    /// (`MotionLayoutContract.mirrorsRightToLeft`) and lays out right to left - as written otherwise.
    /// Design: docs/design/host/layout.md#right-to-left
    public var runDirection: LayoutDirection {
        value(.mirrorsRightToLeft)?.bool == true ? layoutDirection : .leftToRight
    }
}
