import StateUI

/// Pages presented in a sheet: a stack whose pages put their actions on the sheet's bar - at its start and its end,
/// in a group, with a menu, a setting and the overflow - and tabs, each a stack with actions of its own.
struct SheetsSample: SampleContent {
    static let id = "sheets"
    static let title = "Sheets"
    static let summary = "A stack in a sheet with its bar's actions, and tabs in a sheet."

    var examples: [Example] { [Example(StackInASheet()), Example(TabsInASheet())] }
}

/// A stack presented in a sheet, its pages' actions on the sheet's bar.
private struct StackInASheet: ExampleContent {
    // listing: StackInASheet
    @State private var presented = false
    @State private var said = "Nothing done yet."

    var body: some View {
        VStack {
            Text("Present the sheet, press its actions and push a page.")
                .fontSize(12)
                .textColor(Palette.subtle)

            Button("Present the stack")
                .accessibilityIdentifier("sheets.stack")
                .horizontalAlignment(.center)
                .onClicked { presented = true }
                .sheet(isPresented: $presented) {
                    DraftSheet(said: $said)
                }

            Text(said)
                .fontSize(13)
                .fontFamily("Menlo")
                .textColor(Palette.accent)
        }
        .spacing(12)
    }
    // listing: end

    var notes: (any View)? {
        Text("A stack in a sheet brings its bar, and each page puts its actions there as it would in a window: "
            + "Undo at the start, Save and Add as one group at the end, the pin a setting, Delete in the "
            + "overflow, beside the sheet's close button. A pushed page brings its own; Help, the stack's own, "
            + "stands on every page.")
            .fontSize(12)
            .textColor(Palette.subtle)
    }
}

// listing: StackInASheet
/// A draft's stack in a sheet: the bar's actions are its pages', and Help is
/// the stack's own, on every page it shows.
private struct DraftSheet: View {
    @Binding var said: String
    @State private var path: [Int] = []
    @State private var pinned = false

    var body: some View {
        NavigationStack($path) {
            VStack {
                Text(said)
                Text(pinned ? "Pinned" : "Not pinned")
                    .textColor(Palette.subtle)
                Button("Push a page")
                    .accessibilityIdentifier("sheets.push")
                    .onClicked { path.append(path.count + 1) }
            }
            .spacing(16)
            .padding(24)
            .galleryPage("Draft")
            .toolbar {
                ToolbarButton("Undo")
                    .id("sheet.undo")
                    .placement(at: .start)
                    .onClicked { said = "Undone." }

                ToolbarGroup {
                    ToolbarButton("Save")
                        .id("sheet.save")
                        .onClicked { said = "Saved." }
                        .menu(.split) {
                            MenuItem("Save a copy")
                                .id("sheet.saveCopy")
                                .onClicked { said = "Saved a copy." }
                        }

                    ToolbarButton("Add")
                        .id("sheet.add")
                        .icon(ImageSource(light: "menu_duplicate.png", dark: "menu_duplicate_dark.png"))
                        .onClicked { said = "Added." }
                }

                ToolbarToggle("Pin", isOn: $pinned)
                    .id("sheet.pin")
                    .icon(
                        ImageSource(light: "menu_star.png", dark: "menu_star_dark.png"),
                        on: ImageSource(light: "menu_star_on.png", dark: "menu_star_on_dark.png"))

                ToolbarButton("Delete")
                    .id("sheet.delete")
                    .placement(at: .overflow)
                    .role(.destructive)
                    .onClicked { said = "Deleted." }
            }
        } destination: { number in
            Text("Page \(number)")
                .padding(24)
                .galleryPage("Page \(number)")
                .toolbar {
                    ToolbarButton("Share")
                        .id("sheet.share")
                        .onClicked { said = "Shared page \(number)." }
                }
        }
        // The stack's own action, on the bar of every page it shows.
        .toolbar {
            ToolbarButton("Help")
                .id("sheet.help")
                .onClicked { said = "Help for every page." }
        }
    }
}
// listing: end

/// Tabs presented in a sheet, each tab a stack with its bar's actions.
private struct TabsInASheet: ExampleContent {
    // listing: TabsInASheet
    @State private var presented = false
    @State private var said = "Nothing done yet."

    var body: some View {
        VStack {
            Text("Present the tabs, change tabs and press each tab's actions.")
                .fontSize(12)
                .textColor(Palette.subtle)

            Button("Present the tabs")
                .accessibilityIdentifier("sheets.tabs")
                .horizontalAlignment(.center)
                .onClicked { presented = true }
                .sheet(isPresented: $presented) {
                    MailSheet(said: $said)
                }

            Text(said)
                .fontSize(13)
                .fontFamily("Menlo")
                .textColor(Palette.accent)
        }
        .spacing(12)
    }
    // listing: end

    var notes: (any View)? {
        Text("Each tab is a stack of its own: its bar, its actions and its pushed pages stay with it as the tabs "
            + "change, and the sheet's close button stands on every tab's bar.")
            .fontSize(12)
            .textColor(Palette.subtle)
    }
}

// listing: TabsInASheet
/// A mailbox's tabs in a sheet, each a stack.
private struct MailSheet: View {
    enum Tab: Hashable, CaseIterable { case inbox, drafts }

    @Binding var said: String
    @State private var tab: Tab = .inbox
    @State private var inbox: [Int] = []
    @State private var drafts: [Int] = []

    var body: some View {
        TabView(Tab.allCases, selection: $tab) { tab in
            switch tab {
            case .inbox:
                NavigationStack($inbox) {
                    page("Inbox", path: $inbox)
                        .toolbar {
                            ToolbarButton("Refresh")
                                .id("tabs.refresh")
                                .onClicked { said = "Refreshed the inbox." }
                        }
                } destination: { number in
                    Text("Message \(number)").padding(24).galleryPage("Message \(number)")
                }
                .title("Inbox")
                .icon(ImageSource(light: "tab_pages.png", dark: "tab_pages_dark.png"))

            case .drafts:
                NavigationStack($drafts) {
                    page("Drafts", path: $drafts)
                        .toolbar {
                            ToolbarGroup {
                                ToolbarButton("New")
                                    .id("tabs.new")
                                    .icon(ImageSource(light: "menu_duplicate.png", dark: "menu_duplicate_dark.png"))
                                    .onClicked { said = "Started a draft." }
                                ToolbarButton("Send all")
                                    .id("tabs.send")
                                    .onClicked { said = "Sent every draft." }
                            }
                        }
                } destination: { number in
                    Text("Draft \(number)").padding(24).galleryPage("Draft \(number)")
                }
                .title("Drafts")
                .icon(ImageSource(light: "tab_code.png", dark: "tab_code_dark.png"))
            }
        }
    }

    /// A tab's first page: its name, and a button pushing a page onto its stack.
    private func page(_ name: String, path: Binding<[Int]>) -> some View {
        VStack {
            Text(said)
            Button("Push a page")
                .accessibilityIdentifier("tabs.push.\(name.lowercased())")
                .onClicked { path.wrappedValue.append(path.wrappedValue.count + 1) }
        }
        .spacing(16)
        .padding(24)
        .galleryPage(name)
    }
}
// listing: end
