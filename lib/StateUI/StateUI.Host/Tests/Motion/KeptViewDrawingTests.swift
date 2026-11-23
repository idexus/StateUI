// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) @testable import StateUI
@_spi(Host) @testable import StateUIHost
import XCTest

/// Whether the app below is open, and how far the hand has lifted it - a state a short spring carries.
@MainActor private let appOpen = State(wrappedValue: true)
@MainActor private let appLift = State(wrappedValue: 0.0)

/// An app whose holder the hand lifts, its view of one id with the icon it closes onto.
private struct LiftedApp: View {
    var body: some View {
        VStack {
            if appOpen.wrappedValue {
                ZStack { Rectangle().id("app").transition(id: "app") }
                    .translationY(appLift.projectedValue)
            } else {
                HStack { Rectangle().id("app").transition(id: "app") }
            }
        }
    }
}

private struct LiftedAppApplication: Application {
    var body: some Scene { WindowGroup { LiftedApp() } }
}

/// A native half that draws what its element says, as a toolkit does: the numbers it was last told to draw.
@MainActor
private final class DrawingView: NativeElement {
    weak var element: MountedElement?
    var drawn: [Prop: Double] = [:]
    let presentsView = true
    var keepsExits: Bool { true }

    init(_ element: MountedElement) { self.element = element }

    func measured(width: Double?, height: Double?) -> HostChildMeasured { HostChildMeasured(size: .zero, firstBaseline: nil) }
    func standingValue(_ property: Prop) -> HostValue? { nil }
    func animates(_ property: Prop) -> Bool { true }
    func applied(changed: Set<Prop>, wasDescribed: Bool) { draw(changed) }
    func presentFrame(_ changed: Set<Prop>) { draw(changed) }
    func deactivate() {}
    func releasePresentation() {}
    func frameNumbers() -> [Double]? { [0, 0, 300, 500, 0, 100, 0, 100] }
    func arrangeChildren() {}
    func orderChildren() {}
    func invalidateMeasurements() {}
    func configureLayoutMotion() {}

    private func draw(_ changed: Set<Prop>) {
        for property in changed.intersection(MountedElement.transformProperties) {
            drawn[property] = element?.value(property)?.number
        }
    }
}

/// A view kept for the partner its patch may make is drawn as the tree holds it: what its toolkit draws and what a
/// shared presentation reads of it are one.
/// Design: docs/design/host/motion.md#a-shared-presentation-drawn-by-both
@MainActor
final class KeptViewDrawingTests: XCTestCase {
    /// A host's presenter, so its frames present what moves, as a toolkit's do.
    private final class Presenting: HostPresenter {
        func presentRendered(touchedChrome: Bool) {}
        func presentFrame(movedChrome: Bool) {}
        func perform(_ call: HostActCall) {}
        func open(link address: String) {}
        func focus(_ element: MountedElement) {}
    }

    private let clock = WoundClock()
    private let presenter = Presenting()
    private var runtime: HostRuntime?
    private var views: [ObjectIdentifier: DrawingView] = [:]

    override func setUp() async throws {
        appOpen.wrappedValue = true
        appLift.projectedValue.journey.snap(to: 0)
        LiftedAppApplication.register()
        runtime = HostRuntime(clock: clock, reducesMotion: { false }, makeNative: { [unowned self] element in
            let view = DrawingView(element)
            views[ObjectIdentifier(element)] = view
            return view
        }, log: { _ in })
        runtime?.presenter = presenter
        runtime?.connectWindow()
        step(0)
    }

    override func tearDown() async throws {
        runtime = nil
        views = [:]
    }

    private func step(_ milliseconds: Double) {
        clock.time += milliseconds
        runtime?.pump.turn()
        runtime?.displayCycle.frame(now: clock.time)
        runtime?.pump.turn()
    }

    /// THE HAND LIFTS THE APP, AND IT CLOSES BETWEEN TWO FRAMES: the holder kept for the icon is drawn where the tree
    /// holds it - not where its last frame left it while the tree holds it farther on.
    func testAViewKeptForItsPartnerIsDrawnAsItIsHeld() throws {
        let holder = try XCTUnwrap(runtime?.tree.root?.first(type: .zStack))
        _ = appLift.projectedValue.journey.move(to: -200, .spring(response: .milliseconds(80), damping: 1))
        step(16)
        step(16)
        let lifted = try XCTUnwrap(views[ObjectIdentifier(holder)]?.drawn[.translationY])
        XCTAssertLessThan(lifted, -20, "the hand's lift is drawn as it moves")

        appOpen.wrappedValue = false
        step(9)

        XCTAssertEqual(holder.lifecycle, .exiting, "kept for the icon")
        let held = try XCTUnwrap(holder.value(.translationY)?.number)
        let drawn = try XCTUnwrap(views[ObjectIdentifier(holder)]?.drawn[.translationY])
        XCTAssertEqual(drawn, held, accuracy: 0.001, "what its toolkit draws is what the tree holds")
    }
}
