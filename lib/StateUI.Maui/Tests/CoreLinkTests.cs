// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

using System.Runtime.CompilerServices;
using System.Text.RegularExpressions;

namespace StateUI.Maui.Tests;

public partial class CoreLinkTests
{
    /// <summary>
    /// Every call into the running core crosses the core link: each of the
    /// core's entry points is declared in <c>Interop/CoreLink.cs</c> and
    /// nowhere else, so nothing reaches Swift but through it.
    /// </summary>
    /// <remarks>
    /// An entry point of the core is named by the core - <c>stateui_</c> and
    /// the export's own name - and read off the SOURCES, so the arms this suite
    /// does not compile keep to it too. A native import of another library,
    /// the Objective-C runtime's, is no call into the core.
    /// </remarks>
    [Fact]
    public void EveryCallIntoTheCoreCrossesTheCoreLink()
    {
        string link = Path.Combine(Beside("Sources"), "Interop", "CoreLink.cs");

        Assert.True(File.Exists(link), "Interop/CoreLink.cs is where the core's entry points are declared");
        Assert.True(EntryPoint().Count(File.ReadAllText(link)) > 20, "the core link declares almost none of the core");

        List<string> strays = [];

        foreach (string folder in new[] { "Sources", "Linux" })
        {
            string root = Beside(folder);

            foreach (string file in Directory.EnumerateFiles(root, "*.cs", SearchOption.AllDirectories)
                .Where(file => !Path.GetRelativePath(root, file)
                    .Split(Path.DirectorySeparatorChar)
                    .Any(part => part is "bin" or "obj"))
                .Where(file => Path.GetFullPath(file) != Path.GetFullPath(link))
                .Order(StringComparer.Ordinal))
            {
                if (EntryPoint().IsMatch(File.ReadAllText(file)))
                {
                    strays.Add($"{folder}/{Path.GetRelativePath(root, file)}");
                }
            }
        }

        Assert.True(strays.Count == 0, "the core is called around the core link: " + string.Join(", ", strays));
    }

    /// <summary>A native import of one of the core's own entry points.</summary>
    [GeneratedRegex("EntryPoint\\s*=\\s*\"stateui_")]
    private static partial Regex EntryPoint();

    /// <summary>A folder of this host's project, found from where this file sits.</summary>
    private static string Beside(string folder, [CallerFilePath] string path = "") =>
        Path.GetFullPath(Path.Combine(Path.GetDirectoryName(path)!, "..", folder));
}
