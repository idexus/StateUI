import StateUI

/// Pictures from the app's resources: fitted, filled, and one per theme.
struct ImageSample: SampleContent, ExampleContent {
    static let id = "image"
    static let title = "Image"
    static let summary = "A picture from the app's resources, asked for by name."

    // listing: ImageSample
    var body: some View {
        VStack {
            HStack {
                Image(light: "nav_home.png", dark: "nav_home_dark.png")
                    .width(48)
                    .height(48)

                Image(light: "nav_layout.png", dark: "nav_layout_dark.png")
                    .width(48)
                    .height(48)

                Image(light: "nav_input.png", dark: "nav_input_dark.png")
                    .width(48)
                    .height(48)

                Image(light: "nav_shell.png", dark: "nav_shell_dark.png")
                    .width(48)
                    .height(48)
            }
            .spacing(16)
            .horizontalAlignment(.center)

            SectionTitle("Fit or fill")

            // The same square picture in the same wide box, so the only thing
            // between the two is the aspect.
            HStack {
                VStack {
                    Image(light: "nav_media.png", dark: "nav_media_dark.png")
                        .contentMode(.fit)
                        .width(120)
                        .height(60)
                        .background(Palette.surface)

                    Text(".contentMode(.fit)")
                        .fontSize(11)
                        .textColor(Palette.subtle)
                        .horizontalTextAlignment(.center)
                }
                .spacing(4)

                VStack {
                    Image(light: "nav_media.png", dark: "nav_media_dark.png")
                        .contentMode(.fill)
                        .width(120)
                        .height(60)
                        .background(Palette.surface)

                    Text(".contentMode(.fill)")
                        .fontSize(11)
                        .textColor(Palette.subtle)
                        .horizontalTextAlignment(.center)
                }
                .spacing(4)
            }
            .spacing(16)
            .horizontalAlignment(.center)

            SectionTitle("One per theme")

            // The same shape drawn black and white. An Image has no tint, so
            // what changes is the SOURCE - and the half in force is picked as
            // the view is built, so switching the system theme builds this
            // view again with the other file.
            HStack {
                Image("nav_gestures.png")
                    .width(32)
                    .height(32)

                Text("black artwork, always")
                    .fontSize(13)
                    .verticalAlignment(.center)
            }
            .spacing(12)

            HStack {
                Image(light: "nav_gestures.png", dark: "nav_gestures_dark.png")
                    .width(32)
                    .height(32)

                Text("one per theme - switch the system between light and dark")
                    .fontSize(13)
                    .verticalAlignment(.center)
            }
            .spacing(12)
        }
        .spacing(12)
    }
    // listing: end

    var notes: (any View)? {
        VStack {
            Text("The first row is the sidebar's own icons: SVGs in `Resources/Images`, "
                + "each asked for by its `.png` name. Where the build makes no PNG of that "
                + "name, the host loads the SVG of the same name instead.")
                .fontSize(12)
                .textColor(Palette.subtle)

            Text("`.contentMode` is the choice between showing all of the picture and filling "
                + "every corner: `.fit` keeps the whole picture and leaves room on "
                + "two sides, `.fill` covers the box and crops what will not fit.")
                .fontSize(12)
                .textColor(Palette.subtle)

            Text("An `Image` has no tint, so a picture that has to read on both themes is "
                + "two pictures. `ImageSource(light:dark:)` is picked the way "
                + "`Color(light:dark:)` is - as the view is built - so a change of theme "
                + "builds the views wearing one again.")
                .fontSize(12)
                .textColor(Palette.subtle)

            Text("`.isAnimating(true)` runs a picture that HAS frames - a GIF, an "
                + "animated WebP - and does nothing at all to a still one, which is why "
                + "no example above uses it: the gallery ships no animated artwork. It is "
                + "a property rather than an act, so a paused animation is a state the "
                + "tree describes and a rebuild cannot lose.")
                .fontSize(12)
                .textColor(Palette.subtle)
        }
        .spacing(8)
    }
}
