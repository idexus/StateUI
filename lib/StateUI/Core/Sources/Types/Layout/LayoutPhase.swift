// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

/// A layout engine's phase: one number an axis, each moved on its own by the user's hand or the program. This
/// library's own; `Double` is the phase of one axis.
///
///     struct Orbit: LayoutPhase {
///         var turn = 0.0
///         var zoom = 1.0
///
///         static var axes: [WritableKeyPath<Orbit, Double>] { [\.turn, \.zoom] }
///     }
///
///     @State private var orbit = Orbit()
///
///     LayoutEngine(planets, id: \.name) { … } placements: { room, orbit in … }
///         .phase($orbit)
///         .axis(\.turn, input: .scroll(.horizontal, pointsPerUnit: 240), range: 0...7, snaps: .every(1))
///
///     orbit.zoom = 2                    // travels there, the turn going on as it was
///
/// The axes are what the hand and the program move independently; how many dimensions the layout itself has is
/// the arithmetic's. The host walks the phase one lane an axis, in the order `axes` names them.
/// Design: docs/design/views/layout-engine.md#a-phase-of-many-axes
public protocol LayoutPhase: Walked {
    /// The axes, each a number of the phase, in the order the host walks them.
    static var axes: [WritableKeyPath<Self, Double>] { get }

    /// The phase every layout starts at that was lent none.
    init()
}

extension LayoutPhase {
    /// One lane an axis, in the order `axes` names them.
    public var carried: StateCarried { .lanes(Self.axes.map { self[keyPath: $0] }) }

    /// And back, where there is one lane an axis.
    public init?(carried: StateCarried) {
        guard case .lanes(let lanes) = carried, lanes.count == Self.axes.count else { return nil }

        self.init()
        for (axis, lane) in zip(Self.axes, lanes) { self[keyPath: axis] = lane }
    }

    /// One an axis.
    public static var lanes: Int { axes.count }
}

extension Double: LayoutPhase {
    /// The number itself, the one axis.
    public static var axes: [WritableKeyPath<Double, Double>] { [\.self] }
}
