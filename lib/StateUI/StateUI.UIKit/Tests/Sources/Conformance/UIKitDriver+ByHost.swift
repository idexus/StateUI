// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUIConformance

/// What the UIKit driver reaches past UIKit: the acts it hands to the host's own entry, as UIKit lets a test send no
/// touch and moves no scene, and the reads of what the host keeps. A member proven only that way is the host's own -
/// ✓.
/// Design: docs/design/platforms/uikit/conformance.md#what-goes-past-uikit
extension UIKitDriver {
    func byHost(_ ability: String) -> String? {
        let taken = Ability(ability)
        switch taken.act {
        case "tap", "pan", "pinch", "hover", "leave", "drag", "pressDown", "lift":
            return "the view's listening handed the recognizer's states, no touch sent"
        case "choose" where taken.element == "Picker":
            return "the host's choice called, not the menu's action"
        case "answer":
            return "the host's response called, not the alert's action"
        case "dragAndDrop":
            return "the drag and drop interactions' handlers called, no drag session"
        case "dropFiles":
            return "the drop interaction's handler told the driver's files, no drag session"
        case "answerFiles":
            return "the host's response called with the driver's files, not the picker's choice"
        case "switchAway", "switchBack", "bringToFront", "minimize", "restore", "close":
            return "the host told the scene's phase, no scene moved"
        case "endContent":
            return "the navigation delegate told, no web process ended"
        case "choose" where taken.element == "ItemsView", "activate" where taken.element == "an item of ItemsView":
            return "the collection's delegate told, no touch"
        case "open" where taken.element == "Marker":
            return "the map's delegate told of the callout's button, no touch"
        default: break
        }
        switch ability {
        case "read isOn of CheckBox", "read isOn of RadioButton", "read groupName of RadioButton":
            return "the host's own flag, not the button's state"
        case "read selectedIndex of Picker", "read options of Picker", "read title of Picker":
            return "the host's own choice, not the menu's"
        case "read the menu of Window": return "the host's menu bar entries, not UIKit's main menu"
        case "read what the screen reader said": return "the host's own list of what it announced"
        case "read a question": return "the buttons' captions the host keeps"
        case "read a file dialog": return "the host's own record of the picker it presented"
        case "read what was launched":
            return "the host's own record of what it handed iOS, which a test holds back from launching"
        default: break
        }
        if taken.readsATransform { return "the host's own transform, checked against the layer it composed itself" }
        if ability.hasPrefix("read backdrop of ") { return "the effect the host gave the view, which UIKit reads no style of" }
        return nil
    }
}
