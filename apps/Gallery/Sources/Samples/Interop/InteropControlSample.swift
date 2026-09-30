#if APPKIT || UIKIT || GTK || WINUI || ANDROID
import StateUI

/// A control the application registers with its host, described here like any
/// other.
struct InteropControlSample: SampleContent, ExampleContent {
    @State private var signal = TrafficSignal.stop

    static let id = InteropHost.key + "Control"
    static let title = InteropHost.control
    static let summary = InteropHost.controlSummary

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

    #if APPKIT
    static let hostCode = HostCode(
        in: InteropHost.name,
        .swift("""
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

            // And its registration, at the end of the same file. `create`
            // runs once per element and wires what it reports; each `property`
            // puts a described value on the view.
            extension TrafficLightView {
                @MainActor
                static func register() {
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
                }
            }

            // GalleryControls.register(), called from main.swift, lists it:
            TrafficLightView.register()
            """))
    #elseif UIKIT
    static let hostCode = HostCode(
        in: InteropHost.name,
        .swift("""
            // Platforms/UIKit/Host/TrafficLightView.swift - an ordinary
            // UIView that knows nothing of StateUI.
            final class TrafficLightView: UIView {
                var onLampTapped: ((Int) -> Void)?

                // A number, because a closed vocabulary crosses as its
                // member: stop 0, caution 1, go 2.
                var signal: Int32 = -1 {
                    didSet { if signal != oldValue { repaint() } }
                }

                init() {
                    super.init(frame: .zero)

                    for _ in 0..<3 {
                        let lamp = UIView()
                        lamp.layer.cornerRadius = Self.lampSide / 2
                        lamp.isUserInteractionEnabled = false
                        addSubview(lamp)
                        lamps.append(lamp)
                    }

                    // ONE recognizer on the housing, the lamp read from the
                    // tap's position - nothing to keep in step with layout.
                    addGestureRecognizer(UITapGestureRecognizer(
                        target: self, action: #selector(tapped(_:))))
                    repaint()
                }

                // UIKit asks a view how big it is as it lays it out.
                override func sizeThatFits(_ size: CGSize) -> CGSize {
                    CGSize(
                        width: Self.padding * 2 + Self.lampSide,
                        height: Self.padding * 2 + Self.lampSide * 3 + Self.spacing * 2)
                }

                private func repaint() {
                    for (index, lamp) in lamps.enumerated() {
                        let colour = Self.lampColors[index]
                        lamp.backgroundColor = Int32(index) == signal ? colour : colour.withAlphaComponent(0.18)
                    }
                }
            }

            // And its registration, at the end of the same file. `create`
            // runs once per element and wires what it reports; each `property`
            // puts a described value on the view.
            extension TrafficLightView {
                @MainActor
                static func register() {
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
                }
            }

            // GalleryControls.register(), called from main.swift, lists it:
            TrafficLightView.register()
            """))
    #elseif GTK
    static let hostCode = HostCode(
        in: InteropHost.name,
        .swift("""
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
            """))
    #elseif WINUI
    static let hostCode = HostCode(
        in: InteropHost.name,
        .swift("""
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
            """),
        .cpp("""
            // Platforms/WinUI/Relay/Controls.cpp - the lamps as XAML that knows
            // nothing of StateUI: a Border holding three Ellipses. Each function is
            // C++/WinRT behind the C name the Swift half calls, declared in
            // include/CGalleryWinUI.h; a tap is told through the callbacks the Swift
            // half handed over, by the number it made the control with.
            extern "C" GalleryObjectRef gallery_traffic_light_make(int64_t control) {
                try {
                    controls::Border housing;
                    housing.Background(brush(26, 23, 37));
                    housing.CornerRadius(xaml::CornerRadius{18, 18, 18, 18});
                    housing.Padding(xaml::Thickness{12, 12, 12, 12});
                    controls::StackPanel lamps;
                    lamps.Spacing(10);
                    for (int32_t lamp = 0; lamp < 3; ++lamp) {
                        shapes::Ellipse ellipse;
                        ellipse.Width(44);
                        ellipse.Height(44);
                        ellipse.Fill(brush(lampColors[lamp][0], lampColors[lamp][1], lampColors[lamp][2]));
                        ellipse.Opacity(lamp == 0 ? 1 : 0.18);
                        // The light does not switch itself: it reports, and whoever
                        // owns the state decides.
                        ellipse.Tapped([control, lamp](auto const &, xaml::Input::TappedRoutedEventArgs const &args) {
                            args.Handled(true);
                            if (callbacks.lampTapped) callbacks.lampTapped(control, lamp);
                        });
                        lamps.Children().Append(ellipse);
                    }
                    housing.Child(lamps);
                    return detach(housing);
                } catch (...) {
                    report("making a traffic light");
                    return nullptr;
                }
            }

            extern "C" void gallery_traffic_light_set_signal(GalleryObjectRef light, int32_t signal) {
                try {
                    auto lamps = as<controls::Border>(light).Child().as<controls::StackPanel>().Children();
                    for (uint32_t lamp = 0; lamp < lamps.Size(); ++lamp) {
                        lamps.GetAt(lamp).as<xaml::UIElement>().Opacity(static_cast<int32_t>(lamp) == signal ? 1 : 0.18);
                    }
                } catch (...) {
                    report("lighting a lamp");
                }
            }
            """))
    #else
    static let hostCode = HostCode(
        in: InteropHost.name,
        .swift("""
            // Platforms/Android/Swift/Host/TrafficLightView.swift. The lamps
            // are a View of the gallery's own Java - TrafficLightView.java,
            // beside the head - that knows nothing of StateUI; the control
            // makes it and holds it.
            @MainActor
            final class TrafficLightView: AndroidControl {
                let view: JavaObject
                var onLampTapped: ((Int) -> Void)?

                var signal = TrafficSignal.stop {
                    didSet {
                        if signal != oldValue { Java.call(view.reference, Self.setSignal, .int(signal.rawValue)) }
                    }
                }

                init() {
                    number = GalleryControls.reserve()
                    view = Java.new(Self.viewClass, Self.make, .object(StateUIAndroid.context), .long(number))
                    GalleryControls.hold(self, as: number)
                }

                // The view's tap reaches here through a native method of the
                // gallery's, GalleryNatives.lampTapped, by the control's number.
                func tapped(_ index: Int) {
                    onLampTapped?(index)
                }
            }

            // And its registration, at the end of the same file. `create`
            // runs once per element and wires what it reports; each `property`
            // puts a described value on the control.
            extension TrafficLightView {
                @MainActor
                static func register() {
                    StateUIControls.add(TrafficLightContract.self, create: { reports -> TrafficLightView in
                        let light = TrafficLightView()
                        light.onLampTapped = { index in
                            reports.raise(TrafficLightContract.lampTapped, index)
                        }
                        return light
                    }) { light in
                        light.property(TrafficLightContract.signal) { control, signal in
                            control.signal = signal ?? .stop
                        }
                        light.raises(TrafficLightContract.lampTapped)
                    }
                }
            }

            // GalleryControls.register(), called from JNI_OnLoad, lists it:
            TrafficLightView.register()
            """),
        .java("""
            // Platforms/Android/Java/com/stateui/gallery/TrafficLightView.java - a
            // View that knows nothing of StateUI. It is told which lamp is lit, and
            // tells a tap through a native method of the gallery's, by the number
            // its Swift half made it with.
            final class TrafficLightView extends View {
                private static final int[] LAMPS = {0xFFE5484D, 0xFFF5B546, 0xFF46B45F};
                private static final float LAMP = 44, SPACING = 10, PADDING = 12;

                private final long control;
                private final float density;
                private final Paint paint = new Paint(Paint.ANTI_ALIAS_FLAG);
                private final RectF housing = new RectF();
                private int signal = -1;

                TrafficLightView(Context context, long control) {
                    super(context);
                    this.control = control;
                    density = context.getResources().getDisplayMetrics().density;
                    setClickable(true);
                }

                // Which lamp is lit, from the top: what the Swift half's `signal` sets.
                void setSignal(int lamp) {
                    if (lamp == signal) return;
                    signal = lamp;
                    invalidate();
                }

                // How big it is, which the host asks as Android asks any view.
                @Override
                protected void onMeasure(int width, int height) {
                    setMeasuredDimension(
                            resolveSize(Math.round((PADDING * 2 + LAMP) * density), width),
                            resolveSize(Math.round((PADDING * 2 + LAMP * 3 + SPACING * 2) * density), height));
                }

                @Override
                protected void onDraw(Canvas canvas) {
                    housing.set(0, 0, getWidth(), getHeight());
                    paint.setColor(0xFF1A1725);
                    canvas.drawRoundRect(housing, 18 * density, 18 * density, paint);
                    for (int lamp = 0; lamp < 3; lamp++) {
                        paint.setColor(lamp == signal ? LAMPS[lamp] : (LAMPS[lamp] & 0x00FFFFFF) | 0x2E000000);
                        canvas.drawCircle(getWidth() / 2f, centre(lamp), LAMP / 2 * density, paint);
                    }
                }

                // The light does not switch itself: it tells the tap, and whoever
                // owns the state decides.
                @Override
                public boolean onTouchEvent(MotionEvent event) {
                    if (event.getActionMasked() == MotionEvent.ACTION_UP) {
                        for (int lamp = 0; lamp < 3; lamp++) {
                            if (Math.abs(event.getY() - centre(lamp)) <= LAMP / 2 * density) {
                                GalleryNatives.lampTapped(control, lamp);
                                break;
                            }
                        }
                    }
                    return true;
                }

                private float centre(int lamp) {
                    return (PADDING + LAMP / 2 + lamp * (LAMP + SPACING)) * density;
                }
            }

            // Platforms/Android/Java/com/stateui/gallery/GalleryNatives.java - what
            // the gallery's own views tell its Swift half, which answers each by its
            // JNI name.
            final class GalleryNatives {
                static native void lampTapped(long control, int lamp);
            }
            """))
    #endif

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

    var notes: (any View)? {
        VStack {
            Label(InteropHost.lamps + " The host creates it once, keeps "
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
