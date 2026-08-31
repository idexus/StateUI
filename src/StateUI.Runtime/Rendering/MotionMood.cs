// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

namespace StateUI.Runtime.Rendering;

using System.Diagnostics;

/// <summary>
/// Whether the reader has asked for less movement.
/// </summary>
/// <remarks>
/// <para>
/// Every platform has this setting and every platform means the same thing by
/// it: a person for whom movement on a screen is unpleasant or unsafe. A
/// library whose default is that everything travels owes them an answer, and
/// the answer is that nothing does - a value asked to move is simply written,
/// and a flight an author awaited answers TRUE, because the target WAS reached.
/// </para>
/// <para>
/// Read at most once a second rather than watched. Watching it is a different
/// notification on each of the four platforms and a file watch on the fifth,
/// for a setting a person changes perhaps twice in the life of a device; a
/// reading a second old is one motion at the old answer, once.
/// </para>
/// </remarks>
internal static class MotionMood
{
    /// <summary>How long a reading stands before it is taken again.</summary>
    private static readonly long Fresh = Stopwatch.Frequency;

    private static long _read;
    private static bool _reduced;

    /// <summary>
    /// What answers the question where this build has no platform of its own -
    /// set by a platform package, and left null everywhere else.
    /// </summary>
    /// <remarks>
    /// The plain build is the headless tests, which want the platform's answer
    /// to be "no" and never ask twice, and LINUX, whose backend brings its own
    /// package and reads the desktop's setting here.
    /// </remarks>
    internal static Func<bool>? Provided
    {
        get => _provided;

        set
        {
            _provided = value;

            // A platform installing an answer says whatever was read before it
            // was read from nobody.
            _read = 0;
        }
    }

    private static Func<bool>? _provided;

    /// <summary>Whether the reader has asked for less movement.</summary>
    internal static bool Reduced
    {
        get
        {
            long now = Stopwatch.GetTimestamp();

            if (_read != 0 && now - _read < Fresh)
            {
                return _reduced;
            }

            _read = now;
            _reduced = Asked();

            return _reduced;
        }
    }

    /// <summary>The platform's own answer, or false where there is none.</summary>
    private static bool Asked()
    {
        try
        {
#if IOS || MACCATALYST
            return UIKit.UIAccessibility.IsReduceMotionEnabled;
#elif ANDROID
            // The animator duration scale is what a reader turns down, and zero
            // is what "off" means - the same number every Android animation
            // multiplies its length by.
            return Android.Provider.Settings.Global.GetFloat(
                Android.App.Application.Context.ContentResolver,
                Android.Provider.Settings.Global.AnimatorDurationScale,
                1f) == 0f;
#elif WINDOWS
            return !new Windows.UI.ViewManagement.UISettings().AnimationsEnabled;
#else
            return Provided?.Invoke() ?? false;
#endif
        }
        catch (Exception)
        {
            // A platform that will not answer is a platform that has not said
            // no - and a setting nobody could read must never be the reason an
            // interface stops moving.
            return false;
        }
    }
}
