# JNI on Android

How the Android Views host reaches the views. The host is Swift in the
application's process; every call to a view goes through JNI, from Swift,
through the function table of the main thread's environment. There is no
library between the two: the few things the host needs - a class, a method, a
call, a string, a reference - are a few lines each over `jni.h`, which the
NDK's sysroot carries and the host's C module includes.

## The main thread's environment

A JNI environment belongs to one thread. The host calls views on the UI thread
alone, so it keeps one environment: the one the activity's start hands it. A
callback that does not come through a native method - the looper's doorbell,
the choreographer's frame - runs on the same thread and uses the same
environment. Classes and methods are looked up once, on first use, and held
for the life of the process; a lookup that fails stops the process with the
name that is missing, since the application was built without the host's Java
layer.

## Local references

A reference JNI hands back is local to the native frame it was made in. A
native method's frame ends when it returns, and its locals with it. The
looper's and the choreographer's callbacks are not native methods: nothing
would ever free what they make, so each runs inside its own frame of local
references (`PushLocalFrame`/`PopLocalFrame`). A string made for one call is
freed right after it, so a render that writes many never fills a frame.

## Global references

A view Swift keeps is held by a global reference, which is strong: the Java
object lives while Swift holds it. `JavaObject` deletes its reference when it
is released, so a view lives exactly as long as the Swift object that holds
it, and nothing in the host holds a view after the tree drops its element.

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
activity's start and its lifecycle, a click, a layout's measure and
arrangement. The head's `JNI_OnLoad` registers them by name, so the host's
library exports no other symbol, and a native Java declares that Swift does
not register fails at load rather than at the first call.
`NativeProjectTests` holds the two lists equal.

The Java layer exists only where Android wants a subclass or an interface:
the activity, the layout `ViewGroup`, the click listener. Each method forwards
to a registered Swift function.
