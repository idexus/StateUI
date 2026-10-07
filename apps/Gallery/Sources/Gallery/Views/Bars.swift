// The bars a gallery wears.

import StateUI

extension BarElement where Modified == Self {
    /// The bars as `look` says, in `accent`: the platform's own leaves them
    /// unwritten, which follows the system's look and its accent.
    func bars(_ look: BarLook, in accent: AccentChoice) -> Self {
        switch look {
        case .platform: return self
        case .clear: return barBackgroundColor(.transparent).barForegroundColor(Palette.text)
        case .tinted: return barBackgroundColor(accent.translucentColor).barForegroundColor(Palette.text)
        case .colour: return barBackgroundColor(accent.color).barForegroundColor(Palette.onBrand)
        }
    }
}
