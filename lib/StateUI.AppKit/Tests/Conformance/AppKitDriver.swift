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
        renderer?.closeForTesting()
        stateUIUseApp(OneWindowApplication(page: page))
        let renderer = testRenderer(
            resourceDirectory: Self.pictures, clock: clock.map { clock in { clock.now } },
            reducesMotion: { reducesMotion })
        self.renderer = renderer
        renderer.startForTesting()
        comeToTheFront(renderer.windowsForTesting.first?.window)
        return renderer.tree
    }

    func step() {
        guard let renderer else { return }
        RunLoop.current.run(until: Date(timeIntervalSinceNow: 0.01))
        _ = renderer.core.runJobs()
        renderer.pump()
        if renderer.frameClock.held { renderer.displayFrameForTesting() }
    }

    func turn() {
        renderer?.pump()
    }

    func frame() {
        renderer?.displayFrameForTesting()
    }

    func perform(_ act: UserAct, on element: MountedElement) throws {
        let view = (element.native as? AppKitElement)?.view
        switch (act, view) {
        case (.activate, let button as AppKitButtonView): button.performClick(nil)
        case (.activate, let radio as AppKitRadioButtonView): radio.performClick(nil)
        case (.toggle, let toggle as AppKitSwitchView): _ = toggle.accessibilityPerformPress()
        case (.toggle, let check as AppKitCheckBoxView): check.performClick(nil)
        case (.slide(let value), let slider as AppKitSliderView):
            slider.doubleValue = value
            slider.sendAction(slider.action, to: slider.target)
        case (.step(let up), let stepper as AppKitStepperView):
            // What a click on either arrow does: the value one increment on, within the range, then the action.
            let stepped = stepper.doubleValue + (up ? stepper.increment : -stepper.increment)
            stepper.doubleValue = min(max(stepped, stepper.minValue), stepper.maxValue)
            stepper.sendAction(stepper.action, to: stepper.target)
        case (.type(let words), let field as AppKitTextFieldView): try type(words, into: field.textField)
        case (.type(let words), let search as AppKitSearchFieldView): try type(words, into: search)
        case (.type(let words), let editor as AppKitTextEditorView): try type(words, into: editor.textView)
        case (.submit, let field as AppKitTextFieldView): try submit(field.textField)
        case (.submit, let search as AppKitSearchFieldView): try submit(search)
        case (.choose(let place), let picker as AppKitPickerView): picker.chooseForTesting(index: place)
        case (.switchAway, _) where element.type == .window:
            for window in windows { tell(NSWindow.didResignKeyNotification, window) }
            renderer?.applicationResignedActive()
        case (.switchBack, _) where element.type == .window:
            renderer?.applicationBecameActive()
            comeToTheFront(try window(of: element))
        case (.bringToFront, _) where element.type == .window:
            let front = try window(of: element)
            for window in windows where window !== front { tell(NSWindow.didResignKeyNotification, window) }
            comeToTheFront(front)
        case (.minimize, _) where element.type == .window:
            let window = try window(of: element)
            tell(NSWindow.didResignKeyNotification, window)
            tell(NSWindow.didMiniaturizeNotification, window)
        case (.restore, _) where element.type == .window:
            let window = try window(of: element)
            tell(NSWindow.didDeminiaturizeNotification, window)
            comeToTheFront(window)
        case (.close, _) where element.type == .window: try window(of: element).close()
        default: throw DriverCannot(act, on: element)
        }
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
        case (.isVisible, let view?): return (!view.isHidden).propValue
        case (.opacity, let view?): return Double(view.alphaValue).propValue
        case (.isEnabled, let control as NSControl): return control.isEnabled.propValue
        case (.isEnabled, let picker as AppKitPickerView): return picker.isEnabled.propValue
        default: throw DriverCannot(reading: property, of: element)
        }
    }

    /// The native windows the host shows, in the tree's order.
    private var windows: [NSWindow] {
        renderer?.windowsForTesting.compactMap(\.window) ?? []
    }

    /// The native window `element` stands in.
    private func window(of element: MountedElement) throws -> NSWindow {
        guard let window = renderer?.windowsForTesting.first(where: { $0.node?.element === element })?.window else {
            throw DriverCannot("find the window")
        }
        return window
    }

    /// Tells `window`'s delegate what AppKit tells it, as `name` is posted by the window itself.
    private func tell(_ name: Notification.Name, _ window: NSWindow) {
        NotificationCenter.default.post(name: name, object: window)
    }

    /// `window` comes to the front and takes the keyboard, as AppKit tells a window it brings forward. The driver
    /// shows no window on the machine's screen, so no run takes the user's.
    /// Design: docs/design/platforms/appkit/conformance.md#windows
    private func comeToTheFront(_ window: NSWindow?) {
        guard let window else { return }
        tell(NSWindow.didBecomeKeyNotification, window)
    }

    /// Tests/Resources/Images: the pictures the cases name.
    static let pictures = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent()    // Conformance
        .deletingLastPathComponent()    // Tests
        .appendingPathComponent("Resources/Images")

    /// Types `words` as the whole of a field's words, through the editor AppKit gives the field that holds the
    /// keyboard: what a user's typing reports, the field reports.
    private func type(_ words: String, into field: NSTextField) throws {
        guard let window = field.window, window.makeFirstResponder(field),
              let editor = field.currentEditor() as? NSTextView
        else { throw DriverCannot("type into a field with no editor") }
        editor.selectAll(nil)
        editor.insertText(words, replacementRange: editor.selectedRange())
    }

    /// Types `words` as the whole of an editor's words, as the keyboard does.
    private func type(_ words: String, into editor: NSTextView) throws {
        guard let window = editor.window, window.makeFirstResponder(editor) else {
            throw DriverCannot("type into an editor in no window")
        }
        editor.selectAll(nil)
        editor.insertText(words, replacementRange: editor.selectedRange())
    }

    /// Presses Return in `field`, which ends its editing as the keyboard's Return does.
    private func submit(_ field: NSTextField) throws {
        guard let window = field.window, window.makeFirstResponder(field),
              let editor = field.currentEditor() as? NSTextView
        else { throw DriverCannot("submit a field with no editor") }
        editor.insertNewline(nil)
    }
}
#endif
