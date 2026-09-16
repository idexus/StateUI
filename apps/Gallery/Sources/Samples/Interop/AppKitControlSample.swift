#if APPKIT
import StateUI

/// A control the application registers with its host, described here like any
/// other.
struct AppKitControlSample: SampleContent, ExampleContent {
    @State private var signal = TrafficSignal.stop

    static let id = "appKitControl"
    static let title = "An AppKit control"
    static let summary = "An NSView the app registers with its host, described like any other control."

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
        heading: "In AppKit",
        language: .swift,
        code: """
            // Platforms/AppKit/Host/TrafficLightView.swift - an ordinary
            // NSView that knows nothing of StateUI.
            final class TrafficLightView: NSView {
                var onLampTapped: ((Int) -> Void)?

                // A number, because a closed vocabulary crosses as its
                // member: stop 0, caution 1, go 2.
                var signal: Int32 = -1 {
                    didSet { if signal != oldValue { repaint() } }
                }

                init() {
                    super.init(frame: .zero)

                    for _ in 0..<3 {
                        let lamp = NSView()
                        lamp.wantsLayer = true
                        lamp.layer?.cornerRadius = Self.lampSide / 2
                        addSubview(lamp)
                        lamps.append(lamp)
                    }

                    // ONE recognizer on the housing, the lamp read from the
                    // click's position - nothing to keep in step with layout.
                    let click = NSClickGestureRecognizer(
                        target: self, action: #selector(clicked(_:)))
                    addGestureRecognizer(click)
                    repaint()
                }

                private func repaint() {
                    for (index, lamp) in lamps.enumerated() {
                        let colour = Self.lampColors[index]
                        lamp.layer?.backgroundColor = Int32(index) == signal
                            ? colour.cgColor
                            : colour.withAlphaComponent(0.18).cgColor
                    }
                }
            }

            // And the registration, in GalleryControls.register(). `create`
            // runs once per element and wires what it reports; each `property`
            // puts a described value on the view.
            StateUIControls.add(TrafficLightContract.self, create: { reports -> TrafficLightView in
                let light = TrafficLightView()
                light.onLampTapped = { index in
                    reports.raise(TrafficLightContract.lampTapped, index)
                }
                return light
            }) { light in
                light.property(TrafficLightContract.signal) { view, signal in
                    view.signal = (signal ?? .stop).rawValue
                }
                light.raises(TrafficLightContract.lampTapped)
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
            Label("The lamps are an `NSView` the gallery registers with "
                + "`StateUIControls.add`, under the members `TrafficLightContract` "
                + "declares with the type of each value. The host creates it once, keeps "
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
