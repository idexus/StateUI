// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI
@_spi(Host) import StateUIHost

/// `BackgroundElementContract` on a host, on each element wearing the tier, in the place it stands.
@_spi(Host) public enum BackgroundElementTests: ConformanceFamily {
    public static let name = "BackgroundElement"

    public static var cases: [ConformanceCase] {
        [
            Aspects.holds(BackgroundElementContract.background, on: "TextSpan", .color(.yellow), then: .color(.cyan)),
        ] + (
            WindowTests.written + TextSpanTests.written + BarItemElementCases.written + PageElementTests.written
                + VisualElementTests.written
        ).proving(BackgroundElementContract.self)
    }
}
