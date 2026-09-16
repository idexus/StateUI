#if MAUI
import StateUI

/// A control written in C#, registered by the application and described here
/// like any other. Its contract and its Swift half are in
/// Samples/Interop/TrafficLight.swift, shared with every other host.
struct CustomControlSample: SampleContent, ExampleContent {
    @State private var signal = TrafficSignal.stop

    static let id = "customControl"
    static let title = "A C# control"
    static let summary = "A control written in C# and registered by the app, described like any other."

    static let code = """
        enum TrafficSignal: Int32, CaseIterable, HostRepresentable {
            case stop = 0, caution = 1, go = 2
        }

        enum TrafficLightContract: ElementContract {
            static let nodeType: NodeType = "Gallery.TrafficLight"
            static let tiers: [any Contract.Type] = [ViewContract.self]

            static let signal = ElementProperty<Self, TrafficSignal>("signal")
            static let lampTapped = ElementEvent<Self, Int>("lampTapped")

            static let members: [any ContractMember] = [signal, lampTapped]
        }

        struct TrafficLight: View {
            var node = Node(contract: TrafficLightContract.self)

            func signal(_ value: TrafficSignal) -> Self {
                setValue(TrafficLightContract.signal, value)
            }

            func onLampTapped(_ handler: @escaping ValueEventHandler<Int>) -> Self {
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
        heading: "In C#",
        language: .csharp,
        code: """
            public sealed class TrafficLight : ContentView
            {
                public event EventHandler<int>? LampTapped;

                // A number, because a closed vocabulary crosses as its
                // member: stop 0, caution 1, go 2. Anything else lights
                // nothing.
                public int Signal
                {
                    get;
                    set { field = value; Repaint(); }
                } = -1;

                public TrafficLight()
                {
                    var column = new VerticalStackLayout { Spacing = 10 };

                    for (int index = 0; index < _lamps.Length; index++)
                    {
                        var lamp = new BoxView
                        {
                            WidthRequest = 44,
                            HeightRequest = 44,
                            CornerRadius = 22,

                            // Set locally, so nothing behind a dimmed lamp
                            // shows through its alpha in any application
                            // that adopts the control.
                            BackgroundColor = Colors.Transparent,
                        };

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

                // The lit lamp at full colour, the others dimmed to embers.
                private void Repaint()
                {
                    for (int index = 0; index < _lamps.Length; index++)
                    {
                        _lamps[index].Color = index == Signal
                            ? LampColors[index]
                            : LampColors[index].WithAlpha(0.18f);
                    }
                }

                private static readonly Color[] LampColors =
                [
                    Color.FromArgb("#E5484D"),
                    Color.FromArgb("#F5B546"),
                    Color.FromArgb("#46B45F"),
                ];

                private readonly BoxView[] _lamps = new BoxView[3];
            }

            // And the registration, in MauiProgram.CreateMauiApp. `create`
            // runs once per element and wires its events; `apply` runs on
            // every message that touches it and reads only what arrived.
            StateUIControls.Add("Gallery.TrafficLight",
                create: raise =>
                {
                    var light = new TrafficLight();
                    light.LampTapped += (_, index) =>
                        raise(light, "lampTapped", HostValue.Of(index));
                    return light;
                },
                apply: (light, node) =>
                {
                    if (node.GetEnumeration("signal") is int signal)
                    {
                        light.Signal = signal;
                    }
                });
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
            Label("The lamps are a C# control the gallery registers with "
                + "`StateUIControls.Add`, under the names `TrafficLightContract` declares "
                + "with the type of each value. The host creates it once, keeps it by "
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
