// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

using System.Numerics;
// The other half of each control: the message arrives, the MAUI property is
// set.
//
// `lib/StateUI/Tests/Fixtures/controls/*.bin` are written by the Swift tests, one file
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
using StateUI.Maui.Protocol;
using StateUI.Maui.Rendering;

// MAUI's map control, not the namespace holding MapType - see the renderer,
// which threads the same needle, drawn shapes included.
using Map = Microsoft.Maui.Controls.Maps.Map;
using Polygon = Microsoft.Maui.Controls.Shapes.Polygon;
using Polyline = Microsoft.Maui.Controls.Shapes.Polyline;

// Shapes declares a Path and so does System.IO, and this file uses both - one
// to draw with and one to find a fixture. So neither is aliased and the drawn
// one is written out where it appears.
using Path = System.IO.Path;

namespace StateUI.Maui.Tests;

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

        ["TextField"] = (host, view) =>
        {
            var field = Assert.IsType<Entry>(view);

            Assert.Equal("Ada", field.Text);
            Assert.False(field.IsPassword);
            Assert.Equal(ReturnType.Done, field.ReturnType);
            Assert.Equal(ClearButtonVisibility.WhileEditing, field.ClearButtonVisibility);

            // The reader submitting, as opposed to the renderer assigning.
            ((IEntryController)field).SendCompleted();
            Assert.Equal((1, (string?)null), host.Dispatched[^1]);
        },

        ["TextEditor"] = (host, view) =>
        {
            var editor = Assert.IsType<Editor>(view);

            Assert.Equal("Notes", editor.Text);
            Assert.Equal(EditorAutoSizeOption.TextChanges, editor.AutoSize);

            editor.Text = "typed";
            Assert.Equal((1, "\"typed\""), host.Dispatched[^1]);
        },

        ["Image"] = (_, view) =>
        {
            var image = Assert.IsType<Image>(view);

            Assert.Equal("tab_list.png", Assert.IsType<FileImageSource>(image.Source).File);
            Assert.Equal(Aspect.AspectFill, image.Aspect);
            Assert.True(image.IsAnimationPlaying);
        },

        // A button of only an icon is the same control as a captioned one. Its
        // aspect has no MAUI counterpart - a Button draws its image at the
        // image's own size - which StyleTests names as this host's one gap.
        ["IconButton"] = (host, view) =>
        {
            var button = Assert.IsType<Button>(view);

            Assert.Equal("tab_list.png", Assert.IsType<FileImageSource>(button.ImageSource).File);
            Assert.True(string.IsNullOrEmpty(button.Text));

            ((IButtonController)button).SendClicked();
            Assert.Equal((1, (string?)null), host.Dispatched[^1]);
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
            // deterministic.
            Assert.Equal((3, "2"), host.Dispatched[^1]);

            // Its list opening and shutting, which MAUI reports only for a
            // picker a handler stands behind - so one stands in for the
            // platform's.
            picker.Handler = new StandInHandler();

            picker.IsOpen = true;
            Assert.Equal((2, (string?)null), host.Dispatched[^1]);

            picker.IsOpen = false;
            Assert.Equal((1, (string?)null), host.Dispatched[^1]);
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

            // closed(1), dateChanged(2), opened(3) - opening and shutting
            // reported for a picker a handler stands behind, as on a device.
            picker.Handler = new StandInHandler();

            picker.IsOpen = true;
            Assert.Equal((3, (string?)null), host.Dispatched[^1]);

            picker.IsOpen = false;
            Assert.Equal((1, (string?)null), host.Dispatched[^1]);
        },

        ["TimePicker"] = (host, view) =>
        {
            var picker = Assert.IsType<TimePicker>(view);

            Assert.Equal(new TimeSpan(21, 5, 30), picker.Time);
            Assert.Equal("t", picker.Format);
            Assert.False(picker.IsOpen);

            picker.Time = new TimeSpan(7, 45, 0);
            Assert.Equal((3, "[7, 45, 0]"), host.Dispatched[^1]);

            // closed(1), opened(2), timeChanged(3).
            picker.Handler = new StandInHandler();

            picker.IsOpen = true;
            Assert.Equal((2, (string?)null), host.Dispatched[^1]);

            picker.IsOpen = false;
            Assert.Equal((1, (string?)null), host.Dispatched[^1]);
        },

        ["Switch"] = (host, view) =>
        {
            var toggle = Assert.IsType<Switch>(view);

            Assert.True(toggle.IsToggled);
            Assert.Equal(Colors.Green, toggle.OnColor);

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

        ["SearchField"] = (host, view) =>
        {
            var search = Assert.IsType<SearchBar>(view);

            Assert.Equal("al", search.Text);
            Assert.Equal(ReturnType.Search, search.ReturnType);

            // The one tint, on both of the field's icons.
            Assert.Equal(Colors.Gray, search.CancelButtonColor);
            Assert.Equal(Colors.Gray, search.SearchIconColor);

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

        ["ColorBox"] = (_, view) =>
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
            var grid = Assert.IsAssignableFrom<Grid>(view);

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

        ["VStack"] = (_, view) =>
        {
            var stack = Assert.IsAssignableFrom<VerticalStackLayout>(view);

            Assert.Equal(12, stack.Spacing);
            Assert.Equal("One", Assert.IsType<Label>(stack.Children[0]).Text);
        },

        ["HStack"] = (_, view) =>
        {
            var stack = Assert.IsAssignableFrom<HorizontalStackLayout>(view);

            Assert.Equal(6, stack.Spacing);
            Assert.Equal("One", Assert.IsType<Label>(stack.Children[0]).Text);
        },

        ["AbsoluteLayout"] = (_, view) =>
        {
            var layout = Assert.IsAssignableFrom<AbsoluteLayout>(view);

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

        ["ScrollView"] = (host, view) =>
        {
            var scroll = Assert.IsType<ScrollView>(view);

            Assert.Equal(ScrollOrientation.Both, scroll.Orientation);
            Assert.Equal("content", Assert.IsType<Label>(scroll.Content).Text);

            // ScrollView's own pair.
            Assert.Equal(ScrollBarVisibility.Never, scroll.VerticalScrollBarVisibility);
            Assert.Equal(ScrollBarVisibility.Always, scroll.HorizontalScrollBarVisibility);

            // And its movement, which a handler for its rest and a state
            // carrying its offset each ask for - this one has both.
            Assert.NotNull(scroll.GetValue(StateUIRenderer.ScrollMovementProperty));

            // A LAID OUT scroller carries no Clip of its own anywhere but
            // Windows. MEASURED 2026-08-13 on a gallery that showed one
            // screenful and then nothing: an Apple scroller scrolls
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
            // pinClicked(2), pinDetailsClicked(3), after the map's own
            // mapClicked(1).
            castle.SendMarkerClick();
            Assert.Equal((2, (string?)null), host.Dispatched[^1]);

            castle.SendInfoWindowClick();
            Assert.Equal((3, (string?)null), host.Dispatched[^1]);

            // And a tap on the map itself, where it landed - raised through
            // IMap, which is what the platform's map calls.
            ((Microsoft.Maui.Maps.IMap)map).Clicked(new Location(52.2297, 21.0122));
            Assert.Equal((1, "[52.2297, 21.0122]"), host.Dispatched[^1]);
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

            // And the platform's web process going away, raised through
            // IWebView the way the platform raises it.
            ((IWebView)web).ProcessTerminated(new WebProcessTerminatedEventArgs());
            Assert.Equal((5, (string?)null), host.Dispatched[^1]);
        },

        ["TitleBar"] = (host, view) =>
        {
            var bar = Assert.IsType<StateUITitleBar>(view);

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

            // The flag is a PLAIN state the host carries both ways: the work is
            // over and the handler clears it, which nothing else does - and MAUI
            // gives IsRefreshing no event, so the property itself reports, as
            // one lane under the state's number.
            var crossing = new HandCrossing();
            host.Renderer.Crossing = crossing;

            refresh.IsRefreshing = false;
            Assert.NotEmpty(crossing.Written);
            Assert.Equal(0.0, StateBatch.Lanes(StateBatch.Read(crossing.Written[^1].AsSpan())[0].Bytes)[0]);

            // And a pull sets it again, which is what MAUI raises Refreshing
            // for - the state's lane and the event, in that order.
            refresh.IsRefreshing = true;
            Assert.Equal(1.0, StateBatch.Lanes(StateBatch.Read(crossing.Written[^1].AsSpan())[0].Bytes)[0]);
            Assert.Equal((1, (string?)null), host.Dispatched[^1]);
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
            // One radius or four: MAUI's RoundRectangle, square at nought.
            var rectangle = Assert.IsType<TransformedRoundRectangle>(view);

            Assert.Equal(new CornerRadius(16, 16, 0, 0), rectangle.CornerRadius);
        },

        // An Ellipse is its bounds and nothing else, which is why its case in
        // the Swift tests sets nothing: what it can do is the shape tier.
        ["Ellipse"] = (_, view) => Assert.IsType<TransformedEllipse>(view),

        ["Line"] = (_, view) =>
        {
            var line = Assert.IsType<TransformedLine>(view);

            Assert.Equal(0, line.X1);
            Assert.Equal(0, line.Y1);
            Assert.Equal(240, line.X2);
            Assert.Equal(40, line.Y2);
        },

        ["Path"] = (_, view) =>
        {
            var path = Assert.IsType<TransformedPath>(view);

            // The data travelled as the string XAML writes and came back a real
            // Geometry: one figure, closed, with the three points of a triangle.
            var geometry = Assert.IsType<PathGeometry>(path.Data);
            PathFigure figure = Assert.Single(geometry.Figures);

            Assert.Equal(new Point(0, 40), figure.StartPoint);
            Assert.True(figure.IsClosed);
            Assert.Equal(2, figure.Segments.Count);

            // The transform arrived as the whole MATRIX the fixture stated -
            // a turn, a sizing, a lean and a move, composed on the Swift side
            // into six numbers. They are binary fractions on purpose: the
            // fixture states the matrix rather than computing it, so that no
            // platform's maths library can write a different file.
            Matrix3x2 turned = Assert.NotNull(ShapeTransform.GetGeometryTransform(path));

            Assert.Equal(1.5f, turned.M11);
            Assert.Equal(0.375f, turned.M12);
            Assert.Equal(-0.25f, turned.M21);
            Assert.Equal(0.9375f, turned.M22);
            Assert.Equal(6f, turned.M31);
            Assert.Equal(7f, turned.M32);

            // And the path the platform is handed is the triangle through
            // that matrix: (0, 40) lands where the arithmetic says.
            PathF drawn = ((IShape)path).PathForBounds(new Rect(0, 0, 40, 40));

            Assert.Equal(-0.25f * 40 + 6, drawn[0].X, 0.001f);
            Assert.Equal(0.9375f * 40 + 7, drawn[0].Y, 0.001f);
        },

        ["Polygon"] = (_, view) =>
        {
            var polygon = Assert.IsType<TransformedPolygon>(view);

            Assert.Equal([new(20, 0), new(40, 40), new(0, 40)], polygon.Points);
            Assert.Equal(FillRule.Nonzero, polygon.FillRule);
        },

        ["Polyline"] = (_, view) =>
        {
            var polyline = Assert.IsType<TransformedPolyline>(view);

            Assert.Equal([new(0, 30), new(20, 5), new(40, 25)], polyline.Points);
            Assert.Equal(FillRule.EvenOdd, polyline.FillRule);
        },

        ["Canvas"] = (host, view) =>
        {
            var graphics = Assert.IsType<GraphicsView>(view);

            // The drawing arrives whole and in order, one record per canvas
            // call - the command's kind first, then that call's arguments as
            // the things they ARE: numbers as numbers, colours as colours, text
            // as text. So nothing has to be parsed back out of a joined string,
            // and a record carrying a comma is no different from any other.
            HostValue[] commands = Assert.IsType<ViewDrawing>(graphics.Drawable).Commands;

            Assert.Equal(
                (int)ViewDrawing.Kind.FillColor,
                commands[0].Values![0].Member);
            Assert.Equal(
                (int)ViewDrawing.Kind.RestoreState,
                commands[^1].Values![0].Member);

            // The one record that carries text, read as the last of its values.
            HostValue drawString = Assert.Single(
                commands,
                record => record.Values![0].Member == (int)ViewDrawing.Kind.DrawText);

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
            // dragged(1), pressed(2), released(3): a node numbers its handlers
            // in name order.
            var touched = (IGraphicsView)graphics;

            touched.StartInteraction([new PointF(12.5f, 30)]);
            Assert.Equal((2, "[12.5, 30]"), host.Dispatched[^1]);

            touched.DragInteraction([new PointF(13, 31)]);
            Assert.Equal((1, "[13, 31]"), host.Dispatched[^1]);

            touched.EndInteraction([new PointF(14, 32)], false);
            Assert.Equal((3, "[14, 32]"), host.Dispatched[^1]);
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

        ["PositionIndicator"] = (_, view) =>
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
            var stack = Assert.IsAssignableFrom<VerticalStackLayout>(view);

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
            Assert.Equal(FlowDirection.RightToLeft, stack.FlowDirection);

            // The Layout tier: what a layout does with a child drawn outside
            // it, and input let through its own empty area while its children
            // still answer - MAUI's transparency that does not cascade.
            Assert.True(stack.IsClippedToBounds);
            Assert.True(stack.InputTransparent);
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
            var ellipse = Assert.IsType<TransformedEllipse>(stack.Children[0]);

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

            // A solid brush behind a view is a colour, and lands where a colour
            // does - see Values.SetBackground.
            Assert.Equal(Colors.WhiteSmoke, ellipse.BackgroundColor);

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

            // What the view says about itself. The id is the handle automation
            // finds it by and MAUI keeps it on the Element; the three a screen
            // reader hears are attached properties, so they are read back the
            // way they were written.
            Assert.Equal("tiers", label.AutomationId);
            Assert.Equal("The shared tier", SemanticProperties.GetDescription(label));
            Assert.Equal("Everything every view can be told", SemanticProperties.GetHint(label));
            Assert.Equal(SemanticHeadingLevel.Level2, SemanticProperties.GetHeadingLevel(label));
            Assert.True(AutomationProperties.GetIsInAccessibleTree(label));
            Assert.False(AutomationProperties.GetExcludedWithChildren(label));

            Assert.Equal(1, Grid.GetRow(label));
            Assert.Equal(2, Grid.GetColumn(label));
            Assert.Equal(3, Grid.GetRowSpan(label));
            Assert.Equal(4, Grid.GetColumnSpan(label));

            // The attached properties of the layout that places a child. A
            // view outside one carries them all the same, which is what an
            // attached property is.
            Assert.Equal(new Rect(0, 0, 120, 40), AbsoluteLayout.GetLayoutBounds(label));
            Assert.Equal(AbsoluteLayoutFlags.SizeProportional, AbsoluteLayout.GetLayoutFlags(label));

            // The InputView tier, which MAUI declares once and Entry, Editor
            // and SearchBar all inherit - checked here, the shape tier's way.
            // The other two controls' reads are pinned by
            // TheInputTierLandsOnEveryInputView in RendererTests.
            var input = Assert.IsType<Entry>(stack.Children[2]);

            Assert.Equal("Name", input.Placeholder);
            Assert.Equal(Colors.LightGray, input.PlaceholderColor);
            Assert.False(input.IsReadOnly);
            Assert.Equal(Keyboard.Email, input.Keyboard);
            Assert.Equal(40, input.GetValue(StateUIRenderer.MaxLengthProperty));
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
            Assert.Equal(14, StateUIRenderer.EventsOf(stack)?.Count);
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
                $"The renderer builds a {type}, and lib/StateUI/Tests/Fixtures/controls/{type}.bin "
                + "is not there. Add a case to ControlTests on the Swift side and run the "
                + "tests with STATEUI_UPDATE_FIXTURES=1.");

            Assert.True(Checks.ContainsKey(type),
                $"There is a fixture for {type} and nothing in ControlTests reads it. "
                + "A message nobody checks proves nothing about the properties it carries.");
        }
    }

    /// <summary>
    /// A control MOVED into a registration is still one the renderer knows -
    /// so the guard above goes on holding it to a fixture and a check.
    /// </summary>
    /// <remarks>
    /// The guard reads the renderer's <c>Reconcile…</c> methods, and a family
    /// that moves has none any more. Without the registry beside them the list
    /// would shrink by one control per family moved, and the guard would end up
    /// proving nothing while staying green - which is the failure this whole
    /// suite exists to catch.
    /// </remarks>
    [Fact]
    public void AControlMovedIntoARegistrationIsStillHeldToItsFixture()
    {
        List<string> known = [.. RendererControls()];

        Assert.Contains("ProgressBar", known);
        Assert.Contains("ActivityIndicator", known);
        Assert.Contains("Switch", known);
        Assert.Contains("CheckBox", known);
        Assert.Contains("RadioButton", known);
        Assert.Contains("Slider", known);
        Assert.Contains("Stepper", known);
        Assert.Contains("TextField", known);
        Assert.Contains("TextEditor", known);
        Assert.Contains("SearchField", known);
        Assert.Contains("Rectangle", known);
        Assert.Contains("Ellipse", known);
        Assert.Contains("Line", known);
        Assert.Contains("Path", known);
        Assert.Contains("Polygon", known);
        Assert.Contains("Polyline", known);
        Assert.Contains("Image", known);
        Assert.Contains("ColorBox", known);
        Assert.Contains("Picker", known);
        Assert.Contains("DatePicker", known);
        Assert.Contains("TimePicker", known);
        Assert.Contains("Button", known);
        Assert.Contains("WebView", known);
        Assert.Contains("Canvas", known);

        Assert.DoesNotContain(
            typeof(StateUIRenderer).GetMethods(
                BindingFlags.Instance | BindingFlags.Static | BindingFlags.NonPublic)
                .Select(method => method.Name),
            name => name is "ReconcileProgressBar" or "ReconcileActivityIndicator"
                or "ReconcileSwitch" or "ReconcileCheckBox" or "ReconcileRadioButton"
                or "ReconcileSlider" or "ReconcileStepper" or "ReconcileTextField"
                or "ReconcileTextEditor" or "ReconcileSearchField");
    }

    /// <summary>
    /// A registered control takes the FONT TIER - and the family by its NAME,
    /// which is the half no fixture here carries.
    /// </summary>
    /// <remarks>
    /// The control fixtures describe no font on the controls that wear one, so
    /// a registration that dropped the tier, or read the family as text, would
    /// pass every other check in this file while ten controls quietly lost
    /// their font. Read as text a name answers null - which is exactly how that
    /// failure looks from here: nothing assigned, nothing said.
    /// </remarks>
    [Fact]
    public void ARegisteredControlTakesItsFontAndReadsTheFamilyAsAName()
    {
        var host = new Host();

        var button = Assert.IsType<RadioButton>(host.Apply("""
            {"id":1,"type":"RadioButton","props":{
              "fontSize":19,"fontFamily":{"name":"Charter"},
              "fontAttributes":{"enum":1},"fontAutoScalingEnabled":true}}
            """));

        Assert.Equal(19, button.FontSize);
        Assert.Equal("Charter", button.FontFamily);
        Assert.Equal(FontAttributes.Bold, button.FontAttributes);
        Assert.True(button.FontAutoScalingEnabled);
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
        // A family that has moved into a registration has no Reconcile method
        // any more, and its fixture still has to be checked - so the registry
        // is read beside the methods. Without this the guard would shrink by
        // one control with every family that moves, which is the opposite of
        // what it is for. An application's own registered type is left out: its
        // fixture would be the application's to write, and
        // StateUIControlsTests covers the registry's promises.
        foreach (string registered in StateUIControls.Realizing())
        {
            if (TokenNames<HostNodeType>.Parse(registered) != HostNodeType.None)
            {
                yield return registered;
            }
        }

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
                yield return "VStack";
                yield return "HStack";
                continue;
            }

            yield return type;
        }
    }

    /// <summary>
    /// EVERY SHAPE'S PATH GOES THROUGH THE ONE MATRIX - all six, the
    /// bounds-driven ones included. The twin without a transform is the
    /// reference: the transformed twin's path must be exactly the
    /// reference's points through the matrix, which pins the arithmetic once
    /// for every shape and every platform, since each platform rasterizes
    /// from this same path.
    /// </summary>
    [Fact]
    public void EveryShapesPathGoesThroughTheOneMatrix()
    {
        var matrix = new Matrix3x2(1.2f, 0.3f, -0.4f, 0.9f, 10f, 20f);
        var bounds = new Rect(0, 0, 40, 40);

        Geometry Triangle() => (Geometry)new PathGeometryConverter()
            .ConvertFromInvariantString("M 0,40 L 20,0 L 40,40 Z")!;

        Func<Shape>[] makers =
        [
            () => new TransformedLine { X1 = 4, Y1 = 6, X2 = 30, Y2 = 22 },
            () => new TransformedPolygon
            {
                Points = [new Point(0, 0), new Point(20, 4), new Point(9, 30)],
            },
            () => new TransformedPolyline
            {
                Points = [new Point(2, 34), new Point(14, 8), new Point(38, 20)],
            },
            () => new TransformedPath { Data = Triangle() },
            () => new TransformedRoundRectangle { CornerRadius = new CornerRadius(8, 8, 2, 2) },
            () => new TransformedEllipse(),
        ];

        foreach (Func<Shape> make in makers)
        {
            Shape reference = make();
            Shape turned = make();
            turned.SetValue(ShapeTransform.GeometryTransformProperty, matrix);

            PathF expected = ((IShape)reference).PathForBounds(bounds);
            PathF actual = ((IShape)turned).PathForBounds(bounds);

            Assert.Equal(expected.Count, actual.Count);

            for (int at = 0; at < expected.Count; at++)
            {
                Vector2 point = Vector2.Transform(
                    new Vector2(expected[at].X, expected[at].Y), matrix);

                Assert.Equal(point.X, actual[at].X, 0.001f);
                Assert.Equal(point.Y, actual[at].Y, 0.001f);
            }
        }
    }

}
