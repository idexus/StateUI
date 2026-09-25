// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

import CStateUIWinUI
@_spi(Host) import StateUI
@testable import StateUIWinUI
@_spi(Host) import StateUIHostConformance

/// The WinUI host as the conformance suite drives it: each user's act through UI Automation's pattern or the path
/// WinUI's own input takes, and each read from the control itself.
/// Design: docs/design/host/conformance.md#the-driver
@MainActor
final class WinUIDriver: HostDriver {
    let host = "WinUI 3"
    let cannot = [
        "submit on TextField":
            "WinUI raises a text box's KeyDown only from the keyboard; Enter is walked on HelloWorld's field",
    ]
    private var renderer: WinUIRenderer?

    var marks: HostMarks { WinUIRealization.marks }

    func start(clock: TestClock?, reducesMotion: Bool, _ page: @escaping @Sendable () -> any Page) -> MountedTree {
        let renderer = WinUIRenderer.running(clock: clock, reducesMotion: reducesMotion, page)
        self.renderer = renderer
        return renderer.runtime.tree
    }

    func step() {
        renderer?.step()
    }

    func turn() {
        renderer?.runtime.pump.turn()
    }

    func frame() {
        renderer?.frame()
    }

    func perform(_ act: UserAct, on element: MountedElement) throws {
        let view = (element.native as? WinUIElement)?.view
        switch (act, view) {
        case (.activate, let button as WinUIButtonView): stateui_winui_button_invoke(button.handle)
        case (.toggle, let toggle as WinUIToggleView): toggle.toggle()
        case (.slide(let value), let slider as WinUISliderView): slider.move(to: value)
        case (.step(let up), let stepper as WinUIStepperView): stateui_winui_stepper_step_as_user(stepper.handle, up)
        case (.enterWords(let words), let stepper as WinUIStepperView):
            stateui_winui_stepper_enter_as_user(stepper.handle, words)
        case (.type(let words), let search as WinUISearchFieldView):
            // A search box tells the words a moment after it takes them, as a key is told before the next is typed.
            search.type(words)
            for _ in 0..<150 {
                if element.value(.text)?.string == words { break }
                step()
            }
        case (.type(let words), let field as WinUIInputView): field.type(words)
        case (.submit, let search as WinUISearchFieldView): stateui_winui_search_submit_as_user(search.handle)
        case (.choose(let place), let picker as WinUIPickerView):
            stateui_winui_picker_choose_as_user(picker.handle, Int32(place))
        default: throw DriverCannot(act, on: element)
        }
    }

    func held(_ property: Prop, on element: MountedElement) throws -> HostValue? {
        let view = (element.native as? WinUIElement)?.view
        switch (property, view) {
        case (.isOn, let toggle as WinUIToggleView): return toggle.isOn.propValue
        case (.value, let slider as WinUISliderView): return slider.value.propValue
        case (.minimum, let slider as WinUISliderView): return slider.minimum.propValue
        case (.maximum, let slider as WinUISliderView): return slider.maximum.propValue
        case (.value, let stepper as WinUIStepperView): return stepper.value.propValue
        case (.progress, let bar as WinUIProgressBarView): return bar.progress.propValue
        case (.isRunning, let spinner as WinUIActivityIndicatorView): return spinner.isRunning.propValue
        case (.text, let label as WinUITextView): return label.text.propValue
        case (.text, let field as WinUIInputView): return field.text.propValue
        case (.text, let button as WinUIButtonView): return button.text.propValue
        case (.text, let radio as WinUIRadioButtonView): return radio.text.propValue
        case (.selectedIndex, let picker as WinUIPickerView): return picker.chosen < 0 ? nil : picker.chosen.propValue
        case (.options, let picker as WinUIPickerView): return picker.choices.propValue
        case (.isVisible, let view?): return stateui_winui_is_shown(view.handle).propValue
        case (.opacity, let view?): return stateui_winui_opacity(view.handle).propValue
        case (.isEnabled, let view?): return stateui_winui_is_enabled(view.handle).propValue
        default: throw DriverCannot(reading: property, of: element)
        }
    }
}
