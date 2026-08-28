using System.Reflection;
using Microsoft.Maui.Platforms.Linux.Gtk4.Essentials.AppModel;
using Microsoft.Maui.Platforms.Linux.Gtk4.Essentials.Devices;
using Microsoft.Maui.Platforms.Linux.Gtk4.Essentials.Networking;

namespace Gallery;

/// <summary>
/// Puts the Linux answers behind the five Essentials facades that read them
/// statically.
/// </summary>
/// <remarks>
/// <para>
/// <c>AddLinuxGtk4Essentials()</c> registers every service in DEPENDENCY
/// INJECTION and then hands five of them - Preferences, FilePicker,
/// SecureStorage, Clipboard, MediaPicker - to the static facade as well. The
/// rest are reachable only through the container.
/// </para>
/// <para>
/// That is a problem for anything reading <c>Battery.Default</c> or
/// <c>DeviceInfo.Current</c>, because those never consult DI: each is a static
/// field that falls back to the REFERENCE ASSEMBLY's implementation, whose every
/// member throws <c>NotImplementedInReferenceAssemblyException</c>. The library's
/// standard environment providers read all five that way, as MAUI's own
/// documentation has an application do, so without this an app dies at its first
/// battery reading, before anything is drawn.
/// </para>
/// <para>
/// The setters are internal, so this reaches them by name, exactly as the
/// backend's own <c>SetEssentialsDefaults</c> does for its five. A name that
/// ever stops resolving leaves that facade as it was rather than throwing, which
/// is what makes this safe to keep once the gap is closed upstream.
/// </para>
/// </remarks>
internal static class LinuxEssentials
{
    /// <summary>Installs them, before anything reads one.</summary>
    /// <remarks>
    /// Constructed here rather than resolved from the container: this runs while
    /// the application is still being described, which is where an app subscribes
    /// to battery and connectivity, and there is no built service provider yet.
    /// They are the same types the container would have made, and each facade
    /// holds the one instance from now on.
    /// </remarks>
    internal static void Install()
    {
        Adopt(typeof(Microsoft.Maui.Devices.Battery), "SetDefault",
            typeof(Microsoft.Maui.Devices.IBattery), new LinuxBattery());
        Adopt(typeof(Microsoft.Maui.Networking.Connectivity), "SetCurrent",
            typeof(Microsoft.Maui.Networking.IConnectivity), new LinuxConnectivity());
        Adopt(typeof(Microsoft.Maui.Devices.DeviceDisplay), "SetCurrent",
            typeof(Microsoft.Maui.Devices.IDeviceDisplay), new LinuxDeviceDisplay());
        Adopt(typeof(Microsoft.Maui.Devices.DeviceInfo), "SetCurrent",
            typeof(Microsoft.Maui.Devices.IDeviceInfo), new LinuxDeviceInfo());
        Adopt(typeof(Microsoft.Maui.ApplicationModel.AppInfo), "SetCurrent",
            typeof(Microsoft.Maui.ApplicationModel.IAppInfo), new LinuxAppInfo());
    }

    /// <summary>Hands one implementation to one facade.</summary>
    /// <param name="facade">The static Essentials class - Battery, DeviceInfo.</param>
    /// <param name="setter">What its internal setter is called there.</param>
    /// <param name="contract">The interface the setter takes.</param>
    /// <param name="implementation">This platform's answer.</param>
    private static void Adopt(Type facade, string setter, Type contract, object implementation) =>
        facade.GetMethod(setter, BindingFlags.Static | BindingFlags.NonPublic, [contract])
            ?.Invoke(null, [implementation]);
}
