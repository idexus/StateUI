// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

// The MAUI column of the control dictionary - docs/controls - is what this host
// declares it realizes, MauiRealization: a realization without its mark, or a
// mark without its realization, fails here.
//
// A record names an entry of the dictionary or a tier its members come from;
// an entry's own record wins over its tier's, and an entry this host does not
// realize at all carries no mark. `python3 .scripts/controls-dictionary.py`
// writes the column and this host's part of each note from the records.
using System.Runtime.CompilerServices;
using StateUI.Maui.Rendering;

namespace StateUI.Maui.Tests;

public class MauiRealizationTests
{
    /// <summary>One member row of an entry's file, as this host reads it.</summary>
    private sealed record Row(string Entry, string? Tier, string Member, string Mark, string Note);

    /// <summary>docs/controls, found from where this file sits in the repository.</summary>
    private static readonly string Folder = Beside();

    private static string Beside([CallerFilePath] string path = "") =>
        Path.GetFullPath(Path.Combine(Path.GetDirectoryName(path)!, "..", "..", "..", "docs", "controls"));

    /// <summary>The files of one folder of the dictionary, by name, the index left out.</summary>
    private static List<string> Files(string folder) =>
        [.. Directory.GetFiles(folder, "*.md")
            .Select(file => Path.GetFileNameWithoutExtension(file))
            .Where(name => name != "README")
            .Order(StringComparer.Ordinal)];

    private static List<string> Entries() => Files(Folder);

    private static List<string> Tiers() => Files(Path.Combine(Folder, "tiers"));

    /// <summary>A member cell's token: `icon` is `icon`, `onClicked` (`clicked`) is `clicked`.</summary>
    private static string Token(string cell) =>
        cell.Split('`')
            .Where(part => !part.Contains('(') && !part.Contains(')') && part.Trim().Length > 0)
            .LastOrDefault() ?? cell;

    private static string[] Cells(string line) => [.. line.Split('|').Select(cell => cell.Trim())];

    /// <summary>
    /// This host's part of a row's note. The one Notes cell is shared by every
    /// host: AppKit's note stands first as written, and another host's follows
    /// as "; MAUI: ..." - or opens the cell as "MAUI: ..." where AppKit has
    /// none - each running to the next host's name.
    /// </summary>
    /// <param name="note">The whole Notes cell.</param>
    /// <param name="hosts">The hosts the table has a column for.</param>
    private static string MauisPart(string note, IEnumerable<string> hosts)
    {
        const string Label = "MAUI: ";
        int start;

        if (note.StartsWith(Label, StringComparison.Ordinal))
        {
            start = Label.Length;
        }
        else if (note.IndexOf("; " + Label, StringComparison.Ordinal) is int at and >= 0)
        {
            start = at + 2 + Label.Length;
        }
        else
        {
            return "";
        }

        int end = note.Length;

        foreach (string host in hosts.Where(host => host is not "MAUI" and not "AppKit"))
        {
            int next = note.IndexOf("; " + host + ": ", start, StringComparison.Ordinal);

            if (next >= 0 && next < end)
            {
                end = next;
            }
        }

        return note[start..end];
    }

    /// <summary>
    /// Every row of every entry, with the tier its section comes from. The
    /// MAUI mark and the note are found by the table's header, whichever hosts'
    /// columns stand beside them.
    /// </summary>
    private static List<Row> Rows()
    {
        List<Row> rows = [];

        foreach (string entry in Entries())
        {
            string? tier = null;
            int mark = -1;
            int note = -1;
            string[] hosts = [];

            foreach (string line in File.ReadAllLines(Path.Combine(Folder, entry + ".md")))
            {
                if (line.StartsWith("## From [", StringComparison.Ordinal))
                {
                    tier = line["## From [".Length..].Split(']')[0];
                }
                else if (line.StartsWith("## ", StringComparison.Ordinal))
                {
                    tier = null;
                }
                else if (line.StartsWith("| Member |", StringComparison.Ordinal))
                {
                    string[] header = Cells(line);

                    mark = Array.IndexOf(header, "MAUI");
                    note = Array.IndexOf(header, "Notes");
                    hosts = [.. header.Skip(Array.IndexOf(header, "Kind") + 1).Take(note - Array.IndexOf(header, "Kind") - 1)];
                }
                else if (line.StartsWith("| `", StringComparison.Ordinal) && mark >= 0 && note >= 0)
                {
                    string[] row = Cells(line);

                    rows.Add(new Row(entry, tier, Token(row[1]), row[mark], MauisPart(row[note], hosts)));
                }
            }
        }

        return rows;
    }

    private static HashSet<string> TierMembers(string tier) =>
        [.. File.ReadAllLines(Path.Combine(Folder, "tiers", tier + ".md"))
            .Where(line => line.StartsWith("| `", StringComparison.Ordinal))
            .Select(line => Token(Cells(line)[1]))];

    /// <summary>The mark and the note the records give a row.</summary>
    private static (string Mark, string Note) Expected(Row row)
    {
        if (MauiRealization.Unrealized.Contains(row.Entry))
        {
            return ("", "");
        }

        string[] owners = row.Tier is string tier ? [row.Entry, tier] : [row.Entry];

        foreach (string owner in owners)
        {
            if (MauiRealization.Records.FirstOrDefault(record => record.Owner == owner && record.Member == row.Member)
                is MauiRealization.Record found)
            {
                return found.Missing is string missing ? ("✅*", missing) : ("✅", "");
            }
        }

        return ("", "");
    }

    [Fact]
    public void TheDictionarysMauiColumnIsWhatThisHostRealizes()
    {
        List<Row> rows = Rows();

        Assert.NotEmpty(rows);

        foreach (Row row in rows)
        {
            (string mark, string note) = Expected(row);

            Assert.True(row.Mark == mark,
                $"docs/controls/{row.Entry}.md marks {row.Member} \"{row.Mark}\" for MAUI, and MauiRealization "
                + $"says \"{mark}\". Record the realization, then run python3 .scripts/controls-dictionary.py.");

            Assert.True(row.Note == note,
                $"docs/controls/{row.Entry}.md notes \"{row.Note}\" for MAUI on {row.Member}, and MauiRealization "
                + $"says \"{note}\". Run python3 .scripts/controls-dictionary.py.");
        }
    }

    [Fact]
    public void EveryRecordNamesAMemberTheDictionaryLists()
    {
        HashSet<string> entries = [.. Entries()];
        HashSet<string> tiers = [.. Tiers()];
        List<Row> rows = Rows();

        foreach (MauiRealization.Record record in MauiRealization.Records)
        {
            if (entries.Contains(record.Owner))
            {
                Assert.True(rows.Any(row => row.Entry == record.Owner && row.Member == record.Member),
                    $"MauiRealization records {record.Member} on {record.Owner}, which has no such row");
            }
            else if (tiers.Contains(record.Owner))
            {
                Assert.True(TierMembers(record.Owner).Contains(record.Member),
                    $"MauiRealization records {record.Member} on the tier {record.Owner}, which lists no such member");
            }
            else
            {
                Assert.Fail($"MauiRealization records {record.Member} on {record.Owner}, which docs/controls does not hold");
            }
        }

        foreach (string entry in MauiRealization.Unrealized)
        {
            Assert.True(entries.Contains(entry),
                $"MauiRealization.Unrealized names {entry}, which docs/controls does not hold");
        }
    }

    [Fact]
    public void EveryRecordIsWrittenOnce()
    {
        HashSet<string> seen = [];

        foreach (MauiRealization.Record record in MauiRealization.Records)
        {
            Assert.True(seen.Add($"{record.Owner}.{record.Member}"),
                $"MauiRealization records {record.Member} on {record.Owner} twice");
        }
    }
}
