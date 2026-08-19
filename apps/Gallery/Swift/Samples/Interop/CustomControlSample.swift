import StateUI

/// The gallery's own vocabulary for its own control - declared the way the
/// library declares everything, and numbered by the session the same way.
extension NodeType {
    /// The C# TrafficLight, registered in MauiProgram under this name.
    static let trafficLight = NodeType("Gallery.TrafficLight")
}

extension Prop {
    /// Which lamp is lit. C#: TrafficLight.State.
    static let state = Prop("state")
}

extension Event {
    /// A lamp was tapped. C#: TrafficLight.LampTapped.
    static let lampTapped = Event("lampTapped")
}

/// What the light can say.
///
/// A CLOSED vocabulary, so it rides its NUMBER, exactly as every one of the
/// library's own does - a string on this wire means text someone wrote. The
/// numbers are this application's own, since there is no MAUI enum behind a
/// control the application invented; the C# half mirrors them, and the two
/// lists are the contract.
enum TrafficSignal: Int32, CaseIterable {
    /// Red. C#: TrafficLight.Stop.
    case stop = 0

    /// Amber. C#: TrafficLight.Caution.
    case caution = 1

    /// Green. C#: TrafficLight.Go.
    case go = 2
}

/// The Swift half of the C# TrafficLight: an ordinary View wrapping a node of
/// the registered type. `setValue` writes its property, `onEvent` hears its
/// event - the same two primitives every built-in modifier is made of - and
/// the shared tier (margins, opacity, gestures) comes with `View` for free.
struct TrafficLight: View {
    var node = Node(type: .trafficLight)

    /// Which lamp is lit. C#: TrafficLight.State.
    func state(_ value: TrafficSignal) -> Self {
        setValue(.state, .enumeration(value.rawValue))
    }

    /// A lamp was tapped - its index, top to bottom.
    /// C#: TrafficLight.LampTapped.
    func onLampTapped(_ handler: @escaping ValueEventHandler<Int>) -> Self {
        onEvent(.lampTapped) { payload in
            if let index = payload.value()?.int {
                try await handler(index)
            }
        }
    }
}

/// A control written in C#, adopted end to end: registered with
/// StateUIControls, described from Swift like any built-in.
struct CustomControlSample: SampleContent {
    @State private var signal = TrafficSignal.stop

    static let id = "custom-control"
    static let title = "A C# control"
    static let summary = "A C# control registered by the app, described like any other."

    static let code = """
        // The C# control and its registration are the IN C# listing below.
        // The Swift half: tokens for the name, the property and the event,
        // then a View wrapping a node of the registered type.
        extension NodeType { static let trafficLight = NodeType("Gallery.TrafficLight") }
        extension Prop { static let state = Prop("state") }
        extension Event { static let lampTapped = Event("lampTapped") }

        enum TrafficSignal: Int32, CaseIterable {
            case stop = 0, caution = 1, go = 2
        }

        struct TrafficLight: View {
            var node = Node(type: .trafficLight)

            func state(_ value: TrafficSignal) -> Self {
                setValue(.state, .enumeration(value.rawValue))
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
            // The control does not switch itself: a tap reports, the @State
            // decides, and the next render writes the lamp - the same loop
            // every built-in control lives in.
            TrafficLight()
                .state(signal)
                .onLampTapped { index in
                    signal = TrafficSignal.allCases[index]
                }

            Label("the state is Swift's: \\(signal)")

            Button("Advance")
                .onClicked {
                    let all = TrafficSignal.allCases
                    let next = (all.firstIndex(of: signal)! + 1) % all.count
                    signal = all[next]
                }
        }
        """

    /// The other half: an ordinary ContentView with a property and an event,
    /// and the registration in MauiProgram that adopts it.
    static let codeCSharp = """
        public sealed class TrafficLight : ContentView
        {
            public event EventHandler<int>? LampTapped;

            // A NUMBER, because the wire says so: a closed vocabulary
            // crosses as its member. stop 0, caution 1, go 2.
            public int State
            {
                get;
                set { field = value; Repaint(); }
            } = -1;

            public TrafficLight()
            {
                var column = new VerticalStackLayout { Spacing = 10, Padding = new Thickness(12) };

                for (int index = 0; index < _lamps.Length; index++)
                {
                    var lamp = new BoxView { WidthRequest = 44, HeightRequest = 44, CornerRadius = 22 };

                    int tapped = index;
                    var tap = new TapGestureRecognizer();
                    tap.Tapped += (_, _) => LampTapped?.Invoke(this, tapped);
                    lamp.GestureRecognizers.Add(tap);

                    _lamps[index] = lamp;
                    column.Children.Add(lamp);
                }

                Content = new Border { Content = column };
                Repaint();
            }

            private void Repaint()
            {
                for (int index = 0; index < _lamps.Length; index++)
                {
                    _lamps[index].Color = index == State
                        ? LampColors[index]
                        : LampColors[index].WithAlpha(0.18f);
                }
            }

            private static readonly Color[] LampColors =
                [Colors.Red, Colors.Orange, Colors.Green];
            private readonly BoxView[] _lamps = new BoxView[3];
        }

        // And the registration, in MauiProgram.CreateMauiApp:
        StateUIControls.Add("Gallery.TrafficLight",
            create: raise =>
            {
                var light = new TrafficLight();
                light.LampTapped += (_, index) =>
                    raise(light, "lampTapped", SwiftWireValue.Of(index));
                return light;
            },
            apply: (light, node) =>
            {
                if (node.GetEnumeration("state") is int state)
                {
                    light.State = state;
                }
            });
        """

    var content: Element {
        VStack {
            TrafficLight()
                .state(signal)
                .onLampTapped { index in
                    signal = TrafficSignal.allCases[index]
                }
                .horizontalOptions(.center)

            Label("the state is Swift's: \(signal)")
                .fontSize(17)
                .horizontalTextAlignment(.center)

            Button("Advance")
                .onClicked {
                    let all = TrafficSignal.allCases
                    let next = (all.firstIndex(of: signal)! + 1) % all.count
                    signal = all[next]
                }

            Label("The lamps are a C# ContentView the gallery registered with "
                + "StateUIControls.Add - the renderer creates it once, keeps it "
                + "between renders, applies the shared tier around the "
                + "registration's own apply, and a tap finds its Swift handler "
                + "by the id the tree carried. The control never switches "
                + "itself: it reports the lamp, this sample's @State decides, "
                + "and the next render lights it - the loop every built-in "
                + "lives in.")
                .fontSize(14)
                .textColor(Palette.subtle)
        }
        .spacing(5)
    }
}
