// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUIConformance

/// What the Android driver reaches past Android: the activity's lifecycle handed to the host's own entry, and the
/// reads of what the host or its relay keeps. A member proven only that way is the host's own - 🪞.
/// Design: docs/design/platforms/android/conformance.md#what-goes-past-android
extension AndroidDriver {
    func byHost(_ ability: String) -> String? {
        switch Ability(ability).act {
        case "switchAway", "switchBack", "bringToFront", "minimize", "restore", "close":
            return "the host told the activity's phase, no activity moved"
        default: break
        }
        switch ability {
        case "read minimum of Slider", "read maximum of Slider":
            return "the host's own range; the SeekBar holds only steps"
        case "read options of Picker", "read title of Picker": return "the rows the relay keeps, not the spinner's"
        case "read a question": return "what the relay keeps of the dialog it showed"
        default: return nil
        }
    }
}
