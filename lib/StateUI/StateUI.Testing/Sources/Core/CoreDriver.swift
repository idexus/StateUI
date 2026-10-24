// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI
@_spi(Host) import StateUIConformance
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

    func start(
        clock: TestClock?, reducesMotion: Bool, @ViewBuilder _ page: @escaping @MainActor () -> any View
    ) -> MountedTree {
        stateUIUseApp(OneWindowApplication(page: page))
        let runtime = HostRuntime(
            clock: self.clock, reducesMotion: { reducesMotion }, makeNative: { _ in CoreView() }, log: { _ in })
        runtime.presenter = self
        self.runtime = runtime
        runtime.connectWindow()
        runtime.pump.turn()
        return runtime.tree
    }

    func step() {
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

    func perform(_ act: UserAct, on element: MountedElement) throws {
        guard let runtime else { throw DriverCannot(act, on: element) }
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
            element.reportUserChange(.text, .textChanged, .string(words), in: runtime)
        case .submit:
            element.send(.submitted, [], in: runtime)
        case .slide(let value):
            element.reportUserChange(.value, .valueChanged, .number(value), in: runtime)
        case .choose(let place):
            element.reportUserChange(.selectedIndex, .selectedIndexChanged, place.propValue, in: runtime)
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
}

/// No windows around the tree: what a test reads is the tree's, and an act - a question, a file - is answered as a
/// host answers one it cannot perform.
extension CoreDriver: HostPresenter {
    func presentRendered(touchedChrome: Bool) {}
    func presentFrame(movedChrome: Bool) {}

    func perform(_ call: HostActCall) {
        if let completion = call.completion { runtime?.core.fail(completion, reason: "a test's window performs no act") }
    }

    func open(link address: String) {}

    func focus(_ element: MountedElement) {}
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
