// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI
@_spi(Host) import StateUIHost

/// `SearchFieldContract` on a host: the user's search is heard as typed and as submitted; the program's words are
/// shown and heard by nobody; a return saying Next hands the keyboard on.
@_spi(Host) public enum SearchFieldTests: ConformanceFamily {
    public static let name = "SearchField"

    public static var cases: [ConformanceCase] {
        [
            Aspects.standsAlone("SearchField"),
        ]
    }
}
