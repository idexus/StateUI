using System.Globalization;
using Microsoft.Maui.Devices;
using Microsoft.Maui.Networking;
using StateUI.Runtime.Interop;
using StateUI.Runtime.Protocol;

namespace StateUI.Runtime.Rendering;

/// <summary>
/// The STANDARD ENVIRONMENT's host half: what this side knows - the battery,
/// the network, the display, the locale, the device, the app, the window's
/// phase - pushed into the Swift providers any view resolves with
/// <c>@Environment</c>. See <c>Types/HostEnvironment.swift</c> for the other
/// half and the payload each domain carries.
/// </summary>
/// <remarks>
/// <para>
/// Every domain is pushed once at session start, BEFORE the first render, so
/// the first tree already knows its idiom and its locale - and again from the
/// platform's own change events, each push rebuilding exactly the Swift views
/// that read the changed provider. A platform that cannot answer a domain -
/// headless tests, a desktop with no battery - simply does not push it, and
/// the Swift side keeps that provider's defaults: the honest answer, not a
/// crash.
/// </para>
/// <para>
/// Every enum crosses as THIS REPOSITORY's number for the member -
/// <c>SwiftWireValue.OfMember</c> over the mirrors in
/// <c>Protocol/SwiftWireEnums.cs</c>, translated by a switch naming the MAUI
/// member literally, never a cast of MAUI's own value: a cast would leave a
/// MAUI release free to renumber an enum and have the Swift side read every
/// report as a different member, with nothing failing anywhere. The idiom and
/// the window phase have no MAUI enum behind them at all, so their translation
/// is a comparison chain rather than a switch.
/// </para>
/// </remarks>
internal static class StateUIEnvironment
{
    // The domain bytes - the Swift side's EnvironmentDomain, spelled here.
    internal const byte BatteryDomain = 1;
    internal const byte ConnectivityDomain = 2;
    internal const byte DisplayDomain = 3;
    internal const byte LocaleDomain = 4;
    internal const byte DeviceDomain = 5;
    internal const byte AppInfoDomain = 6;
    internal const byte WindowDomain = 7;

    /// <summary>The session that carries a push into Swift - the newest wins,
    /// which is the interface that is showing, the
    /// <see cref="StateUIEvents"/> rule.</summary>
    internal static StateUISession? Session { get; private set; }

    /// <summary>Whether the platform's change events are already wired - once
    /// per process, there being one Swift runtime behind every session.</summary>
    private static bool _wired;

    /// <summary>
    /// Adopts the session and tells Swift everything, one domain at a time -
    /// called from the session's first render, after the app registered and
    /// the wire version matched, and BEFORE the first tree is built. No pump:
    /// this runs inside the render that is about to happen anyway.
    /// </summary>
    internal static void Start(StateUISession session)
    {
        Session = session;
        WireOnce();

        session.PushEnvironment(DeviceDomain, DeviceSnapshot, pump: false);
        session.PushEnvironment(AppInfoDomain, AppSnapshot, pump: false);
        session.PushEnvironment(LocaleDomain, LocaleSnapshot, pump: false);
        session.PushEnvironment(DisplayDomain, DisplaySnapshot, pump: false);
        session.PushEnvironment(BatteryDomain, BatterySnapshot, pump: false);
        session.PushEnvironment(ConnectivityDomain, ConnectivitySnapshot, pump: false);
        session.PushEnvironment(
            WindowDomain,
            () => [SwiftWireValue.OfMember((int)SwiftWindowPhase.Activated)],
            pump: false);
    }

    /// <summary>
    /// Reports where the window now stands. Called from
    /// <see cref="StateUIRenderer.WireWindow"/> as MAUI raises the window's
    /// events; Resumed reports <see cref="SwiftWindowPhase.Deactivated"/>, the
    /// window being visible again but not yet active - Activated follows on its
    /// own where the platform means it.
    /// </summary>
    /// <param name="phase">Which of the three the window is now in.</param>
    internal static void WindowPhase(SwiftWindowPhase phase)
    {
        Session?.PushEnvironment(WindowDomain, () => [SwiftWireValue.OfMember((int)phase)]);
    }

    /// <summary>
    /// Re-pushes the app domain because the theme moved - subscribed by the
    /// session beside the styles rebuild, the one place that already hears
    /// <c>RequestedThemeChanged</c>.
    /// </summary>
    internal static void ThemeChanged()
    {
        Session?.PushEnvironment(AppInfoDomain, AppSnapshot);
    }

    /// <summary>
    /// Subscribes the platform's own change events, each in its own guard: a
    /// source a platform does not implement - headless, or a desktop with no
    /// battery - throws on first touch, and must cost only itself.
    /// </summary>
    private static void WireOnce()
    {
        if (_wired)
        {
            return;
        }

        _wired = true;

        try
        {
            Battery.Default.BatteryInfoChanged += (_, _) =>
                Session?.PushEnvironment(BatteryDomain, BatterySnapshot);
            Battery.Default.EnergySaverStatusChanged += (_, _) =>
                Session?.PushEnvironment(BatteryDomain, BatterySnapshot);
        }
        catch (Exception)
        {
            // The platform does not say; the provider keeps its defaults.
        }

        try
        {
            Connectivity.Current.ConnectivityChanged += (_, _) =>
                Session?.PushEnvironment(ConnectivityDomain, ConnectivitySnapshot);
        }
        catch (Exception)
        {
        }

        try
        {
            DeviceDisplay.Current.MainDisplayInfoChanged += (_, _) =>
                Session?.PushEnvironment(DisplayDomain, DisplaySnapshot);
        }
        catch (Exception)
        {
        }
    }

    /// <summary>The battery's four values, in the Swift provider's order.</summary>
    private static SwiftWireValue[] BatterySnapshot()
    {
        IBattery battery = Battery.Default;

        return
        [
            SwiftWireValue.Of(battery.ChargeLevel),
            SwiftWireValue.OfMember((int)Member(battery.State)),
            SwiftWireValue.OfMember((int)Member(battery.PowerSource)),
            SwiftWireValue.OfMember((int)Member(battery.EnergySaverStatus)),
        ];
    }

    /// <summary>The network's reach, and every profile it is reached by.</summary>
    private static SwiftWireValue[] ConnectivitySnapshot()
    {
        IConnectivity connectivity = Connectivity.Current;

        return
        [
            SwiftWireValue.OfMember((int)Member(connectivity.NetworkAccess)),

            // A list of MEMBERS, so a list of values rather than the run of
            // doubles it was: a run of doubles is a run of quantities.
            SwiftWireValue.OfValues(
                [.. connectivity.ConnectionProfiles.Select(
                    profile => SwiftWireValue.OfMember((int)Member(profile)))]),
        ];
    }

    /// <summary>The main display, as MAUI measures it - pixels, density, and
    /// which way it is turned.</summary>
    private static SwiftWireValue[] DisplaySnapshot()
    {
        DisplayInfo info = DeviceDisplay.Current.MainDisplayInfo;

        return
        [
            SwiftWireValue.Of(info.Width),
            SwiftWireValue.Of(info.Height),
            SwiftWireValue.Of(info.Density),
            SwiftWireValue.OfMember((int)Member(info.Orientation)),
            SwiftWireValue.OfMember((int)Member(info.Rotation)),
            SwiftWireValue.Of(info.RefreshRate),
        ];
    }

    /// <summary>
    /// The reader's language, region, zone and calendar habits - .NET spreads
    /// them over CultureInfo, RegionInfo and TimeZoneInfo, and the zone goes
    /// out as its IANA name, the <c>TimeZoneInfo.local()</c> act's rule.
    /// </summary>
    private static SwiftWireValue[] LocaleSnapshot()
    {
        CultureInfo culture = CultureInfo.CurrentCulture;

        string region = "";
        bool metric = true;

        try
        {
            var info = new RegionInfo(culture.Name);
            region = info.TwoLetterISORegionName;
            metric = info.IsMetric;
        }
        catch (ArgumentException)
        {
            // A neutral culture names no region; the empty string says so.
        }

        TimeZoneInfo zone = TimeZoneInfo.Local;
        string ianaZone =
            zone.HasIanaId ? zone.Id
            : TimeZoneInfo.TryConvertWindowsIdToIanaId(zone.Id, out string? iana) ? iana
            : zone.Id;

        return
        [
            SwiftWireValue.Of(culture.TwoLetterISOLanguageName),
            SwiftWireValue.Of(region),
            SwiftWireValue.Of(culture.Name),
            SwiftWireValue.Of(ianaZone),
            SwiftWireValue.Of(culture.DateTimeFormat.ShortTimePattern.Contains('H')),
            SwiftWireValue.OfMember((int)Member(culture.DateTimeFormat.FirstDayOfWeek)),
            SwiftWireValue.Of(metric),
        ];
    }

    /// <summary>
    /// The device's facts, the idiom first - as this library's number, MAUI
    /// keeping its <see cref="DeviceIdiom"/> as a struct compared by value
    /// with no number to borrow.
    /// </summary>
    private static SwiftWireValue[] DeviceSnapshot()
    {
        IDeviceInfo device = DeviceInfo.Current;
        // MAUI's DeviceIdiom is a struct compared by value, so this is a
        // chain of comparisons rather than a switch - the shape a translation
        // takes when the far side has no enum to switch over.
        DeviceIdiom idiom = device.Idiom;

        SwiftDeviceIdiom member =
            idiom == DeviceIdiom.Phone ? SwiftDeviceIdiom.Phone
            : idiom == DeviceIdiom.Tablet ? SwiftDeviceIdiom.Tablet
            : idiom == DeviceIdiom.Desktop ? SwiftDeviceIdiom.Desktop
            : idiom == DeviceIdiom.TV ? SwiftDeviceIdiom.Tv
            : idiom == DeviceIdiom.Watch ? SwiftDeviceIdiom.Watch
            : SwiftDeviceIdiom.Unknown;

        return
        [
            SwiftWireValue.OfMember((int)member),
            SwiftWireValue.Of(device.Platform.ToString()),
            SwiftWireValue.Of(device.Model),
            SwiftWireValue.Of(device.Manufacturer),
            SwiftWireValue.Of(device.Name),
            SwiftWireValue.Of(device.VersionString),
            SwiftWireValue.OfMember((int)Member(device.DeviceType)),
        ];
    }

    /// <summary>The app's manifest facts, and the one value here that moves:
    /// the requested theme.</summary>
    private static SwiftWireValue[] AppSnapshot()
    {
        Microsoft.Maui.ApplicationModel.IAppInfo app =
            Microsoft.Maui.ApplicationModel.AppInfo.Current;

        return
        [
            SwiftWireValue.Of(app.Name),
            SwiftWireValue.Of(app.PackageName),
            SwiftWireValue.Of(app.VersionString),
            SwiftWireValue.Of(app.BuildString),
            SwiftWireValue.OfMember((int)Member(app.RequestedTheme)),
        ];
    }

    // ---- MAUI's members, translated onto ours ------------------------------
    //
    // One switch per vocabulary, naming the MAUI member literally so the
    // compiler checks the pairing, and a default for the member a newer MAUI
    // might add: the Swift side reads a number it has no case for as its own
    // `.unknown`, so both ends degrade the same way and a new battery state
    // costs the battery nothing but that one value. Nothing here casts - a
    // cast puts MAUI's number on the wire, which is the one thing this must
    // not do.

    /// <summary>How the battery is doing, as this side's member.</summary>
    internal static SwiftBatteryState Member(BatteryState state) => state switch
    {
        BatteryState.Unknown => SwiftBatteryState.Unknown,
        BatteryState.Charging => SwiftBatteryState.Charging,
        BatteryState.Discharging => SwiftBatteryState.Discharging,
        BatteryState.Full => SwiftBatteryState.Full,
        BatteryState.NotCharging => SwiftBatteryState.NotCharging,
        BatteryState.NotPresent => SwiftBatteryState.NotPresent,
        _ => SwiftBatteryState.Unknown,
    };

    /// <summary>Where the power is coming from, as this side's member.</summary>
    internal static SwiftBatteryPowerSource Member(BatteryPowerSource source) => source switch
    {
        BatteryPowerSource.Unknown => SwiftBatteryPowerSource.Unknown,
        BatteryPowerSource.Battery => SwiftBatteryPowerSource.Battery,
        BatteryPowerSource.AC => SwiftBatteryPowerSource.Ac,
        BatteryPowerSource.Usb => SwiftBatteryPowerSource.Usb,
        BatteryPowerSource.Wireless => SwiftBatteryPowerSource.Wireless,
        _ => SwiftBatteryPowerSource.Unknown,
    };

    /// <summary>Whether the battery saver is on, as this side's member.</summary>
    internal static SwiftEnergySaverStatus Member(EnergySaverStatus status) => status switch
    {
        EnergySaverStatus.Unknown => SwiftEnergySaverStatus.Unknown,
        EnergySaverStatus.On => SwiftEnergySaverStatus.On,
        EnergySaverStatus.Off => SwiftEnergySaverStatus.Off,
        _ => SwiftEnergySaverStatus.Unknown,
    };

    /// <summary>What the network can reach, as this side's member.</summary>
    internal static SwiftNetworkAccess Member(NetworkAccess access) => access switch
    {
        NetworkAccess.Unknown => SwiftNetworkAccess.Unknown,
        NetworkAccess.None => SwiftNetworkAccess.None,
        NetworkAccess.Local => SwiftNetworkAccess.Local,
        NetworkAccess.ConstrainedInternet => SwiftNetworkAccess.ConstrainedInternet,
        NetworkAccess.Internet => SwiftNetworkAccess.Internet,
        _ => SwiftNetworkAccess.Unknown,
    };

    /// <summary>One way the device is connected, as this side's member.</summary>
    internal static SwiftConnectionProfile Member(ConnectionProfile profile) => profile switch
    {
        ConnectionProfile.Unknown => SwiftConnectionProfile.Unknown,
        ConnectionProfile.Bluetooth => SwiftConnectionProfile.Bluetooth,
        ConnectionProfile.Cellular => SwiftConnectionProfile.Cellular,
        ConnectionProfile.Ethernet => SwiftConnectionProfile.Ethernet,
        ConnectionProfile.WiFi => SwiftConnectionProfile.WiFi,
        _ => SwiftConnectionProfile.Unknown,
    };

    /// <summary>Which way the screen is turned, as this side's member.</summary>
    internal static SwiftDisplayOrientation Member(DisplayOrientation orientation) => orientation switch
    {
        DisplayOrientation.Unknown => SwiftDisplayOrientation.Unknown,
        DisplayOrientation.Portrait => SwiftDisplayOrientation.Portrait,
        DisplayOrientation.Landscape => SwiftDisplayOrientation.Landscape,
        _ => SwiftDisplayOrientation.Unknown,
    };

    /// <summary>How far the screen is rotated, as this side's member.</summary>
    internal static SwiftDisplayRotation Member(DisplayRotation rotation) => rotation switch
    {
        DisplayRotation.Unknown => SwiftDisplayRotation.Unknown,
        DisplayRotation.Rotation0 => SwiftDisplayRotation.Rotation0,
        DisplayRotation.Rotation90 => SwiftDisplayRotation.Rotation90,
        DisplayRotation.Rotation180 => SwiftDisplayRotation.Rotation180,
        DisplayRotation.Rotation270 => SwiftDisplayRotation.Rotation270,
        _ => SwiftDisplayRotation.Unknown,
    };

    /// <summary>Which look the system asked for, as this side's member.</summary>
    internal static SwiftAppTheme Member(Microsoft.Maui.ApplicationModel.AppTheme theme) => theme switch
    {
        Microsoft.Maui.ApplicationModel.AppTheme.Unspecified => SwiftAppTheme.Unspecified,
        Microsoft.Maui.ApplicationModel.AppTheme.Light => SwiftAppTheme.Light,
        Microsoft.Maui.ApplicationModel.AppTheme.Dark => SwiftAppTheme.Dark,
        _ => SwiftAppTheme.Unspecified,
    };

    /// <summary>Real hardware or an emulator, as this side's member.</summary>
    internal static SwiftDeviceType Member(DeviceType type) => type switch
    {
        DeviceType.Unknown => SwiftDeviceType.Unknown,
        DeviceType.Physical => SwiftDeviceType.Physical,
        DeviceType.Virtual => SwiftDeviceType.Virtual,
        _ => SwiftDeviceType.Unknown,
    };

    /// <summary>
    /// Which day a week starts on, as this side's member - the one translation
    /// here whose far side is .NET's <see cref="DayOfWeek"/> rather than a MAUI
    /// enum, and numbered by us for the same reason as the rest.
    /// </summary>
    internal static SwiftWeekday Member(DayOfWeek day) => day switch
    {
        DayOfWeek.Sunday => SwiftWeekday.Sunday,
        DayOfWeek.Monday => SwiftWeekday.Monday,
        DayOfWeek.Tuesday => SwiftWeekday.Tuesday,
        DayOfWeek.Wednesday => SwiftWeekday.Wednesday,
        DayOfWeek.Thursday => SwiftWeekday.Thursday,
        DayOfWeek.Friday => SwiftWeekday.Friday,
        DayOfWeek.Saturday => SwiftWeekday.Saturday,
        _ => SwiftWeekday.Sunday,
    };
}
