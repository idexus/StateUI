// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

/// What the user asked of the system to use the device - less motion, more contrast, a screen reader, larger words -
/// as the host last reported it. Read it as the device's `accessibility`, `@Environment(\.device)`; the views that
/// read a setting build again when it changes.
///
///     @Environment(\.device) private var device
///
///     Rectangle()
///         .fill(.silver)
///         .height(device.accessibility.prefersHigherContrast ? 2 : 1)
///
/// A platform that cannot tell a setting leaves it as the system draws by default: `false`, and a scale of 1.
@MainActor
public final class AccessibilitySettings {
    /// Whether the user asked for less motion: a view moves less - StateUI's own animations already do - and a
    /// change shows at once or cross fades where it would travel.
    public internal(set) var reducesMotion: Bool {
        get { _reducesMotion }
        set { _reducesMotion = newValue }
    }

    @State private var _reducesMotion = false

    /// Whether the user asked for more contrast: lines drawn stronger, colors further apart.
    public internal(set) var prefersHigherContrast: Bool {
        get { _prefersHigherContrast }
        set { _prefersHigherContrast = newValue }
    }

    @State private var _prefersHigherContrast = false

    /// Whether a screen reader is running - a reason to say in words what a picture shows, never to make the
    /// application work otherwise.
    public internal(set) var isScreenReaderOn: Bool {
        get { _isScreenReaderOn }
        set { _isScreenReaderOn = newValue }
    }

    @State private var _isScreenReaderOn = false

    /// How much larger than the system's own size the user asked words to be: 1 as it draws them, 1.3 for 30 %
    /// larger.
    public internal(set) var textScale: Double {
        get { _textScale }
        set { _textScale = newValue }
    }

    @State private var _textScale: Double = 1

    /// Settings as a test or a preview fakes them, for one branch with `.environment(...)`; what is not said starts
    /// as a headless host's does.
    ///
    ///     Device(accessibility: AccessibilitySettings(reducesMotion: true))
    public init(
        reducesMotion: Bool = false, prefersHigherContrast: Bool = false, isScreenReaderOn: Bool = false,
        textScale: Double = 1
    ) {
        self.reducesMotion = reducesMotion
        self.prefersHigherContrast = prefersHigherContrast
        self.isScreenReaderOn = isScreenReaderOn
        self.textScale = textScale
    }
}
