// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUIConformance

/// What the Android driver reaches past Android: the activity's lifecycle handed to the host's own entry, and the
/// reads of what the host or its relay keeps. A member proven only that way is the host's own - ✓.
/// Design: docs/design/platforms/android/conformance.md#what-goes-past-android
extension AndroidDriver {
    func byHost(_ ability: String) -> String? {
        switch Ability(ability).act {
        case "switchAway", "switchBack", "bringToFront", "minimize", "restore", "close"
        where Ability(ability).element == "Window":
            return "the host told the activity's phase, no activity moved"
        case "toggle" where Ability(ability).element == "SplitView":
            return "the host's own entry the scrim's tap and the bar's button call"
        default: break
        }
        switch ability {
        case "read minimum of Slider", "read maximum of Slider":
            return "the host's own range; the SeekBar holds only steps"
        case "read options of Picker", "read title of Picker": return "the rows the relay keeps, not the spinner's"
        case "read isSidebarVisible of SplitView": return "the split's own flag; the drawer slides on it"
        case "read selectionMode of ItemsView": return "the mode the relay keeps, which its cells tell TalkBack"
        case "read a question": return "what the relay keeps of the dialog it showed"
        case "read minimumDate of DatePicker", "read maximumDate of DatePicker":
            return "the bounds the relay hands its calendar as it opens"
        case "read format of DatePicker", "read format of TimePicker": return "the pattern the relay writes the field in"
        default: return nil
        }
    }
}
