// Every element the gallery declares of its OWN, in one list.
//
// The contracts are shared by every host - what each element IS on screen is
// the host's own half, beside its head under Platforms/ - so the list of them
// is shared too. A guard that asks "is this one of the application's elements"
// reads it here rather than keeping a copy, so no copy can fall behind.

import StateUI

/// The gallery's own elements: a control, a container, and a control with a
/// declared value.
enum GalleryElements {
    /// Every element the gallery declares, whichever host realizes it.
    static let all: [any ElementContract.Type] = [
        TrafficLightContract.self, RatingBarContract.self, BadgeContract.self,
    ]

    /// Their node types, which is what a style's target and a host's
    /// registration are named by.
    static var names: Set<String> {
        Set(all.map { $0.nodeType.name })
    }
}
