// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI
@_spi(Host) import StateUIHost

/// The window of a test with no platform's toolkit: the core and the host layer on a clock the window winds, each
/// view a native half that keeps nothing - so what a view holds is what the tree gave it, and a user's act is the
/// report a host makes of it.
/// Design: docs/design/host/testing.md#a-window-with-no-toolkit
@MainActor
final class CoreDriver: HostDriver {
    let host = "Core"
    let register = HostRegister(records: [])
    let cannot: [String: String] = [:]

    private var runtime: HostRuntime?
    private let clock = CoreClock()

    /// The window's presentation: what a host's window controller keeps, so the page hears it is shown.
    private var presentation = WindowPresentation()

    /// The element holding the keyboard; nil for none.
    private weak var focused: MountedElement?

    func start(
        clock: TestClock?, reducesMotion: Bool, @ViewBuilder _ page: @escaping @MainActor () -> any View
    ) -> MountedTree {
        Renderer.shared.setApplication(OneWindowApplication(page: page))
        let runtime = HostRuntime(
            clock: self.clock, reducesMotion: { reducesMotion }, makeNative: { _ in CoreView() }, log: { _ in })
        runtime.presenter = self
        self.runtime = runtime
        presentation = WindowPresentation()
        runtime.connectWindow()
        runtime.pump.turn()
        return runtime.tree
    }

    func step() {
        guard runtime != nil else {
            _ = HostBoundary.runJobs()
            return
        }
        frame()
        turn()
    }

    func turn() {
        runtime?.pump.turn()
    }

    func frame() {
        clock.time += 1_000 / 60
        runtime?.displayCycle.frame(now: clock.time)
    }

    func close() {
        runtime?.tree.root?.leave()
        runtime = nil
        clock.held = false
        clock.onFrame = nil
        presentation = WindowPresentation()
        focused = nil
    }

    func perform(_ act: StateUIHost.UserAct, on element: MountedElement) throws {
        // As the user: nothing on a disabled view, no words into a read-only field, words as the field holds them;
        // a step, a day, a time and a color as the control offers them, by the host layer's rules.
        // Design: docs/design/host/testing.md#a-window-with-no-toolkit
        guard let runtime else { throw DriverCannot(act, on: element) }
        guard element.isEffectivelyEnabled else { throw DriverCannot("\(act) on \(element.type.name)", because: "it is disabled") }
        switch act {
        case .activate where element.handler(.clicked) != nil:
            element.send(.clicked, [], in: runtime)
        case .activate, .tap(count: 1):
            guard element.hear(.tap(run: 1), in: runtime) else { throw DriverCannot(act, on: element) }
        case .tap(let count):
            for run in 1...max(count, 1) { element.hear(.tap(run: run), in: runtime) }
        case .toggle:
            let on = element.value(.isOn)?.bool ?? false
            element.reportUserChange(.isOn, .toggled, .bool(!on), in: runtime)
        case .type(let words):
            guard element.value(.isReadOnly)?.bool != true else {
                throw DriverCannot("\(act) on \(element.type.name)", because: "it is read-only")
            }
            let held = InputWords.held(
                words, in: element.value(.textCase)?.enumeration.flatMap(TextCase.init(rawValue:)),
                toBound: element.whole(.maximumLength), composing: false)
            element.reportUserChange(.text, .textChanged, .string(held ?? words), in: runtime)
        case .submit:
            element.send(.submitted, [], in: runtime)
        case .slide(let value):
            element.reportUserChange(.value, .valueChanged, .number(value), in: runtime)
        case .choose(let place):
            element.reportUserChange(.selectedIndex, .selectedIndexChanged, place.propValue, in: runtime)
        case .step(let up) where element.type == .stepper:
            try step(up: up, on: element, in: runtime)
        case .pickDate(let day) where element.type == .datePicker:
            let range = (element.value(DatePickerContract.minimum.token), element.value(DatePickerContract.maximum.token))
            guard CalendarArithmetic.held(day, earliest: range.0.flatMap(CalendarDate.init(propValue:)),
                                          latest: range.1.flatMap(CalendarDate.init(propValue:))) == day else {
                throw DriverCannot("\(act) on \(element.type.name)", because: "its calendar offers no such day")
            }
            element.reportUserChange(DatePickerContract.date.token, .dateChanged, day.propValue, in: runtime)
        case .pickTime(let time) where element.type == .timePicker:
            guard CalendarArithmetic.clock(time) == time else {
                throw DriverCannot("\(act) on \(element.type.name)", because: "its clock shows no such time")
            }
            element.reportUserChange(.time, .timeChanged, time.propValue, in: runtime)
        case .pickColor(let color) where element.type == .colorPicker:
            let chosen = ColorChoice.reported(
                color.propValue.fractions ?? (0, 0, 0, 1),
                choosesOpacity: element.bool(ColorPickerContract.choosesOpacity.token) ?? false)
            element.reportUserChange(.color, .colorChanged, chosen.propValue, in: runtime)
        case .focus where Wearing.element(element.type, wears: FocusElementContract.self) != false:
            moveFocus(to: element, in: runtime)
        case .performAccessibilityAction(let name):
            guard element.hear(.accessibilityAction(name), in: runtime) else { throw DriverCannot(act, on: element) }
        case .adjust(let step):
            guard element.hear(.accessibilityAdjustment(step), in: runtime) else { throw DriverCannot(act, on: element) }
        default:
            throw DriverCannot(act, on: element)
        }
    }

    func held(_ property: Prop, on element: MountedElement) throws -> HostValue? {
        element.presented(property)
    }

    /// None served: a test window's requests go where its application sends them.
    func served() throws -> String {
        throw DriverCannot("serve a request")
    }

    /// None held: the window stands up no server.
    func held() throws -> (taken: Int, stopped: Int) {
        throw DriverCannot("count the requests held")
    }

    /// One step of a stepper, as its buttons take it: none where its way is at the range's end.
    private func step(up: Bool, on element: MountedElement, in runtime: HostRuntime) throws {
        let given = ValueArithmetic.ends(
            of: element.type, minimum: element.number(RangeElementContract.minimum.token),
            maximum: element.number(RangeElementContract.maximum.token))
        let ends = ValueArithmetic.range(given.minimum, given.maximum)
        let value = element.number(RangeElementContract.value.token) ?? ends.lower
        let ways = ValueArithmetic.stepsWay(value, lower: ends.lower, upper: ends.upper)
        guard up ? ways.up : ways.down else {
            throw DriverCannot("step on \(element.type.name)", because: "it stands at the end of its range")
        }
        let stepped = ValueArithmetic.step(
            from: value, up: up, step: ValueArithmetic.step(element.number(StepperContract.step.token)), lower: ends.lower,
            upper: ends.upper)
        element.reportUserChange(RangeElementContract.value.token, .valueChanged, .number(stepped), in: runtime)
    }

    /// The keyboard moved to `element`: every element following the focus hears where it now is, as a host's
    /// toolkit tells it.
    private func moveFocus(to element: MountedElement, in runtime: HostRuntime) {
        focused = element
        runtime.tree.root?.reportFocus(in: runtime) { $0 === self.focused }
    }
}

/// No windows around the tree: the one window's page hears it is shown as a host's window shows it, what a test
/// reads is the tree's, and an act - a question, a file - is answered as a host answers one it cannot perform.
extension CoreDriver: HostPresenter {
    func presentRendered(touchedChrome: Bool) {
        guard let runtime, let window = runtime.tree.root?.windows.first else { return }
        _ = presentation.show(window, in: runtime.lifecycle)
    }

    func presentFrame(movedChrome: Bool) {}

    func perform(_ call: HostActCall) {
        if let completion = call.completion { runtime?.core.fail(completion, reason: "a test's window performs no act") }
    }

    func open(link address: String) {}

    func focus(_ element: MountedElement) {
        if let runtime { moveFocus(to: element, in: runtime) }
    }
}

/// The clock a test's window winds, a frame at a time.
@MainActor
private final class CoreClock: FrameClock {
    var time = 0.0
    var now: () -> Double { { [unowned self] in time } }
    var held = false
    var onFrame: ((Double) -> Void)?
}

/// A view's native half with nothing behind it: the tree holds what it shows.
@MainActor
private final class CoreView: NativeElement {
    let presentsView = true
    func standingValue(_ property: Prop) -> HostValue? { nil }
    func animates(_ property: Prop) -> Bool { false }
    func applied(changed: Set<Prop>, wasDescribed: Bool) {}
    func presentFrame(_ changed: Set<Prop>) {}
    func arrangeChildren() {}
    func invalidateMeasurements() {}
    func configureLayoutMotion() {}
    func leave() {}
}
