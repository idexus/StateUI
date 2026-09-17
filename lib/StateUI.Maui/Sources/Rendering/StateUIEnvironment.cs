// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

using System.Globalization;
using Microsoft.Maui.Devices;
using Microsoft.Maui.Networking;
using StateUI.Maui.Interop;
using StateUI.Maui.Protocol;

namespace StateUI.Maui.Rendering;

/// <summary>
/// The STANDARD ENVIRONMENT's host half: what this side knows - the battery,
/// the network, the display, the locale, the device, the app, and the
/// application's phase - pushed into the Swift providers and the
/// <c>ApplicationSession</c> any view resolves with <c>@Environment</c>. See
/// <c>Types/HostEnvironment.swift</c> for the other half and the payload each
/// domain carries.
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
/// <c>HostValue.OfMember</c> over the mirrors in
/// <c>Protocol/HostEnums.cs</c>, translated by a switch naming the MAUI
/// member literally, never a cast of MAUI's own value: a cast would leave a
/// MAUI release free to renumber an enum and have the Swift side read every
/// report as a different member, with nothing failing anywhere. The idiom has
/// no MAUI enum behind it, so its translation is a comparison chain; the
/// application's phase has none either and is named by the window event that
/// fired.
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
    internal const byte ApplicationDomain = 7;

    /// <summary>The session that carries a push into Swift - the process's one
    /// live session, the <see cref="StateUIEvents"/> rule.</summary>
    internal static StateUISession? Session { get; private set; }

    /// <summary>Whether the platform's change events are already wired - once
    /// per process, there being one Swift runtime and one session over it.</summary>
    private static bool _wired;

    /// <summary>
    /// Adopts the session and tells Swift everything, one domain at a time -
    /// called once per process from <c>StateUISession.Initialize</c>, after the
    /// wire version matched and BEFORE the app registers, so the application's
    /// <c>init</c> already reads every provider. That runs as the platform
    /// hands over its first window, or at the first render where nothing did,
    /// and either way before the first tree is built. No pump: a render
    /// follows at once.
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
            ApplicationDomain,
            () => [HostValue.OfMember((int)HostApplicationPhase.Active)],
            pump: false);
    }

    /// <summary>
    /// Reports where the application now stands - moved by whichever of its
    /// windows reported last. Called from
    /// <see cref="StateUIRenderer.WireWindow"/> as MAUI raises a window's
    /// events; Resumed reports <see cref="HostApplicationPhase.Inactive"/>,
    /// the window being visible again but not yet active - Activated follows on
    /// its own where the platform means it.
    /// </summary>
    /// <param name="phase">Which of the three the application is now in.</param>
    internal static void ApplicationPhase(HostApplicationPhase phase)
    {
        Session?.PushEnvironment(ApplicationDomain, () => [HostValue.OfMember((int)phase)]);
    }

    /// <summary>
    /// Re-reads the locale, because the reader may have been changing it while
    /// the app was away. Called as a window RESUMES.
    /// </summary>
    /// <remarks>
    /// <para>
    /// The one standard provider with no change event of its own: MAUI raises
    /// nothing for a zone, a language or a 12/24-hour switch, and .NET holds
    /// <see cref="TimeZoneInfo.Local"/> in a static from the first read - so
    /// without this an app that was in the background while the traveller
    /// crossed a border goes on formatting in the zone it started in.
    /// </para>
    /// <para>
    /// Coming back is the moment to look, and cheap: a resume happens once per
    /// foregrounding, and pushing a domain rebuilds only the views that read
    /// it. A LANGUAGE change is a restart on both mobile platforms - Android
    /// recreates the activity, iOS terminates the app - so what this really
    /// buys is the zone and the clock format.
    /// </para>
    /// </remarks>
    internal static void CameBack()
    {
        // .NET caches the local zone; nothing re-reads it but this.
        TimeZoneInfo.ClearCachedData();

        Session?.PushEnvironment(LocaleDomain, LocaleSnapshot);
    }

    /// <summary>
    /// Re-pushes the app domain because the theme moved - the whole of what a
    /// theme change does on this side, the differ picking every themed value's
    /// half again for the elements that wear one. Subscribed by the session as
    /// it claims the process, the one place that hears
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
            DeviceDisplay.Current.MainDisplayInfoChanged += (_, _) => DisplayMoved();
        }
        catch (Exception)
        {
        }

#if ANDROID
        try
        {
            // A turn from one landscape to the other changes no size, and
            // MAUI's MainDisplayInfoChanged - raised from the orientation
            // sensor - arrives BEFORE the window manager turns the display,
            // so it reads the rotation it is leaving and nothing follows it.
            // The display manager says so once the display HAS turned, and
            // for a new refresh rate too.
            var displays = (Android.Hardware.Display.DisplayManager?)Android.App.Application.Context
                .GetSystemService(Android.Content.Context.DisplayService);
            displays?.RegisterDisplayListener(
                new DisplayTurned(), new Android.OS.Handler(Android.OS.Looper.MainLooper!));
        }
        catch (Exception)
        {
        }
#endif
    }

#if ANDROID
    /// <summary>Hears the display change once it has changed.</summary>
    private sealed class DisplayTurned : Java.Lang.Object, Android.Hardware.Display.DisplayManager.IDisplayListener
    {
        public void OnDisplayAdded(int displayId)
        {
        }

        public void OnDisplayRemoved(int displayId)
        {
        }

        public void OnDisplayChanged(int displayId) => DisplayMoved();
    }
#endif

    /// <summary>
    /// What the display last said - every value its snapshot carries - so
    /// saying it again costs nothing.
    /// </summary>
    private static (double Width, double Height, double Density, DisplayOrientation Orientation,
        DisplayRotation Rotation, float RefreshRate) _display;

    /// <summary>
    /// Says the display may have moved, and pushes it where it has.
    /// </summary>
    /// <remarks>
    /// <para>
    /// A ROTATION IS A WINDOW RESIZE ON EVERY PLATFORM, and the window's own
    /// size change is therefore the signal that is always there - which is
    /// what this is called from, beside the platform's own display event.
    /// Some Android builds never raise <c>MainDisplayInfoChanged</c> at all:
    /// measured on a phone turned to landscape, where the event did not fire
    /// once, so every view reading the display kept its portrait answer and a
    /// heading meant to go on its side stayed on top of the page.
    /// </para>
    /// <para>
    /// A push that would say what the display already says is SKIPPED, because
    /// a desktop window being dragged is a continuous stream of size changes
    /// and each push renders every view that reads one.
    /// </para>
    /// </remarks>
    internal static void DisplayMoved()
    {
        try
        {
            if (!Changed(DeviceDisplay.Current.MainDisplayInfo))
            {
                return;
            }
        }
        catch (Exception)
        {
            // The platform does not say; the provider keeps what it has.
            return;
        }

        Session?.PushEnvironment(DisplayDomain, DisplaySnapshot);
    }

    /// <summary>
    /// Whether <paramref name="info"/> says anything the display's last push
    /// did not, remembering it when it does.
    /// </summary>
    /// <param name="info">What the display says now.</param>
    /// <returns>Whether that is news to a view reading the display.</returns>
    internal static bool Changed(DisplayInfo info)
    {
        (double, double, double, DisplayOrientation, DisplayRotation, float) now =
            (info.Width, info.Height, info.Density, info.Orientation, info.Rotation, info.RefreshRate);

        if (now == _display)
        {
            return false;
        }

        _display = now;
        return true;
    }

    /// <summary>The battery's four values, in the Swift provider's order.</summary>
    private static HostValue[] BatterySnapshot()
    {
        IBattery battery = Battery.Default;

        return
        [
            HostValue.Of(battery.ChargeLevel),
            HostValue.OfMember((int)Member(battery.State)),
            HostValue.OfMember((int)Member(battery.PowerSource)),
            HostValue.OfMember((int)Member(battery.EnergySaverStatus)),
        ];
    }

    /// <summary>The network's reach, and every profile it is reached by.</summary>
    private static HostValue[] ConnectivitySnapshot()
    {
        IConnectivity connectivity = Connectivity.Current;

        return
        [
            HostValue.OfMember((int)Member(connectivity.NetworkAccess)),

            // A list of MEMBERS, so a list of values and not a run of doubles:
            // a run of doubles is a run of quantities, and a member is not one.
            HostValue.OfValues(
                [.. connectivity.ConnectionProfiles.Select(
                    profile => HostValue.OfMember((int)Member(profile)))]),
        ];
    }

    /// <summary>The main display, as MAUI measures it - pixels, density, and
    /// which way it is turned.</summary>
    private static HostValue[] DisplaySnapshot()
    {
        DisplayInfo info = DeviceDisplay.Current.MainDisplayInfo;

        return
        [
            HostValue.Of(info.Width),
            HostValue.Of(info.Height),
            HostValue.Of(info.Density),
            HostValue.OfMember((int)Member(info.Orientation)),
            HostValue.OfMember((int)Member(info.Rotation)),
            HostValue.Of(info.RefreshRate),
        ];
    }

    /// <summary>
    /// The reader's language, region, zone and calendar habits - .NET spreads
    /// them over CultureInfo, RegionInfo and TimeZoneInfo, and the zone goes
    /// out as its IANA name, the <c>TimeZoneInfo.local()</c> act's rule.
    /// </summary>
    private static HostValue[] LocaleSnapshot()
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
            HostValue.Of(culture.TwoLetterISOLanguageName),
            HostValue.Of(region),
            HostValue.Of(culture.Name),
            HostValue.Of(ianaZone),
            HostValue.Of(culture.DateTimeFormat.ShortTimePattern.Contains('H')),
            HostValue.OfMember((int)Member(culture.DateTimeFormat.FirstDayOfWeek)),
            HostValue.Of(metric),
        ];
    }

    /// <summary>
    /// The device's facts, the idiom first - as this library's number, MAUI
    /// keeping its <see cref="DeviceIdiom"/> as a struct compared by value
    /// with no number to borrow.
    /// </summary>
    private static HostValue[] DeviceSnapshot()
    {
        IDeviceInfo device = DeviceInfo.Current;
        // MAUI's DeviceIdiom is a struct compared by value, so this is a
        // chain of comparisons rather than a switch - the shape a translation
        // takes when the far side has no enum to switch over.
        DeviceIdiom idiom = device.Idiom;

        HostFormFactor member =
            idiom == DeviceIdiom.Phone ? HostFormFactor.Phone
            : idiom == DeviceIdiom.Tablet ? HostFormFactor.Tablet
            : idiom == DeviceIdiom.Desktop ? HostFormFactor.Desktop
            : idiom == DeviceIdiom.TV ? HostFormFactor.Tv
            : idiom == DeviceIdiom.Watch ? HostFormFactor.Watch
            : HostFormFactor.Unknown;

        return
        [
            HostValue.OfMember((int)member),
            HostValue.Of(device.Platform.ToString()),
            HostValue.Of(device.Model),
            HostValue.Of(device.Manufacturer),
            HostValue.Of(device.Name),
            HostValue.Of(device.VersionString),
            HostValue.OfMember((int)Member(device.DeviceType)),
        ];
    }

    /// <summary>The app's manifest facts, and the one value here that moves:
    /// the requested theme.</summary>
    private static HostValue[] AppSnapshot()
    {
        Microsoft.Maui.ApplicationModel.IAppInfo app =
            Microsoft.Maui.ApplicationModel.AppInfo.Current;

        return
        [
            HostValue.Of(app.Name),
            HostValue.Of(app.PackageName),
            HostValue.Of(app.VersionString),
            HostValue.Of(app.BuildString),
            HostValue.OfMember((int)Member(app.RequestedTheme)),
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
    internal static HostBatteryState Member(BatteryState state) => state switch
    {
        BatteryState.Unknown => HostBatteryState.Unknown,
        BatteryState.Charging => HostBatteryState.Charging,
        BatteryState.Discharging => HostBatteryState.Discharging,
        BatteryState.Full => HostBatteryState.Full,
        BatteryState.NotCharging => HostBatteryState.NotCharging,
        BatteryState.NotPresent => HostBatteryState.NotPresent,
        _ => HostBatteryState.Unknown,
    };

    /// <summary>Where the power is coming from, as this side's member.</summary>
    internal static HostBatteryPowerSource Member(BatteryPowerSource source) => source switch
    {
        BatteryPowerSource.Unknown => HostBatteryPowerSource.Unknown,
        BatteryPowerSource.Battery => HostBatteryPowerSource.Battery,
        BatteryPowerSource.AC => HostBatteryPowerSource.Ac,
        BatteryPowerSource.Usb => HostBatteryPowerSource.Usb,
        BatteryPowerSource.Wireless => HostBatteryPowerSource.Wireless,
        _ => HostBatteryPowerSource.Unknown,
    };

    /// <summary>Whether the battery saver is on, as this side's member.</summary>
    internal static HostEnergySaverStatus Member(EnergySaverStatus status) => status switch
    {
        EnergySaverStatus.Unknown => HostEnergySaverStatus.Unknown,
        EnergySaverStatus.On => HostEnergySaverStatus.On,
        EnergySaverStatus.Off => HostEnergySaverStatus.Off,
        _ => HostEnergySaverStatus.Unknown,
    };

    /// <summary>What the network can reach, as this side's member.</summary>
    internal static HostNetworkAccess Member(NetworkAccess access) => access switch
    {
        NetworkAccess.Unknown => HostNetworkAccess.Unknown,
        NetworkAccess.None => HostNetworkAccess.None,
        NetworkAccess.Local => HostNetworkAccess.Local,
        NetworkAccess.ConstrainedInternet => HostNetworkAccess.ConstrainedInternet,
        NetworkAccess.Internet => HostNetworkAccess.Internet,
        _ => HostNetworkAccess.Unknown,
    };

    /// <summary>One way the device is connected, as this side's member.</summary>
    internal static HostConnectionProfile Member(ConnectionProfile profile) => profile switch
    {
        ConnectionProfile.Unknown => HostConnectionProfile.Unknown,
        ConnectionProfile.Bluetooth => HostConnectionProfile.Bluetooth,
        ConnectionProfile.Cellular => HostConnectionProfile.Cellular,
        ConnectionProfile.Ethernet => HostConnectionProfile.Ethernet,
        ConnectionProfile.WiFi => HostConnectionProfile.WiFi,
        _ => HostConnectionProfile.Unknown,
    };

    /// <summary>Which way the screen is turned, as this side's member.</summary>
    internal static HostDisplayOrientation Member(DisplayOrientation orientation) => orientation switch
    {
        DisplayOrientation.Unknown => HostDisplayOrientation.Unknown,
        DisplayOrientation.Portrait => HostDisplayOrientation.Portrait,
        DisplayOrientation.Landscape => HostDisplayOrientation.Landscape,
        _ => HostDisplayOrientation.Unknown,
    };

    /// <summary>How far the screen is rotated, as this side's member.</summary>
    internal static HostDisplayRotation Member(DisplayRotation rotation) => rotation switch
    {
        DisplayRotation.Unknown => HostDisplayRotation.Unknown,
        DisplayRotation.Rotation0 => HostDisplayRotation.Rotation0,
        DisplayRotation.Rotation90 => HostDisplayRotation.Rotation90,
        DisplayRotation.Rotation180 => HostDisplayRotation.Rotation180,
        DisplayRotation.Rotation270 => HostDisplayRotation.Rotation270,
        _ => HostDisplayRotation.Unknown,
    };

    /// <summary>Which look the system asked for, as this side's member.</summary>
    internal static HostTheme Member(Microsoft.Maui.ApplicationModel.AppTheme theme) => theme switch
    {
        Microsoft.Maui.ApplicationModel.AppTheme.Unspecified => HostTheme.System,
        Microsoft.Maui.ApplicationModel.AppTheme.Light => HostTheme.Light,
        Microsoft.Maui.ApplicationModel.AppTheme.Dark => HostTheme.Dark,
        _ => HostTheme.System,
    };

    /// <summary>Real hardware or an emulator, as this side's member.</summary>
    internal static HostDeviceType Member(DeviceType type) => type switch
    {
        DeviceType.Unknown => HostDeviceType.Unknown,
        DeviceType.Physical => HostDeviceType.Physical,
        DeviceType.Virtual => HostDeviceType.Virtual,
        _ => HostDeviceType.Unknown,
    };

    /// <summary>
    /// Which day a week starts on, as this side's member - the one translation
    /// here whose far side is .NET's <see cref="DayOfWeek"/> rather than a MAUI
    /// enum, and numbered by us for the same reason as the rest.
    /// </summary>
    internal static HostWeekday Member(DayOfWeek day) => day switch
    {
        DayOfWeek.Sunday => HostWeekday.Sunday,
        DayOfWeek.Monday => HostWeekday.Monday,
        DayOfWeek.Tuesday => HostWeekday.Tuesday,
        DayOfWeek.Wednesday => HostWeekday.Wednesday,
        DayOfWeek.Thursday => HostWeekday.Thursday,
        DayOfWeek.Friday => HostWeekday.Friday,
        DayOfWeek.Saturday => HostWeekday.Saturday,
        _ => HostWeekday.Sunday,
    };
}
