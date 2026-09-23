// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

// A closed vocabulary, numbered by StateUI: append a case, never insert one.
// Design: docs/design/types/vocabularies.md#written-out-and-appended

/// What a map pin stands for - what `.type` takes, and what decides the icon
/// the platform draws.
public enum PinType: Int32, Sendable {
    /// Somewhere on the map, with no more said. The default.
    case generic = 0

    /// A place - a shop, a station, a landmark.
    case place = 1

    /// One the user saved.
    case savedPin = 2

    /// One a search turned up.
    case searchResult = 3
}

extension PinType: HostRepresentable {}
