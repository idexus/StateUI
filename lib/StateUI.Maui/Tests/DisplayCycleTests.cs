// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

using System.Runtime.CompilerServices;
using System.Text.RegularExpressions;

namespace StateUI.Maui.Tests;

public partial class DisplayCycleTests
{
    /// <summary>
    /// The core's cycle runs in one place: the display cycle, which puts the
    /// reader's reports in, runs it, and wears what it wrote - so no report,
    /// channel or renderer path runs one of its own, out of that order.
    /// </summary>
    /// <remarks>
    /// Read off the SOURCES, so the arms this suite does not compile keep it
    /// too. The crossing that declares the call is the one other place it may
    /// be spelled.
    /// </remarks>
    [Fact]
    public void TheCoresCycleRunsInTheDisplayCycleAlone()
    {
        string root = Beside("Sources");

        List<string> found = [.. Directory
            .EnumerateFiles(root, "*.cs", SearchOption.AllDirectories)
            .Where(file => !Path.GetRelativePath(root, file)
                .Split(Path.DirectorySeparatorChar)
                .Any(part => part is "bin" or "obj"))
            .Where(file => Path.GetFileName(file) is not ("DisplayCycle.cs" or "CycleCrossing.cs"))
            .Where(file => CoreCycle().IsMatch(File.ReadAllText(file)))
            .Select(file => Path.GetRelativePath(root, file))
            .Order(StringComparer.Ordinal)];

        Assert.True(
            found.Count == 0,
            "the core's cycle is run outside the display cycle: " + string.Join(", ", found));
    }

    /// <summary>A call that runs the core's cycle, through the crossing or around it.</summary>
    [GeneratedRegex(@"\.Cycle\(|NativeMethods\.CycleRun\(")]
    private static partial Regex CoreCycle();

    /// <summary>A folder of this host's project, found from where this file sits.</summary>
    private static string Beside(string folder, [CallerFilePath] string path = "") =>
        Path.GetFullPath(Path.Combine(Path.GetDirectoryName(path)!, "..", folder));
}
