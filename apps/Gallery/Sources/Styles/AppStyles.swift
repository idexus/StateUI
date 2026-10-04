// The gallery's styles: what every control of a type looks like.
//
// A style with no key applies to every control of its type, so most of the
// gallery's appearance is decided here rather than in the views, in the values
// of the StateUI ramp.
//
// Every colour comes through `Palette`, one name per job. That is what makes the
// look changeable in one file, and what makes it coherent: nothing here picks a
// colour, it says what the thing is FOR and the palette answers.
//
// WHAT IS NOT HERE:
//
//   - No font family. The gallery ships no fonts, and naming a family that is
//     not installed is a way to get a different font on every platform.
//   - Nothing a Style cannot NAME: a shadow is a property of the view that
//     casts it, a page's appearance is what its view says of it, and the bars of
//     NavigationStack and TabView are written on the arrangement itself -
//     see MainPage.body.

import StateUI

/// The application's styles, as the sheet the differ resolves against.
enum AppStyles {
    /// Built once, as the application is made, and never sent: the differ
    /// merges each style into the controls it applies to, so what crosses is a
    /// control with its values already on it. The formFactor comes from the
    /// application's `@Environment` - one style reads it: the SearchField's
    /// touch floor, which every formFactor but the desktop keeps.
    static func sheet(on formFactor: FormFactor) -> StyleSheet {
        StyleSheet {
            // MARK: Text

            Style<Text>()
                .textColor(Palette.text)
                .background(.transparent)
                .fontSize(15)                

            // A page's own name for itself. Tight tracking, because a large
            // size at the default spacing reads loose.
            Style<Text>("Headline")
                .textColor(Palette.text)
                .fontSize(32)
                .fontAttributes(.bold)
                .tracking(-0.5)
                .horizontalAlignment(.center)
                .horizontalTextAlignment(.center)

            // A PAIR, and the second is written from the first: everything
            // about the shape of a quotation is stated once here, and
            // "QuoteLoud" adds the one property that makes it loud. The Styles
            // sample draws both, side by side.
            Style<Text>("Quote")
                .textColor(Palette.subtle)
                .fontSize(17)
                .fontAttributes(.italic)
                .tracking(0.3)
                .horizontalTextAlignment(.center)

            Style<Text>("QuoteLoud")
                .basedOn("Quote")
                .textColor(Palette.accent)

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

            Style<Button>()
                .textColor(Palette.onAccent)
                .background(Palette.accent)
                .fontSize(14)
                .fontAttributes(.bold)
                .lineWidth(0)
                .shape(.roundedRectangle(10))                
                .padding(horizontal: 16, vertical: 11)
                .minimumHeight(44)
                .minimumWidth(44)
                .visualState(.disabled) { $0
                    .textColor(Palette.disabled)
                    .background(Palette.outline)
                }

            // A button that lives in a LIST ROW, where the touch floor is
            // not merely unnecessary but harmful. A recycled cell measures a
            // minimum size INCONSISTENTLY: with one in the row, the cell
            // takes that height on some measure passes and the content's own
            // on others, so the rows draw at two heights and gaps open
            // between them - the platform's cell measurement rather than
            // anything this library does. Dropping the floor draws every row
            // the same height, and a button in a list row is a target beside
            // its text rather than a thumb target of its own.
            //
            // A keyed style REPLACES the implicit one, so this states
            // everything it needs.
            Style<Button>("RowChip")
                .textColor(Palette.onAccent)
                .background(Palette.accent)
                .fontSize(13)
                .fontAttributes(.bold)
                .lineWidth(0)
                .shape(.roundedRectangle(10))
                .padding(horizontal: 14, vertical: 4)
                .minimumHeight(0)
                .minimumWidth(0)
                .visualState(.disabled) { $0
                    .textColor(Palette.disabled)
                    .background(Palette.outline)
                }

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
            //
            // A field takes the palette's own ground, so it stands in the page's
            // violet rather than the platform's grey - and stands at all on
            // Android, whose field a clear background leaves as bare words.
            let field = Palette.field

            Style<TextField>()
                .textColor(Palette.text)
                .background(field)
                .placeholderColor(Palette.subtle)
                .fontSize(15)
                .minimumHeight(44)
                .minimumWidth(44)
                .visualState(.disabled) { $0
                    .textColor(Palette.disabled)
                }

            Style<TextEditor>()
                .textColor(Palette.text)
                .background(field)
                .placeholderColor(Palette.subtle)
                .fontSize(15)
                .minimumHeight(44)
                .minimumWidth(44)
                .visualState(.disabled) { $0
                    .textColor(Palette.disabled)
                }

            Style<Picker>()
                .textColor(Palette.text)
                .background(.transparent)
                .fontSize(15)
                .minimumHeight(44)
                .minimumWidth(44)
                .visualState(.disabled) { $0
                    .textColor(Palette.disabled)
                }

            Style<DatePicker>()
                .textColor(Palette.text)
                .background(.transparent)
                .fontSize(15)
                .minimumHeight(44)
                .minimumWidth(44)
                .visualState(.disabled) { $0
                    .textColor(Palette.disabled)
                }

            Style<TimePicker>()
                .textColor(Palette.text)
                .background(.transparent)
                .fontSize(15)
                .minimumHeight(44)
                .minimumWidth(44)
                .visualState(.disabled) { $0
                    .textColor(Palette.disabled)
                }

            // NO background: a search field keeps the platform's own
            // look on a coloured surface, and that look is the host's. The
            // 44-point floor is a TOUCH screen's: on a desktop it shows as a
            // dead band under the field - a mouse is not a thumb. A
            // desktop's field keeps its platform's size of
            // words too: a larger one grows a toolbar's search field past the
            // bar's own controls.
            let search = Style<SearchField>()
                .textColor(Palette.text)
                .placeholderColor(Palette.subtle)
                .tint(Palette.accent)
                .minimumHeight(formFactor == .desktop ? 0 : 44)
                .minimumWidth(44)
                .visualState(.disabled) { $0
                    .textColor(Palette.disabled)
                    .placeholderColor(Palette.disabled)
                }
            if formFactor == .desktop { search } else { search.fontSize(15) }

            // MARK: Choices
            //
            // Switch, CheckBox and Slider wear the accent when ON, the whole
            // point of having one: whatever is on, anywhere, is orange.

            Style<Switch>()
                .tint(Palette.accent)
                .visualState(.disabled) { $0
                    .tint(Palette.disabled)
                }

            Style<CheckBox>()
                .tint(Palette.accent)
                .minimumHeight(44)
                .minimumWidth(44)
                .visualState(.disabled) { $0
                    .tint(Palette.disabled)
                }

            Style<RadioButton>()
                .background(.transparent)
                .textColor(Palette.text)
                .fontSize(15)
                .minimumHeight(44)
                .minimumWidth(44)
                .visualState(.disabled) { $0
                    .textColor(Palette.disabled)
                }

            Style<Slider>()
                .tint(Palette.accent)
                .visualState(.disabled) { $0
                    .tint(Palette.disabled)
                }

            // MARK: Progress and indicators

            Style<ActivityIndicator>()
                .tint(Palette.accent)

            Style<ProgressBar>()
                .tint(Palette.accent)
                .visualState(.disabled) { $0
                    .tint(Palette.disabled)
                }

            // MARK: The menu's rows
            //
            // A menu row is a view like any other, so it takes a style like any
            // other. What it does NOT take is a visual state saying which row
            // you are on: the application holds the section, so the row that is
            // chosen writes the two values it wants ON TOP of this style - see
            // Gallery/Views/MenuRow.swift, and the rule that a control's own
            // value wins over its style, per property.

            Style<HStack>("MenuRow")
                .spacing(14)
                .padding(horizontal: 18, vertical: 13)
                .background(.transparent)

            Style<Text>("MenuRowText")
                .fontSize(16)
                .verticalAlignment(.center)
                .textColor(Palette.subtle)

            // MARK: Shapes

            // A card is a FILL on a tinted page, with a hairline to hold its
            // edge - which is what makes it read as raised without a shadow, on
            // both themes and on every platform. A shadow would need a colour
            // that works on both, and there is no such colour.
            //
            // A colour here is one property with the view's own background,
            // so a panel that sets its own - a colour, or a gradient like the
            // home page's - replaces this one, the animated panel included.
            // What a card holds is cut to its corners: a picture reaches them.
            Style<ZStack>("Card")
                .background(Palette.raised)
                .stroke(Palette.outline)
                .shape(.roundedRectangle(14))
                .lineWidth(1)
                .clipsContent(true)

            // COLOUR, not background: a ColorBox draws its colour, and a
            // background is a second square behind that one - which Android
            // does not turn with the view, so a rotated box would show it
            // standing still underneath. The gallery's clock hands are the
            // ones that showed it.
            Style<ColorBox>()
                .color(Palette.accent)
        }
    }
}
