// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

// Closing a keyboard the Swift side did not open.
//
// `SoftInput.hide()` names no view - it cannot, since which control has the
// focus is whichever one the reader touched last - so the host works it out by
// asking the page. That decision is the whole of what can be checked here: the
// unfocusing itself goes through a platform handler, and there are none in a
// headless test, so a view told to give up the focus keeps IsFocused true. The
// same limit every renderer test has, and the reason these read
// SwiftFocus.Holding rather than the state afterwards.
//
// What the decision has to get right, each of them a way a simpler walk gets it
// wrong:
//
//   - a field is usually deep in layouts, not a child of the page;
//   - the search box is not in the page's tree AT ALL, MAUI attaching it, so a
//     walk that only looks at children reports nothing while iOS shows a
//     keyboard and no back button;
//   - a container shows a page rather than itself, and the containers NEST, so
//     the descent has to go through every one of them;
//   - a modal sheet is over everything, the showing page included.
using StateUI.Runtime.Rendering;

namespace StateUI.Runtime.Tests;

public class FocusTests
{
    /// <summary>A view MAUI would report as focused, without a platform to do it.</summary>
    /// <remarks>
    /// IsFocused is read-only and set by the platform, and MAUI publishes the
    /// key for exactly this - so a test can say what a device would say.
    /// </remarks>
    private static T Focused<T>(T view) where T : VisualElement
    {
        view.SetValue(VisualElement.IsFocusedPropertyKey, true);
        return view;
    }

    /// <summary>A page whose field sits several layouts down, as one does.</summary>
    private static (ContentPage Page, Entry Field) PageWithAField(bool focused)
    {
        var field = new Entry();

        if (focused)
        {
            Focused(field);
        }

        var inner = new VerticalStackLayout { Children = { new Label(), field } };

        return (
            new ContentPage { Content = new ScrollView { Content = inner } },
            field);
    }

    [Fact]
    public void TheFocusedFieldIsFoundHoweverDeepItSits()
    {
        (ContentPage page, Entry field) = PageWithAField(focused: true);

        Assert.Same(field, SwiftFocus.Holding(page));
        Assert.True(SwiftFocus.Hide(page));
    }

    [Fact]
    public void AKeyboardThatIsAlreadyDownIsAnAnswerRatherThanAFailure()
    {
        (ContentPage page, _) = PageWithAField(focused: false);

        Assert.Null(SwiftFocus.Holding(page));
        Assert.False(SwiftFocus.Hide(page), "nothing was focused, and that is not a failure");
    }

    [Fact]
    public void AskingNoPageAtAllAnswersTheSameWay()
    {
        Assert.Null(SwiftFocus.Holding(null));
        Assert.False(SwiftFocus.Hide(null));
    }

    // ---- Which page is showing ---------------------------------------------

    /// <summary>
    /// The arrangements NEST, so the page being read is found by descending
    /// rather than by one hop: a flyout shows its detail, a set of tabs shows
    /// the current tab, a stack shows the page on top.
    /// </summary>
    /// <remarks>
    /// One hop lands on another container, not on a page, and the keyboard and
    /// every dialog would then aim at that instead of at the page the reader is
    /// looking at - fixtures/sessions/1-opens.txt is exactly this shape.
    /// </remarks>
    [Fact]
    public void ThePageShowingIsFoundThroughEveryContainerOverIt()
    {
        var page = new ContentPage { Title = "Read me" };
        var stack = new NavigationPage(page);
        var tabs = new TabbedPage();
        tabs.Children.Add(stack);

        var flyout = new FlyoutPage
        {
            Flyout = new ContentPage { Title = "Menu" },
            Detail = tabs,
        };

        Assert.Same(page, SwiftFocus.Showing(flyout));
        Assert.Same(page, SwiftFocus.Showing(tabs));
        Assert.Same(page, SwiftFocus.Showing(stack));
        Assert.Same(page, SwiftFocus.Showing(page));
    }

    /// <summary>
    /// A modal sheet is over everything. Reading only the stack's current page
    /// would look for the keyboard on the page UNDER the sheet - which is where
    /// nobody is typing.
    /// </summary>
    [Fact]
    public async Task AModalSheetIsWhereTheKeyboardIs()
    {
        var page = new ContentPage { Title = "Home" };
        var stack = new NavigationPage(page);

        var sheet = new ContentPage { Title = "Sheet" };
        await stack.Navigation.PushModalAsync(sheet);

        Assert.Contains(sheet, stack.Navigation.ModalStack);
        Assert.Same(sheet, SwiftFocus.Showing(stack));
    }
}
