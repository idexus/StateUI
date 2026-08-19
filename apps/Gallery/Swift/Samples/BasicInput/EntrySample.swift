import StateUI

/// MAUI: Entry.
struct EntrySample: SampleContent {
    @State private var name = ""
    @State private var editing = false

    static let id = "entry"
    static let title = "Entry"
    static let summary = "A single-line field. Given a binding it writes every edit back."

    static let code = """
        @State private var name = ""
        @State private var editing = false

        VStack {
            Entry($name)
                .placeholder("Type your name")
                .clearButtonVisibility(.whileEditing)
                .isFocused($editing)

            Label(name.isEmpty ? "Hello, stranger" : "Hello, \\(name)!")

            Label(editing ? "the field has the focus" : "the field does not have the focus")

            Entry("read only")
                .isReadOnly(true)

            Entry()
                .placeholder("a password")
                .isPassword(true)
                .returnType(.done)
        }
        """

    var content: Element {
        VStack {
            Entry($name)
                .placeholder("Type your name")
                .clearButtonVisibility(.whileEditing)
                .isFocused($editing)

            Label(name.isEmpty ? "Hello, stranger" : "Hello, \(name)!")
                .fontSize(17)
                .horizontalTextAlignment(.center)

            Label(editing ? "the field has the focus" : "the field does not have the focus")
                .fontSize(12)
                .textColor(Palette.subtle)
                .horizontalTextAlignment(.center)

            Entry("read only")
                .isReadOnly(true)

            Entry()
                .placeholder("a password")
                .isPassword(true)
                .returnType(.done)

            Label("The binding IS the two-way part: `Entry($name)` sets the text and "
                + "registers the write-back. `.onTextChanged` written afterwards runs "
                + "beside it, never instead of it.")
                .fontSize(12)
                .textColor(Palette.subtle)
        }
        .spacing(12)
    }
}
