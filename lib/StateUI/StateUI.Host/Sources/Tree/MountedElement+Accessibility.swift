// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI

/// What assistive technology meets of an element: its words, its heading level, and whether it is met at all.
/// Design: docs/design/host/tree.md#what-assistive-technology-meets
@_spi(Host) public struct AccessibilityWords: Equatable, Sendable {
    /// The identifier whatever drives the application finds the element by; nil where it gives none.
    public var identifier: String?

    /// What the element is called - as the author says, else the words it leaves out of sight beside its picture;
    /// nil for its view's own words.
    public var label: String?

    /// What the element does, said after its label; nil where it says nothing.
    public var hint: String?

    /// What kind of thing the element is; nil for its view's own kind.
    public var role: AccessibilityRole?

    /// What the element holds, said after its label; nil for its view's own value.
    public var value: String?

    /// The words of the actions a screen reader offers on the element, in order; none where it offers none.
    public var actions: [String]

    /// Its level as a heading, 1 to 9; 0 where it is none.
    public var headingLevel: Int32

    /// Whether it is met, and what is inside it - `.element` also where its view would of itself be left out but it
    /// says words of its own or answers a tap; nil for as its view is of itself.
    public var presence: AccessibilityPresence?

    /// Whether its view is an element to assistive technology: as its presence says, else as the view `standing`
    /// was of itself, before any word reached it.
    /// Design: docs/design/host/tree.md#what-assistive-technology-meets
    public func isElement(standing: Bool) -> Bool {
        presence.map { $0 == .element } ?? standing
    }

    /// Words of these parts.
    public init(
        identifier: String?, label: String?, hint: String?, role: AccessibilityRole? = nil, value: String? = nil,
        actions: [String] = [], headingLevel: Int32, presence: AccessibilityPresence?
    ) {
        self.identifier = identifier
        self.label = label
        self.hint = hint
        self.role = role
        self.value = value
        self.actions = actions
        self.headingLevel = headingLevel
        self.presence = presence
    }
}

extension MountedElement {
    /// What assistive technology meets; a change to any of them puts the element's words on its view again.
    public static let accessibilityProperties: Set<Prop> = [
        .accessibilityIdentifier, .accessibilityLabel, .accessibilityHint, .accessibilityRole, .accessibilityValue,
        .accessibilityActions, .accessibilityHeading, .accessibilityPresence,
    ]

    /// The element's words for assistive technology: left out with its contents, or hidden, or met, as it says -
    /// and saying nothing of it, met where it says words of its own - a label standing for all it holds, a hint, a
    /// kind, a value, an action, a heading - or answers a tap; else as its view stands of itself.
    /// Design: docs/design/host/tree.md#what-assistive-technology-meets
    public var accessibilityWords: AccessibilityWords {
        let (label, hint) = (string(.accessibilityLabel) ?? wordsOutOfSight, string(.accessibilityHint))
        let (role, said) = (value(.accessibilityRole).flatMap(AccessibilityRole.init(propValue:)), string(.accessibilityValue))
        let actions = value(.accessibilityActions).flatMap([String].init(propValue:)) ?? []
        let headingLevel = max(0, value(.accessibilityHeading)?.enumeration ?? 0)
        let saysWords = label != nil || hint != nil || role != nil || said != nil || !actions.isEmpty || headingLevel > 0
            || events[.tapped] != nil
        let presence = value(.accessibilityPresence).flatMap(AccessibilityPresence.init(propValue:))
            ?? (saysWords ? .element : nil)
        return AccessibilityWords(
            identifier: string(.accessibilityIdentifier), label: label, hint: hint, role: role, value: said,
            actions: actions, headingLevel: headingLevel, presence: presence)
    }

    /// The words an element showing words and a picture leaves out of sight (`TextAndIcon`), which name it; nil where
    /// they show, or it has none.
    var wordsOutOfSight: String? {
        guard value(.showsText)?.bool == false, HostPicture(value(.icon)) != nil, let words = string(.text),
              !words.isEmpty
        else { return nil }
        return words
    }

    /// Whether a change to `changed` - everything that changed, what a registration took included - puts the
    /// element's words for assistive technology on its view again: to one of them, to whether its words show beside
    /// its picture, or - its words out of sight naming it - to its words or its picture.
    public func changesAccessibility(_ changed: Set<Prop>) -> Bool {
        !changed.isDisjoint(with: Self.accessibilityProperties) || changed.contains(.showsText)
            || (value(.showsText)?.bool == false && !changed.isDisjoint(with: [.text, .icon]))
    }

    /// What assistive technology says for this element and all it holds, in reading order - the name of a row a
    /// toolkit's screen reader reads no further into: an element's label where it gives one, standing for all it
    /// holds; else its own words - its runs of words whole - then its children's, apart by commas; nothing of what
    /// is left out, and nothing of a hidden element's own while what it holds still speaks.
    /// Design: docs/design/host/tree.md#what-assistive-technology-meets
    public var spokenWords: String {
        let words = accessibilityWords
        guard words.presence != .hiddenWithContents, bool(.isVisible) != false else { return "" }
        let hidden = words.presence == .hidden
        if !hidden, let label = words.label, !label.isEmpty { return label }
        if let runs = textRuns { return hidden ? "" : runs.map(\.text).joined() }
        let own = hidden ? nil : string(.text)
        return ([own ?? ""] + children.map(\.spokenWords)).filter { !$0.isEmpty }.joined(separator: ", ")
    }
}
