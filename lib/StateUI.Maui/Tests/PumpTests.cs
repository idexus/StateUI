// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

using System.Runtime.CompilerServices;

namespace StateUI.Maui.Tests;

/// <summary>
/// A turn of the pump runs the jobs, a pending cycle, the render, then the
/// acts - the one pump every runtime has: the cycle before the render, so one
/// message carries what a handler wrote and what followed it, and the acts
/// after, so an act lands on the interface its handler changed.
/// </summary>
public class PumpTests
{
    /// <summary>
    /// Both turns - the pump's own and a target's render - cycle before they
    /// render and act after, and cycle once.
    /// </summary>
    /// <remarks>
    /// Read off the source: every step of a turn crosses into the core, which
    /// this suite has no library for.
    /// </remarks>
    [Theory]
    [InlineData("internal void Run()")]
    [InlineData("internal void Render()")]
    public void ATurnCyclesBeforeItRendersAndActsAfter(string turn)
    {
        string body = Body(File.ReadAllText(Path.Combine(Beside("Sources"), "Rendering", "Pump.cs")), turn);

        int cycle = body.IndexOf("Cycle();", StringComparison.Ordinal);
        int render = body.IndexOf("_render(true);", StringComparison.Ordinal);
        int acts = body.IndexOf("PerformActCalls();", StringComparison.Ordinal);

        Assert.True(render >= 0 && acts >= 0, $"{turn} renders and acts");
        Assert.True(cycle >= 0 && cycle < render, $"{turn} cycles before it renders");
        Assert.True(render < acts, $"{turn} acts after it renders");
        Assert.Equal(cycle, body.LastIndexOf("Cycle();", StringComparison.Ordinal));
    }

    /// <summary>
    /// A resumed handler comes back through the doorbell alone: the core rings
    /// it for every job and act that lands, so nothing here looks for a resume
    /// on a clock, and nothing asks the core how many are owed.
    /// </summary>
    [Fact]
    public void AResumedHandlerComesBackThroughTheDoorbellAlone()
    {
        string sources = Beside("Sources");
        string pump = File.ReadAllText(Path.Combine(sources, "Rendering", "Pump.cs"));
        string link = File.ReadAllText(Path.Combine(sources, "Interop", "CoreLink.cs"));

        Assert.False(
            pump.Contains("DispatchDelayed", StringComparison.Ordinal),
            "the pump looks for a resume on a clock");
        Assert.False(
            link.Contains("stateui_resumes_pending", StringComparison.Ordinal)
                || link.Contains("stateui_jobs_pending", StringComparison.Ordinal),
            "the core is asked how much it owes");
    }

    /// <summary>The body of the member the signature opens, braces included.</summary>
    /// <param name="source">The file.</param>
    /// <param name="signature">The member's signature, as written.</param>
    /// <returns>From the member's opening brace to its closing one.</returns>
    private static string Body(string source, string signature)
    {
        int at = source.IndexOf(signature, StringComparison.Ordinal);
        Assert.True(at >= 0, $"Pump.cs declares {signature}");

        int open = source.IndexOf('{', at);
        int depth = 0;

        for (int i = open; i < source.Length; i++)
        {
            depth += source[i] switch { '{' => 1, '}' => -1, _ => 0 };

            if (depth == 0)
            {
                return source[open..(i + 1)];
            }
        }

        throw new InvalidOperationException($"{signature} never closes");
    }

    /// <summary>A folder of this host's project, found from where this file sits.</summary>
    private static string Beside(string folder, [CallerFilePath] string path = "") =>
        Path.GetFullPath(Path.Combine(Path.GetDirectoryName(path)!, "..", folder));
}
