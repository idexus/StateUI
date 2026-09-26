// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

import UIKit
@_spi(Host) import StateUI
@_spi(Host) import StateUIHost
@testable import StateUIUIKit
@_spi(Host) import StateUIConformance

/// The UIKit host as the conformance suite drives it: each user's act through the control event or the delegate
/// call UIKit's own input takes into the host, and each read from the control itself.
/// Design: docs/design/host/conformance.md#the-driver
@MainActor
final class UIKitDriver: HostDriver {
    let host = "UIKit"
    let cannot: [String: String] = [:]

    /// What the families ask of a driver that UIKit's has no path for yet says so, and stays empty in UIKit's column
    /// with why, rather than failing.
    func reason(cannot ability: String) -> String? {
        cannot[ability] ?? "UIKit's driver has no path for it yet"
    }

    /// The host the driver started last.
    private(set) var renderer: UIKitRenderer?

    var register: HostRegister { UIKitRealization.register }

    func start(clock: TestClock?, reducesMotion: Bool, _ page: @escaping @Sendable () -> any Page) -> MountedTree {
        finish()
        let renderer = UIKitRenderer.running(clock: clock, reducesMotion: reducesMotion, page)
        self.renderer = renderer
        return renderer.runtime.tree
    }

    /// Ends the host the driver started last.
    func finish() {
        renderer?.finish()
        renderer = nil
    }

    func step() {
        guard let renderer else { return }
        RunLoop.current.run(until: Date(timeIntervalSinceNow: 0.01))
        _ = renderer.runtime.core.runJobs()
        renderer.runtime.pump.turn()
        renderer.layOut()
        if renderer.frameClock.held { renderer.frame() }
    }

    func turn() {
        renderer?.runtime.pump.turn()
        renderer?.layOut()
    }

    func frame() {
        renderer?.frame()
    }

    func perform(_ act: UserAct, on element: MountedElement) throws {
        let view = (element.native as? UIKitElement)?.view
        switch (act, view) {
        case (.activate, let button as UIKitButtonView): button.sendActions(for: .primaryActionTriggered)
        case (.type(let words), let field as UIKitTextFieldView):
            field.text = words
            field.sendActions(for: .editingChanged)
        case (.submit, let field as UIKitTextFieldView): _ = field.textFieldShouldReturn(field)
        default: throw DriverCannot(act, on: element)
        }
    }

    func held(_ property: Prop, on element: MountedElement) throws -> HostValue? {
        let view = (element.native as? UIKitElement)?.view
        switch (property, view) {
        case (.text, let label as UIKitLabelView): return (label.text ?? "").propValue
        case (.text, let field as UIKitTextFieldView): return (field.text ?? "").propValue
        case (.text, let button as UIKitButtonView): return (button.configuration?.title ?? "").propValue
        case (.isVisible, let view?): return (!view.isHidden).propValue
        case (.opacity, let view?): return Double(view.alpha).propValue
        case (.isEnabled, let control as UIControl): return control.isEnabled.propValue
        default: throw DriverCannot(reading: property, of: element)
        }
    }
}
