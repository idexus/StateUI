// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

using System.Runtime.Versioning;
using Microsoft.Maui.ApplicationModel;

namespace StateUI.Runtime.Linux;

/// <summary>
/// Answers which look the reader asked the desktop for, and says when it
/// changes.
/// </summary>
/// <remarks>
/// <para>
/// The backend answers that question from one GTK setting,
/// <c>gtk-application-prefer-dark-theme</c>, which a desktop offering a dark
/// mode never sets: the reader's preference lives in the desktop's own
/// settings under <c>color-scheme</c>, and the theme it then picks is named in
/// <c>gtk-theme-name</c>. So an application is told LIGHT on a screen that is
/// dark, every <c>Color(light:dark:)</c> in it lands on the wrong half, and
/// nothing ever puts it right - the setting the backend reads cannot change on
/// its own.
/// </para>
/// <para>
/// This reads the preference where it actually is and hands the answer to the
/// same static facade the rest of Essentials goes through, WRAPPING whatever
/// was installed there so every other answer about the application stays the
/// platform's own. Two readings, in order: the desktop's settings, and - where
/// those do not exist or leave the choice to the theme - the theme's NAME,
/// a trailing <c>-dark</c> being how a desktop with no such key says it.
/// </para>
/// <para>
/// A change is reported through <c>IApplication.ThemeChanged</c>, which
/// re-reads the facade and raises MAUI's own <c>RequestedThemeChanged</c>.
/// Both readings are watched, because a desktop can change the preference
/// alone and keep one theme that draws either way. A doubled report costs
/// nothing: MAUI drops one that names the theme already showing.
/// </para>
/// <para>
/// The watch is armed from an IDLE, and both settings objects are held for the
/// life of the process - a subscription goes with the object that carries it,
/// and there is no display to read GTK's settings off until the loop runs.
/// </para>
/// </remarks>
[SupportedOSPlatform("linux")]
internal static class LinuxTheme
{
    /// <summary>The desktop settings holding the reader's preference.</summary>
    private const string Desk = "org.gnome.desktop.interface";

    /// <summary>Which look the reader asked the desktop for.</summary>
    private const string Scheme = "color-scheme";

    /// <summary>What that key says when the answer is dark.</summary>
    private const string PrefersDark = "prefer-dark";

    /// <summary>What that key says when the answer is light.</summary>
    private const string PrefersLight = "prefer-light";

    /// <summary>How a theme drawn dark ends its name.</summary>
    private const string Darkly = "-dark";

    /// <summary>Which GTK setting names the theme in force.</summary>
    private const string Named = "gtk-theme-name";

    /// <summary>The desktop's settings, or null where it keeps none.</summary>
    private static Gio.Settings? _desk;

    /// <summary>GTK's own settings, once there is a display to read them.</summary>
    private static Gtk.Settings? _gtk;

    /// <summary>Arms the answer, and the report that follows a change.</summary>
    internal static void Install()
    {
        _desk = Desktop();

        // Wraps what the platform installed rather than replacing it: the
        // theme is the one answer here that is wrong.
        LinuxEssentials.Adopt(
            typeof(AppInfo), "SetCurrent", typeof(IAppInfo), new Appearance(AppInfo.Current));

        if (_desk is Gio.Settings desk)
        {
            desk.OnChanged += (_, args) =>
            {
                if (args.Key == Scheme)
                {
                    Report();
                }
            };
        }

        GLib.Functions.IdleAdd(0, () =>
        {
            _gtk = Gtk.Settings.GetDefault();

            if (_gtk is Gtk.Settings settings)
            {
                settings.OnNotify += (_, args) =>
                {
                    if (args.Pspec.GetName() == Named)
                    {
                        Report();
                    }
                };
            }

            return false;
        });
    }

    /// <summary>Which look is in force, by both readings in order.</summary>
    /// <returns>Dark or light - never unspecified, a desktop always drawing one.</returns>
    internal static AppTheme Wanted()
    {
        if (_desk?.GetString(Scheme) is string asked)
        {
            switch (asked)
            {
                case PrefersDark: return AppTheme.Dark;
                case PrefersLight: return AppTheme.Light;
            }
        }

        return Gtk.Settings.GetDefault()?.GtkThemeName?
            .EndsWith(Darkly, StringComparison.OrdinalIgnoreCase) == true
            ? AppTheme.Dark
            : AppTheme.Light;
    }

    /// <summary>The desktop's settings, where this desktop keeps that key.</summary>
    /// <returns>Them, or null - which is what sends the reading to the theme's name.</returns>
    /// <remarks>
    /// The schema is looked up BEFORE the settings are made: making settings
    /// over a schema that is not installed aborts the process, which is how
    /// GLib reports a programming error, so a desktop that keeps none must be
    /// recognized by the lookup answering nothing.
    /// </remarks>
    private static Gio.Settings? Desktop() =>
        Gio.SettingsSchemaSource.GetDefault()?.Lookup(Desk, true) is Gio.SettingsSchema schema
            && schema.HasKey(Scheme)
                ? Gio.Settings.New(Desk)
                : null;

    /// <summary>Tells the application the answer has changed.</summary>
    private static void Report() =>
        (Microsoft.Maui.Controls.Application.Current as IApplication)?.ThemeChanged();

    /// <summary>The platform's answers about the application, with the theme put right.</summary>
    /// <param name="asked">What the platform installed, which answers all the rest.</param>
    private sealed class Appearance(IAppInfo asked) : IAppInfo
    {
        /// <summary>Which look the desktop is drawing.</summary>
        public AppTheme RequestedTheme => Wanted();

        /// <summary>What the application is called to the system.</summary>
        public string PackageName => asked.PackageName;

        /// <summary>What the application is called to a reader.</summary>
        public string Name => asked.Name;

        /// <summary>The application's version, as text.</summary>
        public string VersionString => asked.VersionString;

        /// <summary>The application's version.</summary>
        public Version Version => asked.Version;

        /// <summary>Which build this is.</summary>
        public string BuildString => asked.BuildString;

        /// <summary>How the application is packaged.</summary>
        public AppPackagingModel PackagingModel => asked.PackagingModel;

        /// <summary>Which way the reader's language runs.</summary>
        public LayoutDirection RequestedLayoutDirection => asked.RequestedLayoutDirection;

        /// <summary>Opens the system's page of settings for this application.</summary>
        public void ShowSettingsUI() => asked.ShowSettingsUI();
    }
}
