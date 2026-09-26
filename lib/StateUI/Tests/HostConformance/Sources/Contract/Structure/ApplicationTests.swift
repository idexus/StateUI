// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI

/// `ApplicationContract` on a host: the application runs, and each act its host does for it with no control behind it
/// answers as the contract says - every question shown and answered as the user answers it, cancelled as the user
/// cancels it; the clock, the zone and a zone's distance from UTC; a word to the screen reader; the keyboard taken
/// down; a value kept for the next launch; a handler's failure reported.
@_spi(Host) public enum ApplicationTests: ConformanceFamily {
    public static let name = "Application"

    public static var cases: [ConformanceCase] {
        [
            ConformanceCase("anApplicationRunsItsSceneWindowAndPage", covers: [Covered(ApplicationContract.self)]) { s in
                s.start { VStack { Label("Running").id("label") } }

                _ = try s.element(ofType: ApplicationContract.nodeType)
                _ = try s.element(ofType: SceneContract.nodeType)
                _ = try s.element(ofType: WindowContract.nodeType)
                s.expect(try s.held(VisualElementContract.isVisible, on: s.element("label")), true, "its page shown")
            },
            ConformanceCase("anAlertIsShownAndDismissed", covers: [
                Covered(ApplicationContract.alert), Covered(ButtonContract.clicked),
            ]) { s in
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
            ConformanceCase("aConfirmationAnswersWhetherItWasAccepted", covers: [
                Covered(ApplicationContract.confirm), Covered(ButtonContract.clicked),
            ]) { s in
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
            ConformanceCase("aChoiceAnswersTheCaptionPressed", covers: [
                Covered(ApplicationContract.chooseAction), Covered(ButtonContract.clicked),
            ]) { s in
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
            ConformanceCase("aPromptAnswersTheWordsTypedOrNothing", covers: [
                Covered(ApplicationContract.prompt), Covered(ButtonContract.clicked),
            ]) { s in
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
            ConformanceCase("questionsWaitTheirTurn", covers: [
                Covered(ApplicationContract.alert), Covered(ApplicationContract.confirm), Covered(ButtonContract.clicked),
            ]) { s in
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
            ConformanceCase("theScreenReaderIsToldAndTheCallerGoesOn", covers: [
                Covered(ApplicationContract.announce), Covered(ButtonContract.clicked),
            ]) { s in
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
            ConformanceCase("theHostTellsTheTimeOfDay", covers: [
                Covered(ApplicationContract.currentTime), Covered(ButtonContract.clicked),
            ]) { s in
                let said = Received<ClockTime>()
                s.start { VStack { Button("Time").onClicked { said.values.append(try await ClockTime.now()) }.id("ask") } }

                try s.perform(.activate, on: s.element("ask"))
                s.settle { !said.values.isEmpty }
                let time = said.values.first
                s.expect(time.map { (0..<24).contains($0.hour) && (0..<60).contains($0.minute) }, true, "a time of day")
                s.expect(time.map { (0..<60).contains($0.second) && (0..<1000).contains($0.millisecond) }, true)
            },
            ConformanceCase("theHostTellsItsZoneAndItsDistanceFromUTC", covers: [
                Covered(ApplicationContract.currentTimeZone), Covered(ApplicationContract.utcOffset),
                Covered(ButtonContract.clicked),
            ]) { s in
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
            ConformanceCase("aZonesDistanceFromUTCIsItsOwnOnTheDayAsked", covers: [
                Covered(ApplicationContract.utcOffset), Covered(ButtonContract.clicked),
            ]) { s in
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
            ConformanceCase("aZoneNobodyKnowsIsRefused", covers: [
                Covered(ApplicationContract.utcOffset), Covered(ButtonContract.clicked),
            ]) { s in
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
            ConformanceCase("theKeyboardIsTakenDownFromTheViewHoldingIt", covers: [
                Covered(ApplicationContract.hideOnScreenKeyboard), Covered(ButtonContract.clicked),
            ]) { s in
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
            ConformanceCase("aValueIsKeptForTheNextLaunch", covers: [
                Covered(ApplicationContract.persistValue), Covered(ButtonContract.clicked),
            ]) { s in
                let name = State(wrappedValue: "", persistentKey: PersistentKey("conformance.name", of: String.self))
                s.start { VStack { Button("Ada").onClicked { name.wrappedValue = "Ada" }.id("write") } }

                try s.perform(.activate, on: s.element("write"))
                try s.settle { try s.kept("conformance.name") == .string("Ada") }
                s.expect(try s.kept("conformance.name"), .string("Ada"))
            },
            ConformanceCase("aScenesValueIsKeptForItsNextLaunch", covers: [
                Covered(ApplicationContract.persistSceneValue), Covered(ButtonContract.clicked),
            ]) { s in
                let section = State(wrappedValue: 0, sceneKey: SceneKey("conformance.section", of: Int.self))
                s.start { VStack { Button("Second").onClicked { section.wrappedValue = 2 }.id("write") } }

                try s.perform(.activate, on: s.element("write"))
                try s.settle { try s.kept("conformance.section", inScene: true) == .number(2) }
                s.expect(try s.kept("conformance.section", inScene: true), .number(2))
            },
            ConformanceCase("aHandlersFailureIsReportedToTheHost", covers: [
                Covered(ApplicationContract.handlerFailed), Covered(ButtonContract.clicked),
            ]) { s in
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

/// A failure a case's handler throws on purpose.
struct ConformanceFailure: Error, CustomStringConvertible {
    let message: String
    var description: String { message }
}
