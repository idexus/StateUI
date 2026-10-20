import StateUI

/// What the platform the gallery runs on honours, read by name: `device.honors`.
struct PlatformSupportSample: SampleContent, ExampleContent {
    // listing: PlatformSupportSample
    /// The device, by its name: what its platform honours is its host's.
    @Environment(\.device) var device
    // listing: end

    static let id = "platformSupport"
    static let title = "Platform support"
    static let summary = "Whether this platform honours a member, so a view leaves out what asks for one it does not."

    // listing: PlatformSupportSample
    var body: some View {
        VStack {
            supported("Opening a picker's list", device.honors(PickerContract.isOpen))
            supported("Hearing a picker's list open", device.honors(PickerContract.opened))
            supported("A tooltip", device.honors(VisualElementContract.tooltip))
            supported("A picture beside a menu's entry", device.honors(MenuItemElementContract.icon))
        }
        .spacing(10)
    }

    /// One member, and whether this platform honours it.
    private func supported(_ words: String, _ honoured: Bool) -> some View {
        HStack {
            Text(words)
                .fontSize(15)

            Spacer()

            Text(honoured ? "honoured" : "not here")
                .fontSize(15)
                .textColor(honoured ? Palette.accent : Palette.subtle)
        }
    }
    // listing: end

    var notes: (any View)? {
        Text("The answer is the platform contract's: where a member is not honoured, writing it changes nothing, "
            + "so the Picker sample shows its \"Open the list\" button only where a list opens at the program's asking.")
            .fontSize(12)
            .textColor(Palette.subtle)
    }
}
