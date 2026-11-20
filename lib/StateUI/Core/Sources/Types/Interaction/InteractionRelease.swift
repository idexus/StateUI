// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

/// How a value goes on once the hand lets go of it.
///
///     .release(.projected(.spring(Spring(response: .milliseconds(500), damping: 0.8))))
///     .release(.nearest(.eased(.milliseconds(250))))
///     .release(.stay)
///
/// Whichever is said, the value comes to rest inside its range, on a snap where it has snaps.
/// Design: docs/design/views/interaction.md#letting-go
public enum InteractionRelease: Equatable, Sendable {
    /// Where the hand left it: the nearest value it may rest at, with no travel.
    case stay

    /// Onto the value it may rest at nearest where the hand left it, under the motion; the hand's speed chooses
    /// nothing.
    case nearest(Motion)

    /// Thrown on: let go with speed it goes on to where the throw would end - the snap nearest there - as the
    /// motion says: eased, its length says how far a throw carries and its curve how it slows; a spring carries the
    /// hand's speed for a third of its response. Let go still, it comes onto the nearest under its state's motion.
    case projected(Motion)

    /// How a value goes on let go unless said: thrown on, slowing as a light friction would.
    static let standard = InteractionRelease.projected(.glide(longest: .milliseconds(800)))

    /// The motion a throw goes on by, where the release throws.
    var throwing: Motion? {
        if case .projected(let motion) = self { return motion }
        return nil
    }
}
