import StateUI
#if !os(WASI)
// listing: SummedOffTheUIThread
import Dispatch
// listing: end
#endif

/// Work done on another thread, handed back to the UI thread through the platform's main queue.
private struct SummedOffTheUIThread: ExampleContent {
    // listing: SummedOffTheUIThread
    @State private var result = "Nothing summed yet"

    var body: some View {
        VStack {
            Text(result)
                .fontSize(15)
                .textColor(Palette.accent)

            Button("Sum a million on another thread").onClicked {
                result = "Summing…"
                let shown = $result
                #if os(WASI)
                shown.wrappedValue = "The Web has no main queue - post to the state instead"
                #else
                DispatchQueue.global().async {
                    let sum = (1 ... 1_000_000).reduce(0, +)
                    // The main queue runs this on the UI thread, where the state is written.
                    DispatchQueue.main.async { shown.wrappedValue = "\(sum), handed back on the main queue" }
                }
                #endif
            }
        }
        .spacing(12)
        .horizontalAlignment(.start)
    }
    // listing: end

    var notes: (any View)? {
        Text("Press the button: the sum comes back through DispatchQueue.main on every host but the Web.")
            .fontSize(12)
            .textColor(Palette.subtle)
    }
}

/// libdispatch's main queue, drained on the UI thread by every native host.
struct MainQueueSample: SampleContent {
    static let id = "mainQueue"
    static let title = "Main queue"
    static let summary = "Work from another thread handed back through DispatchQueue.main, on every host but the Web."

    var examples: [Example] {
        [Example(SummedOffTheUIThread())]
    }
}
