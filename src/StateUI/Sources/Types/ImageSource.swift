// Where a picture comes from, as MAUI names it.
//
// It is a type rather than a String for one reason, and it is the same reason
// Color is not a String: a picture may be TWO pictures, one per theme. Black
// artwork that reads well on a white page disappears on a dark one, and MAUI's
// answer is `{AppThemeBinding Light=… Dark=…}` on the source. Here the half in
// force is chosen as the value is written onto a node, exactly as a Color's is
// - so ONE name crosses, the far side binds nothing, and the view that wrote
// it is rebuilt when the system flips. See Types/Color.swift.
//
// Not a tint: MAUI's only one is `<MauiImage TintColor="…" />`, which recolours
// the file as it is built and so cannot follow anything. Two files it is.

/// A picture, by file name. MAUI: ImageSource.
///
///     Image("tab_list.png")
///     ToolbarItem("Media").iconImageSource("tab_list.png")
///     Image(light: "tab_list.png", dark: "tab_list_dark.png")
///
/// A file in the application's `Resources/Images`, by the name MAUI gives it
/// once built - so `tab_list.svg` is asked for as `tab_list.png`, exactly as
/// it would be in XAML. A plain string is one of these, so only artwork that
/// differs between the themes needs the type written out.
public struct ImageSource: Equatable, Sendable, ExpressibleByStringLiteral {
    /// The file, by the name MAUI gives it once built.
    public let file: String

    /// The file to use when the system is in dark mode, when there is one.
    public let dark: String?

    /// One picture, by the name MAUI gives it once built.
    public init(_ file: String) {
        self.file = file
        self.dark = nil
    }

    /// Two files, one per theme.
    /// MAUI: `{AppThemeBinding Light=…, Dark=…}` on the source - here the half
    /// in force is picked as the value is written.
    ///
    ///     ImageSource(light: "logo.png", dark: "logo_dark.png")
    ///
    /// For artwork that would vanish into one of the two backgrounds. A
    /// picture that reads on both is one file and a plain string.
    public init(light: String, dark: String) {
        self.file = light
        self.dark = dark
    }

    /// What lets every one-picture call site stay a plain string:
    /// `Image("tab_list.png")`, `.iconImageSource("tab_list.png")`.
    public init(stringLiteral value: String) {
        self.init(value)
    }

    /// Whether it names anything at all - what a view asks before drawing one.
    public var isEmpty: Bool { file.isEmpty }

    /// The name in force - the dark one when the system is dark and this
    /// picture was drawn twice.
    ///
    /// Reading the theme here is what records the dependency, the way a
    /// Color's does: the read lands against whichever view is being built, so
    /// a theme change rebuilds that view and leaves the rest alone.
    var resolved: String {
        guard let dark = dark else { return file }

        return StandardEnvironment.app.requestedTheme == .dark ? dark : file
    }

    /// The one name that crosses - and it crosses as TEXT, not as a `.name`
    /// riding the session's dictionary, which is what a style key or a font
    /// family does.
    ///
    /// The difference is whether the vocabulary is BOUNDED. An application has
    /// a handful of styles and a handful of fonts, so numbering them costs one
    /// dictionary entry each and pays for itself on every row. A picture may
    /// be a url built per item - an avatar, a thumbnail - and the dictionary
    /// is the session's, never emptied: numbering those would grow it without
    /// end for names used once. So this stays text, and the rule that keeps
    /// the wire honest is read as "a name is text when there can be no end of
    /// them".
    var propValue: PropValue {
        .string(resolved)
    }

    /// Read back off a node, for the templates that are handed an item and have
    /// to draw it. The theme was resolved on the way in, so what comes back is
    /// the picture being shown rather than the pair it was written as.
    init(_ value: PropValue?) {
        self.init(value?.string ?? "")
    }
}
