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
    @_spi(Host) public static let alert = ElementAct<Self, (Name, Name, String, String, String), Void>("alert", layer: .native)

    /// Has the platform's screen reader say a text.
    ///
    /// See `ApplicationSession.announce`.
    @_spi(Host) public static let announce = ElementAct<Self, String, Void>("announce", layer: .native)

    /// Stops what the host performs for the call answered under an id: its caller's run ended - a request stopped,
    /// a question still waiting its turn dropped. The library sends it; an application calls nothing.
    @_spi(Host) public static let cancelCall = ElementAct<Self, Int, Void>("cancelCall", layer: .structure)

    /// Offers the user a list of actions over a window - the window, the title,
    /// each action's caption, the place of the destructive one where there is
    /// one, and the cancel's caption - answering the place of the one chosen,
    /// or nothing where the choice was cancelled or dismissed.
    ///
    /// See `WindowSession.chooseAction`.
    @_spi(Host) public static let chooseAction = ElementAct<Self, (Name, Name, String, [String], Int?, String), Int?>(
        "chooseAction", layer: .native)

    /// Asks the user a yes-or-no question over a window - the window, the
    /// title, the message, and the captions that accept and cancel - answering
    /// whether it was accepted.
    ///
    /// See `WindowSession.confirm`.
    @_spi(Host) public static let confirm = ElementAct<Self, (Name, Name, String, String, String, String), Bool>("confirm", layer: .native)

    /// The host's local date and time of day, as seven numbers: year, month, day, hour, minute, second,
    /// millisecond.
    ///
    /// See `WallClock.now()` and `WallClock.today()`.
    @_spi(Host) public static let currentTime = ElementAct<Self, Void, [Double]>("currentTime", layer: .native)

    /// A handler's escaped error, reported to the host.
    @_spi(Host) public static let handlerFailed = ElementAct<Self, String, Void>("handlerFailed", layer: .structure)

    /// Takes the keyboard down from whichever view in a window holds the focus,
    /// answering whether one did: the window.
    ///
    /// See `WindowSession.hideOnScreenKeyboard()`.
    @_spi(Host) public static let hideOnScreenKeyboard = ElementAct<Self, (Name, Name), Bool>("hideOnScreenKeyboard", layer: .native)

    /// Opens a file the user chose in the application the system gives its
    /// kind, answering whether one took it.
    ///
    /// See `ChosenFile.launch()`.
    @_spi(Host) public static let launchFile = ElementAct<Self, ChosenFile, Bool>("launchFile", layer: .native)

    /// Opens an address in the application the system gives it - a web page,
    /// a mail address - answering whether one took it.
    ///
    /// See `ApplicationSession.launch(_:)`.
    @_spi(Host) public static let launchAddress = ElementAct<Self, String, Bool>("launchAddress", layer: .native)

    /// Shows the whole application in a theme - light, dark, or the system's,
    /// which follows the user's setting again.
    ///
    /// See `ApplicationSession.colorScheme`.
    @_spi(Host) public static let useColorScheme = ElementAct<Self, ColorScheme?, Void>("useColorScheme", layer: .native)

    /// Draws the application's controls in its own accent where the user
    /// chooses none for the system; nil gives the platform's back.
    ///
    /// See `ApplicationSession.accentColor`.
    @_spi(Host) public static let useAccentColor = ElementAct<Self, Color?, Void>("useAccentColor", layer: .native)

    /// Asks the user for files to open in the dialog over a window - the
    /// window, the kinds it shows, none for any, and whether it takes several -
    /// answering the files chosen, none where it was cancelled.
    ///
    /// See `WindowSession.openFile(types:)`.
    @_spi(Host) public static let openFiles = ElementAct<Self, (Name, Name, [FileType], Bool), [ChosenFile]>("openFiles", layer: .native)

    /// A scene key's new value, on its way to the platform's record of that
    /// scene: the scene, the key, the value.
    @_spi(Host) public static let persistSceneValue = ElementAct<Self, (Name, Name, PropValue), Void>("persistSceneValue", layer: .native)

    /// A kept key's new value, on its way to the store the host keeps it in.
    @_spi(Host) public static let persistValue = ElementAct<Self, (Name, PropValue), Void>("persistValue", layer: .native)

    /// Asks the user to type something over a window - the window, the title,
    /// the message, the captions that accept and cancel, the placeholder, the
    /// most characters, what the field is for and what it starts holding -
    /// answering the text, or nothing where it was cancelled.
    ///
    /// See `WindowSession.prompt`.
    @_spi(Host) public static let prompt = ElementAct<
        Self, (Name, Name, String, String, String, String, String?, Int?, InputPurpose, String), String?
    >("prompt", layer: .native)

    /// The words on the system's clipboard; nothing where it holds none.
    ///
    /// See `Clipboard.read()`.
    @_spi(Host) public static let readClipboard = ElementAct<Self, Void, String?>("readClipboard", layer: .native)

    /// Reads a file the user chose: whole where nothing more is said, else at
    /// most so many bytes from its start.
    ///
    /// See `ChosenFile.read()` and `ChosenFile.read(atMost:)`.
    @_spi(Host) public static let readFile = ElementAct<Self, (ChosenFile, Int?), [UInt8]>("readFile", layer: .native)

    /// Asks the user where to save in the dialog over a window, and writes the
    /// contents there - the window, the contents, the name it suggests and the
    /// kinds it offers - answering the file saved, or nothing where it was
    /// cancelled.
    ///
    /// See `WindowSession.saveFile(_:name:types:)`.
    @_spi(Host) public static let saveFile = ElementAct<Self, (Name, Name, [UInt8], String, [FileType]), ChosenFile?>("saveFile", layer: .native)

    /// Sends a request through the platform's own networking - the address, the
    /// method, the headers as names and values in turn, the body - answering the
    /// status, the headers the same way, their names in lowercase, and the body.
    ///
    /// See `ApplicationSession.send(_:)`.
    @_spi(Host) public static let sendRequest = ElementAct<Self, (String, Name, [String], [UInt8]), (Int, [String], [UInt8])>(
        "sendRequest", layer: .native)

    /// Offers words, an address or both to the platform's share sheet over a
    /// window - the window, the words, the address - answering whether the user
    /// shared them.
    ///
    /// See `WindowSession.share(text:address:)`.
    @_spi(Host) public static let share = ElementAct<Self, (Name, Name, String?, String?), Bool>("share", layer: .native)

    /// How far a zone is from UTC on a day, in minutes: the zone's identifier,
    /// the local one where there is none, and the day, now where there is
    /// none.
    ///
    /// See `WallClock.utcOffset(of:on:)`.
    @_spi(Host) public static let utcOffset = ElementAct<Self, (String?, CalendarDate?), Int>("utcOffset", layer: .native)

    /// Puts words on the system's clipboard, in place of whatever it held.
    ///
    /// See `Clipboard.write(_:)`.
    @_spi(Host) public static let writeClipboard = ElementAct<Self, String, Void>("writeClipboard", layer: .native)

    /// The element's own members.
    public static let members: [any ContractMember] = [
        alert, announce, cancelCall, chooseAction, confirm, currentTime, handlerFailed,
        hideOnScreenKeyboard, launchAddress, launchFile, openFiles, persistSceneValue, persistValue, prompt,
        readClipboard, readFile, saveFile, sendRequest, share, useAccentColor, useColorScheme, utcOffset,
        writeClipboard,
    ]
}
