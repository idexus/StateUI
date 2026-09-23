// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

/// Where a page stands in its native lifecycle.
///
///     .onChanged(page.phase) {
///         if page.phase == .appearing { try await refresh() }
///     }
///
/// It moves as the platform reports, which is not always in one order: a page
/// arriving says `appearing` then `navigatedTo`, while one being left says
/// `navigatingFrom`, `disappearing`, then `navigatedFrom`. A tab becoming
/// visible can say `appearing` without navigation. Reporting the current phase
/// again changes nothing.
public enum PagePhase: Sendable {
    /// Described, and not yet reported on screen - where every page starts.
    case created

    /// It is about to be shown - on every arrival, not only the first: coming
    /// back from a pushed page says it again.
    case appearing

    /// Navigation has arrived at it. Only navigation says this, while
    /// `appearing` also answers a page shown again for any other reason.
    case navigatedTo

    /// Navigation is about to leave it. It is still the page on screen: the
    /// moment to put away what the navigation must not carry.
    case navigatingFrom

    /// It has been covered or left - forward, back, or to another tab.
    case disappearing

    /// Navigation has left it; the destination is on screen.
    case navigatedFrom
}
