// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI

/// Whether a case runs on a host: every member it covers realized there, or the first that is not.
@_spi(Host) public enum Outcome: Equatable, Sendable {
    /// Every covered member is realized, in full or in part: the case runs, and passing proves them.
    case runs
    /// The host's family does not plan the member; why.
    case notPlanned(Covered, reason: String)
    /// The host does not realize the member yet - a gap its column already shows.
    case gap(Covered)

    /// The outcome of a case covering `covers` on a host with `marks`: never run where the host's register says
    /// never, nor where the host does not realize a member.
    public init(covering covers: [Covered], on marks: HostMarks) {
        for covered in covers {
            if case .notPlanned(let reason) = marks.mark(of: covered.member, on: covered.element, from: covered.tier) {
                self = .notPlanned(covered, reason: reason)
                return
            }
            guard marks.realizes(covered.member, on: covered.element, from: covered.tier) else {
                self = .gap(covered)
                return
            }
        }
        self = .runs
    }
}
