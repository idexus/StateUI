import StateUI

/// Files the user opens and saves in the platform's own dialogs, and what the system launches.
struct FilesSample: SampleContent, ExampleContent {
    // listing: FilesSample
    @State private var words = "Words to keep"
    @State private var saved: ChosenFile?
    @State private var answer = "nothing opened or saved yet"
    @State private var dropping = false
    // listing: end

    static let id = "files"
    static let title = "Files"
    static let summary = "A file opened or dropped and read, words saved, and a file or an address launched."

    // listing: FilesSample
    var body: some View {
        VStack {
            TextEditor($words)
                .height(96)

            // The contents go first; nil is a cancel.
            Button("Save…")
                .onClicked {
                    let text = FileType("Text", extensions: ["txt"])
                    saved = try await Dialogs.saveFile(Array(words.utf8), name: "Note", types: [text])
                    answer = saved.map { "saved as \($0.name)" } ?? "cancelled"
                }

            Button("Open…")
                .onClicked {
                    let text = FileType("Text", extensions: ["txt", "md"])
                    guard let file = try await Dialogs.openFile(types: [text]) else {
                        return answer = "cancelled"
                    }
                    words = String(decoding: try await file.read(), as: UTF8.self)
                    answer = "opened \(file.name)"
                }

            // The system opens it in the application it gives its kind.
            Button("Launch the saved file")
                .isEnabled(saved != nil)
                .onClicked {
                    if let saved { try await saved.launch() }
                }

            Button("Launch swift.org")
                .onClicked { try await Links.launch("https://www.swift.org") }

            // A text file dragged from the system onto it is read into the editor.
            ZStack {
                Text(dropping ? "let go to read it" : "Drop a text file here")
                    .fontSize(15)
                    .horizontalTextAlignment(.center)
                    .padding(20)
            }
            .stroke(dropping ? Palette.accent : Palette.outline)
            .lineWidth(dropping ? 2 : 1)
            .shape(.roundedRectangle(10))
            .onDragOver { dropping = true }
            .onDragLeave { dropping = false }
            .onDrop(files: [FileType("Text", extensions: ["txt", "md"])]) { files in
                dropping = false
                words = String(decoding: try await files[0].read(), as: UTF8.self)
                answer = "dropped \(files[0].name)"
            }

            Text(answer)
                .fontSize(17)
                .horizontalTextAlignment(.center)
        }
        .spacing(12)
    }
    // listing: end

    var notes: (any View)? {
        Text("A dialog or a drop answers a file whose name the application reads; where it stands is the "
            + "platform's own, so the host reads it and launches it.")
            .fontSize(12)
            .textColor(Palette.subtle)
    }
}
