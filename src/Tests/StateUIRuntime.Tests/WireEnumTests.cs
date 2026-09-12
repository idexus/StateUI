// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

// Do the two sides of the wire mean the same thing by the same number?
//
// A closed vocabulary crosses as a NUMBER. That is fast and
// exact right up until the two declarations disagree, at which point a Label
// quietly wraps the wrong way, a shape fills by the wrong rule, and nothing
// anywhere fails. There is no compiler between the two halves and no spelling
// left on the wire to disagree loudly - so the only thing standing between us
// and a silent misread is this test.
//
// The numbers are the LIBRARY'S OWN, never MAUI's. MAUI's enum values are
// MAUI's internal business: a release that renumbered one would be read by
// this wire as a different member, with no error and no warning. So the Swift
// side numbers each vocabulary itself, in declaration order from 0, and this
// side mirrors those numbers in Protocol/SwiftWireEnums.cs and translates to
// the MAUI value BY NAME.
//
// This file READS THE SWIFT SOURCES and compares them against the mirrors,
// member for member and number for number, in both directions. Nothing is
// hand-copied: a table of hand-written pairs is exactly the thing that goes
// stale, and it would go stale in the same commit that broke the wire.
//
// The other half of the pairing is WireVocabularyTests.swift, which asks
// whether the Swift declaration is SHAPED right - every case numbered out
// loud, nothing left riding a spelling. Neither test can be written on the
// other side: only Swift can walk its own sources for shape, and only this
// side can reflect the mirrors.

using System.Reflection;
using StateUI.Runtime.Protocol;

namespace StateUI.Runtime.Tests;

public class WireEnumTests
{
    /// <summary>
    /// Vocabularies whose mirror is not found by the naming rule, and why.
    /// Anything not here must be <c>Swift</c> + the Swift type's name with the
    /// dots taken out - see <see cref="MirrorOf"/>.
    /// </summary>
    private static readonly Dictionary<string, Type> MirroredElsewhere = new()
    {
        // The drawing's command list belongs to the reader that replays it,
        // and is nested there for the same reason it is nested in Swift.
        ["DrawCommand.Kind"] = typeof(StateUI.Runtime.Rendering.SwiftDrawable).GetNestedType(
            "Kind", BindingFlags.NonPublic | BindingFlags.Public)!,
    };

    /// <summary>
    /// Vocabularies that never cross, and why - so a name added here is a
    /// decision somebody wrote down rather than a mirror somebody forgot.
    /// </summary>
    private static readonly Dictionary<string, string> StaysOnThisSide = new()
    {
        // WHICH of a view's values a motion is about, which the differ resolves
        // into the numbers beside each property. The host is never told that a
        // motion has kinds at all.
        ["MotionValues"] = "resolved by the differ into each property's own motion",
    };

    [Fact]
    public void EveryVocabularyOnTheWireMeansTheSameNumberOnBothSides()
    {
        List<string> wrong = [];
        int checkedMembers = 0;

        foreach ((string vocabulary, IReadOnlyList<(string Member, int Value)> declared) in SwiftEnums.All())
        {
            if (StaysOnThisSide.ContainsKey(vocabulary))
            {
                continue;
            }

            Type? mirror = MirrorOf(vocabulary);

            if (mirror is null)
            {
                wrong.Add(
                    $"{vocabulary} crosses the wire and this side has no mirror for it - "
                    + $"declare Swift{Flattened(vocabulary)} in Protocol/SwiftWireEnums.cs");
                continue;
            }

            Dictionary<string, int> here = Enum.GetNames(mirror)
                .ToDictionary(name => name, name => Convert.ToInt32(Enum.Parse(mirror, name)));

            foreach ((string member, int value) in declared)
            {
                string spelled = char.ToUpperInvariant(member[0]) + member[1..];
                checkedMembers++;

                if (!here.TryGetValue(spelled, out int mine))
                {
                    wrong.Add($"{vocabulary}.{member} has no {mirror.Name}.{spelled} on this side");
                }
                else if (mine != value)
                {
                    wrong.Add(
                        $"{vocabulary}.{member} is {value} on the Swift side "
                        + $"and {mirror.Name}.{spelled} is {mine} here");
                }
            }

            // And the other way: a member this side has and Swift does not is
            // just as wrong, because it is a number nothing will ever send and
            // a case the converter answers for anyway.
            HashSet<string> theirs =
                [.. declared.Select(member => char.ToUpperInvariant(member.Member[0]) + member.Member[1..])];

            foreach (string mine in here.Keys.Where(name => !theirs.Contains(name)))
            {
                wrong.Add($"{mirror.Name}.{mine} has nothing behind it in Swift's {vocabulary}");
            }
        }

        Assert.True(
            checkedMembers > 120,
            $"only {checkedMembers} members were read from the Swift sources, so this is "
            + "reading the wrong files rather than finding nothing wrong");

        Assert.Equal([], wrong);
    }

    /// <summary>
    /// The scan finds what it is supposed to find. The test above passes
    /// trivially on an empty scan, so a rename or a move that silently emptied
    /// it would otherwise read as a clean suite.
    /// </summary>
    [Fact]
    public void TheSwiftSourcesAreActuallyBeingRead()
    {
        Dictionary<string, IReadOnlyList<(string Member, int Value)>> all = SwiftEnums.All();

        Assert.True(all.Count > 30, $"only {all.Count} vocabularies were found");
        Assert.Contains("LineBreakMode", all.Keys);
        Assert.Equal(4, all["LineBreakMode"].Single(member => member.Member == "tailTruncation").Value);
        Assert.Contains("StrokeShape.Kind", all.Keys);
    }

    /// <summary>The mirror for a Swift vocabulary, or null when there is none.</summary>
    private static Type? MirrorOf(string vocabulary)
    {
        if (MirroredElsewhere.TryGetValue(vocabulary, out Type? elsewhere))
        {
            return elsewhere;
        }

        return typeof(SwiftAct).Assembly.GetType(
            $"StateUI.Runtime.Protocol.Swift{Flattened(vocabulary)}");
    }

    /// <summary>
    /// `StrokeShape.Kind` names `SwiftStrokeShapeKind` - a nested Swift type
    /// keeps its enclosing type's name, since `Kind` alone would be five
    /// different things.
    /// </summary>
    private static string Flattened(string vocabulary) => vocabulary.Replace(".", "");
}

/// <summary>
/// The Swift declarations, read as text.
/// </summary>
/// <remarks>
/// A line scanner rather than a parser, and deliberately literal: a shape it
/// cannot read is reported, never skipped. Two shapes exist in the library -
/// a plain <c>enum X: Int32</c> with <c>case name = 4</c> lines, and an
/// <c>OptionSet</c> struct whose members are
/// <c>static let name = X(rawValue: 1 &lt;&lt; 3)</c>, <c>X([])</c>, or a
/// composite <c>static let name: X = [.a, .b]</c> resolved against the members
/// already read.
/// </remarks>
internal static class SwiftEnums
{
    private static readonly Lazy<Dictionary<string, IReadOnlyList<(string Member, int Value)>>> Read = new(Scan);

    /// <summary>Every vocabulary, by name, with its members in declaration order.</summary>
    internal static Dictionary<string, IReadOnlyList<(string Member, int Value)>> All() => Read.Value;

    /// <summary>`src/StateUI/Sources`, found by walking up from the test assembly.</summary>
    internal static string Sources
    {
        get
        {
            var directory = new DirectoryInfo(AppContext.BaseDirectory);

            while (directory is not null)
            {
                string candidate = Path.Combine(directory.FullName, "src", "StateUI", "Sources");

                if (Directory.Exists(candidate))
                {
                    return candidate;
                }

                directory = directory.Parent;
            }

            throw new DirectoryNotFoundException(
                "src/StateUI/Sources was not found above " + AppContext.BaseDirectory);
        }
    }

    private static Dictionary<string, IReadOnlyList<(string Member, int Value)>> Scan()
    {
        Dictionary<string, IReadOnlyList<(string Member, int Value)>> found = [];

        foreach (string file in Directory.EnumerateFiles(Sources, "*.swift", SearchOption.AllDirectories))
        {
            foreach ((string name, List<(string, int)> members) in Vocabularies(File.ReadAllText(file)))
            {
                Assert.False(
                    found.ContainsKey(name),
                    $"two Swift vocabularies are called {name}, so one of them would be "
                    + "checked against the other's mirror");

                found[name] = members;
            }
        }

        return found;
    }

    private static List<(string Name, List<(string, int)> Members)> Vocabularies(string text)
    {
        List<(string, List<(string, int)>)> found = [];
        string[] lines = text.Replace("\r\n", "\n").Split('\n');

        // The enclosing type, so a nested `Kind` is reported as
        // `StrokeShape.Kind` - there are six of them and they are six
        // different vocabularies. Found by INDENTATION: this library writes
        // one top-level type per declaration with no leading whitespace, and
        // everything nested inside one is indented. A brace counter would be
        // exact and would also have to know about strings, comments and
        // closures; the indentation is what a reader uses too.
        string? enclosing = null;

        string? vocabulary = null;
        List<(string, int)> members = [];
        Dictionary<string, int> byName = [];
        int depth = 0;
        bool isOptionSet = false;

        foreach (string raw in lines)
        {
            string line = raw.Trim();

            if (line.StartsWith("//", StringComparison.Ordinal))
            {
                continue;
            }

            if (vocabulary is null)
            {
                bool nested = raw.StartsWith(' ');

                // `: Int` as well as `: Int32`. Keying on the wider raw type
                // alone would let a vocabulary declared the other way sit
                // outside every check - which is exactly how two of them did.
                string? opened = Opens(line, "enum ", ": Int32") is string plain ? plain
                    : Opens(line, "enum ", ": Int,") is string wide ? wide
                    : Opens(line, "struct ", ": OptionSet") is string bits ? bits
                    : null;

                if (opened is not null)
                {
                    vocabulary = nested && enclosing is not null ? $"{enclosing}.{opened}" : opened;
                    isOptionSet = line.Contains(": OptionSet", StringComparison.Ordinal);
                    members = [];
                    byName = [];
                    depth = 1;

                    if (!nested)
                    {
                        enclosing = opened;
                    }

                    continue;
                }

                // Any other top-level type, so a vocabulary nested in one can
                // name the thing it belongs to.
                if (!nested)
                {
                    enclosing = Opens(line, "struct ", "")
                        ?? Opens(line, "enum ", "")
                        ?? Opens(line, "class ", "")
                        ?? enclosing;
                }

                continue;
            }

            depth += line.Count(character => character == '{') - line.Count(character => character == '}');

            if (depth <= 0)
            {
                found.Add((vocabulary, members));
                vocabulary = null;
                continue;
            }

            if (line.StartsWith("///", StringComparison.Ordinal))
            {
                continue;
            }

            (string Member, int Value)? member = isOptionSet ? Bit(line, byName) : Case(line);

            if (member is (string name, int value))
            {
                members.Add((name, value));
                byName[name] = value;
            }
        }

        return found;
    }

    /// <summary>The type a declaration line opens, or null for any other line.</summary>
    private static string? Opens(string line, string keyword, string conformance)
    {
        if (!line.EndsWith('{')
            || (conformance.Length > 0 && !line.Contains(conformance, StringComparison.Ordinal)))
        {
            return null;
        }

        int at = line.IndexOf(keyword, StringComparison.Ordinal);

        if (at < 0)
        {
            return null;
        }

        string rest = line[(at + keyword.Length)..];
        string name = new([.. rest.TakeWhile(character => char.IsLetterOrDigit(character) || character == '_')]);

        return name.Length == 0 ? null : name;
    }

    /// <summary>`case tailTruncation = 4`, or null.</summary>
    private static (string, int)? Case(string line)
    {
        if (!line.StartsWith("case ", StringComparison.Ordinal) || !line.Contains(" = ", StringComparison.Ordinal))
        {
            return null;
        }

        string[] halves = line[5..].Split(" = ", 2);
        string name = halves[0].Trim().Trim('`');

        return int.TryParse(halves[1].Trim().TrimEnd(','), out int value) ? (name, value) : null;
    }

    /// <summary>
    /// `static let bold = FontAttributes(rawValue: 1 &lt;&lt; 0)`, `= X([])`, or a
    /// composite `static let all: X = [.a, .b]` - resolved against the members
    /// already read, which is why declaration order is kept.
    /// </summary>
    private static (string, int)? Bit(string line, Dictionary<string, int> byName)
    {
        int at = line.IndexOf("static let ", StringComparison.Ordinal);

        if (at < 0)
        {
            return null;
        }

        string rest = line[(at + 11)..];
        string name = new([.. rest.TakeWhile(character => char.IsLetterOrDigit(character) || character == '_')]);
        string tail = rest[name.Length..];

        if (tail.Contains("([])", StringComparison.Ordinal))
        {
            return (name, 0);
        }

        if (tail.Contains("rawValue:", StringComparison.Ordinal))
        {
            string expression = tail[(tail.IndexOf("rawValue:", StringComparison.Ordinal) + 9)..]
                .TrimEnd(')', ' ')
                .Trim();

            if (expression.Contains("<<", StringComparison.Ordinal))
            {
                string[] shifted = expression.Split("<<", 2);

                return int.TryParse(shifted[0].Trim(), out int one) && int.TryParse(shifted[1].Trim(), out int by)
                    ? (name, one << by)
                    : null;
            }

            return int.TryParse(expression, out int literal) ? (name, literal) : null;
        }

        if (tail.Contains('[', StringComparison.Ordinal))
        {
            string list = tail[(tail.IndexOf('[') + 1)..].TrimEnd(']', ' ');
            int value = 0;

            foreach (string part in list.Split(','))
            {
                if (!byName.TryGetValue(part.Trim().TrimStart('.'), out int bit))
                {
                    return null;
                }

                value |= bit;
            }

            return (name, value);
        }

        return null;
    }
}
