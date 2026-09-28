// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI

/// What assistive technology meets of an element: its words, its heading level, and whether it is met at all.
/// Design: docs/design/host/tree.md#what-assistive-technology-meets
@_spi(Host) public struct AccessibilityWords: Equatable, Sendable {
    /// Whether assistive technology meets an element.
    public enum Presence: Equatable, Sendable {
        /// Met, where its view would of itself be left out.
        case met
        /// Left out, its children still met.
        case hidden
        /// Left out with everything in it.
        case hiddenWithChildren
    }

    /// The identifier whatever drives the application finds the element by; nil where it gives none.
    public var identifier: String?

    /// What the element is called; nil for its view's own words.
    public var label: String?

    /// What the element does, said after its label; nil where it says nothing.
    public var hint: String?

    /// Its level as a heading, 1 to 9; 0 where it is none.
    public var headingLevel: Int32

    /// Whether it is met; nil for as its view is of itself.
    public var presence: Presence?
}

extension MountedElement {
    /// What assistive technology meets; a change to any of them puts the element's words on its view again.
    public static let accessibilityProperties: Set<Prop> = [
        .accessibilityIdentifier, .accessibilityLabel, .accessibilityHint, .accessibilityHeadingLevel,
        .isAccessibilityHidden, .automationExcludedWithChildren,
    ]

    /// The element's words for assistive technology: left out with its children, or hidden, or met, as it says.
    public var accessibilityWords: AccessibilityWords {
        let presence: AccessibilityWords.Presence? = switch (
            bool(.automationExcludedWithChildren), bool(.isAccessibilityHidden)
        ) {
        case (true?, _): .hiddenWithChildren
        case (_, true?): .hidden
        case (_, false?): .met
        default: nil
        }
        return AccessibilityWords(
            identifier: string(.accessibilityIdentifier), label: string(.accessibilityLabel),
            hint: string(.accessibilityHint), headingLevel: max(0, value(.accessibilityHeadingLevel)?.enumeration ?? 0),
            presence: presence)
    }

    /// What assistive technology says for this element and all it holds, in reading order - the name of a row a
    /// toolkit's screen reader reads no further into: an element's label where it gives one, standing for all it
    /// holds; else its own words - its runs of words whole - then its children's, apart by commas; nothing of what
    /// is left out or hidden.
    /// Design: docs/design/host/tree.md#what-assistive-technology-meets
    public var spokenWords: String {
        let words = accessibilityWords
        guard words.presence != .hiddenWithChildren, bool(.isVisible) != false else { return "" }
        if let label = words.label, !label.isEmpty { return label }
        if let runs = textRuns { return words.presence == .hidden ? "" : runs.map(\.text).joined() }
        let own = words.presence == .hidden ? nil : string(.text)
        return ([own ?? ""] + children.map(\.spokenWords)).filter { !$0.isEmpty }.joined(separator: ", ")
    }
}
