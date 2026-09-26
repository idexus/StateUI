// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

import StateUI

/// What a case puts on a specimen that only a view of a known kind takes - a state its frame lands in, the states a
/// pan carries, an aim - put on whatever kind the specimen is.
enum Opened {
    /// `view`, its frame landing in `room`.
    static func framed<V: View>(_ view: V, into room: Binding<Rect>) -> Element {
        view.frame(room)
    }

    /// `view`, a pan across it carrying `x`.
    static func pannedAcross<V: View>(_ view: V, carrying x: Binding<Double>) -> Element {
        view.panX(x)
    }

    /// `view`, a pan down it carrying `y`.
    static func pannedDown<V: View>(_ view: V, carrying y: Binding<Double>) -> Element {
        view.panY(y)
    }

    /// `view`, aimed at by `focus`.
    static func aimed<V: View>(_ view: V, by focus: FocusAim) -> Element {
        let aim = Aim(V.self)
        focus.hold(aim)
        return view.aim(aim)
    }
}

/// The keyboard's acts on one view, which a case's buttons call: whatever kind the view is.
final class FocusAim: @unchecked Sendable {
    private var focusing: (() async throws -> Bool)?
    private var unfocusing: (() async throws -> Void)?

    /// Acts on the view `aim` aims at.
    func hold<V>(_ aim: Aim<V>) {
        focusing = { try await aim.focus() }
        unfocusing = { try await aim.unfocus() }
    }

    /// Puts the keyboard on the view; whether it took it.
    func focus() async throws -> Bool {
        try await focusing?() ?? false
    }

    /// Takes the keyboard off the view.
    func unfocus() async throws {
        try await unfocusing?()
    }
}
