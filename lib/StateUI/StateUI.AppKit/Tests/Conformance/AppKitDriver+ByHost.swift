// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUIConformance

/// What the AppKit driver reaches past AppKit: the acts it hands to the host's own entry, as no event reaches a window
/// never ordered in, and the reads of what the host keeps. A member proven only that way is the host's own - ✓.
/// Design: docs/design/platforms/appkit/conformance.md#what-goes-past-appkit
extension AppKitDriver {
    func byHost(_ ability: String) -> String? {
        let (act, element) = (Ability(ability).act, Ability(ability).element)
        switch act {
        case "tap", "pan", "pinch", "hover", "leave", "drag", "pressDown", "lift":
            return "handed to the host's recognizer or handler, no NSEvent sent"
        case "open" where element == "Picker", "close" where element == "Picker":
            return "the host's menu delegate told, no menu opened"
        case "choose" where element == "Picker":
            return "the host's action called, not the pop-up's"
        case "pickDate", "pickTime":
            return "the host's change handler called, not the picker's action"
        case "scroll" where element == "ItemsView":
            return nil
        case "scroll":
            return "the host's movement moved, not the clip view"
        case "choose" where element == "ItemsView", "activate" where element == "an item of ItemsView":
            return "the collection's delegate told, no click"
        case "answer":
            return "the host's response called, no alert shown"
        case "goBack":
            return "the host's toolbar or sheet entry called, no toolbar item or sheet touched"
        case "activate" where element == "ToolbarItem":
            return "the host's toolbar entry called, no toolbar item touched"
        case "switchAway", "switchBack", "bringToFront", "minimize", "restore":
            return "the notification AppKit would post, posted by the driver; the window does not move"
        case "endContent":
            return "the navigation delegate told, no web process ended"
        default: break
        }
        switch ability {
        case "read selectedTab of TabbedView": return "the host's tab choice, not the tab view's"
        case "read isAnimating of ActivityIndicator": return "the host's own flag; the indicator holds none to read"
        case "read inputPurpose of TextField", "read inputPurpose of SearchField", "read inputPurpose of TextEditor":
            return "the traits the host keeps; a Mac shows no keys a purpose picks"
        case "read windowType of Window", "read windowValue of Window": return "the host's restoration record"
        case "read the menu of Window": return "menu items built from the tree at the read, not the main menu"
        case "read what the screen reader said": return "the host's own list of what it announced"
        case "read a question": return "the captions the host keeps, not the alert's buttons"
        default: break
        }
        if Ability(ability).readsATransform {
            return "the host's own transform, checked against the layer it composed itself"
        }
        return nil
    }
}
