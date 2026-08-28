// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

using System.Runtime.Versioning;
using Gtk;

namespace StateUI.Runtime.Linux;

/// <summary>
/// Gives the application's windows the icon the application ships.
/// </summary>
/// <remarks>
/// <para>
/// Nothing on this platform reads the app icon an application declares: there
/// is no Resizetizer to compose it and the backend never tells GTK about one,
/// so every window wears the desktop's own placeholder in the switcher, the
/// dock and the window list.
/// </para>
/// <para>
/// GTK finds an icon by NAME in an icon theme, so an application ships one
/// where a theme keeps them - <c>hicolor/scalable/apps/appicon.svg</c> beside
/// the executable - and this adds that directory to the theme's search path
/// and makes the name the default for every window. A vector needs no sizes,
/// which is the whole of why the theme is scalable and holds one file.
/// </para>
/// <para>
/// It runs from an IDLE because a display is what an icon theme belongs to,
/// and there is none until GTK has started - the builder this is installed
/// from runs before that. An application that ships no such file is left
/// alone.
/// </para>
/// </remarks>
[SupportedOSPlatform("linux")]
internal static class LinuxArtwork
{
    /// <summary>
    /// The name a window's icon is looked up under, which is the file's own.
    /// </summary>
    private const string Name = "appicon";

    /// <summary>Where a theme keeps a scalable application icon.</summary>
    private const string Under = "hicolor/scalable/apps";

    /// <summary>Arms the icon, once GTK has a display to hang it on.</summary>
    internal static void Install() =>
        GLib.Functions.IdleAdd(0, () =>
        {
            string beside = AppContext.BaseDirectory;

            if (!File.Exists(Path.Combine(beside, Under, $"{Name}.svg")))
            {
                return false;
            }

            if (Gdk.Display.GetDefault() is Gdk.Display display)
            {
                IconTheme.GetForDisplay(display).AddSearchPath(beside);
            }

            // Every window takes this unless it says otherwise, and the idle
            // this runs from is the loop's first - before the application is
            // activated and its window built.
            Gtk.Window.SetDefaultIconName(Name);

            return false;
        });
}
