#if WINUI
import StateUI

/// A control the application registers with its host, described here like any
/// other.
struct WinUIControlSample: SampleContent, ExampleContent {
    @State private var signal = TrafficSignal.stop

    static let id = "winUIControl"
    static let title = "A WinUI control"
    static let summary = "A WinUI element the app registers with its host, described like any other control."

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
        heading: "In WinUI",
        language: .swift,
        code: """
            // Platforms/WinUI/Host/TrafficLightControl.swift. The lamps are XAML
            // - a Border, three Ellipses - made by the gallery's own relay,
            // C++/WinRT behind C functions in Platforms/WinUI/Relay. A
            // WinUIControl is an object holding the element it shows.
            @MainActor
            final class TrafficLightControl: WinUIControl {
                let element: OpaquePointer
                var onLampTapped: ((Int) -> Void)?

                var signal = TrafficSignal.stop {
                    didSet { gallery_traffic_light_set_signal(element, signal.rawValue) }
                }

                private let number: Int64

                init() {
                    // The relay tells a tap by the number the control gives it.
                    number = GalleryControls.reserve()
                    element = gallery_traffic_light_make(number)!
                    GalleryControls.hold(self, as: number)
                }

                isolated deinit {
                    GalleryControls.forget(number)
                    gallery_winui_release(element)
                }
            }

            extension TrafficLightControl {
                @MainActor
                static func register() {
                    StateUIControls.add(TrafficLightContract.self, create: { reports -> TrafficLightControl in
                        let light = TrafficLightControl()
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
            Label("The lamps are XAML the gallery's own relay makes, registered with "
                + "`StateUIControls.add`, under the members `TrafficLightContract` "
                + "declares with the type of each value, held by a `WinUIControl` of its own. "
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
