// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

// The MAUI host's Linux platform, lib/StateUI.Maui/Linux, and the head every
// application gives it.
//
// Linux is drawn by MAUI's GTK4 backend, and each file beside LinuxHost.cs
// answers something that backend leaves undone. Nothing in this suite makes a
// GTK widget, so a gap left open passes every behavioural test there is. These
// guards read the sources instead, each with the symptom it keeps away.

import Foundation
import XCTest

final class MauiLinuxTests: XCTestCase {
    /// `lib/StateUI.Maui/Linux`.
    private var platform: URL {
        Fixtures.repository.appendingPathComponent("lib/StateUI.Maui/Linux")
    }

    // MARK: - The platform

    /// The platform arms every gap, from one place. Each `Linux*.cs` beside
    /// `LinuxHost.cs` answers one hole in the GTK4 backend, and an install
    /// left out fails at run time on this platform alone - a tap heard by no
    /// one, a label wearing one property, a navigation that reaches GTK from
    /// the wrong thread. `LinuxHost.Use` installs them all, and it is what an
    /// application's one `UseStateUIApp` call reaches on Linux.
    func testTheLinuxPlatformArmsEveryGap() throws {
        let host = try source("LinuxHost.cs")

        let gaps = try FileManager.default.contentsOfDirectory(atPath: platform.path)
            .filter { $0.hasPrefix("Linux") && $0.hasSuffix(".cs") && $0 != "LinuxHost.cs" }
            .map { String($0.dropLast(3)) }
            .sorted()

        XCTAssertFalse(gaps.isEmpty, "a Linux platform with no Linux*.cs answers nothing.")

        for gap in gaps {
            XCTAssertTrue(
                host.contains("\(gap).Install("),
                "\(gap) is never installed from LinuxHost - its gap is open on Linux.")
        }

        let hosting = try source("StateUIApp.cs")
        XCTAssertTrue(
            hosting.contains("LinuxHost.Use<TApp>(builder)"),
            "UseStateUIApp does not reach LinuxHost - an application on Linux gets none of "
                + "the answers.")
    }

    /// A page's own room is something only this platform can lose, and both
    /// halves of it are invisible to a headless suite. A page's content is
    /// arranged by its panel rather than by a parent, so MAUI never writes the
    /// root's own frame - and `.frame` and `.onFrameChanged` on it are silent
    /// for the life of the page. And a window resize is announced to MAUI by
    /// nothing at all, so the page goes on wearing the size it was laid out at.
    func testALinuxPageIsToldItsRoomAndHearsTheWindowResize() throws {
        let measures = try source("LinuxMeasures.cs")

        XCTAssertTrue(
            measures.contains("root.Parent is Page") && measures.contains("root.Frame = bounds"),
            "LinuxMeasures never writes a page root's own frame - `.frame` and `.onFrameChanged` "
                + "on a page's content then report nothing on Linux, and a page sized from its "
                + "own room keeps whatever it was declared with.")

        XCTAssertTrue(
            measures.contains("window.OnNotify"),
            "LinuxMeasures hears no window resize - the page is laid out once and keeps that "
                + "size, its rows running off a narrowed window and short of a widened one.")

        XCTAssertTrue(
            measures.contains("flyout.Flyout?.Handler?.PlatformView"),
            "LinuxMeasures lays out only the flyout's detail - the pane beside it is a page "
                + "given a height by the same window, and left out it keeps the one it was "
                + "opened at, its list cut off part way down.")

        XCTAssertTrue(
            measures.contains("stack.Pushed"),
            "LinuxMeasures hears no page arriving - a pushed page is laid out once, before its "
                + "widgets have a size, and keeps whatever that pass decided until something "
                + "else lays it out.")

        XCTAssertTrue(
            measures.contains("VisualElement { Parent: Page }")
                && measures.contains("SetOverflow(Gtk.Overflow.Hidden)"),
            "LinuxMeasures never cuts a page at its own edge - GTK leaves overflow visible, so "
                + "a layout placing its children by arithmetic paints outside the page and "
                + "across the flyout pane beside it.")
    }

    /// A panel laid over a window covers what it draws and nothing else. GTK
    /// picks a widget anywhere in its allocation, and `can-target` - its only
    /// refusal - takes the widget's whole subtree with it: a filling overlay
    /// child answers every click meant for the page, and with the refusal set
    /// the panel's own buttons go dead. So the widget handed to GTK is the
    /// panel inside the root the tree wraps it in, allocated exactly the
    /// rectangle that root's own layout puts it at.
    func testTheLinuxOverlayLaysThePanelAndFollowsTheWindow() throws {
        let overlay = try source("LinuxOverlay.cs")

        XCTAssertTrue(
            overlay.contains("Layout { Count: 1 } root") && overlay.contains("root[0] is View panel"),
            "LinuxOverlay hands GTK the whole overlay rather than the panel inside it - a "
                + "widget filling the window is picked everywhere, so every click meant for "
                + "the page under a docked panel is answered by the panel's own layout.")

        XCTAssertTrue(
            overlay.contains("native.OnNotify"),
            "LinuxOverlay hears no resize - MAUI's own window SizeChanged never fires on this "
                + "backend, so a docked panel keeps the place it was given at the size the "
                + "window happened to have and is stretched by every later one.")

        XCTAssertTrue(
            overlay.contains("AddTickCallback"),
            "LinuxOverlay waits for a size on something other than the display's frames - an "
                + "idle that re-arms itself outruns the frame clock that would have given it "
                + "one, which is a whole core spent and a panel that never appears.")
    }

    /// A scroller whose content goes is emptied. The backend's content mapper
    /// answers a new content and nothing else, so `Content` set to nothing
    /// leaves GTK's viewport holding the old panel: a list whose items all go
    /// keeps every row on screen until an item comes back.
    func testALinuxScrollerLetsGoOfAContentThatWent() throws {
        let scrolling = try source("LinuxScrolling.cs")

        XCTAssertTrue(
            scrolling.contains(
                "AppendToMapping<IScrollView, ScrollViewHandler>(\"Content\", Emptied)")
                && scrolling.contains("viewport.SetChild(null)"),
            "LinuxScrolling leaves a scroller's old content in its viewport when the tree says "
                + "it holds nothing - an emptied list keeps its rows on screen until an item "
                + "comes back.")
    }

    /// A label's padding is said once. The backend hands `Label.Padding` to
    /// GTK as the widget's margin, which leaves that room outside the widget's
    /// own background - so the padding is written as CSS, and the margin has
    /// to go, or the two are the same padding twice and every padded row is a
    /// padding taller than what it draws.
    func testALinuxLabelWearsItsPaddingOnce() throws {
        let styling = try source("LinuxStyling.cs")

        XCTAssertTrue(
            styling.contains("widget.MarginTop = 0"),
            "LinuxStyling writes a label's padding as CSS and leaves the margin the backend "
                + "made of the same padding - so the widget asks for that padding twice and "
                + "every list row is a padding taller than what it draws.")

        XCTAssertTrue(
            styling.contains("LabelHandler.Mapper.AppendToMapping"),
            "The margin is cleared from the shared view mapper, which runs BEFORE the label's "
                + "own - so the backend writes it back a moment later and nothing changes.")
    }

    /// A drawing order written between arrangements is still a drawing order.
    /// GTK paints in child order and has no z, so `LinuxTransforms` re-links
    /// the children of a layout whose z has changed - and a placement writes
    /// its z on the host's own frames, arranging nothing, because a move is a
    /// translation. Heard only from the arrangement, a run keeps the order the
    /// last one gave it, and a card ranked behind another is drawn over it.
    func testTheLinuxDrawingOrderFollowsAZWrittenAtAnyTime() throws {
        let transforms = try source("LinuxTransforms.cs")

        XCTAssertTrue(
            transforms.contains("nameof(VisualElement.ZIndex)"),
            "LinuxTransforms hears no change of z - a card the host ranks behind another "
                + "between two arrangements goes on being drawn in front of it.")
    }

    // MARK: - The head

    /// Every application's Linux head is two things and nothing else: the one
    /// hosting call, and an entry point that is the platform's own
    /// application. `StateUIApplication.Start` installs the synchronization
    /// context the GTK loop needs - without it an await continuation resumes
    /// on the thread pool, and whatever it calls next enters GTK off the
    /// thread that owns it. Whatever else answers this platform belongs to
    /// StateUI.Maui.Linux, where every application gets it.
    func testTheLinuxHeadIsHostingAndAnEntryPoint() throws {
        let applications = try Fixtures.applications()
        XCTAssertGreaterThan(applications.count, 1, "apps/ holds no application to read.")

        for application in applications {
            let name = application.lastPathComponent
            let head = application.appendingPathComponent("Platforms/Maui")
            let linux = head.appendingPathComponent("Linux")

            guard FileManager.default.fileExists(atPath: linux.path) else {
                XCTFail("\(name) has no Platforms/Maui/Linux - its MAUI head builds no Linux "
                    + "application.")
                continue
            }

            let hosting = try String(
                contentsOf: head.appendingPathComponent("Host/MauiProgram.cs"), encoding: .utf8)
            XCTAssertTrue(
                hosting.contains("UseStateUIApp<App>()"),
                "\(name): MauiProgram never says UseStateUIApp - on Linux that is the whole "
                    + "platform, and on every other head it is UseMauiApp.")

            let entry = try String(
                contentsOf: linux.appendingPathComponent("Program.cs"), encoding: .utf8)
            XCTAssertTrue(
                entry.contains(": StateUIApplication") && entry.contains("Start<Program>(args)"),
                "\(name): the Linux entry point is not the platform's application - the GTK "
                    + "loop then runs with no synchronization context under it.")

            let strays = Fixtures.files(under: linux).filter { $0 != "Program.cs" }
            XCTAssertEqual(
                strays, [],
                "\(name): Platforms/Maui/Linux holds more than Program.cs - what answers this "
                    + "platform belongs to StateUI.Maui.Linux, where every application gets it.")
        }
    }

    // MARK: - Helpers

    /// One of the Linux platform's sources, read as text.
    private func source(_ name: String) throws -> String {
        try String(contentsOf: platform.appendingPathComponent(name), encoding: .utf8)
    }
}
