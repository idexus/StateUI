// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

// WHAT A SECOND WINDOW CHANGES FOR THE FIRST.
//
// MAUI asks for the current Shell after every pop, and its answer THROWS in an
// application with more than one window and no Shell - "Unable to determine the
// current Shell instance". This library uses no Shell, so a second window - an
// inspector's, a document's - turned every pop the tree asked for into the
// library's error page. The pop has happened by then; it must be finished.
//
// MAUI asks only once a platform's navigation has finished, so a headless
// NavigationPage never reaches the question: these hand the pop's finishing the
// failure MAUI raises, at the level this library decides what it means.

using Microsoft.Maui.Controls;
using StateUI.Runtime.Rendering;

namespace StateUI.Runtime.Tests;

public class SecondWindowTests
{
    /// <summary>What MAUI says, word for word, when it cannot find a Shell.</summary>
    private const string NoShell =
        "Unable to determine the current Shell instance you want to use. "
        + "Please access Shell via the Windows property on Gallery.App.";

    /// <summary>A page the renderer built, listening for the moves it was given ids for.</summary>
    private static ContentPage Page(SwiftPages pages, int id, string title) =>
        Assert.IsType<ContentPage>(pages.Render(null, Host.Parse(
            $"{{\"id\":{id},\"type\":\"ContentPage\",\"props\":{{\"title\":\"{title}\"}},"
            + $"\"events\":{{\"navigatedTo\":{id + 50}}},\"arranged\":true,\"children\":"
            + $"[{{\"id\":{id + 100},\"type\":\"Label\",\"props\":{{\"text\":\"{title}\"}}}}]}}")));

    /// <summary>
    /// A pop MAUI could not finish for want of a Shell is finished here: nothing
    /// fails, and the page it uncovered hears that it was navigated to - the
    /// report MAUI's throw skipped.
    /// </summary>
    [Fact]
    public async Task APopMauiCouldNotFinishIsFinishedHere()
    {
        var host = new Host();
        var pages = new SwiftPages(host.Renderer, (message, exception) => Assert.Fail(message));
        ContentPage leaving = Page(pages, 3, "One");
        ContentPage uncovered = Page(pages, 2, "Home");

        await pages.Popped(
            Task.FromException(new InvalidOperationException(NoShell)),
            leaving,
            () => uncovered);

        Assert.Contains(host.Dispatched, report => report.Id == 52);
    }

    /// <summary>
    /// Any other failure of a pop is still a failure - what is finished here is
    /// MAUI's one question, and nothing it does not ask.
    /// </summary>
    [Fact]
    public async Task AnyOtherFailureOfAPopStillFails()
    {
        var host = new Host();
        var pages = new SwiftPages(host.Renderer, (message, exception) => Assert.Fail(message));
        ContentPage leaving = Page(pages, 3, "One");

        await Assert.ThrowsAsync<InvalidOperationException>(() => pages.Popped(
            Task.FromException(new InvalidOperationException("the stack is empty")),
            leaving,
            () => null));
    }
}
