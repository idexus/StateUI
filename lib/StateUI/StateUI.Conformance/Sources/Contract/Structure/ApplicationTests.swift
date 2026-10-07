// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI
@_spi(Host) import StateUIHost

/// `ApplicationContract` on a host: the application runs, and each act its host does for it with no control behind it
/// answers as the contract says - every question shown and answered as the user answers it, cancelled as the user
/// cancels it; a file saved where the user says, opened and read back; an address and a file launched; the clock, the
/// zone and a zone's distance from UTC; a word to the screen reader; the keyboard taken down; a value kept for the
/// next launch; a handler's failure reported.
@_spi(Host) public enum ApplicationTests: ConformanceFamily {
    public static let name = "Application"

    public static var cases: [ConformanceCase] {
        [
            ConformanceCase("anApplicationRunsItsSceneWindowAndPage", proves: [Covered(ApplicationContract.self)]) { s in
                s.start { VStack { Text("Running").id("label") } }

                _ = try s.element(ofType: ApplicationContract.nodeType)
                _ = try s.element(ofType: SceneContract.nodeType)
                _ = try s.element(ofType: WindowContract.nodeType)
                s.expect(try s.held(VisualElementContract.isVisible, on: s.element("label")), true, "its page shown")
            },
            ConformanceCase("anAlertIsShownAndDismissed", proves: [
                Covered(ApplicationContract.alert),
            ], needs: [Covered(ButtonContract.clicked)]) { s in
                let said = Received<String>()
                s.start {
                    VStack {
                        Button("Alert").onClicked {
                            try await Dialogs.alert("Saved", message: "The draft is kept", cancel: "Fine")
                            said.values.append("dismissed")
                        }.id("ask")
                    }
                }

                try s.perform(.activate, on: s.element("ask"))
                try s.settle { try s.question() != nil }
                s.expect(try s.question(), Question(title: "Saved", message: "The draft is kept", buttons: ["Fine"]))
                s.expect(said.values, [], "the handler waits for the answer")

                try s.perform(.answer("Fine"), on: s.element(ofType: WindowContract.nodeType))
                s.settle { said.values == ["dismissed"] }
                s.expect(said.values, ["dismissed"])
                s.expect(try s.question(), nil, "and the question is gone")
            },
            ConformanceCase("aConfirmationAnswersWhetherItWasAccepted", proves: [
                Covered(ApplicationContract.confirm),
            ], needs: [Covered(ButtonContract.clicked)]) { s in
                let said = Received<Bool>()
                s.start {
                    VStack {
                        Button("Confirm").onClicked {
                            said.values.append(try await Dialogs.confirm(
                                "Delete draft?", message: "It goes for good", accept: "Delete", cancel: "Keep"))
                        }.id("ask")
                    }
                }
                let window = try s.element(ofType: WindowContract.nodeType)

                try s.perform(.activate, on: s.element("ask"))
                try s.settle { try s.question() != nil }
                s.expect(try s.question(),
                         Question(title: "Delete draft?", message: "It goes for good", buttons: ["Delete", "Keep"]))
                try s.perform(.answer("Delete"), on: window)
                s.settle { said.values == [true] }

                try s.perform(.activate, on: s.element("ask"))
                try s.settle { try s.question() != nil }
                try s.perform(.answer("Keep"), on: window)
                s.settle { said.values.count == 2 }
                s.expect(said.values, [true, false], "accepted, then cancelled")
            },
            ConformanceCase("aChoiceAnswersTheCaptionPressed", proves: [
                Covered(ApplicationContract.chooseAction),
            ], needs: [Covered(ButtonContract.clicked)]) { s in
                let said = Received<String>()
                s.start {
                    VStack {
                        Button("Share").onClicked {
                            let chosen = try await Dialogs.chooseAction(
                                "Share via", cancel: "Cancel", destruction: "Delete", buttons: ["Mail", "Message"])
                            said.values.append(chosen ?? "nothing")
                        }.id("ask")
                    }
                }
                let window = try s.element(ofType: WindowContract.nodeType)

                try s.perform(.activate, on: s.element("ask"))
                try s.settle { try s.question() != nil }
                s.expect(try s.question()?.buttons, ["Cancel", "Delete", "Mail", "Message"])
                try s.perform(.answer("Mail"), on: window)
                s.settle { said.values == ["Mail"] }

                try s.perform(.activate, on: s.element("ask"))
                try s.settle { try s.question() != nil }
                try s.perform(.answer("Delete"), on: window)
                s.settle { said.values.count == 2 }

                try s.perform(.activate, on: s.element("ask"))
                try s.settle { try s.question() != nil }
                try s.perform(.answer("Cancel"), on: window)
                s.settle { said.values.count == 3 }
                s.expect(said.values, ["Mail", "Delete", "Cancel"], "a choice, the dangerous one, and the cancel")
            },
            ConformanceCase("aPromptAnswersTheWordsTypedOrNothing", proves: [
                Covered(ApplicationContract.prompt),
            ], needs: [Covered(ButtonContract.clicked)]) { s in
                let said = Received<String>()
                s.start {
                    VStack {
                        Button("Rename").onClicked {
                            let typed = try await Dialogs.prompt(
                                "Rename", message: "A new name", accept: "Save", cancel: "Cancel",
                                placeholder: "Name", initialValue: "Draft")
                            said.values.append(typed ?? "nothing")
                        }.id("ask")
                    }
                }
                let window = try s.element(ofType: WindowContract.nodeType)

                try s.perform(.activate, on: s.element("ask"))
                try s.settle { try s.question() != nil }
                s.expect(try s.question(), Question(
                    title: "Rename", message: "A new name", buttons: ["Cancel", "Save"], field: "Draft"))
                try s.perform(.answer("Save", typing: "Ada"), on: window)
                s.settle { said.values == ["Ada"] }

                try s.perform(.activate, on: s.element("ask"))
                try s.settle { try s.question() != nil }
                try s.perform(.answer("Cancel"), on: window)
                s.settle { said.values.count == 2 }
                s.expect(said.values, ["Ada", "nothing"], "the words typed, then nothing for the cancel")
            },
            ConformanceCase("questionsWaitTheirTurn", proves: [
                Covered(ApplicationContract.alert), Covered(ApplicationContract.confirm),
            ], needs: [Covered(ButtonContract.clicked)]) { s in
                let said = Received<String>()
                s.start {
                    VStack {
                        Button("Alert").onClicked {
                            try await Dialogs.alert("First", message: "")
                            said.values.append("first")
                        }.id("first")
                        Button("Confirm").onClicked {
                            let accepted = try await Dialogs.confirm("Second", message: "", accept: "Yes", cancel: "No")
                            said.values.append("second \(accepted)")
                        }.id("second")
                    }
                }
                let window = try s.element(ofType: WindowContract.nodeType)

                try s.perform(.activate, on: s.element("first"))
                try s.perform(.activate, on: s.element("second"))
                try s.settle { try s.question()?.title == "First" }
                s.expect(try s.question()?.title, "First", "the first asked stands first")
                try s.perform(.answer("OK"), on: window)
                try s.settle { try s.question()?.title == "Second" }
                s.expect(try s.question()?.title, "Second", "then the second")
                try s.perform(.answer("Yes"), on: window)
                s.settle { said.values.count == 2 }
                s.expect(said.values, ["first", "second true"])
            },
            ConformanceCase("aFileSavedIsOpenedAndReadBack", proves: [
                Covered(ApplicationContract.saveFile), Covered(ApplicationContract.openFiles),
                Covered(ApplicationContract.readFile),
            ], needs: [Covered(ButtonContract.clicked)]) { s in
                let said = Received<String>()
                let text = FileType("Text", extensions: ["txt"])
                s.start {
                    VStack {
                        Button("Save").onClicked {
                            let saved = try await Dialogs.saveFile(Array("Kept words".utf8), name: "note", types: [text])
                            said.values.append(saved?.name ?? "nothing")
                        }.id("save")
                        Button("Open").onClicked {
                            guard let file = try await Dialogs.openFile(types: [text]) else {
                                return said.values.append("nothing")
                            }
                            said.values.append("\(file.name): \(String(decoding: try await file.read(), as: UTF8.self))")
                        }.id("open")
                    }
                }
                let window = try s.element(ofType: WindowContract.nodeType)

                try s.perform(.activate, on: s.element("save"))
                try s.settle { try s.fileDialog() != nil }
                s.expect(try s.fileDialog(), .save)
                try s.perform(.answerFiles(["note.txt"]), on: window)
                s.settle { said.values.count == 1 }
                s.expect(said.values, ["note.txt"], "saved under its name, which ends in its kind's extension")

                try s.perform(.activate, on: s.element("open"))
                try s.settle { try s.fileDialog() != nil }
                s.expect(try s.fileDialog(), .open)
                try s.perform(.answerFiles(["note.txt"]), on: window)
                s.settle { said.values.count == 2 }
                s.expect(said.values, ["note.txt", "note.txt: Kept words"], "saved, then opened and read back")
            },
            ConformanceCase("severalFilesAreOpenedAtOnce", proves: [
                Covered(ApplicationContract.openFiles),
            ], needs: [Covered(ButtonContract.clicked), Covered(ApplicationContract.saveFile)]) { s in
                let said = Received<String>()
                s.start {
                    VStack {
                        Button("Save").onClicked {
                            said.values.append(try await Dialogs.saveFile([1], name: "file.txt")?.name ?? "nothing")
                        }.id("save")
                        Button("Open").onClicked {
                            let names = try await Dialogs.openFiles().map(\.name).sorted()
                            said.values.append(names.joined(separator: " "))
                        }.id("open")
                    }
                }
                let window = try s.element(ofType: WindowContract.nodeType)

                for name in ["first.txt", "second.txt"] {
                    let saved = said.values.count
                    try s.perform(.activate, on: s.element("save"))
                    try s.settle { try s.fileDialog() != nil }
                    try s.perform(.answerFiles([name]), on: window)
                    s.settle { said.values.count > saved }
                }
                try s.perform(.activate, on: s.element("open"))
                try s.settle { try s.fileDialog() != nil }
                try s.perform(.answerFiles(["first.txt", "second.txt"]), on: window)
                s.settle { said.values.count == 3 }
                s.expect(said.values, ["first.txt", "second.txt", "first.txt second.txt"], "both saved, then both chosen")
            },
            ConformanceCase("aFileDialogCancelledAnswersNothing", proves: [
                Covered(ApplicationContract.openFiles), Covered(ApplicationContract.saveFile),
            ], needs: [Covered(ButtonContract.clicked)]) { s in
                let said = Received<String>()
                s.start {
                    VStack {
                        Button("Open").onClicked {
                            said.values.append("opened \(try await Dialogs.openFiles().count)")
                        }.id("open")
                        Button("Save").onClicked {
                            let saved = try await Dialogs.saveFile([1], name: "never.txt")
                            said.values.append("saved \(saved?.name ?? "nothing")")
                        }.id("save")
                    }
                }
                let window = try s.element(ofType: WindowContract.nodeType)

                try s.perform(.activate, on: s.element("open"))
                try s.settle { try s.fileDialog() != nil }
                try s.perform(.answerFiles([]), on: window)
                s.settle { said.values.count == 1 }
                try s.perform(.activate, on: s.element("save"))
                try s.settle { try s.fileDialog() != nil }
                try s.perform(.answerFiles([]), on: window)
                s.settle { said.values.count == 2 }
                s.expect(said.values, ["opened 0", "saved nothing"])
                s.expect(try s.fileDialog(), nil, "and the dialog is gone")
            },
            ConformanceCase("anAddressAndAFileAreLaunched", proves: [
                Covered(ApplicationContract.launchLink), Covered(ApplicationContract.launchFile),
            ], needs: [Covered(ButtonContract.clicked), Covered(ApplicationContract.saveFile)]) { s in
                let said = Received<Bool>()
                s.start {
                    VStack {
                        Button("Launch").onClicked {
                            said.values.append(try await Links.launch("https://www.swift.org"))
                            if let saved = try await Dialogs.saveFile(Array("<p>Report</p>".utf8), name: "report.html") {
                                said.values.append(try await saved.launch())
                            }
                        }.id("launch")
                    }
                }

                try s.perform(.activate, on: s.element("launch"))
                try s.settle { try s.fileDialog() != nil }
                try s.perform(.answerFiles(["report.html"]), on: s.element(ofType: WindowContract.nodeType))
                s.settle { said.values.count == 2 }
                s.expect(said.values, [true, true], "each taken")
                s.expect(try s.launched(), ["https://www.swift.org", "report.html"])
            },
            ConformanceCase("theScreenReaderIsToldAndTheCallerGoesOn", proves: [
                Covered(ApplicationContract.announce),
            ], needs: [Covered(ButtonContract.clicked)]) { s in
                let said = Received<String>()
                s.start {
                    VStack {
                        Button("Say").onClicked {
                            try await ScreenReader.announce("Saved the draft")
                            said.values.append("announced")
                        }.id("say")
                    }
                }

                try s.perform(.activate, on: s.element("say"))
                s.settle { said.values == ["announced"] }
                s.expect(said.values, ["announced"])
                s.expect(try s.announced(), ["Saved the draft"])
            },
            ConformanceCase("theApplicationShowsInTheThemeItHolds", proves: [
                Covered(ApplicationContract.useColorScheme),
            ], needs: [Covered(ButtonContract.clicked), Covered(TextualElementContract.text, on: TextContract.self)]) { s in
                s.start { ThemeChoices() }

                @MainActor func inForce() throws -> String? {
                    try s.held(TextualElementContract.text, on: s.element("inForce"))
                }
                try s.perform(.activate, on: s.element("dark"))
                try s.settle { try s.theme() == .dark && inForce() == "dark" }
                s.expect(try s.theme(), .dark, "the platform shows the application dark")
                s.expect(try inForce(), "dark", "and pairs resolve dark")

                try s.perform(.activate, on: s.element("light"))
                try s.settle { try s.theme() == .light && inForce() == "light" }
                s.expect(try s.theme(), .light, "light, whatever the system asks")
                s.expect(try inForce(), "light")

                // Following the system again, whichever theme it asks for: the platform and the pairs agree.
                try s.perform(.activate, on: s.element("system"))
                @MainActor func agree() throws -> Bool {
                    try inForce() == "\(try s.theme())"
                }
                try s.settle { try agree() }
                s.expect(try agree(), true, "the system's theme, shown and resolved alike")
            },
            ConformanceCase("theHostTellsTheTimeOfDay", proves: [
                Covered(ApplicationContract.currentTime),
            ], needs: [Covered(ButtonContract.clicked)]) { s in
                let said = Received<ClockTime>()
                s.start { VStack { Button("Time").onClicked { said.values.append(try await ClockTime.now()) }.id("ask") } }

                try s.perform(.activate, on: s.element("ask"))
                s.settle { !said.values.isEmpty }
                let time = said.values.first
                s.expect(time.map { (0..<24).contains($0.hour) && (0..<60).contains($0.minute) }, true, "a time of day")
                s.expect(time.map { (0..<60).contains($0.second) && (0..<1000).contains($0.millisecond) }, true)
            },
            ConformanceCase("theHostTellsItsZoneAndItsDistanceFromUTC", proves: [
                Covered(ApplicationContract.currentTimeZone), Covered(ApplicationContract.utcOffset),
            ], needs: [Covered(ButtonContract.clicked)]) { s in
                let said = Received<String>()
                s.start {
                    VStack {
                        Button("Zones").onClicked {
                            let zone = try await TimeZoneInfo.local()
                            let local = try await TimeZoneInfo.utcOffset(of: zone)
                            let own = try await TimeZoneInfo.utcOffset()
                            said.values.append("\(!zone.isEmpty) \(local == own)")
                        }.id("ask")
                    }
                }

                try s.perform(.activate, on: s.element("ask"))
                s.settle { !said.values.isEmpty }
                s.expect(said.values, ["true true"], "a zone named, and its distance the host's own")
            },
            ConformanceCase("aZonesDistanceFromUTCIsItsOwnOnTheDayAsked", proves: [
                Covered(ApplicationContract.utcOffset),
            ], needs: [Covered(ButtonContract.clicked)]) { s in
                let said = Received<[Int64]>()
                s.start {
                    VStack {
                        Button("Offsets").onClicked {
                            let tokyo = try await TimeZoneInfo.utcOffset(of: "Asia/Tokyo")
                            let winter = try await TimeZoneInfo.utcOffset(
                                of: "Europe/Warsaw", on: CalendarDate(year: 2026, month: 1, day: 15))
                            let summer = try await TimeZoneInfo.utcOffset(
                                of: "Europe/Warsaw", on: CalendarDate(year: 2026, month: 7, day: 15))
                            said.values.append([tokyo, winter, summer].map { $0.components.seconds / 60 })
                        }.id("ask")
                    }
                }

                try s.perform(.activate, on: s.element("ask"))
                s.settle { !said.values.isEmpty }
                s.expect(said.values, [[540, 60, 120]], "Tokyo's, and Warsaw's in winter and in summer")
            },
            ConformanceCase("aZoneNobodyKnowsIsRefused", proves: [
                Covered(ApplicationContract.utcOffset),
            ], needs: [Covered(ButtonContract.clicked)]) { s in
                let said = Received<String>()
                s.start {
                    VStack {
                        Button("Nowhere").onClicked {
                            do {
                                _ = try await TimeZoneInfo.utcOffset(of: "Nowhere/Else")
                                said.values.append("answered")
                            } catch {
                                said.values.append("refused")
                            }
                        }.id("ask")
                    }
                }

                try s.perform(.activate, on: s.element("ask"))
                s.settle { !said.values.isEmpty }
                s.expect(said.values, ["refused"])
            },
            ConformanceCase("theKeyboardIsTakenDownFromTheViewHoldingIt", proves: [
                Covered(ApplicationContract.hideOnScreenKeyboard),
            ], needs: [Covered(ButtonContract.clicked)]) { s in
                let said = Received<Bool>()
                s.start {
                    VStack {
                        TextField("").id("field")
                        Button("Done").onClicked { said.values.append(try await OnScreenKeyboard.hide()) }.id("done")
                    }
                }
                let field = try s.element("field")

                try s.perform(.focus, on: field)
                try s.settle { try s.focused(field) }
                try s.perform(.activate, on: s.element("done"))
                s.settle { !said.values.isEmpty }
                s.expect(said.values, [true], "a view held it")
                s.expect(try s.focused(field), false, "and it holds it no more")
            },
            ConformanceCase("aValueIsKeptForTheNextLaunch", proves: [
                Covered(ApplicationContract.persistValue),
            ], needs: [Covered(ButtonContract.clicked)]) { s in
                let name = State(wrappedValue: "", persistentKey: PersistentKey("conformance.name", of: String.self))
                s.start { VStack { Button("Ada").onClicked { name.wrappedValue = "Ada" }.id("write") } }

                try s.perform(.activate, on: s.element("write"))
                try s.settle { try s.kept("conformance.name") == .string("Ada") }
                s.expect(try s.kept("conformance.name"), .string("Ada"))
            },
            ConformanceCase("aScenesValueIsKeptForItsNextLaunch", proves: [
                Covered(ApplicationContract.persistSceneValue),
            ], needs: [Covered(ButtonContract.clicked)]) { s in
                s.start { SectionPage() }

                try s.perform(.activate, on: s.element("write"))
                try s.settle { try s.kept("conformance.section", inScene: true) == .number(2) }
                s.expect(try s.kept("conformance.section", inScene: true), .number(2))
            },
            ConformanceCase("aHandlersFailureIsReportedToTheHost", proves: [
                Covered(ApplicationContract.handlerFailed),
            ], needs: [Covered(ButtonContract.clicked)]) { s in
                s.start {
                    VStack {
                        Button("Fail").onClicked { throw ConformanceFailure(message: "the draft could not be saved") }
                            .id("fail")
                    }
                }

                try s.perform(.activate, on: s.element("fail"))
                try s.settle { try s.logged().contains { $0.contains("the draft could not be saved") } }
                s.expect(try s.logged().contains { $0.contains("the draft could not be saved") }, true,
                         "the host's log names the failure")
            },
        ]
    }
}

/// A page whose scene keeps the section it shows, with the button that shows the second: the state is the page's,
/// so its scene claims it.
struct SectionPage: View {
    @State(sceneKey: SceneKey("conformance.section", of: Int.self)) private var section = 0

    var body: some View {
        let section = $section
        return VStack { Button("Second").onClicked { section.wrappedValue = 2 }.id("write") }
    }
}

/// A failure a case's handler throws on purpose.
struct ConformanceFailure: Error, CustomStringConvertible {
    let message: String
    var description: String { message }
}

/// Buttons that hold the application's theme, over the theme in force as words.
private struct ThemeChoices: View {
    @Environment(\.application) private var application

    var body: some View {
        let application = self.application
        return VStack {
            Text("\(application.info.colorScheme)").id("inForce")
            Button("Dark").onClicked { application.colorScheme = .dark }.id("dark")
            Button("Light").onClicked { application.colorScheme = .light }.id("light")
            Button("System").onClicked { application.colorScheme = .system }.id("system")
        }
    }
}
