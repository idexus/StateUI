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

    func start(clock: TestClock?, reducesMotion: Bool, _ page: @escaping @Sendable () -> any Page) -> MountedTree {
        run(clock: clock, reducesMotion: reducesMotion) { OneWindowApplication(page: page) }
    }

    func start(clock: TestClock?, application: @escaping @Sendable () -> any Application) throws -> MountedTree {
        run(clock: clock, reducesMotion: false, application)
    }

    /// Runs `application` on a new host, its first window in front as AppKit brings it; the tree it mounted.
    private func run(
        clock: TestClock?, reducesMotion: Bool, _ application: @escaping @Sendable () -> any Application
    ) -> MountedTree {
        renderer?.closeForTesting()
        stateUIUseApp(application())
        let renderer = testRenderer(
            resourceDirectory: Self.pictures, clock: clock.map { clock in { clock.now } },
            reducesMotion: { reducesMotion })
        self.renderer = renderer
        renderer.startForTesting()
        comeToTheFront(renderer.windowsForTesting.first?.window)
        return renderer.runtime.tree
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
