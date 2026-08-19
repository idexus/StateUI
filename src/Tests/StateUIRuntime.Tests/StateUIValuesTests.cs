// The MAUI-typed readers an application reaches for inside a registered
// control's `apply` - a colour, a thickness, a picture, a brush, a day, a time.
// Driven through the real path: a control registered under a node type, a
// message applied, and what the control ended up holding.

using StateUI.Runtime.Protocol;
using StateUI.Runtime.Rendering;

namespace StateUI.Runtime.Tests;

public class StateUIValuesTests
{
    /// <summary>
    /// A stand-in an application could have written, holding one field per
    /// reader - headless-safe, like every control these tests build.
    /// </summary>
    private sealed class Gauge : Label
    {
        public int? Steps { get; set; }

        public Color? Tint { get; set; }

        public Thickness? Inset { get; set; }

        public Rect? Face { get; set; }

        public ImageSource? Needle { get; set; }

        public Brush? Fill { get; set; }

        public DateTime? Day { get; set; }

        public TimeSpan? Moment { get; set; }
    }

    /// <summary>
    /// Every reader answers the MAUI value its property stands for, under the
    /// name the application declared it by.
    /// </summary>
    [Fact]
    public void AnApplicationReadsItsOwnPropertiesAsTheMauiValuesTheyStandFor()
    {
        StateUIControls.Add("Test.Gauge",
            create: _ => new Gauge(),
            apply: (view, node) =>
            {
                var gauge = (Gauge)view;

                gauge.Steps = node.GetInt("steps");
                gauge.Tint = node.GetColor("tint");
                gauge.Inset = node.GetThickness("inset");
                gauge.Face = node.GetRect("face");
                gauge.Needle = node.GetImageSource("needle");
                gauge.Fill = node.GetBrush("fill");
                gauge.Day = node.GetDate("day");
                gauge.Moment = node.GetTime("moment");
            });

        var host = new Host();
        var gauge = Assert.IsType<Gauge>(host.Apply(
            $$$"""
            {"id":1,"type":"Test.Gauge","props":{
                "steps":2.7,
                "tint":"#E5474D",
                "inset":[1,2,3,4],
                "face":[0,0,120,40],
                "needle":"needle.png",
                "fill":[{{{Host.Member(SwiftBrushKind.SolidColor)}}},"#0000FF"],
                "day":[2026,8,15],
                "moment":[9,30,15]}}
            """));

        // Truncated rather than rounded, which is what the double a number
        // crossed as becomes when MAUI wants a whole one.
        Assert.Equal(2, gauge.Steps);

        Assert.Equal(new Color(0xE5 / 255f, 0x47 / 255f, 0x4D / 255f, 1f), gauge.Tint);
        Assert.Equal(new Thickness(1, 2, 3, 4), gauge.Inset);
        Assert.Equal(new Rect(0, 0, 120, 40), gauge.Face);
        Assert.Equal("needle.png", Assert.IsType<FileImageSource>(gauge.Needle).File);
        Assert.Equal(new Color(0f, 0f, 1f, 1f), Assert.IsType<SolidColorBrush>(gauge.Fill).Color);
        Assert.Equal(new DateTime(2026, 8, 15), gauge.Day);
        Assert.Equal(new TimeSpan(9, 30, 15), gauge.Moment);
    }

    /// <summary>
    /// A property that is absent, or arrived in another shape, answers null -
    /// which is what lets a control ask for everything it understands and
    /// assign only what came.
    /// </summary>
    [Fact]
    public void AReaderAnswersNullForAPropertyThatIsAbsentOrOfAnotherShape()
    {
        StateUIControls.Add("Test.Dial",
            create: _ => new Gauge(),
            apply: (view, node) =>
            {
                var gauge = (Gauge)view;

                gauge.Tint = node.GetColor("tint");
                gauge.Inset = node.GetThickness("inset");
                gauge.Day = node.GetDate("day");
                gauge.Steps = node.GetInt("steps");
            });

        var host = new Host();

        // `tint` is text, `day` names no real one, `inset` is a run of three
        // and no Thickness has ever been three, and `steps` is not there at all.
        var gauge = Assert.IsType<Gauge>(host.Apply(
            """
            {"id":1,"type":"Test.Dial","props":{
                "tint":"crimson",
                "inset":[1,2,3],
                "day":[2026,2,31]}}
            """));

        Assert.Null(gauge.Tint);
        Assert.Null(gauge.Inset);
        Assert.Null(gauge.Day);
        Assert.Null(gauge.Steps);
    }

    /// <summary>
    /// A reader finds a property whose name the LIBRARY also uses - the bag it
    /// arrived in is the reader's business, not the application's.
    /// </summary>
    /// <remarks>
    /// An application names its own properties freely, and some of those names
    /// are the library's too: <c>padding</c>, <c>text</c>, <c>value</c>. Such a
    /// name resolves to a member on the way in and lands in the library's bag,
    /// where a reader looking only under the spelling would find nothing. See
    /// <see cref="SwiftKey"/>.
    /// </remarks>
    [Fact]
    public void AReaderFindsAPropertyWhoseNameTheLibraryAlsoUses()
    {
        StateUIControls.Add("Test.Plate",
            create: _ => new Gauge(),
            apply: (view, node) => ((Gauge)view).Inset = node.GetThickness("padding"));

        var host = new Host();
        var plate = Assert.IsType<Gauge>(host.Apply(
            """{"id":1,"type":"Test.Plate","props":{"padding":[4,8,4,8]}}"""));

        Assert.Equal(new Thickness(4, 8, 4, 8), plate.Inset);
    }
}
