#if MAUI
import StateUI

extension NodeType {
    /// The C# TrafficLight, registered under this name.
    static let trafficLight = NodeType("Gallery.TrafficLight")
}

extension Prop {
    /// Which lamp is lit. C#: `TrafficLight.Signal`.
    static let signal = Prop("signal")
}

extension Event {
    /// A lamp was tapped. C#: `TrafficLight.LampTapped`.
    static let lampTapped = Event("lampTapped")
}

/// What the light can show.
///
/// A closed vocabulary, so it crosses as its member's number. The numbers are
/// this application's own contract, and the C# control mirrors them.
enum TrafficSignal: Int32, CaseIterable {
    /// Red. C#: 0.
    case stop = 0

    /// Amber. C#: 1.
    case caution = 1

    /// Green. C#: 2.
    case go = 2
}

/// The Swift half of the C# TrafficLight: a view wrapping a node of the
/// registered type. `setValue` writes its property and `onEvent` hears its
/// event; margins, alignment, opacity and gestures come with `View`.
struct TrafficLight: View {
    var node = Node(type: .trafficLight)

    /// Which lamp is lit. C#: `TrafficLight.Signal`.
    func signal(_ value: TrafficSignal) -> Self {
        setValue(.signal, .enumeration(value.rawValue))
    }

    /// A lamp was tapped, with its index from the top.
    /// C#: `TrafficLight.LampTapped`.
    func onLampTapped(_ handler: @escaping ValueEventHandler<Int>) -> Self {
        onEvent(.lampTapped) { payload in
            if let index = payload.value()?.int {
                try await handler(index)
            }
        }
    }
}

/// A control written in C#, registered by the application and described here
/// like any other.
struct CustomControlSample: SampleContent, ExampleContent {
    @State private var signal = TrafficSignal.stop

    static let id = "customControl"
    static let title = "A C# control"
    static let summary = "A control written in C# and registered by the app, described like any other."

    static let code = """
        extension NodeType {
            static let trafficLight = NodeType("Gallery.TrafficLight")
        }

        extension Prop {
            static let signal = Prop("signal")
        }

        extension Event {
            static let lampTapped = Event("lampTapped")
        }

        enum TrafficSignal: Int32, CaseIterable {
            case stop = 0, caution = 1, go = 2
        }

        struct TrafficLight: View {
            var node = Node(type: .trafficLight)

            func signal(_ value: TrafficSignal) -> Self {
                setValue(.signal, .enumeration(value.rawValue))
            }

            func onLampTapped(_ handler: @escaping ValueEventHandler<Int>) -> Self {
                onEvent(.lampTapped) { payload in
                    if let index = payload.value()?.int {
                        try await handler(index)
                    }
                }
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
            Label("The lamps are a C# control the gallery registers with "
                + "`StateUIControls.Add`. The host creates it once, keeps it by "
                + "identity between renders, runs the registration's `apply`, and then "
                + "applies what every view shares - margins, alignment, opacity, "
                + "gestures.")
                .fontSize(12)
                .textColor(Palette.subtle)

            Label("The control never switches itself. A tap raises `lampTapped` through "
                + "the `raise` its `create` is handed, this sample's `@State` decides, "
                + "and the next render lights the lamp.")
                .fontSize(12)
                .textColor(Palette.subtle)

            Label("`TrafficSignal` is a closed vocabulary, so it crosses as its member's "
                + "number, which the C# `apply` reads with `node.GetEnumeration`.")
                .fontSize(12)
                .textColor(Palette.subtle)
        }
        .spacing(12)
    }
}
#endif
