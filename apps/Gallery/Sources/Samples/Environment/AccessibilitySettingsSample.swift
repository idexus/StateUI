import StateUI

/// What the user asked of the system to use the device - the device's, read by name: `device.accessibility`.
struct AccessibilitySettingsSample: SampleContent, ExampleContent {
    // listing: AccessibilitySettingsSample
    /// The settings, as the host last reported them.
    @Environment(\.device) var device
    // listing: end

    static let id = "accessibility-settings"
    static let title = "Accessibility Settings"
    static let summary = "Less motion, more contrast, a screen reader and larger words - as the user set them."

    // listing: AccessibilitySettingsSample
    var body: some View {
        let settings = device.accessibility

        return VStack {
            // Each setting is read here, so a change to one builds this
            // closure.
            DebugInfoLabel()

            Text("less motion · \(settings.reducesMotion ? "on" : "off")")
                .fontSize(15)
            Text("more contrast · \(settings.prefersHigherContrast ? "on" : "off")")
                .fontSize(15)
            Text("screen reader · \(settings.isScreenReaderOn ? "on" : "off")")
                .fontSize(15)
            Text("words · \(Int((settings.textScale * 100).rounded())) %")
                .fontSize(15)

            // A rule drawn stronger where the user asked for more contrast.
            Rectangle()
                .fill(settings.prefersHigherContrast ? Palette.accent : Palette.outline)
                .height(settings.prefersHigherContrast ? 3 : 1)
                .isAccessibilityHidden(true)
        }
        .spacing(10)
    }
    // listing: end

    var notes: (any View)? {
        Text("Turn on less motion, more contrast, a screen reader or larger text in the system's settings, "
            + "and the page follows. A setting a platform does not tell stays off, and the words at 100 %.")
            .fontSize(12)
            .textColor(Palette.subtle)
    }
}
