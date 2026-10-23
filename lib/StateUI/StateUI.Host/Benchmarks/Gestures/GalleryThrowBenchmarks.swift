// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

import XCTest
@_spi(Host) import StateUI
@_spi(Host) import StateUIHost

/// A gallery of twelve cards thrown by the hand, frame by frame until it rests.
/// Design: docs/design/host/benchmarks.md#the-gestures
@MainActor
final class GalleryThrowBenchmarks: XCTestCase {
    /// A THROW RUNS ON THE FRAMES, rebuilding no card: each frame places the run, and the one render is the card in
    /// the middle changing.
    func testACardRunThrownUntilItRests() throws {
        let bench = Bench(GalleryApplication())
        let run = try bench.element(.layoutEngine)

        bench.hand(.began, on: run, at: Point(195, 350))
        for _ in 0..<5 {
            bench.frame()
            bench.hand(.changed, on: run, moved: Point(-40, 0))
        }
        bench.hand(.ended, on: run, speed: Point(-2_400, 0))
        let work = bench.measure("gallery, a run of cards thrown, a frame", steps: 30) { _ in
            bench.frame()
        }

        XCTAssertEqual(work, Work(
            renders: 1, built: 1, walks: 0, texts: 0, made: 0, applied: 0, arranged: 1, presented: 26, placed: 300,
            left: 0))
    }
}

private struct GalleryApplication: Application {
    var body: some Scene {
        WindowGroup { CardsPage() }
    }
}

/// Twelve cards, each a picture and its name.
private struct CardsPage: View {
    @State private var shown = 0

    var body: some View {
        GalleryView((0..<12).map { "Card \($0)" }, id: \.self) { name in
            ZStack {
                Rectangle()
                    .fill(Color(hex: 0x0D9488))
                    .cornerRadius(16)
                Text(name)
                    .fontSize(18)
                    .padding(horizontal: 12, vertical: 10)
            }
        }
        .position($shown)
    }
}
