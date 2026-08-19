// The gallery's styles: what every control of a type looks like.
//
// The shape is the .NET MAUI template's Styles.xaml - the same target types, the
// same properties, the same visual states - and the VALUES are the StateUI
// ramp rather than the template's. A style with no key applies to every control
// of its type, so most of the gallery's appearance is decided here rather than
// in the views.
//
// Every colour comes through `Palette`, one name per job. That is what makes the
// look changeable in one file, and what makes it coherent: nothing here picks a
// colour, it says what the thing is FOR and the palette answers.
//
// TWO DELIBERATE DIFFERENCES from the template:
//
//   - No FontFamily. The template ships OpenSansRegular as a MauiFont; this app
//     ships no fonts, and naming a family that is not registered is a way to get
//     a different font on every platform.
//   - Only what a Style can NAME. The template also styles Shadow (not a
//     control - `.shadow` is a property of the view that casts it), SwipeItem
//     (not a StyleTarget), Page (a protocol you declare, whose appearance is
//     its own requirements), and NavigationPage and TabbedPage, whose bar is
//     written on the arrangement itself - see GalleryApp.detail. TitleBar is
//     commented out in the template itself.

import StateUI

/// The application's styles, as the sheet the differ resolves against.
/// MAUI: App.xaml's ResourceDictionary.
enum AppStyles {
    /// Built on demand, like everything else that describes the interface -
    /// and never sent: the differ merges each style into the controls it
    /// applies to, so what crosses is a control with its values already on it.
    /// The idiom comes from the application's `@Environment` - one style
    /// reads it, the SearchBar's touch floor being the phone's alone.
    static func sheet(on idiom: DeviceIdiom) -> StyleSheet {
        StyleSheet {
            // MARK: Text

            Style<Label>()
                .textColor(Palette.text)
                .backgroundColor(.transparent)
                .fontSize(15)                

            // A page's own name for itself. Tight tracking, because a large
            // size at the default spacing reads loose.
            Style<Label>("Headline")
                .textColor(Palette.text)
                .fontSize(32)
                .fontAttributes(.bold)
                .characterSpacing(-0.5)
                .horizontalOptions(.center)
                .horizontalTextAlignment(.center)

            Style<Label>("SubHeadline")
                .textColor(Palette.subtle)
                .fontSize(20)
                .horizontalOptions(.center)
                .horizontalTextAlignment(.center)

            // MARK: Buttons

            Style<Button>()
                .textColor(Palette.onAccent)
                .backgroundColor(Palette.accent)
                .fontSize(14)
                .fontAttributes(.bold)
                .borderWidth(0)
                .cornerRadius(10)                
                .padding(16, 11)
                .minimumHeightRequest(44)
                .minimumWidthRequest(44)
                .visualState(.disabled) { $0
                    .textColor(Palette.disabled)
                    .backgroundColor(Palette.outline)
                }

            // A button that lives in the WINDOW's chrome rather than on a
            // page. The implicit style above is an accent pill 44 points tall
            // - right in the content, and a foreign object in a strip half
            // that height: a filled pill up there reads as something stuck on,
            // whatever colour it is painted.
            //
            // So a chrome button is WORDS AND AN ICON and nothing else - no
            // fill, no border - answering the pointer by brightening rather
            // than by growing a frame. The icon is the one its menu row
            // already carries, in the colour of the words beside it: see
            // nav_surprise_chrome.svg. The MARK is left white, the colour of
            // the application's name it stands beside - the mark and the name
            // are one thing said twice, and the accent belongs to the one
            // thing up here that can be pressed.
            //
            // The colour is the WINDOW's own yellow - read off the minimise
            // button of a running window - so what can be pressed in the
            // chrome matches the other things in the chrome that can be
            // pressed. Fixed rather than `Palette.accent`, the `GalleryPage`
            // exception again: the title bar does not follow the theme, so a
            // themed colour would be right in one theme and wrong in the
            // other. It measures 5.0:1 on the bar's violet, where
            // `swiftOrangeLight` is 3.4:1 and fails AA for text.
            //
            // A keyed style REPLACES the implicit one, so this states
            // everything it needs, the 44-point touch floor deliberately
            // dropped: a title bar is a desktop, and a mouse is not a thumb.
            Style<Button>("ChromeChip")
                .textColor(AppColors.windowYellow)
                .backgroundColor(.transparent)
                .fontSize(13)
                .fontAttributes(.bold)
                .borderWidth(0)
                .padding(5, 0)
                .heightRequest(26)
                .visualState(.normal) { $0
                    .opacity(1)
                }
                .visualState(.pointerOver) { $0
                    .opacity(0.85)
                }

            // A button that lives in a LIST ROW, where the touch floor is
            // not merely unnecessary but harmful. A recycled cell measures a
            // minimum size INCONSISTENTLY: with one in the row, the cell
            // takes that height on some measure passes and the content's own
            // on others, so the rows draw at two heights and gaps open
            // between them - measured on Mac Catalyst, and
            // reproduced with a hand-written C# row and a bare MAUI template
            // both, so it is the platform's cell measurement rather than
            // anything this library does. Dropping the floor draws every row
            // the same height, and a button in a list row is a target beside
            // its text rather than a thumb target of its own.
            //
            // A keyed style REPLACES the implicit one, so this states
            // everything it needs - the ChromeChip rule again.
            Style<Button>("RowChip")
                .textColor(Palette.onAccent)
                .backgroundColor(Palette.accent)
                .fontSize(13)
                .fontAttributes(.bold)
                .borderWidth(0)
                .cornerRadius(10)
                .padding(14, 4)
                .minimumHeightRequest(0)
                .minimumWidthRequest(0)
                .visualState(.disabled) { $0
                    .textColor(Palette.disabled)
                    .backgroundColor(Palette.outline)
                }

            Style<ImageButton>()
                .opacity(1)
                .borderColor(.transparent)
                .borderWidth(0)
                .cornerRadius(10)
                .minimumHeightRequest(44)
                .minimumWidthRequest(44)
                .visualState(.disabled) { $0
                    .opacity(0.4)
                }

            // MARK: Fields

            Style<Entry>()
                .textColor(Palette.text)
                .backgroundColor(.transparent)
                .placeholderColor(Palette.subtle)
                .fontSize(15)
                .minimumHeightRequest(44)
                .minimumWidthRequest(44)
                .visualState(.disabled) { $0
                    .textColor(Palette.disabled)
                }

            Style<Editor>()
                .textColor(Palette.text)
                .backgroundColor(.transparent)
                .placeholderColor(Palette.subtle)
                .fontSize(15)
                .minimumHeightRequest(44)
                .minimumWidthRequest(44)
                .visualState(.disabled) { $0
                    .textColor(Palette.disabled)
                }

            Style<Picker>()
                .textColor(Palette.text)
                .titleColor(Palette.subtle)
                .backgroundColor(.transparent)
                .fontSize(15)
                .minimumHeightRequest(44)
                .minimumWidthRequest(44)
                .visualState(.disabled) { $0
                    .textColor(Palette.disabled)
                    .titleColor(Palette.disabled)
                }

            Style<DatePicker>()
                .textColor(Palette.text)
                .backgroundColor(.transparent)
                .fontSize(15)
                .minimumHeightRequest(44)
                .minimumWidthRequest(44)
                .visualState(.disabled) { $0
                    .textColor(Palette.disabled)
                }

            Style<TimePicker>()
                .textColor(Palette.text)
                .backgroundColor(.transparent)
                .fontSize(15)
                .minimumHeightRequest(44)
                .minimumWidthRequest(44)
                .visualState(.disabled) { $0
                    .textColor(Palette.disabled)
                }

            // NO backgroundColor, and that is measured, not an omission: on
            // iOS a solid one becomes the bar's BarTintColor, rendered
            // through a translucent material that lands visibly OFF the card
            // - and .transparent is worse, a CLEAR tint dropping UISearchBar
            // into a legacy look that is WHITE in both themes, dark mode's
            // light text vanishing into it. The bar behind the field is
            // removed on the HOST instead: MauiProgram appends
            // SearchBarStyle.Minimal to the handler, UIKit's own way to put
            // a search field on a coloured surface. And the 44-point floor is
            // the PHONE's: UIKit pins the field to the TOP of the bar, so on
            // a desktop the touch floor showed as a dead band under the field
            // - a mouse is not a thumb, the ChromeChip rule.
            Style<SearchBar>()
                .textColor(Palette.text)
                .placeholderColor(Palette.subtle)
                .cancelButtonColor(Palette.accent)
                .fontSize(15)
                .minimumHeightRequest(idiom == .desktop ? 0 : 44)
                .minimumWidthRequest(44)
                .visualState(.disabled) { $0
                    .textColor(Palette.disabled)
                    .placeholderColor(Palette.disabled)
                }

            // MARK: Choices
            //
            // All four take the accent when they are ON, which is the whole
            // point of having one: whatever is chosen, anywhere, is orange.

            Style<Switch>()
                .onColor(Palette.accent)
                .thumbColor(AppColors.white)
                .visualState(.disabled) { $0
                    .onColor(Palette.disabled)
                    .thumbColor(Palette.disabled)
                }
                .visualState(.on) { $0
                    .onColor(Palette.accent)
                    .thumbColor(AppColors.white)
                }
                .visualState(.off) { $0
                    .thumbColor(Color(light: AppColors.white, dark: AppColors.inkMutedDark))
                }

            Style<CheckBox>()
                .color(Palette.accent)
                .minimumHeightRequest(44)
                .minimumWidthRequest(44)
                .visualState(.disabled) { $0
                    .color(Palette.disabled)
                }

            Style<RadioButton>()
                .backgroundColor(.transparent)
                .textColor(Palette.text)
                .fontSize(15)
                .minimumHeightRequest(44)
                .minimumWidthRequest(44)
                .visualState(.disabled) { $0
                    .textColor(Palette.disabled)
                }

            Style<Slider>()
                .minimumTrackColor(Palette.accent)
                .maximumTrackColor(Palette.outline)
                .thumbColor(Palette.accent)
                .visualState(.disabled) { $0
                    .minimumTrackColor(Palette.disabled)
                    .maximumTrackColor(Palette.outline)
                    .thumbColor(Palette.disabled)
                }

            // MARK: Progress and indicators

            Style<ActivityIndicator>()
                .color(Palette.accent)

            Style<ProgressBar>()
                .progressColor(Palette.accent)
                .visualState(.disabled) { $0
                    .progressColor(Palette.disabled)
                }

            Style<IndicatorView>()
                .indicatorColor(Palette.outline)
                .selectedIndicatorColor(Palette.accent)

            Style<RefreshView>()
                .refreshColor(Palette.accent)

            // The interop group's registered control - a Style can target it
            // because its registration knows the C# class, and its own
            // `rating` setter comes from the same protocol the control
            // conforms to. Keyed, so only the sample that asks wears it; see
            // Samples/Interop/CustomStyleSample.swift.
            Style<RatingBar>("FourStars")
                .rating(4)
                .backgroundColor(Palette.selected)

            // MARK: The menu's rows
            //
            // A menu row is a view like any other, so it takes a style like any
            // other. What it does NOT take is a visual state saying which row
            // you are on: that is MAUI's answer in a Shell, which holds the
            // items and knows which one it has selected. Here the menu is a
            // page and the application holds the section, so the row that is
            // chosen writes the two values it wants ON TOP of this style - see
            // Gallery/Views/MenuRow.swift, and the rule that a control's own
            // value wins over its style, per property.

            Style<HorizontalStackLayout>("MenuRow")
                .spacing(14)
                .padding(18, 13)
                .backgroundColor(.transparent)

            Style<Label>("MenuRowText")
                .fontSize(16)
                .verticalOptions(.center)
                .textColor(Palette.subtle)

            // MARK: Shapes

            // A card is a FILL on a tinted page, with a hairline to hold its
            // edge - which is what makes it read as raised without a shadow, on
            // both themes and on every platform. A shadow would need a colour
            // that works on both, and there is no such colour.
            //
            // backgroundColor, NOT background. MAUI paints the Background BRUSH
            // whenever one is set and ignores BackgroundColor entirely - so a
            // brush here, in a style every Border gets, cannot be overridden by
            // a view setting its own colour: the two are different properties,
            // and a local value only beats a style setter of the SAME one.
            // Measured - it hid the panel in both animation samples, and with
            // it the whole point of the one that animates a background.
            //
            // A view that wants a GRADIENT still says `.background(…)` and wins,
            // because a brush beats a colour. That is what the home page's
            // panel does.
            Style<Border>()
                .backgroundColor(Palette.raised)
                .stroke(Palette.outline)
                .strokeShape(.roundRectangle(14))
                .strokeThickness(1)

            Style<BoxView>()
                .backgroundColor(Palette.accent)
        }
    }
}
