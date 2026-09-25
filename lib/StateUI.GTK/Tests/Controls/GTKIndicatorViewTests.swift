// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI
@testable import StateUIGTK
import XCTest

/// A spinner a click stops.
private struct SpinnerPage: ContentView {
    @State private var running = true

    var content: any View {
        VStack {
            ActivityIndicator(running)
            Button("Stop").onClicked { running = false }
        }
    }
}

final class GTKIndicatorViewTests: XCTestCase {
    /// A bar fills in its tint as far as its work went, and no further; a fraction past the end is the end.
    func testABarFillsInItsTintAsFarAsItsWorkWent() {
        onUIThread {
            let host = GTKRenderer.running {
                VStack {
                    ProgressBar(0.5).tint(Color("#FF0000")).width(200).height(8)
                    ProgressBar(1.5).width(200).height(8)
                }
                .horizontalAlignment(.start)
                .verticalAlignment(.start)
            }
            let bars = host.views(GTKProgressBarView.self)
            host.settle { bars[0].pixels(at: [(20, 4)]) == [0xFFFF_0000] }

            XCTAssertEqual(bars[0].pixels(at: [(20, 4), (180, 4)]).map { $0 == 0xFFFF_0000 }, [true, false])
            XCTAssertEqual(bars.map(\.progress), [0.5, 1])
        }
    }

    /// A spinner turns while its work runs, and stops when it stops.
    func testASpinnerTurnsWhileItsWorkRuns() throws {
        try onUIThread {
            let host = GTKRenderer.running { SpinnerPage() }
            let spinner = try XCTUnwrap(host.views(GTKActivityIndicatorView.self).first)
            XCTAssertTrue(spinner.isRunning)

            try XCTUnwrap(host.views(GTKButtonView.self).first).click()
            host.settle { !spinner.isRunning }

            XCTAssertFalse(spinner.isRunning)
        }
    }
}
