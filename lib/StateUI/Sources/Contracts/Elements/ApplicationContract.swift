// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

/// The application at the root of a StateUI tree, and what its host does for it
/// with no control behind it: questions for the reader, the clock and the time
/// zone, the screen reader, what is kept.
public enum ApplicationContract: ElementContract, ApplicationTier {
    /// The node type the contract declares.
    public static let nodeType: NodeType = "Application"

    /// It carries structure, not a platform control of its own.
    public static let layer: ElementLayer = .structure

    /// Tells the reader something on the showing page, with one button that
    /// dismisses it: the title, the message and the button's caption.
    ///
    /// See `Dialogs.alert`.
    public static let alert = ElementAct<Self, (String, String, String), Void>("alert")

    /// Has the platform's screen reader say a text.
    ///
    /// See `ScreenReader.announce`.
    public static let announce = ElementAct<Self, String, Void>("announce")

    /// Offers the reader a list of choices on the showing page - the title, the
    /// cancel and the destructive captions where there are ones, and the
    /// choices - answering the pressed caption, or nothing where the sheet was
    /// dismissed.
    ///
    /// See `Dialogs.chooseAction`.
    public static let chooseAction = ElementAct<Self, (String, String?, String?, [String]), String?>(
        "chooseAction")

    /// Asks the reader a yes-or-no question on the showing page - the title,
    /// the message, and the captions that accept and cancel - answering whether
    /// it was accepted.
    ///
    /// See `Dialogs.confirm`.
    public static let confirm = ElementAct<Self, (String, String, String, String), Bool>("confirm")

    /// The host's local time of day, as four numbers: hour, minute, second,
    /// millisecond.
    ///
    /// See `ClockTime.now()`.
    public static let currentTime = ElementAct<Self, Void, [Double]>("currentTime")

    /// The IANA identifier of the host's local time zone.
    ///
    /// See `TimeZoneInfo.local()`.
    public static let currentTimeZone = ElementAct<Self, Void, String>("currentTimeZone")

    /// A handler's escaped error, reported to the host.
    public static let handlerFailed = ElementAct<Self, String, Void>("handlerFailed")

    /// Takes the keyboard down from whichever view on the showing page holds
    /// the focus, answering whether one did.
    ///
    /// See `OnScreenKeyboard.hide()`.
    public static let hideOnScreenKeyboard = ElementAct<Self, Void, Bool>("hideOnScreenKeyboard")

    /// A scene key's new value, on its way to the platform's record of that
    /// scene: the scene, the key, the value.
    public static let persistSceneValue = ElementAct<Self, (Name, Name, PropValue), Void>("persistSceneValue")

    /// A kept key's new value, on its way to the store the host keeps it in.
    public static let persistValue = ElementAct<Self, (Name, PropValue), Void>("persistValue")

    /// Asks the reader to type something on the showing page - the title, the
    /// message, the captions that accept and cancel, the placeholder, the most
    /// characters, what the field is for and what it starts holding - answering
    /// the text, or nothing where it was cancelled.
    ///
    /// See `Dialogs.prompt`.
    public static let prompt = ElementAct<Self, (String, String, String, String, String?, Int?, InputPurpose, String), String?>(
        "prompt")

    /// How far a zone is from UTC on a day, in minutes: the zone's identifier,
    /// the local one where there is none, and the day, today where there is
    /// none.
    ///
    /// See `TimeZoneInfo.utcOffset`.
    public static let utcOffset = ElementAct<Self, (String?, CalendarDate?), Int>("utcOffset")

    /// The element's own members.
    public static let members: [any ContractMember] = [
        alert, announce, chooseAction, confirm, currentTime, currentTimeZone, handlerFailed,
        hideOnScreenKeyboard, persistSceneValue, persistValue, prompt, utcOffset,
    ]
}
