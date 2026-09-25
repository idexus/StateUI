#if GTK
import StateUI

/// A control the application registers with its host, described here like any
/// other.
struct GTKControlSample: SampleContent, ExampleContent {
    @State private var signal = TrafficSignal.stop

    static let id = "gtkControl"
    static let title = "A GTK control"
    static let summary = "A GTK widget the app registers with its host, described like any other control."

    static let codeHeading = "In StateUI"

    static let code = """
        public enum TrafficSignal: Int32, CaseIterable, HostRepresentable {
            case stop = 0, caution = 1, go = 2
        }

        public enum TrafficLightContract: ElementContract {
            public static let nodeType: NodeType = "Gallery.TrafficLight"
            public static let tiers: [any Contract.Type] = [ViewContract.self]

            public static let signal = ElementProperty<Self, TrafficSignal>("signal")
            public static let lampTapped = ElementEvent<Self, Int>("lampTapped")

            public static let members: [any ContractMember] = [signal, lampTapped]
        }

        public struct TrafficLight: View {
            public var node = Node(contract: TrafficLightContract.self)

            public init() {}

            public func signal(_ value: TrafficSignal) -> Self {
                setValue(TrafficLightContract.signal, value)
            }

            public func onLampTapped(_ handler: @escaping ValueEventHandler<Int>) -> Self {
                onEvent(TrafficLightContract.lampTapped, handler)
            }
        }

        @State private var signal = TrafficSignal.stop

        VStack {
            // The signal is read here, so a tap on a lamp builds this closure.
            DebugInfoLabel()

            // The control reports a tap; the state decides what it shows.
            TrafficLight()
                .signal(signal)
                .onLampTapped { index in
                    signal = TrafficSignal(rawValue: Int32(index)) ?? signal
                }

            Label("signal: \\(signal)")

            Button("Advance")
                .onClicked {
                    let all = TrafficSignal.allCases
                    signal = all[(all.firstIndex(of: signal)! + 1) % all.count]
                }
        }
        """

    static let hostCode = HostCode(
        heading: "In GTK",
        language: .swift,
        code: """
            // Platforms/GTK/Host/TrafficLightWidget.swift - a GtkDrawingArea,
            // drawn by cairo, that knows nothing of StateUI. A GTKControl is an
            // object holding the widget it shows.
            @MainActor
            final class TrafficLightWidget: GTKControl {
                let widget: UnsafeMutablePointer<GtkWidget>
                var onLampTapped: ((Int) -> Void)?

                var signal = TrafficSignal.stop {
                    didSet { if signal != oldValue { gtk_widget_queue_draw(widget) } }
                }

                init() {
                    widget = gtk_drawing_area_new()
                    g_object_ref_sink(widget)
                    // … the content size, the draw function (the housing and
                    // three lamps in cairo), and one GtkGestureClick whose
                    // "released" tells which lamp - each a C callback, handed
                    // the control as its data.
                }
            }

            extension TrafficLightWidget {
                @MainActor
                static func register() {
                    StateUIControls.add(TrafficLightContract.self, create: { reports -> TrafficLightWidget in
                        let light = TrafficLightWidget()
                        light.onLampTapped = { index in
                            reports.raise(TrafficLightContract.lampTapped, index)
                        }
                        return light
                    }) { light in
                        // Handed back typed - a TrafficSignal, not its number.
                        light.property(TrafficLightContract.signal) { control, signal in
                            control.signal = signal ?? .stop
                        }
                        light.raises(TrafficLightContract.lampTapped)
                    }
                }
            }
            """)

    var content: any View {
        VStack {
            DebugInfoLabel()

            TrafficLight()
                .signal(signal)
                .onLampTapped { index in
                    signal = TrafficSignal(rawValue: Int32(index)) ?? signal
                }
                .horizontalAlignment(.center)

            Label("signal: \(signal)")
                .fontSize(17)
                .horizontalTextAlignment(.center)

            Button("Advance")
                .onClicked {
                    let all = TrafficSignal.allCases
                    signal = all[(all.firstIndex(of: signal)! + 1) % all.count]
                }
        }
        .spacing(8)
    }

    var notes: Element? {
        VStack {
            Label("The lamps are a `GtkDrawingArea` the gallery registers with "
                + "`StateUIControls.add`, under the members `TrafficLightContract` "
                + "declares with the type of each value, held by a `GTKControl` of its own. "
                + "The host creates it once, keeps "
                + "it by identity between renders, puts each described value on it, and "
                + "then applies what every view shares - margins, alignment, opacity, "
                + "gestures.")
                .fontSize(12)
                .textColor(Palette.subtle)

            Label("The control never switches itself. A tap raises `lampTapped` through "
                + "the reports its `create` is handed, this sample's `@State` decides, "
                + "and the next render lights the lamp.")
                .fontSize(12)
                .textColor(Palette.subtle)

            Label("`TrafficSignal` is a closed vocabulary, so it crosses as its member's "
                + "number - and the registration is handed it back as `TrafficSignal`, "
                + "typed, rather than as that number.")
                .fontSize(12)
                .textColor(Palette.subtle)
        }
        .spacing(12)
    }
}
#endif
