#if MAUI
import StateUI

/// The gallery's own acts and events - the ones with no control behind them.
///
/// MauiProgram registers a C# function or a raise under each name, and this
/// declares what each one takes, answers and carries, the way the library
/// declares its own.
enum GalleryContract: ApplicationTier {
    static let name = "Gallery"

    /// Puts text on the system clipboard. C#: `Clipboard.SetTextAsync`.
    static let setClipboard = ElementAct<Self, String, Void>("Gallery.SetClipboard")

    /// Reads the system clipboard - empty text when it holds none.
    /// C#: `Clipboard.GetTextAsync`.
    static let readClipboard = ElementAct<Self, Void, String>("Gallery.ReadClipboard")

    /// The battery's level, 0 through 1, and whether it is charging.
    /// C#: `Battery.Default`.
    static let batteryLevel = ElementAct<Self, Void, (Double, Bool)>("Gallery.BatteryLevel")

    /// Declared here and registered nowhere: calling it shows what an act no
    /// performer answers does.
    static let nobody = ElementAct<Self, Void, Void>("Gallery.Nobody")

    /// The battery reported: its level and whether it is charging.
    /// C#: `Battery.Default.BatteryInfoChanged`.
    static let batteryChanged = ElementEvent<Self, (Double, Bool)>("Gallery.BatteryChanged")

    /// The network came or went: whether the internet is reachable.
    /// C#: `Connectivity.ConnectivityChanged`.
    static let connectivityChanged = ElementEvent<Self, Bool>("Gallery.ConnectivityChanged")

    static let members: [any ContractMember] = [
        setClipboard, readClipboard, batteryLevel, nobody, batteryChanged, connectivityChanged,
    ]
}
#endif
