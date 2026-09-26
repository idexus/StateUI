// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

#if os(macOS)
import AppKit
@_spi(Host) import StateUI
@_spi(Host) import StateUIHost
@testable import StateUIAppKit
@_spi(Host) import StateUIConformance

/// The AppKit host as the conformance suite drives it: each user's act through the action, the accessibility action
/// or the field editor AppKit's own input takes into the host, and each read from the control itself.
/// Design: docs/design/host/conformance.md#the-driver
@MainActor
final class AppKitDriver: HostDriver {
    let host = "AppKit"
    let cannot: [String: String] = [:]

    /// What the families ask of a driver that AppKit's has no path for yet says so, and stays empty in AppKit's column
    /// with why, rather than failing.
    func reason(cannot ability: String) -> String? {
        cannot[ability] ?? "AppKit's driver has no path for it yet"
    }

    /// The host the driver started last.
    private(set) var renderer: AppKitRenderer?

    var register: HostRegister { AppKitRealization.register }

    /// The preferences the driver's hosts keep their values in, apart from the machine's own.
    let store = UserDefaults(suiteName: "StateUI.AppKitConformance")!

    /// What the hosts wrote to their log since the last started.
    let written = AppKitLogLines()

    /// What the system restores at the next launch: the windows open when the last host ended, each as its delegate
    /// encoded it.
    private var restorable: [(identifier: String, state: Data)] = []

    func start(clock: TestClock?, reducesMotion: Bool, _ page: @escaping @Sendable () -> any Page) -> MountedTree {
        forgetWhatIsKept()
        return run(clock: clock, reducesMotion: reducesMotion) { OneWindowApplication(page: page) }
    }

    func start(clock: TestClock?, application: @escaping @Sendable () -> any Application) throws -> MountedTree {
        run(clock: clock, reducesMotion: false, application)
    }

    /// Ends the running host without the system keeping its windows, and empties the preferences.
    func forgetWhatIsKept() {
        renderer?.closeForTesting()
        renderer = nil
        store.removePersistentDomain(forName: "StateUI.AppKitConformance")
        restorable = []
    }

    /// Runs `application` on a new host as a launch does: the windows the last host left open restored by the
    /// system's road before the application finishes launching, then its first window in front as AppKit brings it;
    /// the tree it mounted.
    /// Design: docs/design/platforms/appkit/conformance.md#windows
    private func run(
        clock: TestClock?, reducesMotion: Bool, _ application: @escaping @Sendable () -> any Application
    ) -> MountedTree {
        restorable = renderer.map { Self.encoded($0.windowsForTesting) } ?? []
        renderer?.closeForTesting()
        stateUIUseApp(application())
        written.listen()
        let renderer = testRenderer(
            resourceDirectory: Self.pictures, preferences: store, clock: clock.map { clock in { clock.now } },
            reducesMotion: { reducesMotion })
        self.renderer = renderer
        AppKitRestorationBroker.shared.host = renderer
        for window in restorable { Self.restore(window) }
        renderer.startForTesting()
        comeToTheFront(renderer.windowsForTesting.first?.window)
        return renderer.runtime.tree
    }

    /// Each window's restorable state, as its delegate encodes it for the system.
    private static func encoded(_ controllers: [AppKitWindowController]) -> [(identifier: String, state: Data)] {
        controllers.compactMap { controller in
            guard let window = controller.window, let identifier = window.identifier?.rawValue else { return nil }
            let archiver = NSKeyedArchiver(requiringSecureCoding: true)
            controller.window(window, willEncodeRestorableState: archiver)
            archiver.finishEncoding()
            return (identifier, archiver.encodedData)
        }
    }

    /// Restores a window as the system does at launch: its restoration class hears its identifier and its state.
    private static func restore(_ window: (identifier: String, state: Data)) {
        guard let state = try? NSKeyedUnarchiver(forReadingFrom: window.state) else { return }
        AppKitWindowRestorer.restoreWindow(
            withIdentifier: NSUserInterfaceItemIdentifier(window.identifier), state: state) { _, _ in }
    }

    func step() {
        guard let renderer else { return }
        RunLoop.current.run(until: Date(timeIntervalSinceNow: 0.01))
        _ = renderer.runtime.core.runJobs()
        renderer.runtime.pump.turn()
        if renderer.frameClock.held { renderer.displayFrameForTesting() }
    }

    func turn() {
        renderer?.runtime.pump.turn()
    }

    func frame() {
        renderer?.displayFrameForTesting()
    }

    func held(_ property: Prop, on element: MountedElement) throws -> HostValue? {
        if element.type == .window { return try windowHolds(property, element) }
        let view = (element.native as? AppKitElement)?.view
        switch (property, view) {
        case (.isOn, let toggle as AppKitSwitchView): return (toggle.state == .on).propValue
        case (.isOn, let check as AppKitCheckBoxView): return (check.state == .on).propValue
        case (.isOn, let radio as AppKitRadioButtonView): return (radio.state == .on).propValue
        case (.value, let slider as AppKitSliderView): return slider.doubleValue.propValue
        case (.minimum, let slider as AppKitSliderView): return slider.minValue.propValue
        case (.maximum, let slider as AppKitSliderView): return slider.maxValue.propValue
        case (.value, let stepper as AppKitStepperView): return stepper.doubleValue.propValue
        case (.minimum, let stepper as AppKitStepperView): return stepper.minValue.propValue
        case (.maximum, let stepper as AppKitStepperView): return stepper.maxValue.propValue
        case (.step, let stepper as AppKitStepperView): return stepper.increment.propValue
        case (.progress, let bar as AppKitProgressView): return bar.doubleValue.propValue
        case (.isRunning, let spinner as AppKitActivityIndicatorView): return spinner.isSpinning.propValue
        case (.text, let label as AppKitLabelView): return label.stringValue.propValue
        case (.text, let field as AppKitTextFieldView): return field.textField.stringValue.propValue
        case (.text, let search as AppKitSearchFieldView): return search.stringValue.propValue
        case (.text, let editor as AppKitTextEditorView): return editor.textView.string.propValue
        case (.text, let button as AppKitButtonView): return button.title.propValue
        case (.text, let check as AppKitCheckBoxView): return check.title.propValue
        case (.text, let radio as AppKitRadioButtonView): return radio.title.propValue
        case (.selectedIndex, let picker as AppKitPickerView):
            return picker.indexOfSelectedItem >= 0 ? picker.indexOfSelectedItem.propValue : nil
        case (.options, let picker as AppKitPickerView): return picker.itemTitles.propValue
        case (.title, let picker as AppKitPickerView): return picker.title.propValue
        case (.date, let picker as AppKitDateTimePickerView): return Self.day(picker.valueLanesForTesting)?.propValue
        case (.minimumDate, let picker as AppKitDateTimePickerView):
            return picker.minimumLanesForTesting.flatMap(Self.day)?.propValue
        case (.maximumDate, let picker as AppKitDateTimePickerView):
            return picker.maximumLanesForTesting.flatMap(Self.day)?.propValue
        case (.time, let picker as AppKitDateTimePickerView):
            let lanes = picker.valueLanesForTesting
            return lanes.count >= 2 ? ClockTime(hour: Int(lanes[0]), minute: Int(lanes[1])).propValue : nil
        case (.currentPage, let tabs as AppKitTabbedView): return tabs.selectedIndexForTesting.propValue
        case (.isSidebarVisible, let split as AppKitSplitView): return split.isEffectivelyPresentedForTesting.propValue
        case (.isVisible, let view?): return (!view.isHidden).propValue
        case (.opacity, let view?): return Double(view.alphaValue).propValue
        case (.isEnabled, let control as NSControl): return control.isEnabled.propValue
        case (.isEnabled, let picker as AppKitPickerView): return picker.isEnabled.propValue
        case (_, let view?):
            if let held = try Self.viewHolds(property, view, element.native as? AppKitElement) { return held }
            throw DriverCannot(reading: property, of: element)
        default: throw DriverCannot(reading: property, of: element)
        }
    }

    /// The day a date picker's lanes say: year, month, day.
    private static func day(_ lanes: [Double]) -> CalendarDate? {
        lanes.count >= 3 ? CalendarDate(year: Int(lanes[0]), month: Int(lanes[1]), day: Int(lanes[2])) : nil
    }

    /// Tests/Resources/Images: the pictures the cases name.
    static let pictures = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent()    // Conformance
        .deletingLastPathComponent()    // Tests
        .appendingPathComponent("Resources/Images")
}
#endif
