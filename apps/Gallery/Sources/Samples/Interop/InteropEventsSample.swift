#if APPKIT || UIKIT || GTK || WINUI || ANDROID
import StateUI

/// Events the host raises on its own, heard with no control behind them.
struct InteropEventsSample: SampleContent, ExampleContent {
    @State private var battery = "not heard yet"
    @State private var log: [String] = []
    @State private var heard: [HostEventSubscription] = []

    static let id = InteropHost.key + "Events"
    static let title = "Hearing from " + InteropHost.name
    static let summary = "Events the host raises on its own, heard with no control behind them."

    static let codeHeading = "In StateUI"

    static let code = """
        // The application's own events, declared beside its acts.
        public enum GalleryContract: ApplicationTier {
            public static let name = "Gallery"

            public static let batteryChanged =
                ElementEvent<Self, (Double, Bool)>("Gallery.BatteryChanged")

            public static let members: [any ContractMember] = [batteryChanged]
        }

        @State private var battery = "not heard yet"
        @State private var log: [String] = []
        @State private var heard: [HostEventSubscription] = []

        VStack {
            // What the host raised is read here, so every raise heard builds
            // this closure.
            DebugInfoLabel()

            Text("battery: \\(battery)")

            Text(log.isEmpty
                ? "Plug or unplug the power."
                : log.suffix(4).joined(separator: "\\n"))
        }
        // Listening for exactly as long as the view is in the tree.
        .onCreated {
            heard.forEach { $0.cancel() }
            heard = [
                HostEvents.on(GalleryContract.batteryChanged) { level, charging in
                    battery = "\\(Int((level * 100).rounded()))%" + (charging ? ", charging" : "")
                    log.append("\\(log.count + 1). battery: \\(battery)")
                },
            ]
        }
        .onDestroying {
            heard.forEach { $0.cancel() }
            heard = []
        }
        """

    #if APPKIT
    static let hostCode = HostCode(
        in: InteropHost.name,
        .swift("""
            // Platforms/AppKit/Host/GalleryEventSources.swift. Raising is safe
            // from any thread, and a raise nobody hears is an ordinary answer,
            // so the source is wired unconditionally.
            enum GalleryEventSources {
                @MainActor
                static func start() {
                    // What the host raises, declared where its source is
                    // wired: a handler listening for anything else is told.
                    StateUIEvents.raises(GalleryContract.batteryChanged)

                    // Named in full: a C function pointer carries no context,
                    // and an unqualified call to a static method captures the
                    // type implicitly.
                    let notify: IOPowerSourceCallbackType = { _ in
                        GalleryEventSources.report()
                    }

                    guard let source = IOPSNotificationCreateRunLoopSource(notify, nil)?
                        .takeRetainedValue()
                    else { return }

                    CFRunLoopAddSource(CFRunLoopGetMain(), source, .defaultMode)
                    report()
                }

                private static func report() {
                    let (level, charging) = GalleryActs.battery()

                    // A power source notifies on far more than a level change,
                    // so an unchanged reading raises nothing.
                    guard level > 0 else { return }
                    guard lastSaid?.level != level || lastSaid?.charging != charging else { return }

                    lastSaid = (level, charging)
                    StateUIEvents.raise(GalleryContract.batteryChanged, level, charging)
                }
            }

            // And in main.swift, before StateUIAppKit.run(...):
            GalleryEventSources.start()
            """))
    #elseif UIKIT
    static let hostCode = HostCode(
        in: InteropHost.name,
        .swift("""
            // Platforms/UIKit/Host/GalleryEventSources.swift. Raising is safe
            // from any thread, and a raise nobody hears is an ordinary answer,
            // so the source is wired unconditionally.
            @MainActor
            enum GalleryEventSources {
                static func start() {
                    // What the host raises, declared where its source is
                    // wired: a handler listening for anything else is told.
                    StateUIEvents.raises(GalleryContract.batteryChanged)

                    // UIKit says nothing of the battery until asked to watch it.
                    UIDevice.current.isBatteryMonitoringEnabled = true
                    for name in [UIDevice.batteryLevelDidChangeNotification,
                                 UIDevice.batteryStateDidChangeNotification] {
                        observers.append(NotificationCenter.default.addObserver(
                            forName: name, object: nil, queue: .main) { _ in
                            MainActor.assumeIsolated { report() }
                        })
                    }
                    report()
                }

                private static func report() {
                    let (level, charging) = GalleryActs.battery()

                    // A simulator has no battery, so it raises nothing; an
                    // unchanged reading raises nothing either.
                    guard level > 0 else { return }
                    guard lastSaid?.level != level || lastSaid?.charging != charging else { return }

                    lastSaid = (level, charging)
                    StateUIEvents.raise(GalleryContract.batteryChanged, level, charging)
                }
            }

            // And in main.swift, before StateUIUIKit.run():
            GalleryEventSources.start()
            """))
    #elseif GTK
    static let hostCode = HostCode(
        in: InteropHost.name,
        .swift("""
            // Platforms/GTK/Host/GalleryEventSources.swift. Raising is safe
            // from any thread, and a raise nobody hears is an ordinary answer,
            // so the source is wired unconditionally.
            enum GalleryEventSources {
                @MainActor
                static func start() {
                    // What the host raises, declared where its source is
                    // wired: a handler listening for anything else is told.
                    StateUIEvents.raises(GalleryContract.batteryChanged)

                    // UPower's display device tells every change of the
                    // battery; a C callback carries no context, so the report
                    // is named in full.
                    guard let device = GalleryPower.device else { return }
                    let changed: @convention(c) (
                        OpaquePointer?, OpaquePointer?, OpaquePointer?, gpointer?
                    ) -> Void = { _, _, _, _ in
                        MainActor.assumeIsolated { GalleryEventSources.report() }
                    }
                    g_signal_connect_data(
                        UnsafeMutableRawPointer(device), "g-properties-changed",
                        unsafeBitCast(changed, to: GCallback.self), nil, nil, GConnectFlags(rawValue: 0))
                    report()
                }

                @MainActor
                private static func report() {
                    let (level, charging) = GalleryPower.battery()

                    // UPower tells more than a level change, so an unchanged
                    // reading raises nothing.
                    guard level > 0 else { return }
                    guard lastSaid?.level != level || lastSaid?.charging != charging else { return }

                    lastSaid = (level, charging)
                    StateUIEvents.raise(GalleryContract.batteryChanged, level, charging)
                }
            }

            // And in main.swift, before StateUIGTK.run(applicationID:):
            GalleryEventSources.start()
            """))
    #elseif WINUI
    static let hostCode = HostCode(
        in: InteropHost.name,
        .swift("""
            // Platforms/WinUI/Host/GalleryEventSources.swift. Raising is safe
            // from any thread, and a raise nobody hears is an ordinary answer,
            // so the source is wired unconditionally.
            enum GalleryEventSources {
                @MainActor
                static func start() {
                    // What the host raises, declared where its source is
                    // wired: a handler listening for anything else is told.
                    StateUIEvents.raises(GalleryContract.batteryChanged)

                    // The gallery's relay asks Windows for each change of the
                    // battery's charge and of the power source
                    // (PowerSettingRegisterNotification).
                    gallery_battery_watch(batteryChanged)
                    report()
                }

                @MainActor
                fileprivate static func report() {
                    let (level, charging) = GalleryPower.battery()

                    // Windows tells more than a level change, so an unchanged
                    // reading raises nothing.
                    guard level > 0 else { return }
                    guard lastSaid?.level != level || lastSaid?.charging != charging else { return }

                    lastSaid = (level, charging)
                    StateUIEvents.raise(GalleryContract.batteryChanged, level, charging)
                }
            }

            // Windows calls it on a thread of its own, so it is declared
            // outside the main actor - a closure written inside `start()`
            // would be the main actor's - and hands the report to it.
            private let batteryChanged: @convention(c) () -> Void = {
                Task { @MainActor in GalleryEventSources.report() }
            }

            // And in main.swift, before StateUIWinUI.run():
            GalleryEventSources.start()
            """),
        .cpp("""
            // Platforms/WinUI/Relay/System.cpp - Windows' notices of the battery's
            // charge and of the power source, each passed on to the function the
            // Swift half handed over. Windows calls it on a thread of its own.
            namespace {
                constexpr GUID batteryPercentage = {0xa7ad8041, 0xb45a, 0x4cae, {0x87, 0xa3, 0xee, 0xcb, 0xb4, 0x68, 0xa9, 0xe1}};
                constexpr GUID powerSource = {0x5d3e9a59, 0xe9d5, 0x4b00, {0xa6, 0xbd, 0xff, 0x34, 0xff, 0x51, 0x65, 0x48}};

                void (*told)(void) = nullptr;

                ULONG CALLBACK changed(PVOID, ULONG, PVOID) {
                    if (told) told();
                    return 0;
                }

                DEVICE_NOTIFY_SUBSCRIBE_PARAMETERS subscription{changed, nullptr};
            }

            extern "C" void gallery_battery_watch(void (*changedTold)(void)) {
                try {
                    told = changedTold;
                    for (auto setting : {&batteryPercentage, &powerSource}) {
                        HPOWERNOTIFY handle = nullptr;
                        PowerSettingRegisterNotification(setting, DEVICE_NOTIFY_CALLBACK, &subscription, &handle);
                    }
                } catch (...) {
                    report("watching the battery");
                }
            }

            // And the reading each notice leads to, which GalleryPower.battery() calls.
            extern "C" void gallery_battery(double *level, bool *charging) {
                try {
                    *level = 0;
                    *charging = false;
                    SYSTEM_POWER_STATUS status{};
                    if (!GetSystemPowerStatus(&status) || (status.BatteryFlag & 128) || status.BatteryLifePercent > 100) return;
                    *level = status.BatteryLifePercent / 100.0;
                    *charging = status.ACLineStatus == 1;
                } catch (...) {
                    report("reading the battery");
                }
            }
            """))
    #else
    static let hostCode = HostCode(
        in: InteropHost.name,
        .swift("""
            // Platforms/Android/Swift/Host/GalleryEventSources.swift. The
            // source is Android's own: the gallery's activity registers a
            // receiver for ACTION_BATTERY_CHANGED while it lives, and its Java
            // tells each reading through a native method of the gallery's.
            enum GalleryEventSources {
                @MainActor
                static func register() {
                    // What the host raises, declared where the head starts:
                    // a handler listening for anything else is told.
                    StateUIEvents.raises(GalleryContract.batteryChanged)
                }

                @MainActor
                static func report(level: Double, charging: Bool) {
                    // A receiver hears every change of the battery's status,
                    // so an unchanged reading raises nothing.
                    guard level > 0 else { return }
                    guard lastSaid?.level != level || lastSaid?.charging != charging else { return }

                    lastSaid = (level, charging)
                    StateUIEvents.raise(GalleryContract.batteryChanged, level, charging)
                }
            }

            // The native method GalleryDevice.java's receiver calls, by its JNI name.
            @_cdecl("Java_com_stateui_gallery_GalleryNatives_batteryChanged")
            public func galleryBatteryChanged(
                _ env: UnsafeMutablePointer<JNIEnv?>?, _ owner: jclass?, _ level: jdouble, _ charging: jboolean
            ) {
                MainActor.assumeIsolated { GalleryEventSources.report(level: level, charging: charging != 0) }
            }
            """),
        .java("""
            // Platforms/Android/Java/com/stateui/gallery/GalleryActivity.java - the
            // gallery's activity: the host's own, and the battery watched while it
            // lives.
            public final class GalleryActivity extends StateUIActivity {
                private BroadcastReceiver battery;

                @Override
                protected void onCreate(Bundle state) {
                    super.onCreate(state);
                    battery = GalleryDevice.watchBattery(this);
                }

                @Override
                protected void onDestroy() {
                    unregisterReceiver(battery);
                    super.onDestroy();
                }
            }

            // Platforms/Android/Java/com/stateui/gallery/GalleryDevice.java - each
            // change of the battery, the one standing first, told to the Swift half
            // through a native method of the gallery's.
            final class GalleryDevice {
                static BroadcastReceiver watchBattery(Context context) {
                    BroadcastReceiver receiver = new BroadcastReceiver() {
                        @Override
                        public void onReceive(Context context, Intent intent) {
                            double[] battery = reading(intent);
                            GalleryNatives.batteryChanged(battery[0], battery[1] != 0);
                        }
                    };
                    IntentFilter filter = new IntentFilter(Intent.ACTION_BATTERY_CHANGED);
                    if (Build.VERSION.SDK_INT >= 33) {
                        context.registerReceiver(receiver, filter, Context.RECEIVER_NOT_EXPORTED);
                    } else {
                        context.registerReceiver(receiver, filter);
                    }
                    return receiver;
                }

                // The level, 0 to 1 - 0 where the device has none - and 1 where it
                // charges, else 0.
                private static double[] reading(Intent status) {
                    if (status == null) return new double[] {0, 0};
                    int level = status.getIntExtra(BatteryManager.EXTRA_LEVEL, -1);
                    int scale = status.getIntExtra(BatteryManager.EXTRA_SCALE, -1);
                    int state = status.getIntExtra(BatteryManager.EXTRA_STATUS, -1);
                    boolean charging = state == BatteryManager.BATTERY_STATUS_CHARGING || state == BatteryManager.BATTERY_STATUS_FULL;
                    return new double[] {level >= 0 && scale > 0 ? (double) level / scale : 0, charging ? 1 : 0};
                }
            }

            // Platforms/Android/Java/com/stateui/gallery/GalleryNatives.java - the
            // native method the receiver calls, answered in Swift by its JNI name.
            final class GalleryNatives {
                static native void batteryChanged(double level, boolean charging);
            }
            """))
    #endif

    var body: some View {
        VStack {
            DebugInfoLabel()

            Text("battery: \(battery)")
                .fontSize(17)

            Text(log.isEmpty
                ? "Plug or unplug the power."
                : log.suffix(4).joined(separator: "\n"))
                .fontSize(13)
                .textColor(Palette.subtle)
        }
        .spacing(8)
        .onCreated {
            heard.forEach { $0.cancel() }
            heard = [
                HostEvents.on(GalleryContract.batteryChanged) { level, charging in
                    battery = "\(Int((level * 100).rounded()))%" + (charging ? ", charging" : "")
                    log.append("\(log.count + 1). battery: \(battery)")
                },
            ]
        }
        .onDestroying {
            heard.forEach { $0.cancel() }
            heard = []
        }
    }

    var notes: (any View)? {
        VStack {
            Text("The host calls `StateUIEvents.raise(event, values)` when the platform "
                + "reports something, from any thread. Every `HostEvents.on` subscription "
                + "to that member runs like a control's handler: on the library's "
                + "executor, handed the values the contract declares, free to await and to "
                + "write `@State`. The head declares each event it raises with "
                + "`StateUIEvents.raises`, so a handler listening for one nothing raises "
                + "is told so once.")
                .fontSize(12)
                .textColor(Palette.subtle)

            Text("The subscriptions are made in `.onCreated` and cancelled in "
                + "`.onDestroying`, so the page listens while it is in the tree. A raise "
                + "nobody hears is an ordinary answer, so the host wires its sources "
                + "unconditionally.")
                .fontSize(12)
                .textColor(Palette.subtle)

            Text("A desktop with no battery reports nothing at all, and that is the "
                + "honest answer rather than a failure: this page then keeps saying it "
                + "has not heard.")
                .fontSize(12)
                .textColor(Palette.subtle)
        }
        .spacing(12)
    }
}
#endif
