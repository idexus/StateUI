// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

// The lanes a walked value crosses in and the batch every value crosses in, as
// the core writes them. JourneyCodecTests.swift writes journey-lanes.txt from
// its own JourneyLanes and state-batches.txt from its own StateBatch; this
// reads both through this side's JourneyCodec and StateBatch.

using System.Globalization;
using StateUI.Maui.Protocol;

namespace StateUI.Maui.Tests;

public class JourneyCodecTests
{
    /// <summary>
    /// Every journey the core wrote reads here as the parts it was written
    /// from: where the value is, where it is going, how fast, the law, the
    /// waiter and the stops.
    /// </summary>
    [Fact]
    public void EveryJourneyInTheCoresTableReadsAsItsParts()
    {
        int read = 0;

        foreach (string[] words in Lines("journey-lanes.txt"))
        {
            int width = int.Parse(After(words, "journey"), CultureInfo.InvariantCulture);
            double[] lanes = Numbers(After(words, "lanes"));
            string line = string.Join(' ', words);

            Assert.True(JourneyCodec.Count(width) == lanes.Length, $"{line}: {lanes.Length} lanes");
            Assert.Equal(Numbers(After(words, "value")), JourneyCodec.ValueOf(lanes, width));
            Assert.Equal(Numbers(After(words, "destination")), JourneyCodec.DestinationOf(lanes, width));
            Assert.Equal(Numbers(After(words, "velocity")), JourneyCodec.VelocityOf(lanes, width));
            Assert.Equal(Number(After(words, "waiter")), lanes[JourneyCodec.Waiter(width)]);
            Assert.Equal(Number(After(words, "stops")), lanes[JourneyCodec.Stops(width)]);

            int law = Array.IndexOf(words, "law");
            (JourneyCodec.Law kind, HostMotion motion) = JourneyCodec.MotionAt(lanes, JourneyCodec.LawAt(width));

            Assert.True(
                string.Equals(words[law + 1], kind.ToString(), StringComparison.OrdinalIgnoreCase),
                $"{line}: read as {kind}");

            switch (kind)
            {
                case JourneyCodec.Law.Eased:
                    Assert.Equal(HostMotion.Law.Eased, motion.Kind);
                    Assert.Equal(uint.Parse(words[law + 2], CultureInfo.InvariantCulture), motion.Millis);
                    Assert.Equal((HostEasing)(int)Number(words[law + 3]), motion.Curve);
                    break;

                case JourneyCodec.Law.Spring:
                    Assert.Equal(HostMotion.Law.Spring, motion.Kind);
                    Assert.Equal(uint.Parse(words[law + 2], CultureInfo.InvariantCulture), motion.Millis);
                    Assert.Equal(Number(words[law + 3]), motion.Factor);
                    break;

                default:
                    Assert.True(motion.Instant, $"{line}: {kind} moves");
                    break;
            }

            read++;
        }

        Assert.True(read >= 5, "the table holds almost no journeys");
    }

    /// <summary>
    /// Every batch the core wrote reads here as its writes, and those writes
    /// lie in the core's own bytes again; a batch cut short keeps the writes
    /// before the cut, as the core's reader does.
    /// </summary>
    [Fact]
    public void EveryBatchInTheCoresTableReadsAndWritesAsTheCoresDoes()
    {
        List<(byte[] Bytes, List<(int Number, ulong Mask, byte[] Bytes)> Writes)> batches = [];
        byte[]? cut = null;
        int keeps = 0;

        foreach (string[] words in Lines("state-batches.txt"))
        {
            switch (words[0])
            {
                case "batch":
                    batches.Add((Convert.FromHexString(words[1]), []));
                    break;

                case "write":
                    batches[^1].Writes.Add((
                        int.Parse(words[1], CultureInfo.InvariantCulture),
                        ulong.Parse(words[2], NumberStyles.HexNumber, CultureInfo.InvariantCulture),
                        words[3] == "-" ? [] : Convert.FromHexString(words[3])));
                    break;

                case "cut":
                    cut = Convert.FromHexString(words[1]);
                    keeps = int.Parse(words[3], CultureInfo.InvariantCulture);
                    break;
            }
        }

        Assert.True(batches.Count >= 4, "the table holds almost no batches");

        foreach ((byte[] bytes, List<(int Number, ulong Mask, byte[] Bytes)> writes) in batches)
        {
            Same(writes, StateBatch.Read(bytes));
            Assert.Equal(bytes, StateBatch.Bytes(writes));
        }

        Assert.NotNull(cut);
        Same(batches[^1].Writes[..keeps], StateBatch.Read(cut));
    }

    private static void Same(
        List<(int Number, ulong Mask, byte[] Bytes)> expected,
        List<(int Number, ulong Mask, byte[] Bytes)> read)
    {
        Assert.Equal(expected.Count, read.Count);

        for (int index = 0; index < expected.Count; index++)
        {
            Assert.Equal(expected[index].Number, read[index].Number);
            Assert.Equal(expected[index].Mask, read[index].Mask);
            Assert.Equal(expected[index].Bytes, read[index].Bytes);
        }
    }

    /// <summary>Every line of a table that is not a comment, as its words.</summary>
    private static IEnumerable<string[]> Lines(string name) =>
        File.ReadAllLines(Path.Combine(Fixtures.Directory, name))
            .Where(line => line.Length > 0 && !line.StartsWith('#'))
            .Select(line => line.Split(' '));

    /// <summary>The word after <paramref name="key"/>.</summary>
    private static string After(string[] words, string key) => words[Array.IndexOf(words, key) + 1];

    private static double Number(string word) =>
        double.Parse(word, NumberStyles.Float, CultureInfo.InvariantCulture);

    private static double[] Numbers(string word) => [.. word.Split(',').Select(Number)];
}
