import StateUI

/// A native context menu attached to any StateUI view.
struct ContextMenuSample: SampleContent, ExampleContent {
    @State private var items = ["Alpha", "Beta", "Gamma"]
    @State private var chosen = "nothing yet"

    static let id = "contextMenu"
    static let title = "Context menu"
    static let summary = "A menu on the view itself, opened with a right-click."

    // The interaction belongs to desktop hosts. The route still remains
    // reachable on every device even where the sample is not listed.
    static let idioms: Set<DeviceIdiom> = [.desktop]

    static let code = """
        @State private var items = ["Alpha", "Beta", "Gamma"]
        @State private var chosen = "nothing yet"

        VStack {
            // The run and what was chosen are read here, so every menu item
            // that acts builds this closure.
            DebugInfoLabel()

            ForEach(Array(items.enumerated()), id: \\.offset) { pair in
                let (index, item) = pair
                return Label(item)
                    .contextMenu {
                        MenuFlyoutItem("Duplicate")
                            .onClicked {
                                items.insert(item + " copy", at: index + 1)
                                chosen = "duplicated \\(item)"
                            }

                        MenuFlyoutSubItem("Move") {
                            MenuFlyoutItem("To the top")
                                .isEnabled(index > 0)
                                .onClicked {
                                    items.remove(at: index)
                                    items.insert(item, at: 0)
                                    chosen = "moved \\(item) to the top"
                                }
                        }

                        MenuFlyoutSeparator()

                        MenuFlyoutItem("Remove")
                            .isDestructive(true)
                            .onClicked {
                                items.remove(at: index)
                                chosen = "removed \\(item)"
                            }
                    }
            }

            Label("Last: \\(chosen)")

            Button("Start again")
                .onClicked {
                    items = ["Alpha", "Beta", "Gamma"]
                    chosen = "nothing yet"
                }
        }
        """

    var content: any View {
        VStack {
            DebugInfoLabel()

            VStack {
                ForEach(Array(items.enumerated()), id: \.offset) { pair in
                    let (index, item) = pair
                    return Label(item)
                        .fontSize(16)
                        .padding(14, 10)
                        .backgroundColor(Palette.raised)
                        .contextMenu {
                            MenuFlyoutItem("Duplicate")
                                .onClicked {
                                    items.insert(item + " copy", at: index + 1)
                                    chosen = "duplicated \(item)"
                                }

                            MenuFlyoutSubItem("Move") {
                                MenuFlyoutItem("To the top")
                                    .isEnabled(index > 0)
                                    .onClicked {
                                        items.remove(at: index)
                                        items.insert(item, at: 0)
                                        chosen = "moved \(item) to the top"
                                    }
                            }

                            MenuFlyoutSeparator()

                            MenuFlyoutItem("Remove")
                                .isDestructive(true)
                                .onClicked {
                                    items.remove(at: index)
                                    chosen = "removed \(item)"
                                }
                        }
                }
            }
            .spacing(2)

            Label("Last: \(chosen)")
                .fontSize(13)
                .textColor(Palette.accent)

            Button("Start again")
                .padding(20, 10)
                .horizontalAlignment(.start)
                .onClicked {
                    items = ["Alpha", "Beta", "Gamma"]
                    chosen = "nothing yet"
                }
        }
        .spacing(12)
    }

    var notes: Element? {
        VStack {
            Label("Right-click a row. The entries are the same three a menu bar takes - "
                + "an item, a submenu and a separator - attached to a view instead of to "
                + "a page.")
                .fontSize(12)
                .textColor(Palette.subtle)

            Label("Context menus are optional platform furniture. Never put the only "
                + "way to perform an essential action behind one.")
                .fontSize(12)
                .textColor(Palette.subtle)

            Label("The menu is a slot on the view rather than one of its children: it is "
                + "written with a modifier, so a Label, a stack or a Border all take one, and "
                + "whatever arranges that control's children leaves it alone.")
                .fontSize(12)
                .textColor(Palette.subtle)
        }
        .spacing(8)
    }
}
