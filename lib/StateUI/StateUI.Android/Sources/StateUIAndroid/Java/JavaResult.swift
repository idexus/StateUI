// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

import CStateUIAndroid

/// What a Java method answers with, as `Java.call` and `Java.callStatic` read it: an `int`, a `long`, a `boolean`,
/// a `float`, a `double`, or an object, as a local reference.
///
///     let width: Int32 = Java.call(view, JavaAPI.getWidth)
public protocol JavaResult {
    /// The answer of `method` called on `object` with `arguments`.
    @MainActor static func answer(of object: jobject, _ method: jmethodID, _ arguments: UnsafePointer<jvalue>?) -> Self

    /// The answer of `owner`'s static `method` called with `arguments`.
    @MainActor static func answer(
        ofStatic owner: jclass, _ method: jmethodID, _ arguments: UnsafePointer<jvalue>?
    ) -> Self
}

extension Int32: JavaResult {
    /// An `int`.
    public static func answer(of object: jobject, _ method: jmethodID, _ arguments: UnsafePointer<jvalue>?) -> Int32 {
        Java.jni.CallIntMethodA(Java.env, object, method, arguments)
    }

    /// A static `int`.
    public static func answer(ofStatic owner: jclass, _ method: jmethodID, _ arguments: UnsafePointer<jvalue>?) -> Int32 {
        Java.jni.CallStaticIntMethodA(Java.env, owner, method, arguments)
    }
}

extension Int64: JavaResult {
    /// A `long`.
    public static func answer(of object: jobject, _ method: jmethodID, _ arguments: UnsafePointer<jvalue>?) -> Int64 {
        Java.jni.CallLongMethodA(Java.env, object, method, arguments)
    }

    /// A static `long`.
    public static func answer(ofStatic owner: jclass, _ method: jmethodID, _ arguments: UnsafePointer<jvalue>?) -> Int64 {
        Java.jni.CallStaticLongMethodA(Java.env, owner, method, arguments)
    }
}

extension Bool: JavaResult {
    /// A `boolean`.
    public static func answer(of object: jobject, _ method: jmethodID, _ arguments: UnsafePointer<jvalue>?) -> Bool {
        Java.jni.CallBooleanMethodA(Java.env, object, method, arguments) != 0
    }

    /// A static `boolean`.
    public static func answer(ofStatic owner: jclass, _ method: jmethodID, _ arguments: UnsafePointer<jvalue>?) -> Bool {
        Java.jni.CallStaticBooleanMethodA(Java.env, owner, method, arguments) != 0
    }
}

extension Float: JavaResult {
    /// A `float`.
    public static func answer(of object: jobject, _ method: jmethodID, _ arguments: UnsafePointer<jvalue>?) -> Float {
        Java.jni.CallFloatMethodA(Java.env, object, method, arguments)
    }

    /// A static `float`.
    public static func answer(ofStatic owner: jclass, _ method: jmethodID, _ arguments: UnsafePointer<jvalue>?) -> Float {
        Java.jni.CallStaticFloatMethodA(Java.env, owner, method, arguments)
    }
}

extension Double: JavaResult {
    /// A `double`.
    public static func answer(of object: jobject, _ method: jmethodID, _ arguments: UnsafePointer<jvalue>?) -> Double {
        Java.jni.CallDoubleMethodA(Java.env, object, method, arguments)
    }

    /// A static `double`.
    public static func answer(
        ofStatic owner: jclass, _ method: jmethodID, _ arguments: UnsafePointer<jvalue>?
    ) -> Double {
        Java.jni.CallStaticDoubleMethodA(Java.env, owner, method, arguments)
    }
}

extension Optional: JavaResult where Wrapped == jobject {
    /// An object, as a local reference; nil for `null`.
    public static func answer(of object: jobject, _ method: jmethodID, _ arguments: UnsafePointer<jvalue>?) -> jobject? {
        Java.jni.CallObjectMethodA(Java.env, object, method, arguments)
    }

    /// A static object, as a local reference; nil for `null`.
    public static func answer(
        ofStatic owner: jclass, _ method: jmethodID, _ arguments: UnsafePointer<jvalue>?
    ) -> jobject? {
        Java.jni.CallStaticObjectMethodA(Java.env, owner, method, arguments)
    }
}
