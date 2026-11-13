# Pictures

An application's pictures stand in its `Resources` as SVG and the bitmap
formats. AppKit, GTK, WinUI and the Web draw SVG themselves and get the
folder as it is; a head whose toolkit draws no SVG - UIKit's, Android's - gets
each SVG drawn, and every macOS bundle gets an icon drawn from
`Resources/AppIcon/appicon_macos.svg`, the artwork already on macOS's icon
grid.

`ApplePictures` draws on a Mac, through AppKit's own SVG reading into a
Core Graphics bitmap in sRGB: one SVG at a scale of its own size; a folder's
SVGs as `<name>@3x.png` - three pixels a point, what the densest common
screens show at one pixel a pixel - with every other picture carried as it
is, only what changed since it was drawn drawn again, and a picture whose
source went taken away; and a macOS icon set, 16, 32, 128, 256 and 512 points
at one and two pixels a point, which `iconutil` makes the bundle's `.icns`.
`iconutil` stays: the system's own icon format is its to write, and ImageIO's
ICNS writer cannot tell a point size at two pixels a point from the size twice
as large at one.
