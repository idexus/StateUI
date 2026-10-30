// The gallery's styles: what a control asked for by name looks like.
//
// A style with no key applies to every control of its type: every button the
// gallery shows wears its violet, and every field lets the panel behind it
// through. Every other control keeps its platform's own look.
//
// Every color comes through `Palette`, one name per job.
//
// WHAT IS NOT HERE:
//
//   - No font family. The gallery ships no fonts, and naming a family that is
//     not installed is a way to get a different font on every platform.
//   - Nothing a Style cannot NAME: a shadow is a property of the view that
//     casts it, a page's appearance is what its view says of it, and the bars of
//     NavigationStack and TabView are written on the arrangement itself.

import StateUI

extension StyleKey where Target == Text {
    /// A page's own name for itself.
    static let headline = StyleKey("Headline")
    /// A quotation, set apart from the text around it.
    static let quote = StyleKey("Quote")
    /// The same quotation, louder.
    static let quoteLoud = StyleKey("QuoteLoud")
    /// The words of a row of the gallery's menu.
    static let menuRowText = StyleKey("MenuRowText")
}

extension StyleKey where Target == ZStack {
    /// A sample's working area.
    static let card = StyleKey("Card")
    /// A page's panel.
    static let panel = StyleKey("Panel")
    /// A row of a list.
    static let listRow = StyleKey("ListRow")
}

extension StyleKey where Target == VStack {
    /// A group of rows.
    static let rowGroup = StyleKey("RowGroup")
}

extension StyleKey where Target == HStack {
    /// A row of the gallery's menu.
    static let menuRow = StyleKey("MenuRow")
}

extension StyleKey where Target == Button {
    /// A button that is only its icon.
    static let iconButton = StyleKey("IconButton")

}

extension StyleKey where Target == RatingBar {
    /// A rating of four stars.
    static let fourStars = StyleKey("FourStars")
}

/// The application's styles, as the sheet the differ resolves against.
@MainActor
enum AppStyles {
    /// Built once, as the application is made, and never sent: the differ
    /// merges each style into the controls it applies to, so what crosses is a
    /// control with its values already on it.
    static var sheet: StyleSheet { sheet(barsInOwnLook: false) }

    /// The sheet, the bars' buttons in the gallery's own look where
    /// `barsInOwnLook` (Appearance ▸ The bars' buttons).
    static func sheet(barsInOwnLook: Bool) -> StyleSheet {
        StyleSheet {
            // MARK: Text

            // listing: AppStyles.sample keep
            // A page's own name for itself. Tight tracking, because a large
            // size at the default spacing reads loose.
            Style<Text>(.headline)
                .fontSize(32)
                .fontWeight(.bold)
                .tracking(-0.5)
                .horizontalAlignment(.center)
                .horizontalTextAlignment(.center)

            // A PAIR, and the second is written from the first: everything
            // about the shape of a quotation is stated once here, and
            // "QuoteLoud" adds the one property that makes it loud. The Styles
            // sample draws both, one under the other.
            Style<Text>(.quote)
                .textColor(Palette.subtle)
                .fontSize(17)
                .fontAttributes(.italic)
                .tracking(0.3)
                .horizontalTextAlignment(.center)

            Style<Text>(.quoteLoud)
                .basedOn(.quote)
                .textColor(Palette.accent)
            // listing: end

            // MARK: Buttons

            // A style for a control the application registers with its host: a
            // style resolves on THIS side by the node type `RatingBar()`
            // makes, and `rating` comes from the protocol the control and its
            // style both wear - so the host receives a control with the values
            // already on it. Keyed, so only the bar that asks wears it; the
            // control is Samples/Interop/RatingBar.swift.
            Style<RatingBar>(.fourStars)
                .rating(4)
                .background(Palette.selected)

            // listing: AppStyles.sample keep
            // Every button the gallery shows wears its violet - a style with no
            // key is every button's - in its platform's shape: a capsule on
            // Apple's platforms and the Web, rounded everywhere else; and
            // lower on the desktops and the Web, where a pointer presses it.
            // Held down on a phone or a tablet, it grows a breath and lights
            // up, under its own motion; elsewhere it presses as the
            // platform's own button does.
            Style<Button>()
                .textColor(Palette.onAccent)
                .background(Palette.accent)
                .lineWidth(0)
                #if APPKIT || UIKIT || WEB
                .shape(.capsule)
                #else
                .shape(.roundedRectangle(10))
                #endif
                #if APPKIT || WINUI || GTK || WEB
                .padding(horizontal: 16, vertical: 6)
                #elseif UIKIT
                .padding(horizontal: 22, vertical: 10)
                #else
                .padding(horizontal: 16, vertical: 11)
                #endif
                #if UIKIT || ANDROID
                .visualState(.pressed) { $0
                    .scale(1.05)
                    .background(Palette.accentLit)
                }
                #endif
                .visualState(.disabled) { $0
                    .textColor(Palette.disabled)
                    .background(Palette.outline)
                }

            // A button's role chooses a style over the one above: it says
            // only what the role changes. The main action keeps the violet;
            // the way out steps back, and what destroys something is red -
            // each lit in its own color while held down on a phone or a
            // tablet.
            Style<Button>(role: .cancel)
                .textColor(Palette.text)
                .background(Palette.selected)
                #if UIKIT || ANDROID
                .visualState(.pressed) { $0.background(Palette.selectedLit) }
                #endif
            Style<Button>(role: .destructive)
                .textColor(Palette.danger)
                .background(Palette.dangerWash)
                #if UIKIT || ANDROID
                .visualState(.pressed) { $0.background(Palette.dangerWashLit) }
                #endif
            // listing: end

            Style<Button>(.iconButton)
                .opacity(1)
                .stroke(.transparent)
                .lineWidth(0)
                .shape(.roundedRectangle(10))
                .minimumHeight(44)
                .minimumWidth(44)
                .visualState(.disabled) { $0
                    .opacity(0.4)
                }

            // MARK: Fields

            // A field lets the panel behind it through, lit a breath, where
            // the platform's own ground stands dark on it.
            Style<TextField>()
                .background(Palette.field)
            Style<TextEditor>()
                .background(Palette.field)
            Style<SearchField>()
                .background(Palette.field)

            // MARK: The menu's rows
            //
            // A menu row is a view like any other, so it takes a style like any
            // other. What it does NOT take is a visual state saying which row
            // you are on: the application holds the section, so the row that is
            // chosen writes its fill ON TOP of this style - see
            // Gallery/Views/MenuRow.swift, and the rule that a control's own
            // value wins over its style, per property.

            Style<HStack>(.menuRow)
                .shape(.roundedRectangle(8))
                .background(.transparent)
                .visualState(.pressed) { $0
                    .background(Palette.hovered)
                }

            Style<Text>(.menuRowText)
                .verticalAlignment(.center)

            // MARK: Lists

            // A list's rows stand in one rounded group, shaded and edged as a
            // sample's panel is; a row lights up under the pointer, and more
            // while it is pressed - as a button is, out as the press leaves it.
            Style<VStack>(.rowGroup)
                .background(Palette.shade)
                .stroke(Palette.edge)
                .lineWidth(1)
                .shape(.roundedRectangle(12))
                .clipsContent(true)

            Style<ZStack>(.listRow)
                .background(.transparent)
                .visualState(.pressed) { $0
                    .background(Palette.selected)
                }
                .visualState(.pointerOver) { $0
                    .background(Palette.hovered)
                }

            // MARK: Shapes

            // The panel a sample stands in lets the window through, darkened a
            // breath and edged by a hairline, as its code does.
            Style<ZStack>(.panel)
                .background(Palette.shade)
                .stroke(Palette.edge)
                .lineWidth(1)
                .shape(.roundedRectangle(12))
                .clipsContent(true)

            // A card within it fills nothing: an outline and its corners mark
            // it, and a card that sets a background of its own - a color, or
            // a gradient like the home page's - shows it. What a card holds is
            // cut to its corners: a picture reaches them.
            Style<ZStack>(.card)
                .stroke(Palette.outline)
                .lineWidth(1)
                .shape(.roundedRectangle(12))
                .clipsContent(true)

            // MARK: The bars

            if barsInOwnLook {
                barStyles
            }
        }
    }

    /// The bars' buttons in the gallery's own look.
    @StyleBuilder
    private static var barStyles: [AnyStyle] {
        // listing: AppStyles.bars
        // Where the host draws the bars' buttons itself - the Web - each
        // group stands in a light rounded box in a fine outline, its buttons
        // inset from it, a button standing alone in one of its own; its
        // buttons' words semibold, each a shade darker under the pointer and
        // pressed.
        Style<ToolbarGroup>()
            .background(Color(light: Color(hex: 0xF4F6F8), dark: Color(hex: 0x2A2F37)))
            .shape(.roundedRectangle(12))
            .stroke(Color(light: Color(hex: 0xB8BEC6), dark: Color(hex: 0x4A515C)))
            .lineWidth(1)
            .padding(3)
            .spacing(2)
            .visualState(.pointerOver) { $0.stroke(Color(light: Color(hex: 0x8E96A0), dark: Color(hex: 0x6B7380))) }

        Style<ToolbarButton>()
            .fontWeight(.semibold)
            .shape(.roundedRectangle(9))
            .visualState(.pointerOver) { $0.background(Color(light: .black, dark: .white).opacity(0.06)) }
            .visualState(.pressed) { $0.background(Color(light: .black, dark: .white).opacity(0.12)) }

        Style<ToolbarToggle>()
            .fontWeight(.semibold)
            .shape(.roundedRectangle(9))
            .visualState(.pointerOver) { $0.background(Color(light: .black, dark: .white).opacity(0.06)) }
        // listing: end
    }
}
