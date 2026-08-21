// The other half of each control: the message arrives, the MAUI property is
// set.
//
// `src/Tests/fixtures/controls/*.bin` are written by the Swift tests, one file
// per control, each built with every modifier that control declares. Here they
// are applied and the real MAUI properties are read back. That is the whole
// check, and it is the one nothing else performs: an unrecognized property is
// ignored by design, so a modifier this side has not caught up with does
// nothing and says nothing.
//
// Two tests keep the set from rotting:
//
//   EveryControlTheRendererKnowsHasAFixture   a new Reconcile method with no
//                                             fixture fails here
//   EveryFixtureIsChecked                     a fixture nothing reads fails here
//
// The tier properties - padding, margin, fontSize, layout options - are checked
// once, from the Elements fixture, rather than on every control: one ApplyView
// sets them for all of them, and one copy of that assertion per control would
// prove one method two dozen times.
using System.Reflection;
using Microsoft.Maui.Controls.Maps;
using Microsoft.Maui.Controls.Shapes;
using Microsoft.Maui.Layouts;
using StateUI.Runtime.Protocol;
using StateUI.Runtime.Rendering;

// MAUI's map control, not the namespace holding MapType - see the renderer,
// which threads the same needle, drawn shapes included.
using Map = Microsoft.Maui.Controls.Maps.Map;
using Polygon = Microsoft.Maui.Controls.Shapes.Polygon;
using Polyline = Microsoft.Maui.Controls.Shapes.Polyline;

// Shapes declares a Path and so does System.IO, and this file uses both - one
// to draw with and one to find a fixture. So neither is aliased and the drawn
// one is written out where it appears.
using Path = System.IO.Path;

namespace StateUI.Runtime.Tests;

public class ControlTests
{
    /// <summary>
    /// What each fixture must produce. The key is the file, without .bin, and
    /// the MAUI type it describes.
    /// </summary>
    private static readonly Dictionary<string, Action<Host, View>> Checks = new()
    {
        ["Label"] = (_, view) =>
        {
            var label = Assert.IsType<Label>(view);

            // Text and FormattedText are MUTUALLY EXCLUSIVE in MAUI, measured
            // here: the message carried both, the renderer assigned both, and
            // setting FormattedText put Text back to null. The runs win because
            // they are applied last, which is MAUI's rule rather than a choice
            // this side makes.
            Assert.Null(label.Text);
            Assert.Equal(LineBreakMode.TailTruncation, label.LineBreakMode);
            Assert.Equal(TextType.Text, label.TextType);
            Assert.Equal(1.5, label.LineHeight);
            Assert.Equal(2, label.MaxLines);
            Assert.Equal(TextDecorations.Underline | TextDecorations.Strikethrough, label.TextDecorations);

            // The runs. Two colours in one label is two Spans - MAUI gives a
            // Label one TextColor and no way to colour part of it.
            Assert.NotNull(label.FormattedText);
            Assert.Equal(2, label.FormattedText!.Spans.Count);

            Span first = label.FormattedText.Spans[0];
            Assert.Equal("let ", first.Text);
            Assert.Equal(Color.FromArgb("#800080"), first.TextColor);
            Assert.Equal(Color.FromArgb("#F5F5F5"), first.BackgroundColor);
            Assert.Equal(13, first.FontSize);
            Assert.Equal("Menlo", first.FontFamily);
            Assert.Equal(FontAttributes.Bold, first.FontAttributes);
            Assert.False(first.FontAutoScalingEnabled);
            Assert.Equal(0.5, first.CharacterSpacing);
            Assert.Equal(1.2, first.LineHeight);
            Assert.Equal(TextDecorations.Underline, first.TextDecorations);

            Assert.Equal("counter", label.FormattedText.Spans[1].Text);
            Assert.Equal(Color.FromArgb("#4682B4"), label.FormattedText.Spans[1].TextColor);
        },

        ["Button"] = (host, view) =>
        {
            var button = Assert.IsType<Button>(view);

            Assert.Equal("Increment", button.Text);
            Assert.Equal(Colors.Gray, button.BorderColor);
            Assert.Equal(1, button.BorderWidth);
            Assert.Equal(8, button.CornerRadius);
            Assert.Equal(LineBreakMode.NoWrap, button.LineBreakMode);

            // A picture beside the caption, and where it sits - the layout
            // travels in MAUI's own spelling and is read by MAUI's converter.
            Assert.Equal("tab_list.png", Assert.IsType<FileImageSource>(button.ImageSource).File);
            Assert.Equal(Button.ButtonContentLayout.ImagePosition.Left, button.ContentLayout.Position);
            Assert.Equal(8, button.ContentLayout.Spacing);

            // The events the fixture carries, reported with the ids Swift gave
            // them - which is the other half of the contract, and the half a
            // property assertion cannot see.
            var controller = (IButtonController)button;

            controller.SendClicked();
            Assert.Equal((1, (string?)null), host.Dispatched[^1]);

            controller.SendPressed();
            Assert.Equal((2, (string?)null), host.Dispatched[^1]);

            controller.SendReleased();
            Assert.Equal((3, (string?)null), host.Dispatched[^1]);
        },

        ["Entry"] = (host, view) =>
        {
            var entry = Assert.IsType<Entry>(view);

            Assert.Equal("Ada", entry.Text);
            Assert.False(entry.IsPassword);
            Assert.Equal(ReturnType.Done, entry.ReturnType);
            Assert.Equal(ClearButtonVisibility.WhileEditing, entry.ClearButtonVisibility);

            // The user typing, as opposed to the renderer assigning: the text
            // travels with the event.
            ((IEntryController)entry).SendCompleted();
            Assert.Equal((1, (string?)null), host.Dispatched[^1]);
        },

        ["Editor"] = (host, view) =>
        {
            var editor = Assert.IsType<Editor>(view);

            Assert.Equal("Notes", editor.Text);
            Assert.Equal(EditorAutoSizeOption.TextChanges, editor.AutoSize);

            editor.Text = "typed";
            Assert.Equal((2, "\"typed\""), host.Dispatched[^1]);
        },

        ["Image"] = (_, view) =>
        {
            var image = Assert.IsType<Image>(view);

            Assert.Equal("tab_list.png", Assert.IsType<FileImageSource>(image.Source).File);
            Assert.Equal(Aspect.AspectFill, image.Aspect);
            Assert.True(image.IsAnimationPlaying);
            Assert.True(image.IsOpaque);
        },

        ["ImageButton"] = (host, view) =>
        {
            var button = Assert.IsType<ImageButton>(view);

            Assert.Equal("tab_list.png", Assert.IsType<FileImageSource>(button.Source).File);
            Assert.Equal(Aspect.AspectFit, button.Aspect);
            Assert.True(button.IsOpaque);
            Assert.Equal(Colors.Gray, button.BorderColor);
            Assert.Equal(1, button.BorderWidth);
            Assert.Equal(8, button.CornerRadius);

            // The same three events a Button has, reported with the ids Swift
            // gave them.
            var controller = (IButtonController)button;

            controller.SendClicked();
            Assert.Equal((1, (string?)null), host.Dispatched[^1]);

            controller.SendPressed();
            Assert.Equal((2, (string?)null), host.Dispatched[^1]);

            controller.SendReleased();
            Assert.Equal((3, (string?)null), host.Dispatched[^1]);
        },

        ["Picker"] = (host, view) =>
        {
            var picker = Assert.IsType<Picker>(view);

            Assert.Equal(["Small", "Medium", "Large"], picker.ItemsSource.Cast<string>());
            Assert.Equal(1, picker.SelectedIndex);
            Assert.Equal("Size", picker.Title);
            Assert.Equal(Colors.Gray, picker.TitleColor);
            Assert.False(picker.IsOpen);

            // The index travels as text, because every event payload does.
            picker.SelectedIndex = 2;
            // closed(1), opened(2), selectedIndexChanged(3): a node numbers
            // its handlers in NAME order, which is what keeps the wire
            // deterministic. The two the platform raises when its own list
            // opens and shuts cannot be provoked without one - setting IsOpen
            // does not raise them - so what is checked here is the property.
            Assert.Equal((3, "2"), host.Dispatched[^1]);
        },

        ["DatePicker"] = (host, view) =>
        {
            var picker = Assert.IsType<DatePicker>(view);

            // The modifier's date, not the initializer's - one key, written
            // twice, and the modifier is written second.
            Assert.Equal(new DateTime(2026, 8, 9), picker.Date);
            Assert.Equal(new DateTime(2026, 1, 1), picker.MinimumDate);
            Assert.Equal(new DateTime(2026, 12, 31), picker.MaximumDate);
            Assert.Equal("D", picker.Format);
            Assert.False(picker.IsOpen);

            picker.Date = new DateTime(2026, 9, 15);
            Assert.Equal((2, "[2026, 9, 15]"), host.Dispatched[^1]);
        },

        ["TimePicker"] = (host, view) =>
        {
            var picker = Assert.IsType<TimePicker>(view);

            Assert.Equal(new TimeSpan(21, 5, 30), picker.Time);
            Assert.Equal("t", picker.Format);
            Assert.False(picker.IsOpen);

            picker.Time = new TimeSpan(7, 45, 0);
            Assert.Equal((3, "[7, 45, 0]"), host.Dispatched[^1]);
        },

        ["Switch"] = (host, view) =>
        {
            var toggle = Assert.IsType<Switch>(view);

            Assert.True(toggle.IsToggled);
            Assert.Equal(Colors.Green, toggle.OnColor);
            Assert.Equal(Colors.LightGray, toggle.OffColor);
            Assert.Equal(Colors.White, toggle.ThumbColor);

            toggle.IsToggled = false;
            Assert.Equal((1, "false"), host.Dispatched[^1]);
        },

        ["CheckBox"] = (host, view) =>
        {
            var box = Assert.IsType<CheckBox>(view);

            Assert.True(box.IsChecked);
            Assert.Equal(Colors.Firebrick, box.Color);

            box.IsChecked = false;
            Assert.Equal((1, "false"), host.Dispatched[^1]);
        },

        ["RadioButton"] = (host, view) =>
        {
            var button = Assert.IsType<RadioButton>(view);

            Assert.Equal("Medium", button.Content);
            Assert.True(button.IsChecked);
            Assert.Equal("size", button.GroupName);
            Assert.Equal(TextTransform.Uppercase, button.TextTransform);
            Assert.Equal(Colors.Gray, button.BorderColor);
            Assert.Equal(1, button.BorderWidth);
            Assert.Equal(8, button.CornerRadius);

            // The false a button reports when it stops being the chosen one -
            // which is what MAUI sends to the loser of a group.
            button.IsChecked = false;
            Assert.Equal((1, "false"), host.Dispatched[^1]);
        },

        ["Slider"] = (host, view) =>
        {
            var slider = Assert.IsType<Slider>(view);

            Assert.Equal(40, slider.Value);
            Assert.Equal(0, slider.Minimum);
            Assert.Equal(100, slider.Maximum);
            Assert.Equal(Colors.CornflowerBlue, slider.MinimumTrackColor);
            Assert.Equal(Colors.LightGray, slider.MaximumTrackColor);
            Assert.Equal(Colors.White, slider.ThumbColor);
            Assert.Equal("thumb.png", Assert.IsType<FileImageSource>(slider.ThumbImageSource).File);

            // The ids follow the fixture, where a node's events are written
            // sorted by name: dragCompleted 1, dragStarted 2, valueChanged 3.
            //
            // 12.5 rather than 12: the number crosses as a double's own eight
            // bytes, so no machine's decimal separator is anywhere on the path
            // and a fraction cannot be garbled by one.
            slider.Value = 12.5;
            Assert.Equal((3, "12.5"), host.Dispatched[^1]);

            // The drag's two ends, raised through the public controller the
            // way a Button's clicks are.
            var controller = (ISliderController)slider;

            controller.SendDragStarted();
            Assert.Equal((2, (string?)null), host.Dispatched[^1]);

            controller.SendDragCompleted();
            Assert.Equal((1, (string?)null), host.Dispatched[^1]);
        },

        ["Stepper"] = (host, view) =>
        {
            var stepper = Assert.IsType<Stepper>(view);

            Assert.Equal(4, stepper.Value);
            Assert.Equal(1, stepper.Minimum);
            Assert.Equal(12, stepper.Maximum);
            Assert.Equal(2, stepper.Increment);

            stepper.Value = 6;
            Assert.Equal((1, "6"), host.Dispatched[^1]);
        },

        ["SearchBar"] = (host, view) =>
        {
            var search = Assert.IsType<SearchBar>(view);

            Assert.Equal("al", search.Text);
            Assert.Equal(ReturnType.Search, search.ReturnType);
            Assert.Equal(Colors.Gray, search.CancelButtonColor);
            Assert.Equal(Colors.CornflowerBlue, search.SearchIconColor);

            ((ISearchBarController)search).OnSearchButtonPressed();
            Assert.Equal((1, (string?)null), host.Dispatched[^1]);

            search.Text = "alp";
            Assert.Equal((2, "\"alp\""), host.Dispatched[^1]);
        },

        ["ActivityIndicator"] = (_, view) =>
        {
            var indicator = Assert.IsType<ActivityIndicator>(view);

            Assert.True(indicator.IsRunning);
            Assert.Equal(Colors.CornflowerBlue, indicator.Color);
        },

        ["ProgressBar"] = (_, view) =>
        {
            var bar = Assert.IsType<ProgressBar>(view);

            Assert.Equal(0.4, bar.Progress);
            Assert.Equal(Colors.CornflowerBlue, bar.ProgressColor);
        },

        ["BoxView"] = (_, view) =>
        {
            var box = Assert.IsType<BoxView>(view);

            Assert.Equal(Colors.CornflowerBlue, box.Color);
            Assert.Equal(new CornerRadius(8), box.CornerRadius);
        },

        ["Border"] = (_, view) =>
        {
            var border = Assert.IsType<Border>(view);

            Assert.Equal(Colors.LightGray, Assert.IsType<SolidColorBrush>(border.Stroke).Color);
            Assert.Equal(1, border.StrokeThickness);

            // The rest of the stroke, which MAUI declares on Border SEPARATELY
            // from the identical set on Shape - two classes sharing only
            // IStroke, so these prove Border's own arm rather than the shape
            // arm read through it.
            Assert.Equal([6d, 3d], border.StrokeDashArray);
            Assert.Equal(2, border.StrokeDashOffset);
            Assert.Equal(PenLineCap.Round, border.StrokeLineCap);
            Assert.Equal(PenLineJoin.Bevel, border.StrokeLineJoin);
            Assert.Equal(4, border.StrokeMiterLimit);

            // MAUI's own converter read "RoundRectangle 12" - the shape travels
            // in the syntax XAML writes it in.
            var shape = Assert.IsType<RoundRectangle>(border.StrokeShape);
            Assert.Equal(new CornerRadius(12), shape.CornerRadius);

            Assert.Equal("Inside", Assert.IsType<Label>(border.Content).Text);
        },

        ["Grid"] = (_, view) =>
        {
            var grid = Assert.IsType<Grid>(view);

            Assert.Equal(70, grid.RowDefinitions[0].Height.Value);
            Assert.Equal(GridUnitType.Auto, grid.RowDefinitions[1].Height.GridUnitType);
            Assert.Equal(1, grid.ColumnDefinitions[0].Width.Value);
            Assert.Equal(2, grid.ColumnDefinitions[1].Width.Value);
            Assert.Equal(12, grid.RowSpacing);
            Assert.Equal(8, grid.ColumnSpacing);

            // Where a child sits is written on the CHILD - an attached property,
            // as in XAML.
            var spanning = (Label)grid.Children[1];
            Assert.Equal(1, Grid.GetRow(spanning));
            Assert.Equal(2, Grid.GetColumnSpan(spanning));
        },

        ["VerticalStackLayout"] = (_, view) =>
        {
            var stack = Assert.IsType<VerticalStackLayout>(view);

            Assert.Equal(12, stack.Spacing);
            Assert.Equal("One", Assert.IsType<Label>(stack.Children[0]).Text);
        },

        ["HorizontalStackLayout"] = (_, view) =>
        {
            var stack = Assert.IsType<HorizontalStackLayout>(view);

            Assert.Equal(6, stack.Spacing);
            Assert.Equal("One", Assert.IsType<Label>(stack.Children[0]).Text);
        },

        ["AbsoluteLayout"] = (_, view) =>
        {
            var layout = Assert.IsType<AbsoluteLayout>(view);

            // Where a child sits is written on the CHILD, as in XAML - and the
            // flags say which of those four numbers are fractions of the layout.
            // Every part proportional is the FOUR BITS ORed, not MAUI's own
            // `All`, which is every bit there is. MAUI reads the flags a bit at
            // a time, so the two lay out identically; four bits is the one that
            // lets a bit nobody declared refuse the value.
            var box = Assert.IsType<BoxView>(layout.Children[0]);
            Assert.Equal(new Rect(0, 0, 1, 0.5), AbsoluteLayout.GetLayoutBounds(box));
            Assert.Equal(
                AbsoluteLayoutFlags.XProportional
                    | AbsoluteLayoutFlags.YProportional
                    | AbsoluteLayoutFlags.WidthProportional
                    | AbsoluteLayoutFlags.HeightProportional,
                AbsoluteLayout.GetLayoutFlags(box));

            var label = Assert.IsType<Label>(layout.Children[1]);
            Assert.Equal(new Rect(1, 1, AbsoluteLayout.AutoSize, AbsoluteLayout.AutoSize),
                AbsoluteLayout.GetLayoutBounds(label));
            Assert.Equal(AbsoluteLayoutFlags.PositionProportional, AbsoluteLayout.GetLayoutFlags(label));
        },

        ["FlexLayout"] = (_, view) =>
        {
            var layout = Assert.IsType<FlexLayout>(view);

            Assert.Equal(FlexDirection.Column, layout.Direction);
            Assert.Equal(FlexWrap.Wrap, layout.Wrap);
            Assert.Equal(FlexJustify.SpaceBetween, layout.JustifyContent);
            Assert.Equal(FlexAlignItems.Center, layout.AlignItems);
            Assert.Equal(FlexAlignContent.SpaceEvenly, layout.AlignContent);
            Assert.Equal(FlexPosition.Relative, layout.Position);

            // What one child asks for, attached to the child.
            var second = Assert.IsType<Label>(layout.Children[1]);
            Assert.Equal(1, FlexLayout.GetGrow(second));

            // A basis is a KIND and a number - `.percent(0.5)` on the other
            // side - so no percent sign crosses and nothing here parses one.
            Assert.Equal(new FlexBasis(0.5f, true), FlexLayout.GetBasis(second));
        },

        ["ScrollView"] = (host, view) =>
        {
            var scroll = Assert.IsType<ScrollView>(view);

            Assert.Equal(ScrollOrientation.Both, scroll.Orientation);
            Assert.Equal("content", Assert.IsType<Label>(scroll.Content).Text);

            // ScrollView's own pair, not the one ItemsView declares - a
            // CarouselView carries that other one.
            Assert.Equal(ScrollBarVisibility.Never, scroll.VerticalScrollBarVisibility);
            Assert.Equal(ScrollBarVisibility.Always, scroll.HorizontalScrollBarVisibility);

            // ScrollY has no event of its own, so it is watched through
            // PropertyChanged - and only because the fixture asked for it.
            ((IScrollViewController)scroll).SetScrolledPosition(0, 120);
            Assert.Equal((1, "120"), host.Dispatched[^1]);

            // A LAID OUT scroller carries no Clip of its own anywhere but
            // Windows. MEASURED 2026-08-13, and it cost a day of a gallery that
            // showed one screenful and then nothing: an Apple scroller scrolls
            // by moving its own BOUNDS, so a clip rectangle written in the
            // view's coordinates stays anchored to the content's origin and
            // masks away everything past the first screen. Android clips by
            // itself and is unharmed either way - only Windows needs one, which
            // is why the code that writes it is behind `#if WINDOWS`.
            ((IView)scroll).Arrange(new Rect(0, 0, 300, 500));
#if WINDOWS
            Assert.NotNull(scroll.Clip);
#else
            Assert.Null(scroll.Clip);
#endif
        },

        ["Map"] = (host, view) =>
        {
            var map = Assert.IsType<Map>(view);

            Assert.Equal(Microsoft.Maui.Maps.MapType.Hybrid, map.MapType);
            Assert.True(map.IsScrollEnabled);
            Assert.True(map.IsZoomEnabled);
            Assert.False(map.IsTrafficEnabled);
            Assert.False(map.IsShowingUser);

            Assert.Equal(2, map.Pins.Count);

            Pin castle = map.Pins[0];
            Assert.Equal("Royal Castle", castle.Label);
            Assert.Equal("Plac Zamkowy 4", castle.Address);
            Assert.Equal(Microsoft.Maui.Controls.Maps.PinType.Place, castle.Type);
            Assert.Equal(new Location(52.2479, 21.0155), castle.Location);
            Assert.Equal("Lazienki Park", map.Pins[1].Label);

            // The platform raises these; the senders are public, which is
            // what lets a headless test say what a tap on the marker and on
            // its callout would.
            castle.SendMarkerClick();
            Assert.Equal((3, (string?)null), host.Dispatched[^1]);

            castle.SendInfoWindowClick();
            Assert.Equal((2, (string?)null), host.Dispatched[^1]);
        },

        ["WebView"] = (host, view) =>
        {
            var web = Assert.IsType<WebView>(view);

            Assert.Equal("https://example.com/docs",
                Assert.IsType<UrlWebViewSource>(web.Source).Url);

            Assert.Equal("StateUI/1.0", web.UserAgent);

            // CanGoBack and CanGoForward have no event of their own, so they
            // are watched through PropertyChanged - and only because the
            // fixture asked. The controller interface is public, which is what
            // lets a headless test say what the platform would after a
            // navigation.
            ((IWebViewController)web).CanGoBack = true;
            Assert.Equal((1, "true"), host.Dispatched[^1]);

            ((IWebViewController)web).CanGoForward = true;
            Assert.Equal((2, "true"), host.Dispatched[^1]);

            // Why the navigation happened is a MEMBER and the url is text, so a
            // url full of commas is one value and arrives whole.
            ((IWebViewController)web).SendNavigating(new WebNavigatingEventArgs(
                WebNavigationEvent.NewPage, web.Source, "https://example.com/a,b"));
            Assert.Equal((4, "enum 3, \"https://example.com/a,b\""), host.Dispatched[^1]);

            ((IWebViewController)web).SendNavigated(new WebNavigatedEventArgs(
                WebNavigationEvent.NewPage, web.Source, "https://example.com/a,b",
                WebNavigationResult.Success));
            Assert.Equal((3, "enum 1, enum 3, \"https://example.com/a,b\""), host.Dispatched[^1]);
        },

        ["TitleBar"] = (host, view) =>
        {
            var bar = Assert.IsType<TitleBar>(view);

            Assert.Equal("StateUI Gallery", bar.Title);
            Assert.Equal("Fundamentals", bar.Subtitle);
            Assert.Equal("stateui_mark.png", Assert.IsType<FileImageSource>(bar.Icon).File);
            Assert.Equal(Colors.White, bar.ForegroundColor);

            Assert.Equal("lead", Assert.IsType<Label>(bar.LeadingContent).Text);
            Assert.Equal("mid", Assert.IsType<Label>(bar.Content).Text);
            Assert.Equal("act", Assert.IsType<Button>(bar.TrailingContent).Text);

            // Every slot view is registered as passthrough, which is what
            // makes the button press rather than drag the window.
            Assert.Equal(3, bar.PassthroughElements.Count);
            Assert.Contains(bar.TrailingContent, bar.PassthroughElements);
        },

        ["RefreshView"] = (host, view) =>
        {
            var refresh = Assert.IsType<RefreshView>(view);

            Assert.True(refresh.IsRefreshing);
            Assert.Equal(Colors.CornflowerBlue, refresh.RefreshColor);
            Assert.True(refresh.IsRefreshEnabled);
            Assert.Equal("Pull me", Assert.IsType<Label>(refresh.Content).Text);

            // The work is over, and the handler clears the flag - which nothing
            // else does. MAUI gives IsRefreshing no event, so it is the property
            // watch that reports it, under the id the binding took.
            refresh.IsRefreshing = false;
            Assert.Equal((1, "false"), host.Dispatched[^1]);

            // And a pull sets it again, which is what MAUI raises Refreshing
            // for - both reports, in that order.
            refresh.IsRefreshing = true;
            Assert.Equal([(1, "true"), (2, (string?)null)], host.Dispatched[^2..]);
        },

        ["SwipeView"] = (host, view) =>
        {
            var swipe = Assert.IsType<SwipeView>(view);

            Assert.Equal(80, swipe.Threshold);

            // The children are read by TYPE: the content is whatever is not a
            // set of items.
            Assert.Equal("Swipe me", Assert.IsType<Label>(swipe.Content).Text);

            Assert.Equal(SwipeMode.Reveal, swipe.LeftItems.Mode);
            Assert.Equal(SwipeBehaviorOnInvoked.Auto, swipe.LeftItems.SwipeBehaviorOnInvoked);

            var favourite = Assert.IsType<SwipeItem>(Assert.Single(swipe.LeftItems));
            Assert.Equal("Favourite", favourite.Text);
            Assert.Equal("tab_list.png",
                Assert.IsType<FileImageSource>(favourite.IconImageSource).File);
            Assert.Equal(Colors.Gold, favourite.BackgroundColor);
            Assert.False(favourite.IsDestructive);
            Assert.True(favourite.IsEnabled);
            Assert.True(favourite.IsVisible);

            Assert.Equal(SwipeMode.Execute, swipe.RightItems.Mode);
            Assert.Equal(SwipeBehaviorOnInvoked.Close, swipe.RightItems.SwipeBehaviorOnInvoked);

            var delete = Assert.IsType<SwipeItem>(Assert.Single(swipe.RightItems));
            Assert.Equal("Delete", delete.Text);
            Assert.Equal(Colors.Firebrick, delete.BackgroundColor);

            // An item is not a view, and it reports the same way one does: the
            // handler id is read off the item when the event fires.
            // The three the SWIPE itself reports, raised through MAUI's own
            // controller. Their ids are the node's handlers in NAME order -
            // swipeChanging(1), swipeEnded(2), swipeStarted(3) - and the
            // items' come after them.
            var controller = (ISwipeViewController)swipe;

            controller.SendSwipeStarted(new SwipeStartedEventArgs(SwipeDirection.Left));
            Assert.Equal((3, "enum 2"), host.Dispatched[^1]);

            controller.SendSwipeChanging(new SwipeChangingEventArgs(SwipeDirection.Left, -40));
            Assert.Equal((1, "enum 2, -40"), host.Dispatched[^1]);

            controller.SendSwipeEnded(new SwipeEndedEventArgs(SwipeDirection.Left, true));
            Assert.Equal((2, "enum 2, true"), host.Dispatched[^1]);

            ((Microsoft.Maui.Controls.ISwipeItem)favourite).OnInvoked();
            Assert.Equal((4, (string?)null), host.Dispatched[^1]);

            ((Microsoft.Maui.Controls.ISwipeItem)delete).OnInvoked();
            Assert.Equal((5, (string?)null), host.Dispatched[^1]);
        },

        // ---- The shapes ----------------------------------------------------
        //
        // What they share is checked once, from the Elements fixture; each of
        // these reads only what that shape has of its own.

        ["Rectangle"] = (_, view) =>
        {
            var rectangle = Assert.IsType<Microsoft.Maui.Controls.Shapes.Rectangle>(view);

            Assert.Equal(8, rectangle.RadiusX);
            Assert.Equal(4, rectangle.RadiusY);
        },

        ["RoundRectangle"] = (_, view) =>
        {
            var rectangle = Assert.IsType<RoundRectangle>(view);

            Assert.Equal(new CornerRadius(16, 16, 0, 0), rectangle.CornerRadius);
        },

        // An Ellipse is its bounds and nothing else, which is why its case in
        // the Swift tests sets nothing: what it can do is the shape tier.
        ["Ellipse"] = (_, view) => Assert.IsType<Ellipse>(view),

        ["Line"] = (_, view) =>
        {
            var line = Assert.IsType<Line>(view);

            Assert.Equal(0, line.X1);
            Assert.Equal(0, line.Y1);
            Assert.Equal(240, line.X2);
            Assert.Equal(40, line.Y2);
        },

        ["Path"] = (_, view) =>
        {
            var path = Assert.IsType<Microsoft.Maui.Controls.Shapes.Path>(view);

            // The data travelled as the string XAML writes and came back a real
            // Geometry: one figure, closed, with the three points of a triangle.
            var geometry = Assert.IsType<PathGeometry>(path.Data);
            PathFigure figure = Assert.Single(geometry.Figures);

            Assert.Equal(new Point(0, 40), figure.StartPoint);
            Assert.True(figure.IsClosed);
            Assert.Equal(2, figure.Segments.Count);

            // The transform arrived as a GROUP holding one of each kind, in
            // the order written - which is the only shape whose reader
            // recurses, so it is the one worth pinning.
            var group = Assert.IsType<TransformGroup>(path.RenderTransform);
            Assert.Equal(5, group.Children.Count);

            var rotate = Assert.IsType<RotateTransform>(group.Children[0]);
            Assert.Equal(15, rotate.Angle);
            Assert.Equal(20, rotate.CenterX);
            Assert.Equal(20, rotate.CenterY);

            var scale = Assert.IsType<ScaleTransform>(group.Children[1]);
            Assert.Equal(1.5, scale.ScaleX);
            Assert.Equal(0.5, scale.ScaleY);

            var skew = Assert.IsType<SkewTransform>(group.Children[2]);
            Assert.Equal(10, skew.AngleX);
            Assert.Equal(5, skew.AngleY);

            var translate = Assert.IsType<TranslateTransform>(group.Children[3]);
            Assert.Equal(6, translate.X);
            Assert.Equal(7, translate.Y);

            var matrix = Assert.IsType<MatrixTransform>(group.Children[4]);
            Assert.Equal(8, matrix.Matrix.OffsetX);
            Assert.Equal(9, matrix.Matrix.OffsetY);
        },

        ["Polygon"] = (_, view) =>
        {
            var polygon = Assert.IsType<Polygon>(view);

            Assert.Equal([new(20, 0), new(40, 40), new(0, 40)], polygon.Points);
            Assert.Equal(FillRule.Nonzero, polygon.FillRule);
        },

        ["Polyline"] = (_, view) =>
        {
            var polyline = Assert.IsType<Polyline>(view);

            Assert.Equal([new(0, 30), new(20, 5), new(40, 25)], polyline.Points);
            Assert.Equal(FillRule.EvenOdd, polyline.FillRule);
        },

        ["GraphicsView"] = (host, view) =>
        {
            var graphics = Assert.IsType<GraphicsView>(view);

            // The drawing arrives whole and in order, one record per canvas
            // call - the command's kind first, then that call's arguments as
            // the things they ARE: numbers as numbers, colours as colours, text
            // as text. So nothing has to be parsed back out of a joined string,
            // and a record carrying a comma is no different from any other.
            SwiftWireValue[] commands = Assert.IsType<SwiftDrawable>(graphics.Drawable).Commands;

            Assert.Equal(
                (int)SwiftDrawable.Kind.FillColor,
                commands[0].Values![0].Member);
            Assert.Equal(
                (int)SwiftDrawable.Kind.RestoreState,
                commands[^1].Values![0].Member);

            // The one record that carries text, read as the last of its values.
            SwiftWireValue drawString = Assert.Single(
                commands,
                record => record.Values![0].Member == (int)SwiftDrawable.Kind.DrawString);

            Assert.Equal("Hello, world", drawString.Values![^1].Text);

            // And it replays: a canvas that counts what it was told to do sees
            // every instruction, with the numbers it was sent.
            var canvas = new CountingCanvas();
            graphics.Drawable.Draw(canvas, new RectF(0, 0, 100, 100));

            Assert.Equal(commands.Length, canvas.Calls.Count);
            Assert.Equal("FillColor=#6495ED", canvas.Calls[0]);
            Assert.Contains("DrawLine(0,0,40,40)", canvas.Calls);
            Assert.Contains("DrawString(Hello, world,10,20,80,16,Center,Bottom)", canvas.Calls);

            // A touch reports where it happened, in the canvas's own
            // coordinates - which is what makes a drawing surface possible.
            // Raised through the interface: GraphicsView declares an EVENT of
            // each of these names as well, and the event is what wins by name.
            var touched = (IGraphicsView)graphics;

            touched.StartInteraction([new PointF(12.5f, 30)]);
            Assert.Equal((3, "[12.5, 30]"), host.Dispatched[^1]);

            touched.DragInteraction([new PointF(13, 31)]);
            Assert.Equal((1, "[13, 31]"), host.Dispatched[^1]);

            touched.EndInteraction([new PointF(14, 32)], false);
            Assert.Equal((2, "[14, 32]"), host.Dispatched[^1]);
        },

        ["CarouselView"] = (host, view) =>
        {
            var carousel = Assert.IsType<CarouselView>(view);

            Assert.False(carousel.Loop);
            Assert.True(carousel.IsSwipeEnabled);
            Assert.False(carousel.IsBounceEnabled);
            Assert.True(carousel.IsScrollAnimated);
            Assert.Equal(new Thickness(40), carousel.PeekAreaInsets);
            Assert.Equal(ScrollBarVisibility.Never, carousel.VerticalScrollBarVisibility);
            Assert.Equal(ScrollBarVisibility.Never, carousel.HorizontalScrollBarVisibility);

            // A carousel's layout is a LINEAR one - MAUI types the property that
            // way, a carousel showing one item at a time.
            var layout = Assert.IsType<LinearItemsLayout>(carousel.ItemsLayout);
            Assert.Equal(ItemsLayoutOrientation.Horizontal, layout.Orientation);

            var items = Assert.IsAssignableFrom<IEnumerable<View>>(carousel.ItemsSource).ToList();
            Assert.Equal(["One", "Two"], items.Cast<Label>().Select(l => l.Text));
            Assert.Equal(1, carousel.Position);

            // The empty view is furniture, not an item: the pages are
            // untouched by it.
            Assert.Equal("Nothing to leaf through", Assert.IsType<Label>(carousel.EmptyView).Text);

            // Swiping to another item reports the POSITION: MAUI's
            // CurrentItemChanged carries the item, which Swift already has.
            carousel.Position = 0;
            Assert.Equal((1, "0"), host.Dispatched[^1]);
        },

        ["IndicatorDots"] = (_, view) =>
        {
            var indicator = Assert.IsType<IndicatorView>(view);

            // The dots are the described views, and MAUI counts them itself.
            var dots = Assert.IsAssignableFrom<IEnumerable<View>>(indicator.ItemsSource).ToList();
            Assert.Equal(3, dots.Count);
            Assert.Equal(1, indicator.Position);

            // The template shows the view it is handed - nothing is built.
            var holder = Assert.IsType<ContentView>(indicator.IndicatorTemplate!.CreateContent());
            holder.BindingContext = dots[1];
            Assert.Same(dots[1], holder.Content);
        },

        ["IndicatorView"] = (_, view) =>
        {
            var indicator = Assert.IsType<IndicatorView>(view);

            Assert.Equal(3, indicator.Count);
            Assert.Equal(1, indicator.Position);
            Assert.Equal(Colors.LightGray, indicator.IndicatorColor);
            Assert.Equal(Colors.CornflowerBlue, indicator.SelectedIndicatorColor);
            Assert.Equal(8, indicator.IndicatorSize);
            Assert.Equal(5, indicator.MaximumVisible);
            Assert.Equal(IndicatorShape.Square, indicator.IndicatorsShape);
            Assert.False(indicator.HideSingle);
        },

        // The protocol tiers, once. A stack for what VisualElement, View,
        // Layout and StackBase declare; the label inside it for text, font,
        // alignment and grid placement.
        ["Elements"] = (host, view) =>
        {
            var stack = Assert.IsType<VerticalStackLayout>(view);

            Assert.True(stack.IsVisible);
            Assert.False(stack.IsEnabled);
            Assert.Equal(0.5, stack.Opacity);
            Assert.Equal(Colors.WhiteSmoke, stack.BackgroundColor);
            Assert.Equal(200, stack.WidthRequest);
            Assert.Equal(100, stack.HeightRequest);
            Assert.Equal(50, stack.MinimumWidthRequest);
            Assert.Equal(25, stack.MinimumHeightRequest);
            Assert.Equal(400, stack.MaximumWidthRequest);
            Assert.Equal(300, stack.MaximumHeightRequest);
            Assert.Equal(15, stack.Rotation);
            Assert.Equal(30, stack.RotationX);
            Assert.Equal(45, stack.RotationY);
            Assert.Equal(1.5, stack.Scale);
            Assert.Equal(2, stack.ScaleX);
            Assert.Equal(3, stack.ScaleY);
            Assert.Equal(10, stack.TranslationX);
            Assert.Equal(20, stack.TranslationY);
            Assert.Equal(0.25, stack.AnchorX);
            Assert.Equal(0.75, stack.AnchorY);
            Assert.Equal(3, stack.ZIndex);
            Assert.False(stack.InputTransparent);
            Assert.Equal(FlowDirection.RightToLeft, stack.FlowDirection);

            // The Layout tier: what a layout does with a child drawn outside
            // it, and whether its own transparency reaches its children.
            Assert.True(stack.IsClippedToBounds);
            Assert.False(stack.CascadeInputTransparent);

            Assert.Equal(new Thickness(4, 8, 4, 8), stack.Margin);
            Assert.Equal(LayoutOptions.Center, stack.HorizontalOptions);
            Assert.Equal(LayoutOptions.Fill, stack.VerticalOptions);
            Assert.Equal(new Thickness(24, 16, 24, 16), stack.Padding);
            Assert.Equal(12, stack.Spacing);

            // The four-value spelling, through MAUI's own converter - left,
            // top, right, bottom.
            Assert.Equal(
                new SafeAreaEdges(
                    SafeAreaRegions.None,
                    SafeAreaRegions.SoftInput,
                    SafeAreaRegions.Container,
                    SafeAreaRegions.All),
                stack.SafeAreaEdges);

            // The Shape tier, which MAUI declares once and all seven shapes
            // inherit - so it is checked here, beside the font tier, rather than
            // in each shape's own case.
            var ellipse = Assert.IsType<Ellipse>(stack.Children[0]);

            var fill = Assert.IsType<RadialGradientBrush>(ellipse.Fill);
            Assert.Equal(new Point(0.3, 0.3), fill.Center);
            Assert.Equal(0.8, fill.Radius);
            Assert.Equal([Colors.White, Colors.SteelBlue], fill.GradientStops.Select(stop => stop.Color));
            Assert.Equal([0f, 1f], fill.GradientStops.Select(stop => stop.Offset));

            var stroke = Assert.IsType<LinearGradientBrush>(ellipse.Stroke);
            Assert.Equal(new Point(0, 0), stroke.StartPoint);
            Assert.Equal(new Point(1, 1), stroke.EndPoint);
            Assert.Equal([Colors.Gold, Colors.Tomato], stroke.GradientStops.Select(stop => stop.Color));

            Assert.Equal(2, ellipse.StrokeThickness);
            Assert.Equal([4d, 2d], ellipse.StrokeDashArray);
            Assert.Equal(1, ellipse.StrokeDashOffset);
            Assert.Equal(PenLineCap.Round, ellipse.StrokeLineCap);
            Assert.Equal(PenLineJoin.Bevel, ellipse.StrokeLineJoin);
            Assert.Equal(4, ellipse.StrokeMiterLimit);
            Assert.Equal(Stretch.UniformToFill, ellipse.Aspect);

            // A brush behind a view, which is what VisualElement.Background is.
            // A themed one is BOUND rather than resolved, so what can be seen
            // here is the colour for the theme in force.
            Assert.Equal(Colors.WhiteSmoke, Assert.IsType<SolidColorBrush>(ellipse.Background).Color);

            var label = Assert.IsType<Label>(stack.Children[1]);

            Assert.Equal("Tiers", label.Text);
            Assert.Equal(Colors.Firebrick, label.TextColor);
            Assert.Equal(1.5, label.CharacterSpacing);
            Assert.Equal(TextTransform.Uppercase, label.TextTransform);
            Assert.Equal(20, label.FontSize);
            Assert.Equal("OpenSansRegular", label.FontFamily);
            Assert.Equal(FontAttributes.Bold, label.FontAttributes);
            Assert.False(label.FontAutoScalingEnabled);
            Assert.Equal(TextAlignment.Center, label.HorizontalTextAlignment);
            Assert.Equal(TextAlignment.End, label.VerticalTextAlignment);
            Assert.Equal(new Thickness(8, 4, 8, 4), label.Padding);

            Assert.Equal(1, Grid.GetRow(label));
            Assert.Equal(2, Grid.GetColumn(label));
            Assert.Equal(3, Grid.GetRowSpan(label));
            Assert.Equal(4, Grid.GetColumnSpan(label));

            // The attached properties of the other two layouts that place a
            // child. A view in neither carries them all the same, which is what
            // an attached property is.
            Assert.Equal(new Rect(0, 0, 120, 40), AbsoluteLayout.GetLayoutBounds(label));
            Assert.Equal(AbsoluteLayoutFlags.SizeProportional, AbsoluteLayout.GetLayoutFlags(label));

            Assert.Equal(2, FlexLayout.GetOrder(label));
            Assert.Equal(1, FlexLayout.GetGrow(label));
            Assert.Equal(0, FlexLayout.GetShrink(label));
            Assert.Equal(FlexAlignSelf.Center, FlexLayout.GetAlignSelf(label));
            Assert.Equal(new FlexBasis(0.5f, true), FlexLayout.GetBasis(label));

            // The InputView tier, which MAUI declares once and Entry, Editor
            // and SearchBar all inherit - checked here, the shape tier's way.
            // The other two controls' reads are pinned by
            // TheInputTierLandsOnEveryInputView in RendererTests.
            var input = Assert.IsType<Entry>(stack.Children[2]);

            Assert.Equal("Name", input.Placeholder);
            Assert.Equal(Colors.LightGray, input.PlaceholderColor);
            Assert.False(input.IsReadOnly);
            Assert.Equal(Keyboard.Email, input.Keyboard);
            Assert.Equal(40, input.MaxLength);
            Assert.False(input.IsSpellCheckEnabled);
            Assert.False(input.IsTextPredictionEnabled);

            // The caret and the selection, both clamped by MAUI to the text
            // the field is holding - "Ada", so 1 and 2 both fit.
            Assert.Equal(1, input.CursorPosition);
            Assert.Equal(2, input.SelectionLength);

            // A gesture is a recognizer on the VIEW, which is what a tappable
            // row is in MAUI - not a button with something around it. All seven
            // of MAUI's, on one view, each configured from its own properties.
            var tap = Assert.Single(stack.GestureRecognizers.OfType<TapGestureRecognizer>());
            Assert.Equal(2, tap.NumberOfTapsRequired);

            // A swipe is the exception to one-per-kind: one recognizer per
            // DIRECTION, because MAUI reports the direction a recognizer was
            // configured for rather than the one the finger went. See
            // StateUIRenderer.ApplySwipe.
            SwipeGestureRecognizer[] swipes = [.. stack.GestureRecognizers.OfType<SwipeGestureRecognizer>()];

            Assert.Equal(
                [SwipeDirection.Left, SwipeDirection.Up],
                swipes.Select(each => each.Direction));

            Assert.All(swipes, each => Assert.Equal(60u, each.Threshold));

            var pan = Assert.Single(stack.GestureRecognizers.OfType<PanGestureRecognizer>());
            Assert.Equal(1, pan.TouchPoints);

            Assert.Single(stack.GestureRecognizers.OfType<PinchGestureRecognizer>());
            Assert.Single(stack.GestureRecognizers.OfType<PointerGestureRecognizer>());

            var drag = Assert.Single(stack.GestureRecognizers.OfType<DragGestureRecognizer>());
            Assert.True(drag.CanDrag);

            var drop = Assert.Single(stack.GestureRecognizers.OfType<DropGestureRecognizer>());
            Assert.True(drop.AllowDrop);

            // Eight recognizers and nothing else: one per kind, however many
            // handlers a kind carries - the pointer one alone answers five -
            // plus the second swipe, this view listening two ways.
            Assert.Equal(8, stack.GestureRecognizers.Count);

            // What each one RUNS is checked in RendererTests, as far as a
            // headless test can: MAUI raises a gesture from the platform
            // handler, so the ids being on the view is what can be seen here.
            // Loaded and Unloaded are in the same boat - MAUI raises them as
            // the view attaches to a window, and there is none.
            Assert.Equal(16, StateUIRenderer.EventsOf(stack)?.Count);
            Assert.NotNull(StateUIRenderer.EventsOf(stack)?[SwiftEvent.Loaded]);
            Assert.NotNull(StateUIRenderer.EventsOf(stack)?[SwiftEvent.Unloaded]);
        },
    };

    [Theory]
    [MemberData(nameof(Controls))]
    public void AControlIsBuiltFromWhatSwiftSent(string name)
    {
        var host = new Host();

        View view = host.ApplyMessage(Fixtures.ReadBytes($"controls/{name}.bin"));

        Checks[name](host, view);
    }

    public static TheoryData<string> Controls
    {
        get
        {
            var data = new TheoryData<string>();

            foreach (string name in Checks.Keys.OrderBy(name => name))
            {
                data.Add(name);
            }

            return data;
        }
    }

    /// <summary>
    /// A control the renderer knows about but nothing checks.
    /// </summary>
    /// <remarks>
    /// The renderer's own methods are the list: one <c>Reconcile{Type}</c> per
    /// control it can build. Adding a control means adding one, so this fails
    /// the moment a control arrives without a fixture and a check - which is the
    /// point, because remembering to add a test is the rule that gets forgotten
    /// in exactly the session where it matters.
    /// </remarks>
    [Fact]
    public void EveryControlTheRendererKnowsHasAFixture()
    {
        foreach (string type in RendererControls())
        {
            Assert.True(File.Exists(Path.Combine(Fixtures.Directory, "controls", $"{type}.bin")),
                $"The renderer builds a {type}, and src/Tests/fixtures/controls/{type}.bin "
                + "is not there. Add a case to ControlTests on the Swift side and run the "
                + "tests with STATEUI_UPDATE_FIXTURES=1.");

            Assert.True(Checks.ContainsKey(type),
                $"There is a fixture for {type} and nothing in ControlTests reads it. "
                + "A message nobody checks proves nothing about the properties it carries.");
        }
    }

    /// <summary>And the same hole from the other end: a fixture nothing reads.</summary>
    [Fact]
    public void EveryFixtureIsChecked()
    {
        foreach (string file in Directory.GetFiles(Path.Combine(Fixtures.Directory, "controls"), "*.bin"))
        {
            string name = Path.GetFileNameWithoutExtension(file);

            Assert.True(Checks.ContainsKey(name),
                $"{name}.bin is written by the Swift tests and read by nothing here.");
        }
    }

    /// <summary>
    /// Every MAUI type the renderer has a method for.
    /// </summary>
    /// <remarks>
    /// <c>ReconcileStack</c> is generic and stands for both stacks;
    /// <c>ReconcileUnknown</c> is the red marker an unrecognized type renders
    /// as, which has a test of its own in RendererTests.
    /// </remarks>
    private static IEnumerable<string> RendererControls()
    {
        IEnumerable<string> names = typeof(StateUIRenderer)
            .GetMethods(BindingFlags.Instance | BindingFlags.Static | BindingFlags.NonPublic)
            .Select(method => method.Name)
            .Where(name => name.StartsWith("Reconcile") && name.Length > "Reconcile".Length)
            .Distinct();

        foreach (string name in names)
        {
            string type = name["Reconcile".Length..];

            // The two dispatch arms that are not controls of the library's
            // own: the marker for a type nobody knows, and the registry for
            // the types an APPLICATION registers - whose fixtures would be
            // the application's to write, not this suite's.
            // StateUIControlsTests covers the registry's promises instead.
            if (type is "Unknown" or "Registered")
            {
                continue;
            }

            if (type == "Stack")
            {
                yield return "VerticalStackLayout";
                yield return "HorizontalStackLayout";
                continue;
            }

            yield return type;
        }
    }
}
