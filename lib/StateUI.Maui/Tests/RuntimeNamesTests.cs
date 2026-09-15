// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

using System.Runtime.CompilerServices;
using System.Text.RegularExpressions;

namespace StateUI.Maui.Tests;

/// <summary>
/// The runtime's names, read off the SOURCES rather than the assembly, so the
/// arms this suite does not compile - Android, Apple, Windows and Linux - keep
/// them too.
/// </summary>
public partial class RuntimeNamesTests
{
    /// <summary>
    /// The runtime's types keep the architecture's reserved words: no type of
    /// the runtime is an ENGINE - that word is the application's frame code -
    /// and a CHANNEL is only the state channel, one per <c>@State</c>.
    /// </summary>
    [Fact]
    public void TheRuntimesTypesKeepTheReservedWords()
    {
        List<string> found = [.. Declarations("Sources", "Linux")
            .Where(declared => declared.Type.EndsWith("Engine", StringComparison.Ordinal)
                || (declared.Type.Contains("Channel", StringComparison.Ordinal)
                    && !declared.Type.StartsWith("StateChannel", StringComparison.Ordinal)))
            .Select(declared => declared.Where)];

        Assert.True(
            found.Count == 0,
            "an engine is application code, and a channel is a state's: " + string.Join(", ", found));
    }

    /// <summary>
    /// A type of the runtime is named for what it is - a wire mirror for the
    /// typed patch's <c>Host</c> type, every other type for the element it is -
    /// and never for the language on the other side of the wire.
    /// </summary>
    [Fact]
    public void NoTypeIsNamedForTheLanguageAcrossTheWire()
    {
        List<string> found = [.. Declarations("Sources", "Linux")
            .Where(declared => declared.Type.StartsWith("Swift", StringComparison.Ordinal))
            .Select(declared => declared.Where)];

        Assert.True(
            found.Count == 0,
            "a runtime type is named for what it is, not for Swift: " + string.Join(", ", found));
    }

    /// <summary>Every type declared under the given folders of this host's project.</summary>
    /// <param name="folders">Folders beside this one's, such as <c>Sources</c>.</param>
    /// <returns>Each type's name, and where it is declared.</returns>
    private static IEnumerable<(string Type, string Where)> Declarations(params string[] folders)
    {
        foreach (string folder in folders)
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
                    yield return (type, $"{folder}/{Path.GetRelativePath(root, file)}: {type}");
                }
            }
        }
    }

    /// <summary>A type's declaration, its name captured.</summary>
    [GeneratedRegex(@"\b(?:class|struct|interface|enum|record(?:\s+(?:class|struct))?)\s+(\w+)")]
    private static partial Regex Declaration();

    /// <summary>A folder of this host's project, found from where this file sits.</summary>
    private static string Beside(string folder, [CallerFilePath] string path = "") =>
        Path.GetFullPath(Path.Combine(Path.GetDirectoryName(path)!, "..", folder));
}
