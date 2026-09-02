// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

namespace StateUI.Runtime.Rendering;

using System.Diagnostics;
using System.Globalization;
using System.Text;

/// <summary>
/// Every frame of every motion, written down.
/// </summary>
/// <remarks>
/// <para>
/// Off unless <c>STATEUI_FRAMES</c> is set in the environment, and when it is
/// off the only cost is a read of a readonly bool. On, it writes
/// <c>stateui-motion.log</c> in the temporary directory: one line per write,
/// carrying which value moved, how far into the motion it was, where it got to
/// and how fast it was going.
/// </para>
/// <para>
/// It is what every claim about a motion here is measured on. A curve that
/// judders, a retarget that cuts, a frame rate that is not the display's - none
/// of those can be seen from the outside, and all three are one column of this
/// file.
/// </para>
/// </remarks>
internal static class MotionTrace
{
    /// <summary>Whether anything is written down at all.</summary>
    internal static readonly bool Watching =
        !string.IsNullOrEmpty(Environment.GetEnvironmentVariable("STATEUI_FRAMES"));

    private static readonly object Pen = new();
    private static StreamWriter? _file;
    private static long _began;

    /// <summary>Where the lines go.</summary>
    internal static string Path { get; } =
        System.IO.Path.Combine(System.IO.Path.GetTempPath(), "stateui-motion.log");

    /// <summary>Writes down one frame of one channel.</summary>
    /// <param name="channel">The channel that was just written.</param>
    internal static void Wrote(MotionChannel channel)
    {
        var line = new StringBuilder();

        line.Append(Name(channel)).Append("  p");

        Numbers(line, channel.P);
        line.Append("  v");
        Numbers(line, channel.V);
        line.Append("  to");
        Numbers(line, channel.Target);

        Say(line.ToString());
    }

    /// <summary>Writes down anything else worth knowing, in the same file.</summary>
    /// <remarks>
    /// STAMPED HERE, so every line in the file carries the same clock and the
    /// file reads as one timeline: what a frame did and what the layout around
    /// it decided are only worth having together.
    /// </remarks>
    /// <param name="what">The line.</param>
    internal static void Say(string what)
    {
        if (!Watching)
        {
            return;
        }

        lock (Pen)
        {
            _file ??= new StreamWriter(Path, append: false) { AutoFlush = true };
            _file.WriteLine(
                Since().ToString("F1", CultureInfo.InvariantCulture) + "  " + what);
        }
    }

    /// <summary>Milliseconds since the first line was written.</summary>
    private static double Since()
    {
        long now = Stopwatch.GetTimestamp();

        if (_began == 0)
        {
            _began = now;
        }

        return (now - _began) * 1000.0 / Stopwatch.Frequency;
    }

    /// <summary>What to call the value that moved.</summary>
    private static string Name(MotionChannel channel)
    {
        string owner = channel.Moves.Owner.GetType().Name;
        object key = channel.Moves.Key;

        return key is Microsoft.Maui.Controls.BindableProperty property
            ? owner + "." + property.PropertyName
            : owner + ".place";
    }

    private static void Numbers(StringBuilder line, double[] lanes)
    {
        foreach (double lane in lanes)
        {
            line.Append(' ').Append(lane.ToString("F3", CultureInfo.InvariantCulture));
        }
    }
}
