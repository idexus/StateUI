// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

/// What `TextField`, `TextEditor` and `SearchField` share: the placeholder
/// and its colour, the keyboard, the caret and selection, the length cap and
/// read-only.
public protocol InputViewProperties: ViewProperties {}

/// A view the user types into.
public protocol InputView: View, InputViewProperties {}

extension InputView {
    /// Fires on every edit, with the whole of the new text. Runs after a
    /// binding's write, so the state already holds it.
    public func onTextChanged(_ handler: @escaping ValueEventHandler<String>) -> Modified {
        onEvent(InputViewContract.textChanged, handler)
    }
}

extension InputViewProperties {
    /// Where the caret sits, counted in characters from the start.
    ///
    /// Typing moves it by itself; write it to put the caret somewhere else,
    /// such as the end of text just filled in. A position past the end lands
    /// at the end.
    public func cursorPosition(_ value: Int) -> Modified {
        setValue(InputViewContract.cursorPosition, value)
    }

    /// How many characters from the caret are selected, 0 being none.
    ///
    ///     TextField($name).cursorPosition(0).selectionLength(name.count)
    ///
    /// selects the lot, for a field filled in for the user to replace.
    public func selectionLength(_ value: Int) -> Modified {
        setValue(InputViewContract.selectionLength, value)
    }

    /// Whether the platform underlines what it thinks is misspelt.
    ///
    /// Worth turning off for anything that is not prose - a code, a name, a
    /// serial number.
    public func isSpellCheckEnabled(_ value: Bool) -> Modified {
        setValue(InputViewContract.isSpellCheckEnabled, value)
    }

    /// Whether the platform offers the next word as the user types.
    ///
    /// Not the same as the spell check, and usually turned off with it and for
    /// the same fields.
    public func isTextPredictionEnabled(_ value: Bool) -> Modified {
        setValue(InputViewContract.isTextPredictionEnabled, value)
    }

    /// What the field says while it is empty.
    public func placeholder(_ value: String) -> Modified {
        setValue(InputViewContract.placeholder, value)
    }

    /// The colour of that text.
    public func placeholderColor(_ value: Color) -> Modified {
        setValue(InputViewContract.placeholderColor, value)
    }

    /// Whether the text can be selected and copied but not changed - which is
    /// not the same as disabled.
    public func isReadOnly(_ value: Bool) -> Modified {
        setValue(InputViewContract.isReadOnly, value)
    }

    /// What the field is for - an email address, a number, a url and the rest -
    /// which picks the keyboard the platform offers.
    public func inputPurpose(_ value: InputPurpose) -> Modified {
        setValue(InputViewContract.inputPurpose, value)
    }

    /// How many characters the field accepts.
    public func maximumLength(_ value: Int) -> Modified {
        setValue(InputViewContract.maximumLength, value)
    }
}
