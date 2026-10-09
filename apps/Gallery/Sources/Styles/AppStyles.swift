// The gallery's styles: what a control asked for by name looks like.
//
// A style with no key applies to every control of its type: every button the
// gallery shows wears its violet, every field lets the panel behind it through,
// and a ColorBox naming no colour wears the accent. Every other control keeps
// its platform's own look.
//
// Every colour comes through `Palette`, one name per job.
//
// WHAT IS NOT HERE:
//
//   - No font family. The gallery ships no fonts, and naming a family that is
//     not installed is a way to get a different font on every platform.
//   - Nothing a Style cannot NAME: a shadow is a property of the view that
//     casts it, a page's appearance is what its view says of it, and the bars of
//     NavigationStack and TabView are written on the arrangement itself.

import StateUI

/// The application's styles, as the sheet the differ resolves against.
@MainActor
enum AppStyles {
    /// Built once, as the application is made, and never sent: the differ
    /// merges each style into the controls it applies to, so what crosses is a
    /// control with its values already on it.
    static var sheet: StyleSheet {
        StyleSheet {
            // MARK: Text

            // listing: AppStyles.sample keep
            // A page's own name for itself. Tight tracking, because a large
            // size at the default spacing reads loose.
            Style<Text>("Headline")
                .fontSize(32)
                .fontAttributes(.bold)
                .tracking(-0.5)
                .horizontalAlignment(.center)
                .horizontalTextAlignment(.center)

            // A PAIR, and the second is written from the first: everything
            // about the shape of a quotation is stated once here, and
            // "QuoteLoud" adds the one property that makes it loud. The Styles
            // sample draws both, one under the other.
            Style<Text>("Quote")
                .textColor(Palette.subtle)
                .fontSize(17)
                .fontAttributes(.italic)
                .tracking(0.3)
                .horizontalTextAlignment(.center)

            Style<Text>("QuoteLoud")
                .basedOn("Quote")
                .textColor(Palette.accent)
            // listing: end

            // MARK: Buttons

            // A style for a control the application registers with its host: a
            // style resolves on THIS side by the node type `RatingBar()`
            // makes, and `rating` comes from the protocol the control and its
            // style both wear - so the host receives a control with the values
            // already on it. Keyed, so only the bar that asks wears it; the
            // control is Samples/Interop/RatingBar.swift.
            Style<RatingBar>("FourStars")
                .rating(4)
                .background(Palette.selected)

            // listing: AppStyles.sample keep
            // Every button the gallery shows wears its violet - a style with no
            // key is every button's.
            Style<Button>()
                .textColor(Palette.onAccent)
                .background(Palette.accent)
                .lineWidth(0)
                .shape(.roundedRectangle(10))
                .padding(horizontal: 16, vertical: 11)
                .visualState(.disabled) { $0
                    .textColor(Palette.disabled)
                    .background(Palette.outline)
                }

            // Every ColorBox that names no colour of its own wears the violet.
            Style<ColorBox>()
                .color(Palette.accent)
            // listing: end

            Style<Button>("IconButton")
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

            // On the Web a picker stands on the page's surface, opaque, where
            // every platform's own lets what lies behind through: there it
            // takes the fields' ground.
            #if WEB
            Style<Picker>()
                .background(Palette.field)
            #endif

            // MARK: The menu's rows
            //
            // A menu row is a view like any other, so it takes a style like any
            // other. What it does NOT take is a visual state saying which row
            // you are on: the application holds the section, so the row that is
            // chosen writes its fill ON TOP of this style - see
            // Gallery/Views/MenuRow.swift, and the rule that a control's own
            // value wins over its style, per property.

            Style<HStack>("MenuRow")
                .shape(.roundedRectangle(8))
                .background(.transparent)

            Style<Text>("MenuRowText")
                .verticalAlignment(.center)

            // MARK: Lists

            // A list's rows stand in one rounded group, shaded and edged as a
            // sample's panel is; a row lights up under the pointer.
            Style<VStack>("RowGroup")
                .background(Palette.shade)
                .stroke(Palette.edge)
                .lineWidth(1)
                .shape(.roundedRectangle(12))
                .clipsContent(true)

            Style<ZStack>("ListRow")
                .background(.transparent)
                .visualState(.pointerOver) { $0
                    .background(Palette.hovered)
                }

            // MARK: Shapes

            // The panel a sample stands in lets the window through, darkened a
            // breath and edged by a hairline, as its code does.
            Style<ZStack>("Panel")
                .background(Palette.shade)
                .stroke(Palette.edge)
                .lineWidth(1)
                .shape(.roundedRectangle(12))
                .clipsContent(true)

            // A card within it fills nothing: an outline and its corners mark
            // it, and a card that sets a background of its own - a colour, or
            // a gradient like the home page's - shows it. What a card holds is
            // cut to its corners: a picture reaches them.
            Style<ZStack>("Card")
                .stroke(Palette.outline)
                .lineWidth(1)
                .shape(.roundedRectangle(12))
                .clipsContent(true)
        }
    }
}
