import StateUI

/// MAUI: Image.
struct ImageSample: SampleContent {
    static let id = "image"
    static let title = "Image"
    static let summary = "A picture from the app's resources, asked for by the name MAUI gives it."

    static let code = """
        VStack {
            HStack {
                Image(light: "nav_home.png", dark: "nav_home_dark.png")
                    .widthRequest(48)
                    .heightRequest(48)

                Image(light: "nav_layout.png", dark: "nav_layout_dark.png")
                    .widthRequest(48)
                    .heightRequest(48)
            }

            // The same shape drawn black, and drawn once per theme. MAUI has
            // no tint on an Image, so what changes is the SOURCE.
            HStack {
                Image("nav_gestures.png")
                    .widthRequest(32)
                    .heightRequest(32)

                Label("black artwork, always")
                    .verticalOptions(.center)
            }

            HStack {
                Image(light: "nav_gestures.png", dark: "nav_gestures_dark.png")
                    .widthRequest(32)
                    .heightRequest(32)

                Label("one per theme - switch the system between light and dark")
                    .verticalOptions(.center)
            }
        }
        """

    var content: Element {
        VStack {
            HStack {
                Image(light: "nav_home.png", dark: "nav_home_dark.png")
                    .widthRequest(48)
                    .heightRequest(48)

                Image(light: "nav_layout.png", dark: "nav_layout_dark.png")
                    .widthRequest(48)
                    .heightRequest(48)

                Image(light: "nav_input.png", dark: "nav_input_dark.png")
                    .widthRequest(48)
                    .heightRequest(48)

                Image(light: "nav_shell.png", dark: "nav_shell_dark.png")
                    .widthRequest(48)
                    .heightRequest(48)
            }
            .spacing(16)
            .horizontalOptions(.center)

            Label("These are the flyout's own icons: SVGs in Resources/Images, declared "
                + "once with <MauiImage Include=\"Resources/Images/*.svg\" />.")
                .fontSize(12)
                .textColor(Palette.subtle)

            Label("The build rasterizes each vector into the densities the platform wants, "
                + "so nav_home.svg is asked for as nav_home.png - exactly as it would be "
                + "in XAML.")
                .fontSize(12)
                .textColor(Palette.subtle)

            SectionTitle("ONE PER THEME")

            // The same shape drawn black and white. MAUI has no tint on an
            // Image, so what changes is the SOURCE - and the half in force is
            // picked as the value is written, so switching the system theme
            // rebuilds this view with the other file.
            HStack {
                Image("nav_gestures.png")
                    .widthRequest(32)
                    .heightRequest(32)

                Label("black artwork, always")
                    .fontSize(13)
                    .verticalOptions(.center)
            }
            .spacing(12)

            HStack {
                Image(light: "nav_gestures.png", dark: "nav_gestures_dark.png")
                    .widthRequest(32)
                    .heightRequest(32)

                Label("one per theme - switch the system between light and dark")
                    .fontSize(13)
                    .verticalOptions(.center)
            }
            .spacing(12)

            Label("MAUI has no tint on an Image, so a picture that has to read on both "
                + "themes is two pictures. ImageSource(light:dark:) is the same idea as "
                + "Color(light:dark:), and the host applies it the same way.")
                .fontSize(12)
                .textColor(Palette.subtle)

            Label("`.isAnimationPlaying(true)` runs a picture that HAS frames - a GIF, an "
                + "animated WebP - and does nothing at all to a still one, which is why "
                + "no example above uses it: the gallery ships no animated artwork. It is "
                + "a property rather than an act, so a paused animation is a state the "
                + "tree describes and a rebuild cannot lose.")
                .fontSize(12)
                .textColor(Palette.subtle)
        }
        .spacing(12)
    }
}
