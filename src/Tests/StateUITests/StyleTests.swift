// Styles: what a style is, and what a control wearing one puts on the wire.
//
// A style never travels. It is a bag of the same property values a control
// carries, and the differ merges it into the control it belongs to - so most of
// this file is about the RESOLUTION: which style a control wears, whose value
// wins, and what the message therefore says. What the renderer does with the
// result is next door, in the C# StyleTests, against the fixture this file
// writes.

import Foundation
import StateUIWireProbe
import XCTest
@testable import StateUI

/// The window under every styled application here.
private struct HomeWindow: Window {
    var content: Page { Home() }
}

/// An application with styles, which is where MAUI keeps them too.
private struct StyledApp: Application {
    func createWindow() -> Window { HomeWindow() }

    var styles: StyleSheet? {
        StyleSheet {
            Style<Label>().fontSize(14)
        }
    }
}

private struct Home: ContentPage {
    var content: Element { label("home") }
}

final class StyleTests: XCTestCase {
    // MARK: - What a style is

    /// The target type is not written twice. It comes from the target's own
    /// blank initializer, which is the same place a node's type comes from.
    func testAStyleNamesTheTypeItsSettersWereWrittenAgainst() {
        let style = Style<Label>()
            .textColor(.black)
            .fontSize(14)
            .erased

        XCTAssertEqual(style.target, "Label")
        XCTAssertEqual(style.props["textColor"], Color("#000000").propValue)
        XCTAssertEqual(style.props["fontSize"], .number(14))
        XCTAssertNil(style.props["text"], "nothing set is nothing set")
    }

    /// The two namespaces, as everywhere else: a string identity is one somebody
    /// wrote, and here that is the key a style is asked for by.
    func testAKeyedStyleCarriesItsKeyAndAnImplicitOneCarriesNone() {
        XCTAssertEqual(Style<Label>("Headline").fontSize(32).erased.key, "Headline")
        XCTAssertNil(Style<Label>().fontSize(14).erased.key)
    }

    /// A style can only set properties, and that is the COMPILER's promise
    /// rather than this test's: `Style<Button>().onClicked { }` does not
    /// compile, a style conforming to the property tiers alone. What is left
    /// to pin at run time is that the states a maximal style carries hold no
    /// handlers anywhere in them.
    func testAStyleCarriesNoHandlers() {
        let style = Style<Button>()
            .cornerRadius(8)
            .visualState(.disabled) { $0.textColor(.gray) }
            .erased

        XCTAssertEqual(style.props["cornerRadius"], .number(8))
        XCTAssertTrue(style.states.allSatisfy { $0.events.isEmpty })
        XCTAssertTrue(style.states.allSatisfy { $0.children.allSatisfy { $0.events.isEmpty } })
    }

    // MARK: - Visual states

    func testAVisualStateIsASetterBagOfItsOwn() throws {
        let states = Style<Switch>()
            .backgroundColor(.white)
            .visualState(.disabled) { $0.backgroundColor(.gray) }
            .visualState(.on, group: "SwitchStates") { $0.backgroundColor(.green) }
            .erased
            .states

        // Four: the two written down, and a Normal for each group - see below.
        XCTAssertEqual(states.count, 4)

        // The name is MAUI's, spelled as MAUI matches it: the state manager
        // compares strings, so this one is NOT camelCased on the wire.
        let disabled = try XCTUnwrap(states.first { $0.props["name"] == .name("Disabled") })
        XCTAssertEqual(disabled.props["group"], .name("CommonStates"))
        XCTAssertEqual(states.last?.props["group"], .name("SwitchStates"))

        let setters = try XCTUnwrap(disabled.children.first { $0.type == "Setters" })
        XCTAssertEqual(setters.props["backgroundColor"], Color("#808080").propValue)
    }

    /// A control starts in the FIRST state its group declares, so a style that
    /// only says what Disabled looks like would draw everything disabled. MAUI's
    /// own template writes an empty Normal above every other state for this
    /// reason; a style that did not write one gets it.
    func testAGroupOfStatesAlwaysStartsWithNormal() {
        let states = Style<Button>()
            .textColor(.white)
            .visualState(.disabled) { $0.textColor(.gray) }
            .erased
            .states

        XCTAssertEqual(states.map { $0.props["name"] }, [.name("Normal"), .name("Disabled")])
        XCTAssertTrue(states.first?.children.isEmpty ?? false,
                      "the one that was added changes nothing - it is only somewhere to return to")
    }

    /// And a style that wrote its own is left exactly as it was: two states of
    /// the same name in one group is what MAUI refuses.
    func testAStyleThatWroteItsOwnNormalKeepsIt() {
        let states = Style<Button>()
            .textColor(.white)
            .visualState(.normal) { $0.backgroundColor(.transparent) }
            .visualState(.disabled) { $0.textColor(.gray) }
            .erased
            .states

        XCTAssertEqual(states.map { $0.props["name"] }, [.name("Normal"), .name("Disabled")])
        XCTAssertFalse(states.first?.children.isEmpty ?? true, "and it is the one that was written")
    }

    /// The resting state stands FIRST whatever order it was written in, since a
    /// group opens in the state it declares first.
    func testTheRestingStateStandsFirstWhereverItWasWritten() {
        let states = Style<Button>()
            .visualState(.disabled) { $0.textColor(.gray) }
            .visualState(.normal) { $0.backgroundColor(.transparent) }
            .erased
            .states

        XCTAssertEqual(states.map { $0.props["name"] }, [.name("Normal"), .name("Disabled")])
    }

    /// A state written twice is written once - MAUI refuses two states of one
    /// name in one group, so the second has to win rather than stand beside it.
    func testAStateWrittenTwiceIsTheSecondWriting() throws {
        let states = Style<Button>()
            .visualState(.disabled) { $0.textColor(.gray) }
            .visualState(.disabled) { $0.textColor(.white) }
            .erased
            .states

        let disabled = try XCTUnwrap(states.first { $0.props["name"] == .name("Disabled") })

        XCTAssertEqual(states.count, 2, "the Normal and the one Disabled")
        XCTAssertEqual(
            disabled.children.first { $0.type == "Setters" }?.props["textColor"],
            Color("#FFFFFF").propValue)
    }

    /// A RadioButton rests in Unchecked, not Normal - which is MAUI's own doing
    /// (`ApplyIsCheckedState` runs BEFORE the base, so a Normal beside the pair
    /// ends every transition and the pair is never seen). Measured on the C#
    /// side, in MauiStatesTests; what this pins is that the resting state a
    /// style is given follows the TARGET.
    func testARadioButtonRestsInUncheckedRatherThanNormal() {
        let states = Style<RadioButton>()
            .visualState(.checked) { $0.textColor(.white) }
            .erased
            .states

        XCTAssertEqual(
            states.map { $0.props["name"] }, [.name("Unchecked"), .name("Checked")])
    }

    // MARK: - States on the control itself

    func testAControlCarriesTheStatesItWroteForItself() throws {
        let node = Button("Save")
            .visualState(.disabled) { $0.textColor(.gray) }
            .node

        let states = node.children.filter { $0.type == "VisualState" }

        XCTAssertEqual(states.map { $0.props["name"] }, [.name("Normal"), .name("Disabled")])

        let disabled = try XCTUnwrap(states.last)

        XCTAssertEqual(disabled.props["group"], .name("CommonStates"))
        XCTAssertEqual(
            disabled.children.first { $0.type == "Setters" }?.props["textColor"],
            Color("#808080").propValue)
    }

    /// The same arrangement a style gets, since it is the same code: written
    /// once, the resting state first, and a second writing winning.
    func testAControlsStatesAreArrangedTheWayAStylesAre() {
        let node = Switch()
            .visualState(.on) { $0.backgroundColor(.green) }
            .visualState(.off) { $0.backgroundColor(.gray) }
            .visualState(.on) { $0.backgroundColor(.white) }
            .node

        let states = node.children.filter { $0.type == "VisualState" }

        XCTAssertEqual(
            states.map { $0.props["name"] },
            [.name("Normal"), .name("On"), .name("Off")])
        XCTAssertEqual(
            states.last(where: { $0.props["name"] == .name("On") })?
                .children.first { $0.type == "Setters" }?.props["backgroundColor"],
            Color("#FFFFFF").propValue)
    }

    /// And they are appended AFTER whatever the control lays out, which is where
    /// the renderer subtracts them - the `.contextFlyout` rule.
    func testAControlsStatesComeAfterWhatItLaysOut() {
        let node = VStack {
            Label("one")
            Label("two")
        }
        .visualState(.disabled) { $0.opacity(0.5) }
        .node

        XCTAssertEqual(
            node.children.map { $0.type },
            ["Label", "Label", "VisualState", "VisualState"])
    }

    // MARK: - Hearing which state it entered

    /// A listener DECLARES the states it names, because a state announces
    /// itself with a setter and a setter has to sit in a state somebody wrote
    /// down.
    func testAListenerDeclaresTheStatesItNames() {
        let node = Button("Save")
            .onVisualStateChanged(.pressed) { _ in }
            .node

        let states = node.children.filter { $0.type == "VisualState" }

        XCTAssertEqual(states.map { $0.props["name"] }, [.name("Normal"), .name("Pressed")])
        XCTAssertTrue(states.allSatisfy { $0.children.isEmpty },
                      "declaring a state to hear it must not change what it looks like")
        XCTAssertNotNil(node.events["visualStateChanged"])
    }

    /// And it leaves a state that was already written exactly as it was.
    func testAListenerLeavesAStateThatWasWrittenAlone() throws {
        let node = Button("Save")
            .visualState(.pressed) { $0.backgroundColor(.green) }
            .onVisualStateChanged(.pressed, .disabled) { _ in }
            .node

        let states = node.children.filter { $0.type == "VisualState" }
        let pressed = try XCTUnwrap(states.first { $0.props["name"] == .name("Pressed") })

        XCTAssertEqual(
            states.map { $0.props["name"] },
            [.name("Normal"), .name("Pressed"), .name("Disabled")])
        XCTAssertEqual(
            pressed.children.first { $0.type == "Setters" }?.props["backgroundColor"],
            Color("#008000").propValue)
    }

    /// Naming none declares none - what is heard is then whatever the control
    /// declared for itself.
    func testAListenerThatNamesNoStateDeclaresNone() {
        let node = Button("Save")
            .onVisualStateChanged { _ in }
            .node

        XCTAssertTrue(node.children.filter { $0.type == "VisualState" }.isEmpty)
        XCTAssertNotNil(node.events["visualStateChanged"])
    }

    /// The report carries the state's NAME, which is what MAUI matches one by -
    /// and it arrives as the typed state, so it can be compared to `.pressed`.
    func testTheReportArrivesAsTheStateItself() {
        let renders = Renders()
        var heard: [String] = []

        let patch = renders.render(
            Button("Save")
                .onVisualStateChanged(.pressed) { state in
                    heard.append(state == .pressed ? "it is pressed" : state.name)
                }
                .body)

        let id = patch.events?["visualStateChanged"] ?? -1

        XCTAssertTrue(renders.fire(id, with: [.string("Pressed")]))
        XCTAssertTrue(renders.fire(id, with: [.string("Normal")]))

        XCTAssertEqual(heard, ["it is pressed", "Normal"])
    }

    /// A payload of another shape leaves the handler alone - the rule every
    /// typed event follows, so a state nobody can name never runs one.
    func testAReportOfTheWrongShapeLeavesTheHandlerAlone() {
        let renders = Renders()
        var heard: [String] = []

        let patch = renders.render(
            Button("Save")
                .onVisualStateChanged(.pressed) { heard.append($0.name) }
                .body)

        XCTAssertTrue(renders.fire(patch.events?["visualStateChanged"] ?? -1, with: [.number(3)]))
        XCTAssertTrue(heard.isEmpty)
    }

    // MARK: - The sheet

    /// Two styles under one key, or two implicit ones for one target, are one -
    /// and BOTH are still written down, which is how a test can see the mistake
    /// that a dictionary would swallow.
    func testTheLastStyleFiledUnderANameIsTheOneThatAnswers() {
        let sheet = StyleSheet {
            Style<Label>().fontSize(10)
            Style<Label>().fontSize(20)
            Style<Label>("Big").fontSize(30)
            Style<Label>("Big").fontSize(40)
        }

        XCTAssertEqual(sheet.written.count, 4, "what was written is kept, mistakes included")
        XCTAssertEqual(sheet.style(for: Label("x").node)?.props["fontSize"], .number(20))
        XCTAssertEqual(
            sheet.style(for: Label("x").style("Big").node)?.props["fontSize"], .number(40))
    }

    /// A style based on another carries the other's values underneath its own -
    /// flattened when the sheet is built, so a control resolving one never walks
    /// a chain.
    func testAStyleBasedOnAnotherCarriesItsValuesUnderneath() throws {
        let sheet = StyleSheet {
            Style<Label>("Body").fontSize(16).textColor(.black)
            Style<Label>("Headline").fontSize(32).basedOn("Body")
        }

        let headline = try XCTUnwrap(sheet.style(for: Label("x").style("Headline").node))

        XCTAssertEqual(headline.props["fontSize"], .number(32), "its own wins")
        XCTAssertEqual(headline.props["textColor"], Color("#000000").propValue, "the rest comes from Body")
    }

    /// It may name one written BELOW it - the whole sheet is filed before any of
    /// it is flattened, which a XAML dictionary cannot do.
    func testAStyleMayBeBasedOnOneWrittenAfterIt() {
        let sheet = StyleSheet {
            Style<Label>("Headline").fontSize(32).basedOn("Body")
            Style<Label>("Body").textColor(.black)
        }

        XCTAssertEqual(
            sheet.style(for: Label("x").style("Headline").node)?.props["textColor"],
            Color("#000000").propValue)
    }

    /// A chain that comes back round to itself stops where it began. There is
    /// nowhere to report a mistake in a sheet, and a build that never returns is
    /// the worst way to find out about one.
    func testAChainOfStylesThatCirclesBackStops() {
        let sheet = StyleSheet {
            Style<Label>("One").fontSize(10).basedOn("Two")
            Style<Label>("Two").textColor(.black).basedOn("One")
        }

        XCTAssertEqual(sheet.style(for: Label("x").style("One").node)?.props["fontSize"],
                       .number(10))
    }

    /// A key naming nothing falls through to the implicit style, which is what
    /// MAUI does: an unresolved Style is no style, and no style is what makes an
    /// implicit one apply.
    func testAKeyNobodyFiledFallsThroughToTheImplicitStyle() {
        let sheet = StyleSheet { Style<Label>().fontSize(14) }

        XCTAssertEqual(
            sheet.style(for: Label("x").style("Nothing").node)?.props["fontSize"], .number(14))
    }

    // MARK: - Resolving one into a control

    /// The implicit style's values arrive on the control, and the control's own
    /// win - one property at a time, which is MAUI's precedence and this
    /// library's everywhere else.
    func testAControlWearsItsStyleAndItsOwnValuesWin() {
        let sheet = StyleSheet {
            Style<Label>().fontSize(14).textColor(.black)
        }

        let patch = Renders().render(
            Label("Hi").fontSize(20).body, styles: sheet)

        XCTAssertEqual(patch.props["fontSize"], .number(20), "the control's own")
        XCTAssertEqual(patch.props["textColor"], Color("#000000").propValue, "and the style's rest")
    }

    /// A keyed style REPLACES the implicit one for the type - it is asked for,
    /// so it says everything it needs.
    func testAKeyedStyleReplacesTheImplicitOne() {
        let sheet = StyleSheet {
            Style<Label>().fontSize(14).textColor(.black)
            Style<Label>("Headline").fontSize(32)
        }

        let patch = Renders().render(Label("Hi").style("Headline").body, styles: sheet)

        XCTAssertEqual(patch.props["fontSize"], .number(32))
        XCTAssertNil(patch.props["textColor"], "nothing of the implicit one comes with it")
    }

    /// And the key itself never travels: the host has no dictionary to look one
    /// up in, and nothing on that side knows what a style is.
    func testTheKeyIsConsumedRatherThanSent() {
        let sheet = StyleSheet { Style<Label>("Headline").fontSize(32) }
        let renders = Renders()

        XCTAssertNil(renders.render(Label("Hi").style("Headline").body, styles: sheet).props["style"])

        // And with no sheet at all, so an application that writes a key and no
        // styles sends a control rather than a name nobody can resolve.
        XCTAssertNil(Renders().render(Label("Hi").style("Headline").body).props["style"])
    }

    /// A control with no style of its own sends what it always sent.
    func testAControlNoStyleReachesIsUntouched() {
        let sheet = StyleSheet { Style<Button>().fontSize(14) }
        let patch = Renders().render(Label("Hi").body, styles: sheet)

        XCTAssertEqual(patch.props["text"], .string("Hi"))
        XCTAssertNil(patch.props["fontSize"])
    }

    /// The style's states become the control's own, which is the one shape the
    /// renderer knows.
    func testAStylesStatesArriveAsTheControlsOwn() throws {
        let sheet = StyleSheet {
            Style<Button>().visualState(.disabled) { $0.textColor(.gray) }
        }

        let patch = Renders().render(Button("Save").body, styles: sheet)
        let states = patch.children.filter { $0.type == "VisualState" }

        XCTAssertEqual(states.map { $0.props["name"] }, [.name("Normal"), .name("Disabled")])

        let setters = try XCTUnwrap(states.last?.children.first { $0.type == "Setters" })
        XCTAssertEqual(setters.props["textColor"], Color("#808080").propValue)
    }

    /// A state written on the CONTROL is written OVER the style's state of the
    /// same name, one setter at a time. MAUI replaces the whole group list -
    /// a list is one property - and merging is what every other value here
    /// does, so this is a deliberate difference.
    func testAControlsStateIsWrittenOverItsStylesState() throws {
        let sheet = StyleSheet {
            Style<Button>().visualState(.disabled) { $0
                .textColor(.gray)
                .backgroundColor(.white)
            }
        }

        let patch = Renders().render(
            Button("Save")
                .visualState(.disabled) { $0.textColor(.red) }
                .body,
            styles: sheet)

        let disabled = try XCTUnwrap(
            patch.children.first { $0.props["name"] == .name("Disabled") })
        let setters = try XCTUnwrap(disabled.children.first { $0.type == "Setters" })

        XCTAssertEqual(setters.props["textColor"], Color("#FF0000").propValue, "the control's own")
        XCTAssertEqual(setters.props["backgroundColor"], Color("#FFFFFF").propValue, "and the style's rest")
    }

    /// Which is what lets a control HEAR a state its style paints: the listener
    /// declares an empty state, and an empty state changes nothing.
    func testDeclaringAStateToHearItKeepsWhatTheStylePaints() throws {
        let sheet = StyleSheet {
            Style<Button>().visualState(.pressed) { $0.backgroundColor(.green) }
        }

        let patch = Renders().render(
            Button("Save").onVisualStateChanged(.pressed) { _ in }.body,
            styles: sheet)

        let pressed = try XCTUnwrap(
            patch.children.first { $0.props["name"] == .name("Pressed") })

        XCTAssertEqual(
            pressed.children.first { $0.type == "Setters" }?.props["backgroundColor"],
            Color("#008000").propValue)
    }

    /// A state in a group the style never mentioned joins the list rather than
    /// replacing it.
    func testAStateTheStyleNeverMentionedIsAddedToIt() {
        let sheet = StyleSheet {
            Style<Switch>().visualState(.disabled) { $0.opacity(0.5) }
        }

        let patch = Renders().render(
            Switch(true)
                .visualState(.on, group: "SwitchStates") { $0.backgroundColor(.green) }
                .body,
            styles: sheet)

        XCTAssertEqual(
            patch.children.filter { $0.type == "VisualState" }.map { $0.props["group"] },
            [.name("CommonStates"), .name("CommonStates"),
             .name("SwitchStates"), .name("SwitchStates")])
    }

    /// A sheet that MOVED is the one thing a memoized subtree cannot see: its
    /// token says the inputs have not changed, and a style is not one of them.
    func testAStyleThatMovedReachesAnUnchangedMemo() {
        struct Card: Element {
            var body: Node { Label("card").body }
        }

        let renders = Renders()
        let tree = Node(type: "VerticalStackLayout", children: [Card().memoized(by: 1).body])

        renders.render(tree, styles: StyleSheet { Style<Label>().fontSize(14) })

        let patch = renders.render(tree, styles: StyleSheet { Style<Label>().fontSize(20) })

        XCTAssertEqual(patch.children.first?.props["fontSize"], .number(20))
    }

    /// And a sheet that did not move leaves the memo's whole saving where it
    /// was: an unchanged token still skips.
    func testAnUnchangedSheetStillLetsAMemoSkip() {
        struct Card: Element {
            var body: Node { Label("card").body }
        }

        let renders = Renders()
        let tree = Node(type: "VerticalStackLayout", children: [Card().memoized(by: 1).body])
        let sheet = { StyleSheet { Style<Label>().fontSize(14) } }

        renders.render(tree, styles: sheet())

        XCTAssertTrue(renders.render(tree, styles: sheet()).isEmpty)
    }

    // MARK: - Colours that follow the theme

    func testAColourWithADarkHalfPicksItsHalfAsItIsWritten() {
        let themed = Color(light: .white, dark: Color.fromArgb("#1f1f1f"))

        XCTAssertEqual(
            Style<Label>().textColor(themed).erased.props["textColor"],
            Color("#FFFFFF").propValue,
            "written while the system is light")

        withTheme(.dark) {
            XCTAssertEqual(
                Style<Label>().textColor(themed).erased.props["textColor"],
                Color("#1f1f1f").propValue,
                "and the other half while it is dark")
        }
    }

    /// It is a Color, so it goes wherever a Color goes - and the half in force
    /// is picked as the value is written, which is why one colour arrives.
    func testAThemedColourCanBeWrittenOnAControlToo() {
        let themed = Color(light: .black, dark: .white)

        XCTAssertEqual(Label("Hi").textColor(themed).body.props["textColor"],
                       Color.black.propValue)

        withTheme(.dark) {
            XCTAssertEqual(Label("Hi").textColor(themed).body.props["textColor"],
                           Color.white.propValue)
        }
    }

    /// And a style's colour becomes the CONTROL's, resolved on the way - so
    /// nothing on the far side binds or resolves a theme.
    func testAStylesThemedColourArrivesOnTheControlResolved() {
        let sheet = StyleSheet {
            Style<Label>().textColor(Color(light: .black, dark: .white))
        }

        XCTAssertEqual(
            Renders().render(Label("Hi").body, styles: sheet).props["textColor"],
            Color.black.propValue)
    }

    /// The read is what makes the next theme change find this view: a colour
    /// with two halves asks `AppInfo` which one to use, and that read is
    /// recorded against whichever view is being built.
    func testWritingAThemedColourRecordsAReadOfTheTheme() {
        let (_, reads) = ReadScope.collect {
            _ = Label("Hi").textColor(Color(light: .black, dark: .white)).body
        }

        XCTAssertTrue(reads.contains(ObjectIdentifier(StandardEnvironment.app)),
                      "a themed colour depends on the theme, and says so")

        let (_, plain) = ReadScope.collect {
            _ = Label("Hi").textColor(.black).body
        }

        XCTAssertFalse(plain.contains(ObjectIdentifier(StandardEnvironment.app)),
                       "a colour with one half asks nothing")
    }

    // MARK: - Pictures that follow the theme

    /// The same story a themed colour tells: the half in force is picked as
    /// the value is written, so one name crosses.
    func testAPictureCanBeDrawnOncePerTheme() {
        func both() -> Node { Image(light: "nav_home.png", dark: "nav_home_dark.png").body }

        XCTAssertEqual(both().props["source"], .string("nav_home.png"))

        withTheme(.dark) {
            XCTAssertEqual(both().props["source"], .string("nav_home_dark.png"))
        }

        XCTAssertEqual(Image("nav_home.png").body.props["source"], .string("nav_home.png"),
                       "and one drawn once is the same name in both")
    }

    /// A file name is all most of them are, so a bare literal is an image
    /// source wherever one is asked for.
    func testAnImageSourceIsWrittenAsALiteralWhereThereIsOnlyOne() {
        let plain: ImageSource = "tab_list.png"

        XCTAssertEqual(plain.file, "tab_list.png")
        XCTAssertNil(plain.dark)
        XCTAssertFalse(plain.isEmpty)
    }

    /// The pictures that hang off a PAGE take one too, and what lands on the
    /// node is the picture being SHOWN - the theme resolved as the value was
    /// written, not carried across as a pair for somebody else to choose from.
    func testAPagesPictureIsWrittenAsThePictureBeingShown() {
        let item = ToolbarItem("Save")
            .iconImageSource(ImageSource(light: "tab_list.png", dark: "tab_list_dark.png"))

        XCTAssertEqual(item.node.props["iconImageSource"], .string("tab_list.png"))

        let menu = MenuFlyoutItem("Reset").iconImageSource("menu_reset.png")

        XCTAssertEqual(menu.node.props["iconImageSource"], .string("menu_reset.png"))
    }

    // MARK: - Asking for one

    func testAControlAsksForAKeyedStyleByName() {
        XCTAssertEqual(Label("Welcome").style("Headline").body.props["style"],
                       .name("Headline"))
    }

    // MARK: - Where they live

    /// The application's sheet reaches the controls under its window, and
    /// nothing about the sheet itself is on the wire.
    func testTheApplicationsStylesReachTheControlsAndNothingElse() {
        Renderer.shared.setApplication(StyledApp())

        let dump = WireProbe.dumpMessage(Renderer.shared.renderWire(baseline: 0))

        XCTAssertTrue(dump.contains("fontSize: number 14"), dump)
        XCTAssertFalse(dump.contains("ResourceDictionary"), dump)
        XCTAssertFalse(dump.contains("Style"), dump)
    }

    /// An application that declares none says nothing about styles, and its
    /// controls carry only what they were written with.
    func testAnApplicationWithNoStylesLeavesItsControlsAlone() {
        struct Plain: Application {
            func createWindow() -> Window { HomeWindow() }
        }

        Renderer.shared.setApplication(Plain())

        XCTAssertFalse(
            WireProbe.dumpMessage(Renderer.shared.renderWire(baseline: 0))
                .contains("fontSize"))
    }

    // MARK: - The set, kept honest

    /// Every control can be styled, or the rule is not a rule.
    ///
    /// The same kind of check as testEveryControlHasACase next door, and the
    /// same justification for reading source code: it is a test, and it can only
    /// ever under-report.
    func testEveryControlIsAStyleTarget() throws {
        let declared = try Fixtures.text(in: "Style.swift")

        for source in try Fixtures.controlSources() {
            for type in try Fixtures.nodeTypes(in: source).sorted()
            where !Fixtures.notViews.contains(type) {
                XCTAssertTrue(declared.contains("extension \(type): StyleTarget {}"), """
                    \(source) describes \(type), which Style.swift does not \
                    declare a style target.

                    Every control can be styled. Give it an initializer that \
                    sets nothing, if it has none, and add the conformance.
                    """)
            }
        }
    }

    /// And the other half of the same rule: a control's OWN property surface
    /// is a `<Name>Properties` protocol, and the style wears it. A protocol
    /// declared without its `StyleBag` conformance would compile and quietly
    /// leave `Style<Name>` without the control's own setters.
    func testEveryPropertySurfaceReachesTheStyle() throws {
        let declared = try Fixtures.text(in: "Style.swift")

        // Elements.swift declares the TIER surfaces, which reach the style
        // through the `where Target:` conformances - this walk is about the
        // per-control ones, declared beside their control.
        for source in try Fixtures.controlSources() where source != "Elements.swift" {
            let text = try Fixtures.text(in: source)

            for surface in text.occurrences(between: "public protocol ", and: ":")
            where surface.hasSuffix("Properties") {
                let target = String(surface.dropLast("Properties".count))

                XCTAssertTrue(
                    declared.contains(
                        "extension StyleBag: \(surface) where Target == \(target) {}"),
                    """
                    \(source) declares \(surface), which Style.swift does not \
                    hand to StyleBag - Style<\(target)> is missing the \
                    control's own setters.
                    """)
            }
        }
    }

    /// The property tiers must stay PROPERTY tiers: a handler subscribed from
    /// one would be reachable from a style, which is the exact hole the tier
    /// split closes. Source-read, so it can only under-report; the compiler
    /// carries the rest - `addHandler` is declared on `BindableObject`, out of
    /// a `PropertyContainer` extension's reach.
    func testThePropertyTiersCarryNoHandlers() throws {
        for source in try Fixtures.allSources() where source.path.hasPrefix("Views/") {
            for block in source.text.components(separatedBy: "\nextension ").dropFirst() {
                let name = block.prefix { $0 != " " && $0 != ":" && $0 != "{" }

                guard name.hasSuffix("Properties") || name == "PropertyContainer"
                        || name == "PaddingElement" || name == "TextStyleElement"
                        || name == "TextElement" || name == "FontElement"
                        || name == "TextAlignmentElement" || name == "BarElement"
                else { continue }

                XCTAssertFalse(
                    block.components(separatedBy: "\n}\n").first?.contains("addHandler") ?? false,
                    "extension \(name) in \(source.path) puts a handler on the property side")
            }
        }
    }

    // MARK: - The fixture

    /// A styled tree as the host receives it, kept where both halves can see it.
    ///
    /// The whole contract: no style, no dictionary, no key - four controls
    /// carrying what their styles gave them, one of them with the states its
    /// style declared.
    func testAStyledTreeIsWrittenDown() throws {
        let differ = Differ()

        let sheet = StyleSheet {
            Style<Label>()
                .textColor(Color(light: Color.fromArgb("#212121"), dark: .white))
                .fontSize(14)

            Style<Label>("Body").fontSize(16)

            Style<Label>("Headline")
                .fontSize(32)
                .fontAttributes(.bold)
                .horizontalTextAlignment(.center)
                .basedOn("Body")

            Style<Button>()
                .textColor(.white)
                .backgroundColor(Color.fromArgb("#512BD4"))
                .cornerRadius(8)
                .padding(14, 10)
                .minimumHeightRequest(44)
                .visualState(.disabled) { $0
                    .textColor(Color(light: Color.fromArgb("#141414"),
                                     dark: Color.fromArgb("#C8C8C8")))
                    .backgroundColor(Color.fromArgb("#C8C8C8"))
                }

            Style<Border>()
                .stroke(Color.fromArgb("#C8C8C8"))
                .strokeThickness(1)
                .strokeShape(.roundRectangle(12))
        }

        let tree = Node(type: "Application", children: [
            Node(type: "Window", children: [
                Node(type: "ContentPage", children: [
                    VStack {
                        Label("Welcome").style("Headline")
                        Label("Body text")
                        Button("Save").isEnabled(false)
                        Border { Label("in a border") }
                    }
                    .body,
                ]),
            ]),
        ])

        let result = differ.reconcile(nil, with: tree, styles: sheet)

        let bytes = Wire.encode(result.patch, generation: 1, dictionary: WireDictionary())
        try Fixtures.check(
            bytes,
            sidecar: WireProbe.dumpMessage(bytes, names: WireNames()),
            against: "styled")
    }
}
