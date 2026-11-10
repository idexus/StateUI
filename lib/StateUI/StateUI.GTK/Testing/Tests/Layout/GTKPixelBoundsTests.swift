// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI
@_spi(Host) import StateUIHost
@testable import StateUIGTK
@testable import StateUIGTKDriver
import XCTest

@MainActor
final class GTKPixelBoundsTests: XCTestCase {
    /// A size GTK cannot hold - finite, but past its 32-bit pixels - stands empty, and the tree goes on past it.
    func testAViewWiderThanGTKHoldsStandsEmptyAndTheTreeGoesOn() {
        onUIThread {
            let host = GTKRenderer.running {
                VStack {
                    Text("wide").width(3e9)
                    Text("after")
                }
            }
            XCTAssertEqual(host.views(GTKTextView.self).count, 2, "the tree stood past the unholdable width")
        }
    }

    /// GTK's pixels: sizes and coordinates within 32 bits, a margin within the 16 GTK keeps of it.
    func testPixelsKeepWithinWhatGTKHolds() {
        XCTAssertEqual(GTKPixels.size(12.4), 12)
        XCTAssertEqual(GTKPixels.size(12.2, rounding: .up), 13)
        for points in [3e9, -5, .nan, .infinity] {
            XCTAssertEqual(GTKPixels.size(points), 0, "\(points)")
        }
        XCTAssertEqual(GTKPixels.distance(-7.6, rounding: .up), -7)
        XCTAssertEqual(GTKPixels.distance(-3e9), 0)
        XCTAssertEqual(GTKPixels.margin(Double(Int16.max)), Int32(Int16.max))
        XCTAssertEqual(GTKPixels.margin(Double(Int16.max) + 1), 0, "GTK refuses a margin past 16 bits")
    }

    /// Numbers past what GTK counts - its 32-bit pixels, Pango's 1024ths of a point, a label's lines - stop nothing:
    /// each stands as none, or at what GTK holds.
    func testNumbersPastWhatGTKCountsStopNothing() throws {
        onUIThread {
            let host = GTKRenderer.running { PastCountsPage() }
            host.settle { host.views(GTKTextView.self).count == 3 }

            XCTAssertEqual(host.views(GTKTextView.self).map(\.text).sorted(), ["Lines", "Padded", "Spaced"])
            XCTAssertEqual(host.views(GTKButtonView.self).count, 1)
            XCTAssertEqual(host.views(GTKImageView.self).count, 1)
            XCTAssertNotNil(host.window)
        }
    }
}

/// A page whose every number is past what GTK counts, its window's sizes too.
private struct PastCountsPage: View {
    @Environment(\.window) private var window

    var body: some View {
        let window = self.window
        return VStack {
            Text("Spaced").tracking(1e300).fontSize(1e300)
            Text("Padded").padding(Insets(1e300))
            Text("Lines").maximumLines(3_000_000_000)
            Button("Share").icon(.icon(.share)).iconSpacing(1e300)
            Image(.icon(.add)).width(1e300).height(1e300)
        }
        .onCreated {
            window.width = 1e300
            window.height = 1e300
            window.minimumWidth = 1e300
            window.minimumHeight = 1e300
        }
    }
}
