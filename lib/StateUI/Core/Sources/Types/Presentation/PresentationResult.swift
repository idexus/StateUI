// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

/// Whether a presentation change reached a host: what `PresentationChange.applied()` answers.
public enum PresentationApplication: Equatable, Sendable {
    /// A host took the change's writes: every movement they started under the aimed view is known.
    case applied

    /// Nothing shows the aimed view. The writes stand; nothing of them was drawn.
    case notPresented
}

/// How the movements a presentation change started ended: what `PresentationChange.settled()` answers.
public enum PresentationResult: Equatable, Sendable {
    /// Every movement came to rest where the change sent it - or the change started none.
    case settled

    /// At least one movement ended otherwise: why, each reason once, in the order
    /// `PresentationInterruption` declares them.
    case interrupted([PresentationInterruption])

    /// Nothing shows the aimed view.
    case notPresented
}

/// Why a movement a presentation change started did not come to rest where the change sent it.
public enum PresentationInterruption: Equatable, Sendable {
    /// A later write sent what it moved elsewhere.
    case superseded

    /// A state it moved was stopped where it stood.
    case stopped

    /// The view it moved left, or the window showing it did.
    case detached

    /// A view left by an exit nothing draws where it stood: it went at once.
    case unsupported

    /// A view's exit was cut short: too many views leaving at once, or one leaving for too long.
    case limited

    /// The reasons in the order a result names them.
    static let declared: [PresentationInterruption] = [.superseded, .stopped, .detached, .unsupported, .limited]
}
