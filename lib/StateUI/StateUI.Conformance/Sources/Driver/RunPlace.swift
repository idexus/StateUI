// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI
@_spi(Host) import StateUIHost

/// Where a run of a text's words stands among the words its text shows, as the host layer's runs place it: the
/// text, and the run's letters in UTF-16 - what a driver reads a native text's attributes over.
@_spi(Host) public struct RunPlace {
    /// The text the run stands in.
    public let text: MountedElement

    /// The run's letters among the text's, in UTF-16.
    public let range: Range<Int>

    /// The place of `span` in the text it stands in; nil where it stands in none or the text shows no runs.
    @MainActor public init?(of span: MountedElement) {
        var each = span.parent
        while let found = each, found.type != .text { each = found.parent }
        guard let text = each, let runs = text.textRuns,
              let place = text.children.first(where: { $0.type == .textSpans })?.children
                  .filter({ $0.type == .textSpan }).firstIndex(where: { $0 === span }),
              runs.indices.contains(place)
        else { return nil }
        let start = runs[..<place].reduce(0) { $0 + $1.text.utf16.count }
        self.text = text
        range = start..<start + runs[place].text.utf16.count
    }
}
