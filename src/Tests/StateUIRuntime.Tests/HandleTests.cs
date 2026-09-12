// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

// AN AUTOMATION ID SURVIVES WHAT THE TREE DOES TO ITS CONTROL.
//
// MAUI's own setter takes one write and throws on the next, even of the same
// value. The tree writes the id again whenever it describes the control in
// full - a resync - and a list hands a row's control to the next item of its
// shape, with that item's id.

using Microsoft.Maui.Controls;

namespace StateUI.Runtime.Tests;

public class HandleTests
{
    /// <summary>A label with a handle, as Swift describes it in full.</summary>
    private const string Handled =
        """{"id":1,"type":"Label","props":{"text":"one","automationId":"card.one"}}""";

    /// <summary>
    /// A control described in full again keeps its handle - and the message
    /// lands, where a second write of the same id through MAUI's setter threw
    /// and failed every resync of a page with one on it.
    /// </summary>
    [Fact]
    public void AControlDescribedInFullAgainKeepsItsHandle()
    {
        var host = new Host();
        View label = host.Renderer.Render(null, Host.Parse(Handled));

        View again = host.Renderer.Render(label, Host.Parse(Handled));

        Assert.Same(label, again);
        Assert.Equal("card.one", again.AutomationId);
    }

    /// <summary>
    /// A control given to another item takes that item's handle, which is what
    /// a list's recycled row is.
    /// </summary>
    [Fact]
    public void AControlGivenToAnotherItemTakesItsHandle()
    {
        var host = new Host();
        View label = host.Renderer.Render(null, Host.Parse(Handled));

        View again = host.Renderer.Render(label, Host.Parse(
            """{"id":1,"type":"Label","props":{"text":"two","automationId":"card.two"}}"""));

        Assert.Same(label, again);
        Assert.Equal("card.two", again.AutomationId);
    }
}
