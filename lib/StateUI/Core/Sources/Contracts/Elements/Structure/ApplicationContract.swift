// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

/// The application at the root of a StateUI tree, and what its host does for it
/// with no control behind it: questions for the user, the files they open and
/// save, what the system launches and what the user shares, the clock and the
/// time zone, the screen reader, the clipboard, what is kept.
public enum ApplicationContract: ElementContract, ApplicationTier {
    /// The node type the contract declares.
    public static let nodeType: NodeType = "Application"

    /// It carries structure, not a platform control of its own.
    public static let layer: ElementLayer = .structure

    /// Tells the user something over a window, with one button that dismisses
    /// it: the window, as its scene's key and its own - both empty for the
    /// window the user is in - the title, the message and the button's caption.
    ///
    /// See `WindowSession.alert`.
    public static let alert = ElementAct<Self, (Name, Name, String, String, String), Void>("alert")

    /// Has the platform's screen reader say a text.
    ///
    /// See `ApplicationSession.announce`.
    public static let announce = ElementAct<Self, String, Void>("announce")

    /// Stops what the host performs for the call answered under an id: its caller's run ended - a request stopped,
    /// a question still waiting its turn dropped. The library sends it; an application calls nothing.
    public static let cancelCall = ElementAct<Self, Int, Void>("cancelCall")

    /// Offers the user a list of actions over a window - the window, the title,
    /// each action's caption, the place of the destructive one where there is
    /// one, and the cancel's caption - answering the place of the one chosen,
    /// or nothing where the choice was cancelled or dismissed.
    ///
    /// See `WindowSession.chooseAction`.
    public static let chooseAction = ElementAct<Self, (Name, Name, String, [String], Int?, String), Int?>(
        "chooseAction")

    /// Asks the user a yes-or-no question over a window - the window, the
    /// title, the message, and the captions that accept and cancel - answering
    /// whether it was accepted.
    ///
    /// See `WindowSession.confirm`.
    public static let confirm = ElementAct<Self, (Name, Name, String, String, String, String), Bool>("confirm")

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

    /// Takes the keyboard down from whichever view in a window holds the focus,
    /// answering whether one did: the window.
    ///
    /// See `WindowSession.hideOnScreenKeyboard()`.
    public static let hideOnScreenKeyboard = ElementAct<Self, (Name, Name), Bool>("hideOnScreenKeyboard")

    /// Opens a file the user chose in the application the system gives its
    /// kind, answering whether one took it.
    ///
    /// See `ChosenFile.launch()`.
    public static let launchFile = ElementAct<Self, ChosenFile, Bool>("launchFile")

    /// Opens an address in the application the system gives it - a web page,
    /// a mail address - answering whether one took it.
    ///
    /// See `ApplicationSession.launch(_:)`.
    public static let launchLink = ElementAct<Self, String, Bool>("launchLink")

    /// Shows the whole application in a theme - light, dark, or the system's,
    /// which follows the user's setting again.
    ///
    /// See `ApplicationSession.colorScheme`.
    public static let useColorScheme = ElementAct<Self, ColorScheme, Void>("useColorScheme")

    /// Asks the user for files to open in the dialog over a window - the
    /// window, the kinds it shows, none for any, and whether it takes several -
    /// answering the files chosen, none where it was cancelled.
    ///
    /// See `WindowSession.openFile(types:)`.
    public static let openFiles = ElementAct<Self, (Name, Name, [FileType], Bool), [ChosenFile]>("openFiles")

    /// A scene key's new value, on its way to the platform's record of that
    /// scene: the scene, the key, the value.
    public static let persistSceneValue = ElementAct<Self, (Name, Name, PropValue), Void>("persistSceneValue")

    /// A kept key's new value, on its way to the store the host keeps it in.
    public static let persistValue = ElementAct<Self, (Name, PropValue), Void>("persistValue")

    /// Asks the user to type something over a window - the window, the title,
    /// the message, the captions that accept and cancel, the placeholder, the
    /// most characters, what the field is for and what it starts holding -
    /// answering the text, or nothing where it was cancelled.
    ///
    /// See `WindowSession.prompt`.
    public static let prompt = ElementAct<
        Self, (Name, Name, String, String, String, String, String?, Int?, InputPurpose, String), String?
    >("prompt")

    /// The words on the system's clipboard; nothing where it holds none.
    ///
    /// See `Clipboard.text()`.
    public static let readClipboard = ElementAct<Self, Void, String?>("readClipboard")

    /// Reads a file the user chose: whole where nothing more is said, else at
    /// most so many bytes from its start.
    ///
    /// See `ChosenFile.read()` and `ChosenFile.read(atMost:)`.
    public static let readFile = ElementAct<Self, (ChosenFile, Int?), [UInt8]>("readFile")

    /// Asks the user where to save in the dialog over a window, and writes the
    /// contents there - the window, the contents, the name it suggests and the
    /// kinds it offers - answering the file saved, or nothing where it was
    /// cancelled.
    ///
    /// See `WindowSession.saveFile(_:name:types:)`.
    public static let saveFile = ElementAct<Self, (Name, Name, [UInt8], String, [FileType]), ChosenFile?>("saveFile")

    /// Sends a request through the platform's own networking - the address, the
    /// method, the headers as names and values in turn, the body - answering the
    /// status, the headers the same way, their names in lowercase, and the body.
    ///
    /// See `ApplicationSession.send(_:)`.
    public static let sendRequest = ElementAct<Self, (String, Name, [String], [UInt8]), (Int, [String], [UInt8])>(
        "sendRequest")

    /// Offers words, a link or both to the platform's share sheet over a window -
    /// the window, the words, the link - answering whether the user shared
    /// them.
    ///
    /// See `WindowSession.share(text:link:)`.
    public static let share = ElementAct<Self, (Name, Name, String?, String?), Bool>("share")

    /// How far a zone is from UTC on a day, in minutes: the zone's identifier,
    /// the local one where there is none, and the day, now where there is
    /// none.
    ///
    /// See `TimeZoneInfo.utcOffset`.
    public static let utcOffset = ElementAct<Self, (String?, CalendarDate?), Int>("utcOffset")

    /// Puts words on the system's clipboard, in place of whatever it held.
    ///
    /// See `Clipboard.write(text:)`.
    public static let writeClipboard = ElementAct<Self, String, Void>("writeClipboard")

    /// The element's own members.
    public static let members: [any ContractMember] = [
        alert, announce, cancelCall, chooseAction, confirm, currentTime, currentTimeZone, handlerFailed,
        hideOnScreenKeyboard, launchFile, launchLink, openFiles, persistSceneValue, persistValue, prompt,
        readClipboard, readFile, saveFile, sendRequest, share, useColorScheme, utcOffset, writeClipboard,
    ]
}
