# Pictures on Apple's platforms

AppKit and UIKit keep the pictures they make alike, in the package they
share, `lib/StateUI/StateUI.Apple`.

## The pictures made

A host makes a picture once - a file read, a symbol found, bytes decoded -
and hands it to every view that shows it (`PictureCache`). A picture stays
found while anything shows it, through a table that holds it weakly: a view
handed it again finds the same image and nothing changed, however much the
cache let go meanwhile. Of the pictures nothing shows, the latest asked for
are kept besides, so a page shown again reads and decodes nothing; their
pixels stay within the host layer's budget (`PictureArithmetic.keptPixels`,
forty million), and past it the one asked for longest ago goes first; one
holding more than the whole budget is not kept, and lets nothing go. A
picture costs the pixels it holds: a bitmap its own, a glyph those of its
picture, a drawing or a symbol none.

The cache decides alone what it keeps, so the same pictures asked for in the
same order keep the same ones on every machine. The renderer lets go of
everything it kept when the system says memory runs short
(`letGoOfKeptWhenMemoryRunsShort`, libdispatch's memory pressure source),
and at no other time; a cache no renderer made, as a test makes one, keeps
by its budget alone.

The budget holds the largest page of pictures the Gallery shows - its home
page, nineteen cards, some 38 million pixels as UIKit decodes them - so going
back to it decodes nothing again, while an application showing picture after
picture keeps no more than that of the ones it has left.

## A drawing keeps no pixels

An SVG or a PDF stands as a drawing (`NSImage.isDrawing`). AppKit keeps,
inside a drawing it is asked to draw, a bitmap of each size it was drawn at,
for as long as the drawing lives - and a picture lives while anything shows
it, so a card drawn large once and shown small elsewhere holds the large
bitmap besides. The host makes a drawing with `cacheMode = .never`: an image
view draws it into pixels of its own, of the size it shows ([a drawn
picture](../appkit/views.md#a-drawn-picture)), and lets them go with itself.
UIKit reads the bitmap an SVG is drawn into as the application is built
(`PictureArithmetic.drawnFiles`), so its pictures are pixels alone.
