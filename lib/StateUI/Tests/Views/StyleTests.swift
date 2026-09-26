// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

// Styles: what a style is, and what a control wearing one puts in the patch.
//
// A style never travels. It is a bag of the same property values a control
// carries, and the differ merges it into the control it belongs to - so most of
// this file is about the RESOLUTION: which style a control wears, whose value
// wins, and what the message therefore says - which is what a host reads,
// asserted at the end of this file.

import Foundation
import XCTest
@_spi(Host) @testable import StateUI

/// The window under every styled application here.
private struct HomeWindow: Window {
    var page: any Page { Home() }
}

/// An application with styles, which is where an application keeps them - written
/// into the application's session as it is made.
private struct StyledApp: Application {
    @Environment private var application: ApplicationSession

    init() {
        application.styles = StyleSheet {
            Style<Label>().fontSize(14)
        }
    }

    var scene: any Scene { HomeWindow() }
}

private struct Home: ContentView {
    var content: any View { ModifiedContent(node: label("home")) }
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
    /// compile, a style conforming to the property tiers alone. Its states are
    /// values too: a name, a group and what they set.
    func testAStyleCarriesValuesAndStatesOnly() {
        let style = Style<Button>()
            .strokeWidth(2)
            .visualState(.disabled) { $0.textColor(.gray) }
            .erased

        XCTAssertEqual(style.props["strokeWidth"], .number(2))
        XCTAssertEqual(style.states, [
            DeclaredState(name: "Disabled", setters: ["textColor": Color("#808080").propValue]),
        ])
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

    /// A key naming a style declared for ANOTHER control falls through to the
    /// implicit style, exactly as a key naming nothing does: half of a
    /// Button's values applied to a Label and half dropped unread is a
    /// mismatch, and no style is the honest answer.
    func testAKeyDeclaredForAnotherControlFallsThroughToTheImplicit() {
        let sheet = StyleSheet {
            Style<Button>("Cta").fontSize(20)
            Style<Label>().fontSize(14)
        }

        let worn = sheet.style(for: Label("x").style("Cta").node)

        XCTAssertEqual(worn?.props["fontSize"], .number(14),
                       "the implicit Label style answers, not the Button's")
        XCTAssertEqual(worn?.target, .label)
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
    /// it is flattened.
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

    /// A key naming nothing falls through to the implicit style: an unresolved
    /// style is no style, and no style is what makes an implicit one apply.
    func testAKeyNobodyFiledFallsThroughToTheImplicitStyle() {
        let sheet = StyleSheet { Style<Label>().fontSize(14) }

        XCTAssertEqual(
            sheet.style(for: Label("x").style("Nothing").node)?.props["fontSize"], .number(14))
    }

    // MARK: - Resolving one into a control

    /// The implicit style's values arrive on the control, and the control's own
    /// win - one property at a time, which is this library's precedence
    /// everywhere.
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

    /// A sheet that MOVED is one thing a composed view's inputs cannot see:
    /// a style is not one of them, so the differ compares the sheet beside
    /// them and builds the view when it moved.
    func testAStyleThatMovedReachesACarriedView() {
        struct Card: ContentView {
            var content: any View { Label("card") }
        }

        let renders = Renders()
        let tree = Node(type: "VStack", children: [Card().body])
        renders.render(tree, styles: StyleSheet { Style<Label>().fontSize(14) })
        let patch = renders.render(tree, styles: StyleSheet { Style<Label>().fontSize(20) })
        XCTAssertEqual(patch.children.first?.props["fontSize"], .number(20))
    }

    /// And a sheet that did not move leaves the carry where it was: a view
    /// built with the same inputs under the same sheet is not built again.
    func testAnUnchangedSheetLeavesACarriedViewAlone() {
        struct Card: ContentView {
            var content: any View { Label("card") }
        }

        let renders = Renders()
        let tree = Node(type: "VStack", children: [Card().body])
        let sheet = { StyleSheet { Style<Label>().fontSize(14) } }
        renders.render(tree, styles: sheet())
        XCTAssertTrue(renders.render(tree, styles: sheet()).isEmpty)
    }

    // MARK: - Colours that follow the theme

    /// A colour with a dark half is written as BOTH - the style holds the
    /// pair - and the element wearing it is built with the half the theme
    /// says. One sheet, made once, serves both themes.
    func testAColourWithADarkHalfIsWrittenAsBothAndBuiltAsOne() {
        let themed = Color(light: .white, dark: Color("#1f1f1f"))
        let sheet = StyleSheet { Style<Label>().textColor(themed) }

        XCTAssertEqual(
            Style<Label>().textColor(themed).erased.props["textColor"],
            .themed(light: Color("#FFFFFF").propValue, dark: Color("#1f1f1f").propValue),
            "written, it is both halves")

        XCTAssertEqual(
            Renders().render(Label("Hi").body, styles: sheet).props["textColor"],
            Color("#FFFFFF").propValue,
            "built while the system is light")

        withTheme(.dark) {
            XCTAssertEqual(
                Renders().render(Label("Hi").body, styles: sheet).props["textColor"],
                Color("#1f1f1f").propValue,
                "and the other half while it is dark, from the same sheet")
        }
    }

    /// It is a Color, so it goes wherever a Color goes - and the half in force
    /// is picked as the element wearing it is built, which is why one colour
    /// arrives.
    func testAThemedColourCanBeWrittenOnAControlToo() {
        let themed = Color(light: .black, dark: .white)

        XCTAssertEqual(
            Label("Hi").textColor(themed).body.props["textColor"],
            .themed(light: Color.black.propValue, dark: Color.white.propValue),
            "written, it is both halves - the differ picks one")

        XCTAssertEqual(
            Renders().render(Label("Hi").textColor(themed).body).props["textColor"],
            Color.black.propValue)

        withTheme(.dark) {
            XCTAssertEqual(
                Renders().render(Label("Hi").textColor(themed).body).props["textColor"],
                Color.white.propValue)
        }
    }

    /// A pair written OUTSIDE every build - here in the test itself, the way a
    /// handler writes one into a session - follows the theme all the same:
    /// the element wearing it is the theme's reader, whoever wrote it.
    func testAThemedColourWrittenOutsideEveryBuildFollowsTheTheme() {
        let app = StandardEnvironment.app
        let was = app.requestedTheme
        defer { app.requestedTheme = was }
        app.requestedTheme = .light

        let written = Label("Hi").textColor(Color(light: .black, dark: .white)).body
        let renders = Renders()
        let first = renders.render(stack([written], id: "root"))
        XCTAssertEqual(first.child(.auto(1))?.props["textColor"], Color.black.propValue)

        Renderer.shared.clearInvalidation()
        app.requestedTheme = .dark
        let flipped = renders.revisit(changed: Renderer.shared.pendingChanges)

        XCTAssertEqual(
            flipped.child(.auto(1))?.props["textColor"], Color.white.propValue,
            "the label is the theme's reader, and was built again for it")
    }

    /// A theme change builds the element wearing the pair and nothing around
    /// it: the closure that wrote the label read nothing, and does not run
    /// again.
    func testAThemeChangeBuildsTheElementWearingThePairAlone() {
        let app = StandardEnvironment.app
        let was = app.requestedTheme
        defer { app.requestedTheme = was }
        app.requestedTheme = .light

        let runs = Runs()
        let renders = Renders()
        renders.render(stack([Wearing(runs: runs).body], id: "root"))
        XCTAssertEqual(runs.count, 1)

        Renderer.shared.clearInvalidation()
        app.requestedTheme = .dark
        let flipped = renders.revisit(changed: Renderer.shared.pendingChanges)

        XCTAssertEqual(runs.count, 1, "the closure that wrote the label read nothing")
        XCTAssertEqual(
            flipped.child(.auto(1))?.child(.auto(2))?.props["textColor"], Color.white.propValue,
            "and the label was built again from what it wrote")
    }

    /// A colour PAIR in a state the host carries crosses as the half in force,
    /// and reading the state answers the pair that was written.
    func testAColourPairTheHostCarriesCrossesAsTheHalfInForce() {
        withTheme(.dark) {
            let tint = State(Color(light: .black, dark: .white))
            _ = tint.projectedValue.journeyImage

            XCTAssertEqual(tint.storage.journeyLanes?.destination, Color.white)
            XCTAssertEqual(tint.wrappedValue, Color(light: .black, dark: .white))
        }
    }

    /// And it follows the theme: the element handing the state on is the
    /// theme's reader, so a theme change builds it again and the host is sent
    /// to the other half - the way a pair written on a node crosses.
    func testAColourPairTheHostCarriesFollowsTheTheme() {
        let app = StandardEnvironment.app
        let was = app.requestedTheme
        defer { app.requestedTheme = was }
        app.requestedTheme = .light

        let tint = State(Color(light: .black, dark: .white))
        let renders = Renders()
        renders.render(stack([Tinted(tint: tint.projectedValue).body], id: "root"))

        XCTAssertEqual(tint.storage.journeyLanes?.destination, Color.black)

        Renderer.shared.clearInvalidation()
        app.requestedTheme = .dark
        renders.revisit(changed: Renderer.shared.pendingChanges)

        XCTAssertEqual(
            tint.storage.journeyLanes?.destination, Color.white,
            "the element handing the state on read the theme, and laid the other half")
    }

    /// A box whose colour the host carries from a state it is handed.
    private struct Tinted: ContentView {
        let tint: Binding<Color>

        var content: any View { ColorBox().background(tint) }
    }

    /// Counts how often the closure writing a label runs.
    private final class Runs {
        var count = 0

        func text(_ words: String) -> String {
            count += 1
            return words
        }
    }

    /// A pair on a label inside a stack whose closure reads nothing.
    private struct Wearing: ContentView {
        let runs: Runs

        var content: any View {
            VStack {
                Label(runs.text("Hi")).textColor(Color(light: .black, dark: .white))
            }
        }
    }

    /// And a style's colour becomes the CONTROL's, resolved on the way - so
    /// no host binds or resolves a theme.
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
    /// recorded against whichever view is being built - against the THEME
    /// property, so the change that finds it is a write to `requestedTheme`
    /// and nothing else the app object says.
    func testWritingAThemedColourRecordsAReadOfTheTheme() {
        let app = StandardEnvironment.app
        let was = app.requestedTheme
        defer { app.requestedTheme = was }
        app.requestedTheme = .light

        // Built by the differ, inside the view's own read scope - a node the
        // test builds eagerly as an argument is read by nobody. In a block of
        // its own, so this reader is gone before the second half asks whether
        // a plain colour left any.
        do {
            let renders = Renders()
            let first = renders.render(stack([Themed().body], id: "root"))
            XCTAssertEqual(first.child(.auto(1))?.props["textColor"], Color.black.propValue)

            Renderer.shared.clearInvalidation()
            app.requestedTheme = .dark
            let flipped = renders.revisit(changed: Renderer.shared.pendingChanges)

            XCTAssertEqual(flipped.child(.auto(1))?.props["textColor"], Color.white.propValue,
                           "a themed colour depends on the theme, and the theme found it")
        }

        // A colour with one half asks nothing: with only that label live, the
        // theme's write has no reader and the renderer refuses it.
        let plain = Renders()
        plain.render(stack([Plain().body], id: "root"))
        Renderer.shared.clearInvalidation()
        app.requestedTheme = .light

        XCTAssertFalse(Renderer.shared.needsRender, "a colour with one half asks nothing")
        _ = plain
    }

    /// A label whose colour has two halves, built where the differ can see
    /// the read.
    private struct Themed: ContentView {
        var content: any View {
            Label("Hi").textColor(Color(light: .black, dark: .white))
        }
    }

    /// The same label with one half, which asks the theme nothing.
    private struct Plain: ContentView {
        var content: any View {
            Label("Hi").textColor(.black)
        }
    }

    // MARK: - Pictures that follow the theme

    /// The same story a themed colour tells: the picture is written as both
    /// names, and the element showing it is built with the one in force - so
    /// one name crosses.
    func testAPictureCanBeDrawnOncePerTheme() {
        func both() -> Node { Image(light: "nav_home.png", dark: "nav_home_dark.png").body }

        XCTAssertEqual(
            both().props["source"],
            .themed(light: .string("nav_home.png"), dark: .string("nav_home_dark.png")))
        XCTAssertEqual(Renders().render(both()).props["source"], .string("nav_home.png"))

        withTheme(.dark) {
            XCTAssertEqual(Renders().render(both()).props["source"], .string("nav_home_dark.png"))
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

    /// The pictures that hang off a PAGE take one too, and a pair stays a
    /// pair on the node - written into a page's session from a handler, it is
    /// still the differ that picks which one is shown.
    func testAPagesPictureIsWrittenAsBothAndShownAsOne() {
        let item = ToolbarItem("Save")
            .icon(ImageSource(light: "tab_list.png", dark: "tab_list_dark.png"))

        XCTAssertEqual(
            item.node.props["icon"],
            .themed(light: .string("tab_list.png"), dark: .string("tab_list_dark.png")))

        withTheme(.dark) {
            XCTAssertEqual(
                Renders().render(item.body).props["icon"], .string("tab_list_dark.png"))
        }

        let menu = MenuItem("Reset").icon("menu_reset.png")

        XCTAssertEqual(menu.node.props["icon"], .string("menu_reset.png"))
    }

    // MARK: - Asking for one

    func testAControlAsksForAKeyedStyleByName() {
        XCTAssertEqual(Label("Welcome").style("Headline").body.props["style"],
                       .name("Headline"))
    }

    // MARK: - Where they live

    /// The application's sheet reaches the controls under its window, and
    /// nothing about the sheet itself is in the patch.
    func testTheApplicationsStylesReachTheControlsAndNothingElse() {
        Renderer.shared.setApplication(StyledApp())

        let dump = PatchDump.text(Renderer.shared.renderHost(baseline: 0).root)

        XCTAssertTrue(dump.contains("fontSize: number 14"), dump)
        XCTAssertFalse(dump.contains("ResourceDictionary"), dump)
        XCTAssertFalse(dump.contains("Style"), dump)
    }

    /// An application that declares none says nothing about styles, and its
    /// controls carry only what they were written with.
    func testAnApplicationWithNoStylesLeavesItsControlsAlone() {
        struct Plain: Application {
            var scene: any Scene { HomeWindow() }
        }

        Renderer.shared.setApplication(Plain())

        XCTAssertFalse(
            PatchDump.text(Renderer.shared.renderHost(baseline: 0).root)
                .contains("fontSize"))
    }

    // MARK: - The set, kept honest

    /// Every control can be styled, or the rule is not a rule.
    ///
    /// The same kind of check as testEveryControlHasACase next door, and the
    /// same justification for reading source code: it is a test, and it can only
    /// ever under-report - and the count at its end refuses a scan that reads
    /// nothing.
    func testEveryControlIsAStyleTarget() throws {
        let declared = try SourceTree.text(in: "StyleTarget.swift")
        var read = 0

        for source in try SourceTree.controlSources() {
            for type in try SourceTree.nodeTypes(in: source).sorted()
            where !SourceTree.notViews.contains(type) {
                read += 1
                XCTAssertTrue(declared.contains("extension \(type): StyleTarget {}"), """
                    \(source) describes \(type), which StyleTarget.swift does \
                    not declare a style target.

                    Every control can be styled. Give it an initializer that \
                    sets nothing, if it has none, and add the conformance.
                    """)
            }
        }

        XCTAssertGreaterThan(read, 30, "the scan read almost nothing")
    }

    /// And the other half of the same rule: a control's OWN property surface
    /// is a `<Name>Properties` protocol, and the style wears it. A protocol
    /// declared without its `StyleBag` conformance would compile and quietly
    /// leave `Style<Name>` without the control's own setters.
    func testEveryPropertySurfaceReachesTheStyle() throws {
        let declared = try SourceTree.text(in: "StyleBag+Properties.swift")
        var read = 0

        // The shared tier's files declare the TIER surfaces, which reach the
        // style through the `where Target:` conformances - this walk is about
        // the per-control ones, declared beside their control.
        for source in try SourceTree.controlSources() where !SourceTree.sharedTier.contains(source) {
            let text = try SourceTree.text(in: source)

            for surface in text.occurrences(between: "public protocol ", and: ":")
            where surface.hasSuffix("Properties") {
                let target = String(surface.dropLast("Properties".count))

                read += 1

                XCTAssertTrue(
                    declared.contains(
                        "extension StyleBag: \(surface) where Target == \(target) {}"),
                    """
                    \(source) declares \(surface), which StyleBag+Properties.swift \
                    does not hand to StyleBag - Style<\(target)> is missing the \
                    control's own setters.
                    """)
            }
        }

        XCTAssertGreaterThan(read, 21, "the scan read almost nothing")
    }

    /// The property tiers must stay PROPERTY tiers: a handler subscribed from
    /// one would be reachable from a style, which is the exact hole the tier
    /// split closes. Source-read, so it can only under-report; the compiler
    /// carries the rest - `addHandler` is declared on `ModifiableElement`, out of
    /// a `PropertyContainer` extension's reach.
    func testThePropertyTiersCarryNoHandlers() throws {
        var read = 0

        for source in try SourceTree.allSources() where source.path.hasPrefix("Views/") {
            for block in source.text.components(separatedBy: "\nextension ").dropFirst() {
                let name = block.prefix { $0 != " " && $0 != ":" && $0 != "{" }

                guard name.hasSuffix("Properties") || name == "PropertyContainer"
                        || name == "PaddingElement" || name == "TextStyleElement"
                        || name == "TextElement" || name == "FontElement"
                        || name == "TextAlignmentElement" || name == "BarElement"
                else { continue }

                read += 1

                XCTAssertFalse(
                    block.components(separatedBy: "\n}\n").first?.contains("addHandler") ?? false,
                    "extension \(name) in \(source.path) puts a handler on the property side")
            }
        }

        XCTAssertGreaterThan(read, 35, "the scan read almost nothing")
    }

    // MARK: - What a host receives

    /// A styled tree as the host receives it. The whole contract: no style, no
    /// sheet, no key - four controls carrying what their styles gave them, one
    /// of them with the states its style declared.
    func testAStyledTreeArrivesAsItsControlsValues() throws {
        let differ = Differ()

        let sheet = StyleSheet {
            Style<Label>()
                .textColor(Color(light: Color("#212121"), dark: .white))
                .fontSize(14)

            Style<Label>("Body").fontSize(16)

            Style<Label>("Headline")
                .fontSize(32)
                .fontAttributes(.bold)
                .horizontalTextAlignment(.center)
                .basedOn("Body")

            Style<Button>()
                .textColor(.white)
                .background(Color("#512BD4"))
                .shape(.roundedRectangle(8))
                .padding(14, 10)
                .minimumHeight(44)
                .visualState(.disabled) { $0
                    .textColor(Color(light: Color("#141414"),
                                     dark: Color("#C8C8C8")))
                    .background(Color("#C8C8C8"))
                }

            Style<ZStack>()
                .stroke(Color("#C8C8C8"))
                .strokeWidth(1)
                .shape(.roundedRectangle(12))
        }

        var main = Node(type: "Window", children: [
            Node(type: "Page", children: [
                VStack {
                    Label("Welcome").style("Headline")
                    Label("Body text")
                    Button("Save").isEnabled(false)
                    ZStack { Label("in an outline") }
                }
                .body,
            ]),
        ])
        main.id = SceneElement.mainKey

        var scene = Node(type: "Scene", children: [main])
        scene.id = "1"

        let tree = Node(type: "Application", children: [scene])

        let stack = try XCTUnwrap(differ.reconcile(nil, with: tree, styles: sheet).patch
            .at(.manual("1"), .manual(SceneElement.mainKey), .auto(2), .auto(3)))
        let ink = Color("#212121").propValue

        // The headline's style, based on the body's - and standing in place of
        // the default label's, whose colour it does not take.
        XCTAssertEqual(stack.at(.auto(4))?.props, [
            "text": .string("Welcome"), "fontSize": .number(32),
            "fontAttributes": FontAttributes.bold.propValue,
            "horizontalTextAlignment": TextAlignment.center.propValue,
        ])
        XCTAssertEqual(stack.at(.auto(5))?.props, [
            "text": .string("Body text"), "fontSize": .number(14), "textColor": ink,
        ])

        // The button in the state its style declared for a disabled one, that
        // state's values the half of the theme in force; no state crosses.
        let button = try XCTUnwrap(stack.at(.auto(6)))
        XCTAssertEqual(button.props["background"], Color("#C8C8C8").propValue)
        XCTAssertEqual(button.props["textColor"], Color("#141414").propValue)
        XCTAssertEqual(button.props["isEnabled"], .bool(false))
        XCTAssertTrue(button.children.isEmpty)

        // A card's style, and the default label's inside it.
        XCTAssertEqual(stack.at(.auto(7))?.props["strokeWidth"], .number(1))
        XCTAssertEqual(stack.at(.auto(7), .auto(8))?.props["fontSize"], .number(14))

        XCTAssertFalse(
            stack.subtree.contains { $0.props.keys.contains("style") },
            "no style name reaches the host")
    }
}
