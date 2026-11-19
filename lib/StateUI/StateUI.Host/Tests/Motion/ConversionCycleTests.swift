// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

import XCTest
@_spi(Host) @testable import StateUI
@_spi(Host) @testable import StateUIHost

/// A converted state through the real display cycle: the result's channel travels under its own motion and reports
/// every frame, and no frame of it is ever a write into the source; the user's take of the control is.
@MainActor
final class ConversionCycleTests: XCTestCase {
    /// A source at 0.123 shown in rounded hundredths. Sent to 0.5, the result travels 12 to 50 frame by frame while
    /// the source stands at 0.5 exactly; the user taking the thumb to 40 writes 0.4, once.
    func testTheResultsFramesNeverWriteTheSourceAndTheUsersTakeDoes() throws {
        let model = Volume()
        shared = model
        defer { shared = nil }
        Renderer.shared.setApplication(PercentApplication())
        let clock = WoundClock()
        let runtime = HostRuntime(clock: clock, reducesMotion: { false }, makeNative: { _ in NoView() }, log: { _ in })
        runtime.connectWindow()
        runtime.pump.turn()
        let slider = try XCTUnwrap(runtime.tree.root?.first(type: .slider))
        let binding = try XCTUnwrap(slider.driven[.value])
        XCTAssertEqual(slider.number(.value), 12, "0.123 in rounded hundredths")
        XCTAssertEqual(runtime.stateChannels.count, 1, "the result has a channel; its source is plain data")

        model.volume = 0.5
        runtime.pump.turn()
        var shown: [Double] = []
        while clock.time < 400 {
            clock.time += 16
            runtime.displayCycle.frame(now: clock.time)
            runtime.pump.turn()
            shown.append(slider.number(.value) ?? .nan)
            XCTAssertEqual(model.volume, 0.5, "a frame of the result went back to its source")
        }
        XCTAssertTrue(shown.contains { $0 > 12 && $0 < 50 }, "the result traveled: \(shown.prefix(6))")
        XCTAssertEqual(shown.last, 50)

        XCTAssertTrue(runtime.take([40], through: binding))
        runtime.pump.turn()
        XCTAssertEqual(model.volume, 0.4, "the user's take landed on the source")
        XCTAssertEqual(slider.number(.value), 40)
    }
}

/// The source.
@MainActor
private final class Volume {
    @State var volume = 0.123
}

/// The model the page under test shows.
@MainActor private var shared: Volume? {
    get { held }
    set { held = newValue ?? Volume() }
}

@MainActor private var held = Volume()

private struct PercentApplication: Application {
    var body: some Scene { WindowGroup { PercentPage() } }
}

private struct PercentPage: View {
    var body: some View {
        Slider(held.$volume.convert(
            { ($0 * 100).rounded() }, back: { $0 / 100 }, motion: .eased(.milliseconds(200), curve: .linear)))
            .maximum(100)
    }
}
