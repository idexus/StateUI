// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

using StateUI.Maui.Protocol;

namespace StateUI.Maui.Tests;

/// <summary>
/// The application's handlers are raised in the order the reader and the
/// platform gave them, and never inside an apply: one raised while a message is
/// being applied waits for the message to be in.
/// </summary>
public class HandlerDispatchTests
{
    /// <summary>
    /// A scene's announcement made while a message is being applied - a window
    /// the system restored, offered to its scene - reaches the handler once the
    /// message is in, rather than being lost to it.
    /// </summary>
    [Fact]
    public void AnAnnouncementMadeInsideAnApplyIsRaisedOnceItIsIn()
    {
        var host = new Host();

        using (host.Renderer.Applying())
        {
            host.Renderer.Announce(7, HostValue.Of(1));
            Assert.Empty(host.Dispatched);
        }

        Assert.Equal([7], host.Dispatched.Select(raised => raised.Id));
    }

    /// <summary>
    /// Handlers held while a message is being rendered are raised in the order
    /// they came, and only once the last hold lets go - a render nested in
    /// another holds and releases in its turn without raising the outer's.
    /// </summary>
    [Fact]
    public void HeldHandlersAreRaisedInTheOrderTheyCameOnceTheLastHoldLetsGo()
    {
        var host = new Host();

        host.Renderer.Handlers.Hold();
        host.Renderer.Announce(3);
        host.Renderer.Handlers.Hold();
        host.Renderer.Announce(4);
        host.Renderer.Handlers.Release();

        Assert.Empty(host.Dispatched);

        host.Renderer.Handlers.Release();

        Assert.Equal([3, 4], host.Dispatched.Select(raised => raised.Id));
    }
}
