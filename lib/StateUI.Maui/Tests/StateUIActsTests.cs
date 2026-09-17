// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

// The application's own acts: registered under a name, found by Perform's
// default arm, answering typed values. The arm itself is three lines over
// this registry; what the registration promises is pinned here.

using StateUI.Maui.Protocol;
using StateUI.Maui.Rendering;

namespace StateUI.Maui.Tests;

public class StateUIActsTests
{
    /// <summary>An act as Perform would hold it, for a performer to read.</summary>
    private static HostActCall Call(string name, params HostValue[] arguments) =>
        new(HostAct.None, name, arguments, completion: -1);

    [Fact]
    public async Task ARegisteredAsyncFunctionAnswersItsValues()
    {
        StateUIActs.Add("Test.Echo", async call =>
        {
            await Task.Yield();
            return [HostValue.Of(call.GetString(0) ?? "")];
        });

        var performer = StateUIActs.Find("Test.Echo");
        Assert.NotNull(performer);

        HostValue[] answered = await performer(Call("Test.Echo", HostValue.Of("hi")));
        Assert.Equal("hi", Assert.Single(answered).Text);
    }

    [Fact]
    public async Task APlainFunctionRegistersTheSameWay()
    {
        StateUIActs.Add("Test.Two", call =>
            [HostValue.Of(2.0), HostValue.Of(true)]);

        HostValue[] answered = await StateUIActs.Find("Test.Two")!(Call("Test.Two"));

        Assert.Equal(2, answered.Length);
        Assert.Equal(2.0, answered[0].Number);
    }

    /// <summary>
    /// A name nothing registered answers null, which is what lets the default
    /// arm go on to report "unknown act" - a failure, never a silence.
    /// </summary>
    [Fact]
    public void AnUnregisteredNameAnswersNothing()
    {
        Assert.Null(StateUIActs.Find("Test.Nobody"));
    }
}
