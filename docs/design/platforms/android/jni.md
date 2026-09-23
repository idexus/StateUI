# JNI on Android

How the Android Views host reaches the views. The host is Swift in the
application's process; every call to a view goes through JNI, from Swift,
through the function table of the main thread's environment. There is no
library between the two: the few things the host needs - a class, a method, a
call, a string, a reference - are a few lines each over `jni.h`, which the
NDK's sysroot carries and the host's C module includes.

## The main thread's environment

A JNI environment belongs to one thread. The host calls views on the UI thread
alone, so it keeps one environment: the one the activity's start hands it. The
looper's doorbell, which does not come through a native method, runs on the
same thread and uses the same environment. Classes and methods are looked up once, on first use, and held
for the life of the process; a lookup that fails stops the process with the
name that is missing, since the application was built without the host's Java
layer.

## Local references

A reference JNI hands back is local to the native frame it was made in. A
native method's frame ends when it returns, and its locals with it. The
looper's callback is not a native method: nothing would ever free what it
makes, so it runs inside its own frame of local references
(`PushLocalFrame`/`PopLocalFrame`). A string made for one call is
freed right after it, so a render that writes many never fills a frame.

## Global references

A view Swift keeps is held by a global reference, which is strong: the Java
object lives while Swift holds it. `JavaObject` deletes its reference when it
is released, so a view lives exactly as long as the Swift object that holds
it, and nothing in the host holds a view after the tree drops its element.

The reference is only as good as the Swift object holding it, and Swift
releases an object after its last use, not at the end of the statement: a
listener made only to be handed to a view is released the moment its
reference is read, before the call that hands it over, and the call meets a
deleted reference. Such an object is held through the call with
`withExtendedLifetime`.

## A view and its number

Java calls back into Swift for a click, a measure, a layout. It cannot hold a
Swift object, and a raw pointer handed to it would outlive the view. Each view
is given a number instead, and Java calls back with that number: the host
finds the live view by it, and a callback for a view that has left finds
nothing and does nothing. The number is given before the Java object is made,
so a `StateUIViewGroup` knows it from its constructor.

## Strings

A Java string is made from the text's UTF-16. `NewStringUTF` takes modified
UTF-8, which cannot hold a character outside the basic plane, so an emoji or a
rare script would arrive broken.

## Exceptions

A Java exception left pending makes the next JNI call abort the process. Every
call is followed by a check that describes the exception to logcat, clears it,
and says which call raised it.

## The natives

The Java layer declares the host's native methods on `StateUIHost`: the
activity's start and its lifecycle, the display's frame, what the user does
to a control - a
click, a turn, a slider's move and drag, words typed, a Return - and a
layout's measure and arrangement. The head's `JNI_OnLoad` registers them by name, so the host's
library exports no other symbol, and a native Java declares that Swift does
not register fails at load rather than at the first call.
`NativeProjectTests` holds the two lists equal.

The Java layer exists only where Android wants a subclass or an interface:
the activity, the layout `ViewGroup`, the frame callback, and one listener
for what the user does to a view ([controls](controls.md)). Each method forwards to a registered
Swift function.

## What a frame writes

A crossing costs a hundred nanoseconds or so, and what it starts in Java
costs more, so the host crosses as seldom as a frame allows. A view keeps
what the host last wrote to it - its transform, its opacity, the place it
was laid out at - and a frame writes only what differs and reads nothing
back: the place a travelling layout starts from is the one the host wrote.
What Android asks for in several calls is one: a placement measures the view
exactly and lays it out, the whole transform with its pivot is set at once,
and a measurement answers both sizes. A view that only moves keeps its
drawing, and a layout moved without a change of size, with nothing in it
asking to be measured again, leaves its children where they stand. A ring
of 24 cards an engine places every frame went from 687 crossings to 59.

The writes are not gathered into one buffer for the whole frame: Android's
layout pass reads what the host wrote in the same frame, and a buffer that
waited for the frame's end would hand it what stood before; it would also
keep a second table of the views in Java.

