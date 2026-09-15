// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

using StateUI.Maui.Protocol;
using StateUI.Maui.Rendering;

namespace StateUI.Maui.Tests;

/// <summary>
/// A message means something only against the tree it was computed from: the
/// intake claims a message's generation once it went in whole, and asks for the
/// whole tree whenever it cannot be sure of what it holds.
/// </summary>
public class PatchIntakeTests
{
    private static HostRender Message(int generation) =>
        new() { Generation = generation, Root = new HostPatch() };

    /// <summary>A message taken whole is the baseline the next render quotes.</summary>
    [Fact]
    public void AMessageTakenWholeIsWhatTheNextRenderQuotes()
    {
        var intake = new PatchIntake();

        Assert.Equal(0, intake.Quote());
        Assert.True(intake.Take(Message(5), (_, _) => true));
        Assert.Equal(5, intake.Quote());
    }

    /// <summary>
    /// A quote drops the generation as it is read, so a render that goes wrong
    /// before its message is in leaves the next one asking for the whole tree.
    /// </summary>
    [Fact]
    public void AQuoteDropsTheGenerationUntilAMessageIsIn()
    {
        var intake = new PatchIntake();
        intake.Take(Message(5), (_, _) => true);

        Assert.Equal(5, intake.Quote());
        Assert.Equal(0, intake.Quote());
    }

    /// <summary>A message about a tree this side is not holding claims nothing.</summary>
    [Fact]
    public void ARefusedMessageLeavesTheNextRenderAskingForTheWholeTree()
    {
        var intake = new PatchIntake();
        intake.Take(Message(5), (_, _) => true);
        intake.Quote();

        Assert.False(intake.Take(Message(6), (_, _) => false));
        Assert.Equal(0, intake.Quote());
    }

    /// <summary>An apply that throws claims nothing and leaves nothing applying.</summary>
    [Fact]
    public void AnApplyThatThrowsClaimsNothing()
    {
        var intake = new PatchIntake();

        Assert.Throws<InvalidOperationException>(() =>
            intake.Take(Message(7), (_, _) => throw new InvalidOperationException()));
        Assert.Equal(0, intake.Quote());
        Assert.False(intake.IsApplying);
    }

    /// <summary>
    /// A message taken while another is being applied is computed against a
    /// tree the outer apply has not finished writing, so once both are in what
    /// is on screen is not reliably either: the next render is the whole tree,
    /// whatever the inner one claimed.
    /// </summary>
    [Fact]
    public void AMessageTakenUnderAnotherLeavesTheNextRenderWhole()
    {
        var intake = new PatchIntake();
        bool inner = false;

        Assert.True(intake.Take(Message(5), (_, _) =>
        {
            Assert.True(intake.IsApplying);
            intake.Quote();
            inner = intake.Take(Message(6), (_, _) => true);
            return true;
        }));

        Assert.True(inner);
        Assert.False(intake.IsApplying);
        Assert.Equal(0, intake.Quote());
    }
}
