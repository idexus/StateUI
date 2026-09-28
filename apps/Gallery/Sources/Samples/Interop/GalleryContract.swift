// The gallery's own acts and events, declared once for every host that
// answers them. Each host registers a performer or a source of its own under
// these names, beside its own head under Platforms/.
//
// PUBLIC, because a host in the same process registers BY TYPE and lives in a
// module of its own: these declarations are the application's API towards its
// own host.

import StateUI

/// The gallery's own acts and events - the ones with no control behind them.
///
/// A host registers a function or a raise under each name, and this declares
/// what each one takes, answers and carries, the way the library declares its
/// own. The names are the APPLICATION's, so they are the same wherever it
/// runs; what answers them is the host's.
public enum GalleryContract: ApplicationTier {
    public static let name = "Gallery"

    /// Puts text on the system clipboard.
    public static let setClipboard = ElementAct<Self, String, Void>("Gallery.SetClipboard")

    /// Reads the system clipboard - empty text when it holds none.
    public static let readClipboard = ElementAct<Self, Void, String>("Gallery.ReadClipboard")

    /// The battery's level, 0 through 1, and whether it is charging.
    public static let batteryLevel = ElementAct<Self, Void, (Double, Bool)>("Gallery.BatteryLevel")

    /// Declared here and registered nowhere: calling it shows what an act no
    /// performer answers does.
    public static let nobody = ElementAct<Self, Void, Void>("Gallery.Nobody")

    /// The battery reported: its level and whether it is charging.
    public static let batteryChanged =
        ElementEvent<Self, (Double, Bool)>("Gallery.BatteryChanged")

    /// The network came or went: whether the internet is reachable.
    public static let connectivityChanged =
        ElementEvent<Self, Bool>("Gallery.ConnectivityChanged")

    public static let members: [any ContractMember] = [
        setClipboard, readClipboard, batteryLevel, nobody, batteryChanged, connectivityChanged,
    ]
}
