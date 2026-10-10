# Interop on the Web

An application's own control on the Web is an object holding the page's
element it shows (`WebControl`, `WebPageElement`), registered with the
host's registry as every host registers one (`StateUIControls.add`): the
host makes a view of its own around the element (`WebHostedView`), which
holds the control as long as the element stands in the tree, places it as
any view and lets go of the element and of every listener the control hung
on it as the element leaves.

The element is the browser's own extension of itself: a custom element the
application defines in JavaScript, beside its head - a page's own language,
as Java is beneath the Android host and C++ beneath WinUI's - which knows
nothing of StateUI. The control tells it what it is through its attributes,
which the element hears in its `attributeChangedCallback`, and hears what
it does through the events it raises. The page loads the application's
scripts - its head's `Page` folder, which `run-app.sh` lays beside the page
- before the module starts, so an element a control makes is already the
application's when the browser makes it.

A control drawing with the GPU draws with WebGL 2: every browser of today
draws with it, where WebGPU is still missing from some platforms and some
devices.

## Acts and events

The application's acts are the host layer's to perform (`InteropActs`): one
of its own, and one aimed at its control, handed the control the host made
for the element. Its events go to the core as every host raises them. What
only the page's JavaScript reaches, the application's scripts reach: the
page sets up one object for them, `StateUI`, before any of them runs - its
`acts`, each answering by a promise, and `tell`, which the module hears as
soon as it stands to. An act's promise settles a call Swift awaits; the last
words a script told under a name are handed to every hearer of it as the
hearer starts, so a script need not know when the module started. Only words
cross, so an application says in them what it hands over and reads back.

