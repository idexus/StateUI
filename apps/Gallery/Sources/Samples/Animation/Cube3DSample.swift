#if APPKIT || UIKIT || GTK || WINUI || ANDROID || WEB
import StateUI

/// A cube the host draws on the GPU - Metal on AppKit and UIKit, OpenGL 3.3 on GTK, Direct3D 11.1 on WinUI,
/// OpenGL ES 3.0 on Android, WebGL 2 on the Web - with everything about it described from this side.
struct Cube3DSample: SampleContent, ExampleContent {
    // listing: Cube3DSample
    @State private var size = 0.6
    @State private var color = 0
    @State private var spinning = true
    // listing: end

    #if APPKIT
    static let id = "appKitMetal"
    static let title = "A Metal view"
    static let summary = "A cube drawn on the GPU by the host, sized and coloured from StateUI."

    #elseif UIKIT
    static let id = "uiKitMetal"
    static let title = "A Metal view"
    static let summary = "A cube drawn on the GPU by the host, sized and coloured from StateUI."
    #elseif GTK
    static let id = "gtkOpenGL"
    static let title = "An OpenGL view"
    static let summary = "A cube drawn by OpenGL 3.3 in the host, sized and coloured from StateUI."
    #elseif WINUI
    static let id = "winUIDirect3D"
    static let title = "A Direct3D view"
    static let summary = "A cube drawn by Direct3D 11.1 in the host, sized and coloured from StateUI."
    #elseif WEB
    static let id = "webWebGL"
    static let title = "A WebGL view"
    static let summary = "A cube drawn by WebGL 2 in the page, sized and coloured from StateUI."
    #else
    static let id = "androidOpenGLES"
    static let title = "An OpenGL ES view"
    static let summary = "A cube drawn by OpenGL ES 3.0 in the host, sized and coloured from StateUI."
    #endif

    static let codeHeading = "In StateUI"

    static var code: String { Listings.joined("Cube3D", "Cube3DSample") }

    // listing: Cube3DSample
    /// The names the picker offers, in the order `CubeColor` declares them -
    /// so the chosen index IS the vocabulary's member number.
    static let colors = ["Teal", "Amber", "Violet"]
    // listing: end

    #if APPKIT
    static let hostCode = HostCode(in: InteropHost.name, marked: "Cube3DSample.AppKit.swift", "Cube3DSample.AppKit.metal")
    #elseif UIKIT
    static let hostCode = HostCode(in: InteropHost.name, marked: "Cube3DSample.UIKit.swift", "Cube3DSample.UIKit.metal")
    #elseif GTK
    static let hostCode = HostCode(in: InteropHost.name, marked: "Cube3DSample.GTK.swift", "Cube3DSample.GTK.glsl")
    #elseif WINUI
    static let hostCode = HostCode(in: InteropHost.name, marked: "Cube3DSample.WinUI.swift", "Cube3DSample.WinUI.cpp", "Cube3DSample.WinUI.hlsl")
    #elseif WEB
    static let hostCode = HostCode(in: InteropHost.name, marked: "Cube3DSample.Web.swift", "Cube3DSample.Web.javascript")
    #else
    static let hostCode = HostCode(in: InteropHost.name, marked: "Cube3DSample.Android.swift", "Cube3DSample.Android.java", "Cube3DSample.Android.glsl")
    #endif

    // listing: Cube3DSample
    var body: some View {
        VStack {
            DebugInfoLabel()

            Cube3D()
                .size($size)
                .color(CubeColor(rawValue: Int32(color)) ?? .teal)
                .isSpinning($spinning)
                .accessibilityIdentifier("cube3D.cube")
                .accessibilityLabel("Cube")
                .horizontalAlignment(.center)

            Text()
                .text($size.journey.convert { "Edge: \(Int($0.value * 100))% of the view" })
                .fontSize(17)
                .horizontalTextAlignment(.center)

            Slider($size)
                .accessibilityIdentifier("cube3D.size")
                .accessibilityLabel("Edge")
                .minimum(0.2)
                .maximum(1)
                .tint(Palette.accent)

            Picker(Self.colors)
                .accessibilityIdentifier("cube3D.color")
                .accessibilityLabel("Color")
                .selectedIndex($color)
                .placeholder("Color")

            HStack {
                Text("Spin")
                    .fontSize(14)
                    .verticalAlignment(.center)

                Switch($spinning)
                    .accessibilityIdentifier("cube3D.spin")
                    .accessibilityLabel("Spin")
                    .tint(Palette.accent)
            }
            .spacing(12)
            .horizontalAlignment(.center)
        }
        .spacing(12)
    }
    // listing: end

    #if APPKIT
    private static let drawnBy = "The cube is an `MTKView` the gallery registers with "
        + "`StateUIControls.add`, exactly as it registers a view that draws with a layer. A "
        + "view that draws on the GPU is still an `NSView`, so the registration has nothing "
        + "extra to say."
    private static let stopsWith = "The loop also stops with the window, so nothing is "
        + "left turning behind a page you have left."
    #elseif UIKIT
    private static let drawnBy = "The cube is an `MTKView` the gallery registers with "
        + "`StateUIControls.add`, exactly as it registers a view that draws with a layer. A "
        + "view that draws on the GPU is still a `UIView`, so the registration has nothing "
        + "extra to say."
    private static let stopsWith = "The loop also stops with the window, so nothing is "
        + "left turning behind a page you have left."
    #elseif GTK
    private static let drawnBy = "The cube is a `GtkGLArea` drawing with OpenGL 3.3 core, "
        + "held by a `GTKControl` the gallery registers with `StateUIControls.add` - a "
        + "widget like any other, so the registration has nothing extra to say."
    private static let stopsWith = "GTK ticks only a widget on screen, so nothing is "
        + "left turning behind a page you have left."
    #elseif WINUI
    private static let drawnBy = "The cube is a `SwapChainPanel` drawing with Direct3D 11.1, "
        + "made by the gallery's own C++/WinRT relay and held by a `WinUIControl` the gallery "
        + "registers with `StateUIControls.add` - an element like any other, so the "
        + "registration has nothing extra to say."
    private static let stopsWith = "The cube follows WinUI's frames only while it stands on "
        + "screen, so nothing is left turning behind a page you have left."
    #elseif WEB
    private static let drawnBy = "The cube is a custom element of the gallery's own JavaScript, `<gallery-cube3d>`, "
        + "drawing with WebGL 2 and held by a `WebControl` the gallery registers with `StateUIControls.add` - an "
        + "element like any other, so the registration has nothing extra to say."
    private static let stopsWith = "The cube asks for the browser's frames only while it is in view, so nothing is "
        + "left turning behind a page you have left."
    #else
    private static let drawnBy = "The cube is a `TextureView` of the gallery's own Java, drawn into with OpenGL ES "
        + "3.0 from Swift and held by an `AndroidControl` the gallery registers with `StateUIControls.add` - a view "
        + "like any other, so the registration has nothing extra to say."
    private static let stopsWith = "The cube asks for the display's frames only while it stands in a window, so "
        + "nothing is left turning behind a page you have left."
    #endif

    var notes: (any View)? {
        VStack {
            Text(Self.drawnBy)
                .fontSize(12)
                .textColor(Palette.subtle)

            Text("The edge is HANDED OVER: `.size($size)` gives the host the state "
                + "itself, and the caption is a conversion of that same journey. Nothing "
                + "here reads `size`, so a drag builds this example not once - the cube "
                + "grows and the number counts up on the host's own frames. The spin is "
                + "handed over too, a flag the host sets as it stands, so a flip builds "
                + "nothing either; the colour is a plain value, described again on the "
                + "one build a pick costs.")
                .fontSize(12)
                .textColor(Palette.subtle)

            Text("Nothing about the drawing crosses. What travels is a number, a "
                + "vocabulary member and a flag; the corners, the matrix and the frames "
                + "are the host's own, and this side never learns they exist.")
                .fontSize(12)
                .textColor(Palette.subtle)

            Text("Turning the spin off stops the host's render loop rather than hiding "
                + "it: the cube holds the angle it had, and a changed size or colour "
                + "still draws the one frame it needs. " + Self.stopsWith)
                .fontSize(12)
                .textColor(Palette.subtle)

            Text("One `Cube3D` on this side, drawn by each host in its own way. An "
                + "element only some hosts can honestly realize is declared only for "
                + "them - this one stands under the same condition as its sample, so no "
                + "other host is held to a promise it cannot keep.")
                .fontSize(12)
                .textColor(Palette.subtle)
        }
        .spacing(12)
    }
}
#endif
