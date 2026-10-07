import StateUI

/// A binding is no reader: one state, handed on as `$level` to a knob that
/// drags it and to two meters that show it - one by READING the value, one by
/// CONVERTING it - and each meter wears its own build count.
struct BindingReaderSample: SampleContent, ExampleContent {
    // listing: BindingReaderSample
    /// The one value this page is about, owned here and handed on to every
    /// child as `$level`. This body never reads it.
    @State private var level = 0.2
    // listing: end

    static let id = "bindingReader"
    static let title = "A binding is no reader"
    static let summary = "One state, `$level`: the meter that reads it rebuilds, the one that converts it does not."

    // listing: BindingReaderSample
    var body: some View {
        VStack {
            // The knob is handed the state: it drags it and sends it, and
            // reads it at no build.
            Knob(level: $level)

            // Two meters on the same state. The first READS the value in its
            // body, so every report rebuilds it; the second CONVERTS it and is
            // never rebuilt.
            ReadingMeter(level: $level)

            ConvertedMeter(level: $level)
        }
        .spacing(18)
    }
    // listing: end

    var notes: (any View)? {
        VStack {
            Text("One state, `level`, handed on as `$level` three times: to the knob, "
                + "which drags it and sends it, and to two meters. Handing it on makes "
                + "nobody a reader - the page around the three is never rebuilt for "
                + "it - and what each meter costs is decided inside it. The first "
                + "meter READS `level` to set its bar, so every report the thumb makes "
                + "rebuilds that meter and its count climbs; the second is handed the "
                + "same `$level` and CONVERTS it - `$level.convert { … }`, words the "
                + "host works out on its own frames - and its count stays at one.")
                .fontSize(12)
                .textColor(Palette.subtle)

            Text("`@Binding` is the same spelling at every depth: in a child, `level` "
                + "is the value and `$level` is the binding again, so `Slider($level)`, "
                + "`following: $level` and `level = 1` are written as the owner writes "
                + "them. Full and Empty are assignments, and the thumb travels under the "
                + "slider's own `.motion`.")
                .fontSize(12)
                .textColor(Palette.subtle)

            Text("A read in a body is the ONE thing that makes a reader, whether the "
                + "state is the view's own or borrowed. So a value a view must show is "
                + "read where it is shown and costs that view's renders alone, and a "
                + "value that only has to move is handed on and costs none.")
                .fontSize(12)
                .textColor(Palette.subtle)
        }
        .spacing(12)
    }
}

// listing: BindingReaderSample
/// The input, handed the parent's state: drags it and sends it.
private struct Knob: View {
    @Binding var level: Double

    var body: some View {
        VStack {
            Slider($level)
                .accessibilityIdentifier("bindingReader.level")
                .accessibilityLabel("Level")
                .motion(.eased(600, .cubicOut))

            HStack {
                Button("Full")
                    .onClicked { level = 1 }

                Button("Empty")
                    .onClicked { level = 0 }
            }
            .spacing(10)
        }
        .spacing(12)
    }
}
// listing: end

// listing: BindingReaderSample
/// A meter that READS the value: a reader, rebuilt on every report, and it
/// says so on its own face.
private struct ReadingMeter: View {
    @Binding var level: Double

    var body: some View {
        // Taken before the container, so it is this view's own reading.
        let count = BuildCount.of(debugInfo())   // this view's own build count

        return VStack {
            // A GET: this meter is a reader, and every report rebuilds it.
            ProgressBar()
                .progress(level)
                .tint(Palette.accent)

            Text("a bar that reads the value — \(count)")
                .fontSize(12)
                .textColor(Palette.subtle)
        }
        .spacing(8)
    }
}
// listing: end

// listing: BindingReaderSample
/// A meter handed the same state and CONVERTING it: no reader, never rebuilt,
/// and it says so too.
private struct ConvertedMeter: View {
    @Binding var level: Double

    var body: some View {
        let count = BuildCount.of(debugInfo())   // stays at one

        return VStack {
            // The words are the host's own arithmetic over the state, worked
            // out on its frames - handing a conversion on reads nothing here.
            Text()
                .text($level.convert { "\(Int(($0 * 100).rounded()))%" })
                .fontSize(17)

            Text("a conversion of the same state — \(count)")
                .fontSize(12)
                .textColor(Palette.subtle)
        }
        .spacing(8)
    }
}
// listing: end
