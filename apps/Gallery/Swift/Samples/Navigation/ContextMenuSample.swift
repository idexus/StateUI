import StateUI

/// MAUI: FlyoutBase.ContextFlyout, filled with a MenuFlyout.
struct ContextMenuSample: SampleContent {
    @State private var items = ["Alpha", "Beta", "Gamma"]
    @State private var chosen = "nothing yet"

    static let id = "contextMenu"
    static let title = "Context menu"
    static let summary = "A menu on the view itself, opened with a right-click."

    // MAUI attaches a context flyout on Mac Catalyst and Windows and nowhere
    // else - ViewHandler.MapContextFlyout is an EMPTY method on iOS and
    // Android, read from 10.0.20's IL after a long press on both kinds of
    // phone showed nothing. So the listing follows the menu, the TitleBar
    // rule; the route still reaches the page on any device.
    static let idioms: Set<DeviceIdiom> = [.desktop]

    static let code = """
        @State private var items = ["Alpha", "Beta", "Gamma"]
        @State private var chosen = "nothing yet"

        VStack {
            ForEach(Array(items.enumerated()), id: \\.offset) { pair in
                let (index, item) = pair
                return Label(item)
                    .contextFlyout {
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

    var example: Element {
        VStack {
            VStack {
                ForEach(Array(items.enumerated()), id: \.offset) { pair in
                    let (index, item) = pair
                    return Label(item)
                        .fontSize(16)
                        .padding(14, 10)
                        .backgroundColor(Palette.raised)
                        .contextFlyout {
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
                .horizontalOptions(.start)
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

            Label("ONLY A DESKTOP SHOWS ONE. MAUI attaches the menu on Mac Catalyst and "
                + "Windows; on iOS and Android a long press opens nothing and nothing "
                + "complains. Never put the only way to do something behind a context "
                + "menu.")
                .fontSize(12)
                .textColor(Palette.subtle)

            Label("The menu is a slot on the view rather than one of its children: it is "
                + "written with a modifier, so a Label, a stack or a Border all take one, and "
                + "whatever arranges that control's children leaves it alone.")
                .fontSize(12)
                .textColor(Palette.subtle)
        }
        .spacing(12)
    }
}
