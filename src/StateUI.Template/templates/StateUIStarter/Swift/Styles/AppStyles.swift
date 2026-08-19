import StateUI

/// The application's styles: what every control of a type looks like.
/// MAUI: what App.xaml merges.
///
/// A style with no key applies to every control of its type, so the look of
/// the app is decided here rather than repeated in the views. Add a style the
/// day a control needs one - the sample app in the StateUI repository has
/// the full version of this file, one style per control it shows.
enum AppStyles {
    /// Built on demand, and never sent: a style is resolved on this side,
    /// into the controls it applies to.
    static var sheet: StyleSheet {
        StyleSheet {
            // Both colours carry both themes, so the app follows the system
            // with nothing else to write.
            Style<Label>()
                .textColor(Color(light: .black, dark: .white))
                .fontSize(15)

            Style<Button>()
                .textColor(.white)
                .backgroundColor(Color(light: Color.fromArgb("#512BD4"), dark: Color.fromArgb("#7B5CE0")))
                .fontSize(14)
                .fontAttributes(.bold)
                .cornerRadius(10)
                .padding(16, 11)
        }
    }
}
