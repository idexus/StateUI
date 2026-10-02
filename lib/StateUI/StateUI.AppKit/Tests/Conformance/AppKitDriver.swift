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
    let cannot = [
        "read aspect of Button": "AppKit's button has no covering scale, as the register records: a fill shows fitted",
        "read shape of a box shorter than its radius":
            "AppKit's layer holds the radius it draws, at most half the box's shorter side",
    ]
    let platformHasNone = AppKitDriver.none()

    /// What AppKit holds none of: what StateUI draws in a view's `draw(_:)`, where StateUI's layout places the
    /// children, what StateUI measures and what the host cuts - each proven by its effect in another case.
    private static func none() -> [String: String] {
        var none = [
            "read growsWithText of TextEditor":
                "an editor's growing is StateUI's measuring, which no property of AppKit's holds; its frames prove it",
        ]
        for field in ["TextField", "SearchField", "TextEditor"] {
            none["read maximumLength of \(field)"] =
                "AppKit's field keeps no bound: the host cuts what is typed, and typing proves it"
        }
        let shapePaint = [
            "aspect", "renderTransform", "fill", "stroke", "strokeWidth", "strokeDashOffset", "strokeDashPattern",
            "strokeLineCap", "strokeLineJoin", "strokeMiterLimit",
        ]
        for shape in ["Ellipse", "Line", "Path", "Polygon", "Polyline", "Rectangle"] {
            for member in shapePaint {
                none["read \(member) of \(shape)"] =
                    "StateUI draws a shape in its view's draw(_:), which holds none of its \(member); its drawing proves it"
            }
        }
        for layout in ["Grid", "HStack", "VStack", "ZStack"] {
            for member in ["stroke", "strokeWidth", "shape"] {
                none["read \(member) of \(layout)"] =
                    "StateUI draws a layout's box in its view's draw(_:), which holds none of its \(member); its drawing proves it"
            }
        }
        for layout in ["Grid", "HStack", "VStack", "ZStack", "ScrollView"] {
            none["read padding of \(layout)"] =
                "AppKit's view places its children where StateUI's layout says; their frames prove it"
        }
        for stack in ["HStack", "VStack"] {
            none["read spacing of \(stack)"] = "AppKit's view places its children where StateUI's layout says; their frames prove it"
        }
        return none
    }

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

    /// What the hosts wrote to their log since the last one started.
    let written = AppKitLogLines()

    /// What the system restores at the next launch: the windows open when the last host ended, each as its delegate
    /// encoded it.
    private var restorable: [KeptWindow] = []

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

    /// Each window's restorable state as the system keeps it: what its delegate encodes, and its frame.
    private static func encoded(_ controllers: [AppKitWindowController]) -> [KeptWindow] {
        controllers.compactMap { controller in
            guard let window = controller.window, let identifier = window.identifier?.rawValue else { return nil }
            let archiver = NSKeyedArchiver(requiringSecureCoding: true)
            controller.window(window, willEncodeRestorableState: archiver)
            archiver.finishEncoding()
            return KeptWindow(identifier: identifier, state: archiver.encodedData, frame: window.frame)
        }
    }

    /// Restores a window as the system does at launch: its restoration class hears its identifier and its state,
    /// and the window it gives back stands where it stood.
    private static func restore(_ window: KeptWindow) {
        guard let state = try? NSKeyedUnarchiver(forReadingFrom: window.state) else { return }
        AppKitWindowRestorer.restoreWindow(
            withIdentifier: NSUserInterfaceItemIdentifier(window.identifier), state: state) { restored, _ in
                restored?.setFrame(window.frame, display: false)
            }
    }

    /// What the system keeps of a window between launches.
    struct KeptWindow {
        let identifier: String
        let state: Data
        let frame: NSRect
    }

    /// One pass of the main loop, what AppKit autoreleases in it let go as it ends.
    func step() {
        guard let renderer else { return }
        autoreleasepool {
            RunLoop.current.run(until: Date(timeIntervalSinceNow: 0.01))
            _ = renderer.runtime.core.runJobs()
            renderer.runtime.pump.turn()
            if renderer.frameClock.held { renderer.displayFrameForTesting() }
            layOutWindows()
        }
    }

    /// Lays each window out as the display cycle does: the windows stand off the screen, where none runs. A user
    /// sees a window laid out, and acts on it laid out.
    /// Design: docs/design/platforms/appkit/conformance.md#windows
    func layOutWindows() {
        for controller in renderer?.windowsForTesting ?? [] { controller.window?.layoutIfNeeded() }
    }

    func turn() {
        renderer?.runtime.pump.turn()
    }

    func frame() {
        renderer?.displayFrameForTesting()
    }

    /// Where the element's view stands in its window, as AppKit placed it - measured down from the window's top.
    func place(of element: MountedElement) throws -> Rect {
        guard let view = (element.native as? AppKitElement)?.view, let window = view.window,
              let content = window.contentView
        else { throw DriverCannot("read where \(element.type.name) stands") }
        let frame = view.convert(view.bounds, to: nil)
        return Rect(
            x: frame.minX, y: content.bounds.height - frame.maxY, width: frame.width, height: frame.height)
    }

    func held(_ property: Prop, on element: MountedElement) throws -> HostValue? {
        layOutWindows()
        if element.type == .window { return try windowHolds(property, element) }
        if element.type == .menuItem || element.type == .toolbarItem { return try itemHolds(property, element) }
        if element.type == .pin { return try pinHolds(property, element) }
        if let map = (element.native as? AppKitElement)?.view as? AppKitMapView, let held = mapHolds(property, map) {
            return held
        }
        if let web = (element.native as? AppKitElement)?.view as? AppKitWebView, let held = webHolds(property, web) {
            return held
        }
        if property == .barTitle || property == .barSubtitle { return try titleAreaHolds(property, element) }
        if property == .barBackgroundColor { return try barHolds(element) }
        // Whether a page offers the way back: the window's toolbar holds its back item while the page shows.
        if property == .hasBackButton, element.type == .page {
            return (try controller(of: element).toolbarForTesting.itemForTesting(AppKitWindowToolbar.back) != nil).propValue
        }
        let view = (element.native as? AppKitElement)?.view
        switch (property, view) {
        case (.layoutDirection, let view?):
            return (view.userInterfaceLayoutDirection == .rightToLeft ? LayoutDirection.rightToLeft : .leftToRight).propValue
        case (.selectedItems, let items as AppKitItemsView): return .strings(items.selectedForTesting)
        case (.selectionMode, let items as AppKitItemsView): return items.modeForTesting.propValue
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
        case (.text, let label as AppKitTextView): return label.stringValue.propValue
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
        case (.tint, let picker as AppKitPickerView): return picker.contentTintForTesting.map { Self.color($0).propValue }
        case (.tint, let check as AppKitCheckBoxView): return check.contentTintColor.map { Self.color($0).propValue }
        case (.tint, let slider as AppKitSliderView): return slider.trackFillColor.map { Self.color($0).propValue }
        case (.date, let picker as AppKitDatePickerView): return picker.date.propValue
        case (.minimumDate, let picker as AppKitDatePickerView): return picker.earliestForTesting?.propValue
        case (.maximumDate, let picker as AppKitDatePickerView): return picker.latestForTesting?.propValue
        case (.time, let picker as AppKitTimePickerView): return picker.time.propValue
        case (.currentPage, let tabs as AppKitTabbedView): return tabs.selectedIndexForTesting.propValue
        case (.isSidebarVisible, let split as AppKitSplitView): return split.isEffectivelyPresentedForTesting.propValue
        // Shown: in a window, and neither it nor any view it stands in hidden.
        case (.isVisible, let view?): return (view.window != nil && !view.isHiddenOrHasHiddenAncestor).propValue
        case (.opacity, let view?): return Double(view.alphaValue).propValue
        case (.isEnabled, let field as AppKitTextFieldView): return field.textField.isEnabled.propValue
        case (.isReadOnly, let field as AppKitTextFieldView): return (!field.textField.isEditable).propValue
        case (.isReadOnly, let search as AppKitSearchFieldView): return (!search.isEditable).propValue
        // A text view takes input while the user can edit or select it, and is read only while they can only select.
        case (.isEnabled, let editor as AppKitTextEditorView):
            return (editor.textView.isEditable || editor.textView.isSelectable).propValue
        case (.isReadOnly, let editor as AppKitTextEditorView):
            return (!editor.textView.isEditable && editor.textView.isSelectable).propValue
        case (.isEnabled, let control as NSControl): return control.isEnabled.propValue
        case (.isEnabled, let picker as AppKitPickerView): return picker.isEnabled.propValue
        case (_, let view?):
            if let held = try Self.viewHolds(property, view, element.native as? AppKitElement) { return held }
            throw DriverCannot(reading: property, of: element)
        default: throw DriverCannot(reading: property, of: element)
        }
    }

    /// Tests/Resources/Images: the pictures the cases name.
    static let pictures = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent()    // Conformance
        .deletingLastPathComponent()    // Tests
        .appendingPathComponent("Resources/Images")
}
#endif
