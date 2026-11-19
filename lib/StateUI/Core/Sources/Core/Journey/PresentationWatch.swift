// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

/// The reader key of the bodies that read a state's sample, and what an engine following its journey compares.
/// Design: docs/design/core/journeys.md#two-reader-sets
@MainActor
final class PresentationWatch: FollowedState, NamedState {
    /// How many times the sample changed, came or went, or a run showed the value elsewhere.
    var revision = 0

    var readAtBuild = false

    private weak var state: (any NamedState)?

    init(of state: any NamedState) {
        self.state = state
    }

    var stamp: Int { revision }

    var reports: Int { 0 }

    /// What a build's reason calls it: the state by its name, and what of it was read.
    var origin: String? {
        state?.origin.map { "\(BuildScope.readable($0)).journey.sample" }
    }
}
