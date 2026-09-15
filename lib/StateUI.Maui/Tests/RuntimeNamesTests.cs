// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

using System.Runtime.CompilerServices;
using System.Text.RegularExpressions;

namespace StateUI.Maui.Tests;

public partial class RuntimeNamesTests
{
    /// <summary>
    /// The runtime's types keep the architecture's reserved words: no type of
    /// the runtime is an ENGINE - that word is the application's frame code -
    /// and a CHANNEL is only the state channel, one per <c>@State</c>.
    /// </summary>
    /// <remarks>
    /// Read off the SOURCES rather than the assembly, so the arms this suite
    /// does not compile - Android, Apple, Windows and Linux - keep them too.
    /// </remarks>
    [Fact]
    public void TheRuntimesTypesKeepTheReservedWords()
    {
        List<string> found = [];

        foreach (string folder in new[] { "Sources", "Linux" })
        {
            string root = Beside(folder);

            IEnumerable<string> files = Directory
                .EnumerateFiles(root, "*.cs", SearchOption.AllDirectories)
                .Where(file => !Path.GetRelativePath(root, file)
                    .Split(Path.DirectorySeparatorChar)
                    .Any(part => part is "bin" or "obj"))
                .Order(StringComparer.Ordinal);

            foreach (string file in files)
            {
                foreach (Match match in Declaration().Matches(File.ReadAllText(file)))
                {
                    string type = match.Groups[1].Value;

                    if (type.EndsWith("Engine", StringComparison.Ordinal)
                        || (type.Contains("Channel", StringComparison.Ordinal)
                            && !type.StartsWith("StateChannel", StringComparison.Ordinal)))
                    {
                        found.Add($"{folder}/{Path.GetRelativePath(root, file)}: {type}");
                    }
                }
            }
        }

        Assert.True(
            found.Count == 0,
            "an engine is application code, and a channel is a state's: " + string.Join(", ", found));
    }

    /// <summary>A type's declaration, its name captured.</summary>
    [GeneratedRegex(@"\b(?:class|struct|interface|enum|record(?:\s+(?:class|struct))?)\s+(\w+)")]
    private static partial Regex Declaration();

    /// <summary>A folder of this host's project, found from where this file sits.</summary>
    private static string Beside(string folder, [CallerFilePath] string path = "") =>
        Path.GetFullPath(Path.Combine(Path.GetDirectoryName(path)!, "..", folder));
}
