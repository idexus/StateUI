# The look of the Web

The Web host looks like a current web page, not like another platform's
application: one stylesheet of the host's, `stateui-web.css`, gives the window
its bar, the sidebar, the pages and the controls their look, light or dark as
the user's system is. What an application says of an element's look - a
colour, a font, a box, a shape - is that element's own style, which wins over
every rule of the stylesheet, so the application's look is always the one
shown.

## The parts

The page's colours, its radius and its bar's height are CSS variables on the
root, given once for the light appearance and again for the dark. The font is
the system's own. The bar stands over the room, translucent and blurred over
what scrolls beneath where the application paints it nothing; its buttons are
pictures with a background where the pointer is. The sidebar is a surface of
its own beside the page, a drawer over it where the page is narrow. Buttons
and fields take a border, rounded corners and a ring in the accent colour
where the keyboard's focus is; a checkbox, a radio button, a slider and a
progress bar take the accent colour. Scroll bars are thin. A control the host
makes no element for yet is named in red, in a dashed box, where it belongs.

## Motion

The drawer slides, a pushed page rises into place, and the shade fades in -
none of them where the user asks for less motion.
