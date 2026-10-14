// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

// A key: a character's, or one of a closed set numbered by StateUI.
// Design: docs/design/types/keyboard.md#a-key

/// A key a shortcut is pressed with: a character's - written as one, `"s"` -
/// or one of the keys that write none.
///
///     Button("Save").keyboardShortcut("s")
///     Button("Send").keyboardShortcut(.return)
///
/// A letter is its key whatever its case: Shift is a modifier, so `"S"` is
/// the key `"s"`.
public struct Key: Hashable, Sendable, ExpressibleByExtendedGraphemeClusterLiteral {
    /// The character the key writes, a letter in lower case; nil for a key writing none.
    @_spi(Host) public let character: Character?

    /// The key writing no character; nil for a character's.
    @_spi(Host) public let named: NamedKey?

    /// The key writing `character`.
    public init(_ character: Character) {
        let lower = character.lowercased()
        self.character = lower.count == 1 ? Character(lower) : character
        named = nil
    }

    /// The key writing the character written, `"s"`.
    public init(extendedGraphemeClusterLiteral value: Character) {
        self.init(value)
    }

    /// The key writing no character that `named` is.
    @_spi(Host) public init(_ named: NamedKey) {
        character = nil
        self.named = named
    }

    /// Return, or Enter.
    public static let `return` = Key(.return)

    /// Escape.
    public static let escape = Key(.escape)

    /// Delete: the key taking back the character before the cursor.
    public static let delete = Key(.delete)

    /// The up arrow.
    public static let upArrow = Key(.upArrow)

    /// The down arrow.
    public static let downArrow = Key(.downArrow)

    /// The left arrow.
    public static let leftArrow = Key(.leftArrow)

    /// The right arrow.
    public static let rightArrow = Key(.rightArrow)

    /// The function key F1.
    public static let f1 = Key(.f1)

    /// The function key F2.
    public static let f2 = Key(.f2)

    /// The function key F3.
    public static let f3 = Key(.f3)

    /// The function key F4.
    public static let f4 = Key(.f4)

    /// The function key F5.
    public static let f5 = Key(.f5)

    /// The function key F6.
    public static let f6 = Key(.f6)

    /// The function key F7.
    public static let f7 = Key(.f7)

    /// The function key F8.
    public static let f8 = Key(.f8)

    /// The function key F9.
    public static let f9 = Key(.f9)

    /// The function key F10.
    public static let f10 = Key(.f10)

    /// The function key F11.
    public static let f11 = Key(.f11)

    /// The function key F12.
    public static let f12 = Key(.f12)
}

extension Key: HostRepresentable {
    /// The key as it crosses: a character as text, another key by its number.
    public var propValue: PropValue {
        if let character { return .string(String(character)) }
        return .enumeration(named?.rawValue ?? 0)
    }

    /// The key back from what crossed.
    public init?(propValue: PropValue) {
        switch propValue {
        case .string(let text) where text.count == 1: self.init(text.first!)
        case .enumeration(let number):
            guard let named = NamedKey(rawValue: number) else { return nil }
            self.init(named)
        default: return nil
        }
    }

    /// `keys` once each, in StateUI's order - the keys writing no character by their number, then the characters -
    /// as a patch carries them.
    @_spi(Host) public static func ordered(_ keys: some Sequence<Key>) -> [Key] {
        Set(keys).sorted {
            switch ($0.named, $1.named) {
            case let (first?, second?): first.rawValue < second.rawValue
            case (.some, nil): true
            case (nil, .some): false
            case (nil, nil): String($0.character ?? " ") < String($1.character ?? " ")
            }
        }
    }
}

/// The keys that write no character, as a host reads them.
@_spi(Host) public enum NamedKey: Int32, Sendable, CaseIterable {
    /// Return, or Enter.
    case `return` = 1
    /// Escape.
    case escape = 2
    /// Delete, taking back the character before the cursor.
    case delete = 3
    /// The up arrow.
    case upArrow = 4
    /// The down arrow.
    case downArrow = 5
    /// The left arrow.
    case leftArrow = 6
    /// The right arrow.
    case rightArrow = 7
    /// The function key F1.
    case f1 = 11
    /// The function key F2.
    case f2 = 12
    /// The function key F3.
    case f3 = 13
    /// The function key F4.
    case f4 = 14
    /// The function key F5.
    case f5 = 15
    /// The function key F6.
    case f6 = 16
    /// The function key F7.
    case f7 = 17
    /// The function key F8.
    case f8 = 18
    /// The function key F9.
    case f9 = 19
    /// The function key F10.
    case f10 = 20
    /// The function key F11.
    case f11 = 21
    /// The function key F12.
    case f12 = 22
}
