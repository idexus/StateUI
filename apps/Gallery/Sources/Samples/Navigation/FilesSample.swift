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
                .onClicked(.ignoreWhileRunning) {
                    let text = FileType("Text", extensions: ["txt"])
                    saved = try await Dialogs.saveFile(Array(words.utf8), name: "Note", types: [text])
                    answer = saved.map { "saved as \($0.name)" } ?? "cancelled"
                }

            // No file longer than 1 KB is read whole: one byte past it says it is longer.
            Button("Open…")
                .onClicked(.ignoreWhileRunning) {
                    let text = FileType("Text", extensions: ["txt", "md"])
                    guard let file = try await Dialogs.openFile(types: [text]) else {
                        return answer = "cancelled"
                    }
                    let start = try await file.read(atMost: 1025)
                    guard start.count <= 1024 else { return answer = "\(file.name) is longer than 1 KB" }
                    words = String(decoding: start, as: UTF8.self)
                    answer = "opened \(file.name)"
                }

            // The system opens it in the application it gives its kind.
            Button("Launch the saved file")
                .isEnabled(saved != nil)
                .onClicked(.ignoreWhileRunning) {
                    if let saved { try await saved.launch() }
                }

            Button("Launch swift.org")
                .onClicked(.ignoreWhileRunning) { try await Links.launch("https://www.swift.org") }

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
            .onDrop(files: [FileType("Text", extensions: ["txt", "md"])], .waitForPrevious) { files in
                dropping = false
                let start = try await files[0].read(atMost: 1025)
                guard start.count <= 1024 else { return answer = "\(files[0].name) is longer than 1 KB" }
                words = String(decoding: start, as: UTF8.self)
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
            + "platform's own, so the host reads it and launches it. A file of 1 KB at most is read: "
            + "`read(atMost:)` takes one byte more and stops, so a longer one is never read whole.")
            .fontSize(12)
            .textColor(Palette.subtle)
    }
}
