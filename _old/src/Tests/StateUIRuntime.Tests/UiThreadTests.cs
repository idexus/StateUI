// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

// The check that stands behind everything the Swift side assumes.
//
// It has no visible effect when it passes, which is most of the time and the
// whole point - so what these pin down is the other case: that a wrong thread is
// reported, that it is reported ONCE, and that a test with no platform under it
// is not mistaken for one.
using Microsoft.Maui.Dispatching;
using StateUI.Runtime.Rendering;

namespace StateUI.Runtime.Tests;

public class UiThreadTests
{
    /// <summary>A dispatcher that says whatever the test needs it to say.</summary>
    private sealed class Dispatcher(bool elsewhere) : IDispatcher
    {
        public bool IsDispatchRequired => elsewhere;

        public bool Dispatch(Action action)
        {
            action();
            return true;
        }

        public bool DispatchDelayed(TimeSpan delay, Action action)
        {
            action();
            return true;
        }

        public IDispatcherTimer CreateTimer() => throw new NotSupportedException();
    }

    [Fact]
    public void TheUiThreadPassesAndSaysNothing()
    {
        List<string> said = [];
        var check = new UiThread(said.Add);

        Assert.True(check.Verify(new Dispatcher(elsewhere: false), "a render"));
        Assert.Empty(said);
    }

    [Fact]
    public void AnyOtherThreadIsReported()
    {
        List<string> said = [];
        var check = new UiThread(said.Add);

        Assert.False(check.Verify(new Dispatcher(elsewhere: true), "an event from MAUI"));

        string message = Assert.Single(said);
        Assert.Contains("an event from MAUI", message);
        Assert.Contains("not the one MAUI draws on", message);
    }

    /// <summary>
    /// A standing condition, not an incident: every event after the first would
    /// repeat it, and the first report is the one worth reading.
    /// </summary>
    [Fact]
    public void ItIsSaidOnceHoweverOftenItHappens()
    {
        List<string> said = [];
        var check = new UiThread(said.Add);
        var dispatcher = new Dispatcher(elsewhere: true);

        for (int i = 0; i < 10; i++)
        {
            Assert.False(check.Verify(dispatcher, "an event from MAUI"));
        }

        Assert.Single(said);
    }

    /// <summary>
    /// A test has one thread and nothing to compare it against, which is not the
    /// same as being on the wrong one.
    /// </summary>
    [Fact]
    public void NoDispatcherIsNotAComplaint()
    {
        List<string> said = [];
        var check = new UiThread(said.Add);

        Assert.True(check.Verify(null, "a render"));
        Assert.Empty(said);
    }
}
