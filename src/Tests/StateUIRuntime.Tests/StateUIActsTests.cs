// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

// The application's own acts: registered under a name, found by Perform's
// default arm, answering typed values. The arm itself is three lines over
// this registry; what the registration promises is pinned here.

using StateUI.Runtime.Protocol;
using StateUI.Runtime.Rendering;

namespace StateUI.Runtime.Tests;

public class StateUIActsTests
{
    /// <summary>A command as Perform would hold it, for a performer to read.</summary>
    private static SwiftCommand Command(string name, params SwiftWireValue[] arguments) =>
        new(SwiftAct.None, name, arguments, completion: -1);

    [Fact]
    public async Task ARegisteredAsyncFunctionAnswersItsValues()
    {
        StateUIActs.Add("Test.Echo", async command =>
        {
            await Task.Yield();
            return [SwiftWireValue.Of(command.GetString(0) ?? "")];
        });

        var performer = StateUIActs.Find("Test.Echo");
        Assert.NotNull(performer);

        SwiftWireValue[] answered = await performer(Command("Test.Echo", SwiftWireValue.Of("hi")));
        Assert.Equal("hi", Assert.Single(answered).Text);
    }

    [Fact]
    public async Task APlainFunctionRegistersTheSameWay()
    {
        StateUIActs.Add("Test.Two", command =>
            [SwiftWireValue.Of(2.0), SwiftWireValue.Of(true)]);

        SwiftWireValue[] answered = await StateUIActs.Find("Test.Two")!(Command("Test.Two"));

        Assert.Equal(2, answered.Length);
        Assert.Equal(2.0, answered[0].Number);
    }

    /// <summary>
    /// A name nothing registered answers null, which is what lets the default
    /// arm go on to report "unknown command" - a failure, never a silence.
    /// </summary>
    [Fact]
    public void AnUnregisteredNameAnswersNothing()
    {
        Assert.Null(StateUIActs.Find("Test.Nobody"));
    }
}
