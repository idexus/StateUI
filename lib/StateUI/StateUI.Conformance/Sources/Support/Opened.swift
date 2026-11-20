// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI

/// What a case puts on a specimen that only a view of a known kind takes - a state its frame lands in, the states a
/// pan carries, an aim - put on whatever kind the specimen is.
@MainActor
enum Opened {
    /// `view`, its frame at `stage` landing in `room`.
    static func framed<V: View>(_ view: V, into room: Binding<Rect>, stage: GeometryStage = .layout) -> some View {
        view.frame(into: room, stage: stage)
    }

    /// `view`, the hand moving `x` across it a point a point, left where the hand leaves it.
    static func moved<V: View>(_ view: V, across x: Binding<Double>) -> some View {
        view.interaction(.value(x, input: .translation(.horizontal)).release(.stay))
    }

    /// `view`, drawn twelve points across while a press stands on it.
    static func pressed<V: View>(_ view: V) -> some View {
        view.interaction(.press(values: .translation) { _ in PresentationOffset(translation: Point(x: 12, y: 0)) })
    }

    /// `view`, taken by the hand any way as soon as the press moves.
    static func taken<V: View>(_ view: V) -> some View {
        view.interaction(.drag(.both))
    }

    /// `view`, taken by the hand any way and dismissed thrown thirty points up.
    static func thrown<V: View>(_ view: V) -> some View {
        view.interaction(.drag(.both).dismissal(directions: .up, threshold: 30))
    }

    /// `view`, aimed at by `focus`.
    static func aimed<V: View>(_ view: V, by focus: FocusAim) -> some View {
        let aim = Aim(V.self)
        focus.hold(aim)
        return view.aim(aim)
    }
}

/// The keyboard's acts on one view, which a case's buttons call: whatever kind the view is.
final class FocusAim: @unchecked Sendable {
    private var focusing: (@MainActor () async throws -> Bool)?
    private var unfocusing: (@MainActor () async throws -> Void)?

    /// Acts on the view `aim` aims at.
    func hold<V>(_ aim: Aim<V>) {
        focusing = { try await aim.call(FocusElementContract.focus) }
        unfocusing = { try await aim.call(FocusElementContract.unfocus) }
    }

    /// Puts the keyboard on the view; whether it took it.
    @MainActor func focus() async throws -> Bool {
        try await focusing?() ?? false
    }

    /// Takes the keyboard off the view.
    @MainActor func unfocus() async throws {
        try await unfocusing?()
    }
}
