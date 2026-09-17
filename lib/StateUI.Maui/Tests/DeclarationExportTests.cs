// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

// What this runtime says about itself, written to exports/ and held to it.
//
// The direction is the reverse of every fixture under lib/StateUI/Tests: those
// are authored by the Swift tests and this side's writers are held to them,
// while an export is authored HERE, by the registrations, and read by the side
// that holds the contracts. That is why it lives in a directory of its own.
//
// Run with STATEUI_UPDATE_EXPORTS=1 to write the export instead of checking
// it, then read the .txt sidecar in the diff.

using StateUI.Maui.Protocol;
using StateUI.Maui.Rendering;

namespace StateUI.Maui.Tests;

public class DeclarationExportTests
{
    private static bool Updating =>
        Environment.GetEnvironmentVariable("STATEUI_UPDATE_EXPORTS") == "1";

    /// <summary>
    /// The export is what the registrations say, to the byte and to the line.
    /// </summary>
    /// <remarks>
    /// A member reaching a control through a registration that nobody exported
    /// would be a member this host realizes and cannot report, which is the
    /// failure the whole road exists to end. The sidecar is checked too: one
    /// that drifted from its bytes would lie to exactly the reader it is for.
    /// </remarks>
    [Fact]
    public void WhatThisHostDeclaresIsWhatItExports()
    {
        byte[] bytes = MauiDeclaration.Bytes();
        string sidecar = MauiDeclaration.Sidecar();
        string binary = Path.Combine(Fixtures.Exports, "maui.bin");
        string text = Path.Combine(Fixtures.Exports, "maui.txt");

        if (Updating)
        {
            Directory.CreateDirectory(Fixtures.Exports);
            File.WriteAllBytes(binary, bytes);
            File.WriteAllText(text, sidecar);

            return;
        }

        string hint = "\n\nEither a registration changed - in which case run the suite again with "
            + "STATEUI_UPDATE_EXPORTS=1 and read the diff - or something stopped being realized.";

        Assert.Equal(File.ReadAllBytes(binary), bytes);
        Assert.True(File.ReadAllText(text) == sidecar, "exports/maui.txt no longer matches." + hint);
    }

    /// <summary>
    /// The export is deterministic: the same registry writes the same bytes,
    /// whatever order it was built in.
    /// </summary>
    [Fact]
    public void TheSameRegistryWritesTheSameBytes()
    {
        Assert.Equal(MauiDeclaration.Bytes(), MauiDeclaration.Bytes());
    }

    /// <summary>
    /// A declaration carries an element's events as well as its members - the
    /// half a registration could not say at all until it recorded them.
    /// </summary>
    [Fact]
    public void ADeclarationCarriesMembersAndEventsAlike()
    {
        (string Element, IEnumerable<string> Members, IEnumerable<string> Events) slider =
            MauiDeclaration.Elements.Single(element => element.Element == "Slider");

        Assert.Equal(["maximum", "minimum", "value"], slider.Members.Order(StringComparer.Ordinal));
        Assert.Equal(
            ["dragCompleted", "dragStarted", "valueChanged"],
            slider.Events.Order(StringComparer.Ordinal));
    }

    /// <summary>
    /// Every name in the export is a name the contracts can be asked about -
    /// never the empty spelling a token this runtime has no member for
    /// answers.
    /// </summary>
    [Fact]
    public void NoNameInTheExportIsEmpty()
    {
        foreach ((string element, IEnumerable<string> members, IEnumerable<string> events)
            in MauiDeclaration.Elements)
        {
            Assert.NotEqual("", element);
            Assert.DoesNotContain("", members);
            Assert.DoesNotContain("", events);
        }
    }
}
