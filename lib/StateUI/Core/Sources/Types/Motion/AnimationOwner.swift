// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

/// Who animates a state the host does not: an engine of the application's.
///
///     @State(animatedBy: .engine) private var ball = 0.0
///
/// Said at the declaration alone, since which side animates a state is fixed
/// when the state first reaches the host.
///
/// Design: docs/design/types/motion.md#an-engine-animates-a-state-of-its-own
public enum AnimationOwner: Equatable, Sendable {
    /// An engine of the application's: a write moves only where the value is
    /// going, the host animates nothing, and the engine writes where the value
    /// is and how fast it goes, frame by frame.
    case engine
}
