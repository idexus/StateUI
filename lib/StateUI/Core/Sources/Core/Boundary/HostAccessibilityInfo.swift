// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

/// The user's accessibility settings supplied by a native host, whenever the platform reports a change.
@_spi(Host) public struct HostAccessibilityInfo: Equatable, Sendable {
    /// Whether the user asked for less motion.
    public let reducesMotion: Bool

    /// Whether the user asked for more contrast.
    public let prefersHigherContrast: Bool

    /// Whether a screen reader is running.
    public let isScreenReaderOn: Bool

    /// How much larger than the system's own size the user asked words to be.
    public let textScale: Double

    /// A complete report.
    public init(reducesMotion: Bool, prefersHigherContrast: Bool, isScreenReaderOn: Bool, textScale: Double) {
        self.reducesMotion = reducesMotion
        self.prefersHigherContrast = prefersHigherContrast
        self.isScreenReaderOn = isScreenReaderOn
        self.textScale = textScale
    }
}
