// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

// The two motion laws, walked with the core's numbers. MotionLawTests.swift
// writes every trajectory of its table into motion-laws.txt; this walks each
// trip the file describes and asks MotionLaw where it stands at each
// instant the file names.

using System.Globalization;
using StateUI.Maui.Protocol;
using StateUI.Maui.Rendering;

namespace StateUI.Maui.Tests;

public class MotionLawTests
{
    /// <summary>
    /// Every trip in the core's trajectory table stands at the same value and
    /// speed here, and arrives at the same instant.
    /// </summary>
    [Fact]
    public void EveryTripInTheCoresTableWalksToTheSameNumbers()
    {
        Trip? trip = null;
        int instants = 0;

        foreach (string line in File.ReadAllLines(Path.Combine(Fixtures.Directory, "motion-laws.txt")))
        {
            if (line.Length == 0 || line.StartsWith('#'))
            {
                continue;
            }

            string[] words = line.Split(' ');

            if (words[0] == "trip")
            {
                trip = Parse(words);
                continue;
            }

            // at <elapsed> <moving|rested> value <lanes> velocity <lanes>
            Assert.NotNull(trip);
            double[] value = new double[trip.From.Length];
            double[] velocity = new double[trip.From.Length];

            bool rested = MotionLaw.Sample(trip, Number(words[1]), value, velocity);

            Assert.True(rested == (words[2] == "rested"), $"{line}: arrived {rested}");
            Close(Lanes(words[4]), value, line);
            Close(Lanes(words[6]), velocity, line);
            instants++;
        }

        Assert.True(instants > 100, "the table holds almost no trajectories");
    }

    /// <summary>
    /// A trip from its line:
    /// <c>trip law curve milliseconds damping from lanes to lanes velocity lanes</c>.
    /// </summary>
    private static Trip Parse(string[] words)
    {
        uint millis = (uint)Number(words[3]);
        HostMotion motion = words[1] == "spring"
            ? HostMotion.Spring(millis, Number(words[4]))
            : HostMotion.Eased(millis, Enum.Parse<SwiftEasing>(words[2], ignoreCase: true));
        double[] from = Lanes(words[6]);

        return new Trip
        {
            // The law reads where the trip began and where it is going, and
            // never what it moves.
            Moves = null!,
            P = new double[from.Length],
            V = new double[from.Length],
            From = from,
            StartV = Lanes(words[10]),
            Target = Lanes(words[8]),
            Motion = motion,
        };
    }

    private static double Number(string word) =>
        double.Parse(word, NumberStyles.Float, CultureInfo.InvariantCulture);

    private static double[] Lanes(string word) => [.. word.Split(',').Select(Number)];

    /// <summary>
    /// Equal to a billionth of the larger: the platforms' maths libraries may
    /// round <c>exp</c>, <c>sin</c> and <c>cos</c> differently in the last
    /// digit, and the table is written on one of them.
    /// </summary>
    private static void Close(double[] expected, double[] actual, string line)
    {
        Assert.Equal(expected.Length, actual.Length);

        for (int lane = 0; lane < expected.Length; lane++)
        {
            double scale = Math.Max(1, Math.Max(Math.Abs(expected[lane]), Math.Abs(actual[lane])));

            Assert.True(
                Math.Abs(expected[lane] - actual[lane]) <= 1e-9 * scale,
                $"{line}: lane {lane} walks to {actual[lane]}");
        }
    }
}
