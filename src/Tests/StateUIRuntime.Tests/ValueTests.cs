// The one place where a wire value becomes a MAUI value.
//
// The shapes are the wire's own, not MAUI's: a closed vocabulary is a number, a
// value made of parts is its parts, and the one value carrying a spelling is
// text someone wrote. So the notation says which - Host.Member(…) for a member
// of a vocabulary, a nested list for a value with parts - and every assertion
// here is the same question asked of a different shape: does it become the
// right MAUI value on arrival.
using Microsoft.Maui.Controls.Shapes;
using StateUI.Runtime.Protocol;
using StateUI.Runtime.Rendering;

namespace StateUI.Runtime.Tests;

public class ValueTests
{
    private static View Render(string json) => new Host().Apply(json);

    [Fact]
    public void AThicknessArrivesAsLeftTopRightBottom()
    {
        var label = (Label)Render("""{"id":"a","type":"Label","props":{"padding":[1,2,3,4]}}""");

        Assert.Equal(new Thickness(1, 2, 3, 4), label.Padding);
    }

    [Fact]
    public void TwoNumbersMeanHorizontalAndVertical()
    {
        var label = (Label)Render("""{"id":"a","type":"Label","props":{"padding":[20,10]}}""");

        Assert.Equal(new Thickness(20, 10, 20, 10), label.Padding);
    }

    /// <summary>
    /// A closed vocabulary crosses as a NUMBER and lands on the member of MAUI's
    /// own enum that number stands for.
    /// </summary>
    /// <remarks>
    /// <para>
    /// The TRANSLATION is what this pins: our number goes in, written through
    /// the mirror that declares it, and MAUI's member is written out opposite,
    /// so an arm wired to the wrong member fails here. That the two numberings
    /// agree across the boundary at all is <c>WireEnumTests</c>'s question,
    /// member for member and both ways.
    /// </para>
    /// <para>
    /// A bit set is one number as well, and it is the one shape the host cannot
    /// switch on: there is a number per COMBINATION rather than per member, so
    /// it is read a bit at a time.
    /// </para>
    /// </remarks>
    [Fact]
    public void AClosedVocabularyCrossesAsOurNumberAndLandsOnMauisMember()
    {
        var label = (Label)Render($$$"""
            {"id":"a","type":"Label","props":{
              "horizontalOptions":{{{Host.Member(SwiftLayoutOptions.Center)}}},
              "lineBreakMode":{{{Host.Member(SwiftLineBreakMode.TailTruncation)}}},
              "fontAttributes":{{{Host.Member(SwiftFontAttributes.Bold | SwiftFontAttributes.Italic)}}},
              "horizontalTextAlignment":{{{Host.Member(SwiftTextAlignment.End)}}}
            }}
            """);

        Assert.Equal(LayoutOptions.Center, label.HorizontalOptions);
        Assert.Equal(LineBreakMode.TailTruncation, label.LineBreakMode);
        Assert.Equal(FontAttributes.Bold | FontAttributes.Italic, label.FontAttributes);
        Assert.Equal(TextAlignment.End, label.HorizontalTextAlignment);
    }

    /// <summary>
    /// A number no member of the vocabulary declares is IGNORED rather than
    /// guessed at, so the property keeps whatever it already had.
    /// </summary>
    /// <remarks>
    /// Every accessor answers null on its default arm and the renderer assigns
    /// only what it was actually given, which is the whole of how this wire
    /// degrades. It matters most for a number: a number is what a newer Swift
    /// side sends for a member this host has never heard of.
    /// </remarks>
    [Fact]
    public void ANumberNoMemberDeclaresIsIgnoredRatherThanGuessed()
    {
        var label = (Label)Render("""
            {"id":"a","type":"Label","props":{"horizontalOptions":{"enum":97}}}
            """);

        Assert.Equal(LayoutOptions.Fill, label.HorizontalOptions);
    }

    /// <summary>
    /// A day is three numbers - year, month, day - and the calendar that turns
    /// them into a date is on this side.
    /// </summary>
    /// <remarks>
    /// The library never imports Foundation, so the Swift side has neither a
    /// calendar nor a formatter to write a date with; the three fields a
    /// <c>CalendarDate</c> is are all it can say. A trio naming no real day - a
    /// 31st of February, a month 13 - reads as nothing at all.
    /// </remarks>
    [Fact]
    public void ADateTravelsAsYearMonthDay()
    {
        var picker = (DatePicker)Render("""
            {"id":"d","type":"DatePicker","props":{
              "minimumDate":[2020,1,1],"maximumDate":[2030,12,31],"date":[2026,8,2]}}
            """);

        Assert.Equal(new DateTime(2026, 8, 2), picker.Date);
        Assert.Equal(new DateTime(2020, 1, 1), picker.MinimumDate);
    }

    /// <summary>
    /// A value made of parts travels AS its parts: a grid's lengths and a
    /// border's outline, each a kind and whatever that kind takes.
    /// </summary>
    /// <remarks>
    /// <para>
    /// A definition list is <c>[kind, number]</c> per row, and the LIST says how
    /// many rows there are; a stroke shape is <c>[kind, radius]</c>. Both are
    /// read by <c>SwiftValues</c> rather than by a MAUI type converter, there
    /// being no text on the wire to hand one.
    /// </para>
    /// <para>
    /// Auto carries 1 rather than 0, which is what MAUI's own
    /// <c>GridLength.Auto</c> carries: a GridLength compares by both fields, so
    /// a 0 there would build a length equal to no static MAUI declares.
    /// </para>
    /// </remarks>
    [Fact]
    public void AValueMadeOfPartsTravelsAsItsParts()
    {
        var grid = (Grid)Render($$$"""
            {"id":"g","type":"Grid","props":{"rowDefinitions":[
              [{{{Host.Member(SwiftGridLengthKind.Auto)}}},1],
              [{{{Host.Member(SwiftGridLengthKind.Star)}}},1],
              [{{{Host.Member(SwiftGridLengthKind.Star)}}},2],
              [{{{Host.Member(SwiftGridLengthKind.Absolute)}}},100]
            ]}}
            """);

        Assert.Equal(GridUnitType.Auto, grid.RowDefinitions[0].Height.GridUnitType);
        Assert.Equal(1, grid.RowDefinitions[1].Height.Value);
        Assert.Equal(2, grid.RowDefinitions[2].Height.Value);
        Assert.Equal(100, grid.RowDefinitions[3].Height.Value);

        var border = (Border)Render($$$"""
            {"id":"b","type":"Border","props":{
              "strokeShape":[{{{Host.Member(SwiftStrokeShapeKind.RoundRectangle)}}},12],
              "stroke":"#FF0000"
            }}
            """);

        Assert.Equal(12, Assert.IsType<RoundRectangle>(border.StrokeShape).CornerRadius.TopLeft);
        Assert.Equal(Colors.Red, Assert.IsType<SolidColorBrush>(border.Stroke).Color);
    }

    [Fact]
    public void AListOfStringsIsWhatAPickerChoosesFrom()
    {
        var picker = (Picker)Render("""
            {"id":"p","type":"Picker","props":{"itemsSource":["Small","Large"],"selectedIndex":1}}
            """);

        Assert.Equal(2, picker.ItemsSource.Count);
        Assert.Equal(1, picker.SelectedIndex);
        Assert.Equal("Large", picker.SelectedItem);
    }

    [Fact]
    public void AnIdentityKeepsItsKindSoTwelveAndTwelveAreNotConfused()
    {
        var host = new Host();

        // A renderer-assigned 12 and an author's "12" are different elements.
        var number = host.Apply("""{"id":12,"type":"Label","props":{"text":"assigned"}}""");
        Assert.Equal("12", Tree.Identity(number));

        var text = host.Apply("""{"id":"12","type":"Label","props":{"text":"written"}}""");
        Assert.NotSame(number, text);
        // The author's namespace keeps its quotes, so the two can never meet.
        Assert.Equal("\"12\"", Tree.Identity(text));
    }
    // ---- The scroller's grid ----------------------------------------------

    [Theory]
    // A grid from nothing: the halfway mark between two points is where the
    // answer changes, and it changes the same way going back.
    [InlineData(0, 100, 0, 0)]
    [InlineData(49, 100, 0, 0)]
    [InlineData(51, 100, 0, 100)]
    [InlineData(149, 100, 0, 100)]
    [InlineData(151, 100, 0, 200)]
    // A grid that starts somewhere: 10, 60, 110 … with the marks at 35 and 85,
    // which is the layout a strip with a pad before its first card has.
    [InlineData(34, 50, 10, 10)]
    [InlineData(36, 50, 10, 60)]
    [InlineData(86, 50, 10, 110)]
    // No grid at all leaves the offset exactly where it was.
    [InlineData(137, 0, 0, 137)]
    public void AnOffsetRoundsToTheNearestPointOfTheGrid(
        double offset, double interval, double from, double expected)
    {
        Assert.Equal(expected, StateUIRenderer.SnapPoint(offset, interval, from), 6);
    }
}