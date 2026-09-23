// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

// The host's JNI: the main thread's environment, the references Swift holds,
// and the calls, each straight through the function table.
// Design: docs/design/platforms/android/jni.md#the-main-threads-environment

import CStateUIAndroid

/// The main thread's JNI environment and the calls the host makes through it.
@MainActor
enum Java {
    /// The process's virtual machine, as the library's load received it.
    nonisolated(unsafe) static var machine: UnsafeMutablePointer<JavaVM?>?

    /// The main thread's environment, taken when the activity starts the host.
    static var env: UnsafeMutablePointer<JNIEnv?>!

    /// The function table every call goes through.
    static var jni: JNINativeInterface { env.pointee!.pointee }

    /// Runs `body` inside a frame of local references, let go when it returns.
    /// Design: docs/design/platforms/android/jni.md#local-references
    static func frame<Result>(_ body: () -> Result) -> Result {
        _ = jni.PushLocalFrame(env, 64)
        defer { _ = jni.PopLocalFrame(env, nil) }
        return body()
    }

    /// Says and clears a pending Java exception: one left pending aborts the next call.
    /// Design: docs/design/platforms/android/jni.md#exceptions
    static func check(_ call: @autoclosure () -> String) {
        guard jni.ExceptionCheck(env) != 0 else { return }

        jni.ExceptionDescribe(env)
        jni.ExceptionClear(env)
        AndroidLog.error("a Java exception in \(call())")
    }

    /// A class, held for the life of the process.
    static func findClass(_ name: String) -> jclass {
        guard let local = jni.FindClass(env, name) else {
            check("FindClass \(name)")
            fatalError("StateUI Android: the class \(name) is missing from the application")
        }

        defer { jni.DeleteLocalRef(env, local) }
        return jni.NewGlobalRef(env, local)!
    }

    /// An instance method of `owner`.
    static func method(_ owner: jclass, _ name: String, _ signature: String) -> jmethodID {
        guard let method = jni.GetMethodID(env, owner, name, signature) else {
            check("GetMethodID \(name)")
            fatalError("StateUI Android: \(name)\(signature) is missing")
        }

        return method
    }

    /// A static method of `owner`.
    static func staticMethod(_ owner: jclass, _ name: String, _ signature: String) -> jmethodID {
        guard let method = jni.GetStaticMethodID(env, owner, name, signature) else {
            check("GetStaticMethodID \(name)")
            fatalError("StateUI Android: \(name)\(signature) is missing")
        }

        return method
    }

    /// A static field's value of type int.
    static func staticInt(_ owner: jclass, _ name: String) -> Int32 {
        let field = jni.GetStaticFieldID(env, owner, name, "I")
        check("GetStaticFieldID \(name)")
        return jni.GetStaticIntField(env, owner, field)
    }

    /// A static field's object, held for the life of the process.
    static func staticObject(_ owner: jclass, _ name: String, _ signature: String) -> JavaObject {
        let field = jni.GetStaticFieldID(env, owner, name, signature)
        check("GetStaticFieldID \(name)")
        return JavaObject(jni.GetStaticObjectField(env, owner, field)!)
    }

    /// An instance field of `owner`.
    static func field(_ owner: jclass, _ name: String, _ signature: String) -> jfieldID {
        guard let field = jni.GetFieldID(env, owner, name, signature) else {
            check("GetFieldID \(name)")
            fatalError("StateUI Android: the field \(name) is missing")
        }

        return field
    }

    // MARK: - Calls

    /// A new object, held globally.
    static func new(_ owner: jclass, _ constructor: jmethodID, _ arguments: jvalue...) -> JavaObject {
        let local = arguments.withUnsafeBufferPointer { jni.NewObjectA(env, owner, constructor, $0.baseAddress) }
        check("a constructor")
        return JavaObject(local!)
    }

    /// Calls a method returning nothing.
    static func call(_ object: jobject, _ method: jmethodID, _ arguments: jvalue...) {
        arguments.withUnsafeBufferPointer { _ = jni.CallVoidMethodA(env, object, method, $0.baseAddress) }
        check("a call")
    }

    /// Calls a method returning an int.
    static func callInt(_ object: jobject, _ method: jmethodID, _ arguments: jvalue...) -> Int32 {
        let result = arguments.withUnsafeBufferPointer { jni.CallIntMethodA(env, object, method, $0.baseAddress) }
        check("a call")
        return result
    }

    /// Calls a method returning a boolean.
    static func callBool(_ object: jobject, _ method: jmethodID, _ arguments: jvalue...) -> Bool {
        let result = arguments.withUnsafeBufferPointer { jni.CallBooleanMethodA(env, object, method, $0.baseAddress) }
        check("a call")
        return result != 0
    }

    /// Calls a static method returning a boolean.
    static func callStaticBool(_ owner: jclass, _ method: jmethodID, _ arguments: jvalue...) -> Bool {
        let result = arguments.withUnsafeBufferPointer {
            jni.CallStaticBooleanMethodA(env, owner, method, $0.baseAddress)
        }
        check("a static call")
        return result != 0
    }

    /// Calls a method returning a float.
    static func callFloat(_ object: jobject, _ method: jmethodID, _ arguments: jvalue...) -> Float {
        let result = arguments.withUnsafeBufferPointer { jni.CallFloatMethodA(env, object, method, $0.baseAddress) }
        check("a call")
        return result
    }

    /// Calls a method returning an object, as a local reference.
    static func callObject(_ object: jobject, _ method: jmethodID, _ arguments: jvalue...) -> jobject? {
        let result = arguments.withUnsafeBufferPointer { jni.CallObjectMethodA(env, object, method, $0.baseAddress) }
        check("a call")
        return result
    }

    /// Calls a static method returning an object, as a local reference.
    static func callStaticObject(_ owner: jclass, _ method: jmethodID, _ arguments: jvalue...) -> jobject? {
        let result = arguments.withUnsafeBufferPointer {
            jni.CallStaticObjectMethodA(env, owner, method, $0.baseAddress)
        }
        check("a static call")
        return result
    }

    /// Reads a float field.
    static func float(_ object: jobject, _ field: jfieldID) -> Float {
        jni.GetFloatField(env, object, field)
    }

    /// Writes an int field.
    static func set(_ object: jobject, _ field: jfieldID, _ value: Int32) {
        jni.SetIntField(env, object, field, value)
    }

    /// Writes a boolean field.
    static func set(_ object: jobject, _ field: jfieldID, _ value: Bool) {
        jni.SetBooleanField(env, object, field, value ? 1 : 0)
    }

    // MARK: - Values

    /// A Java string of `text`'s UTF-16, as a local reference.
    /// Design: docs/design/platforms/android/jni.md#strings
    static func string(_ text: String) -> jstring? {
        var units = Array(text.utf16)
        return jni.NewString(env, &units, jsize(units.count))
    }

    /// The text of a Java string.
    static func text(_ string: jstring?) -> String {
        guard let string else { return "" }

        let count = Int(jni.GetStringLength(env, string))
        guard let units = jni.GetStringChars(env, string, nil) else { return "" }
        defer { jni.ReleaseStringChars(env, string, units) }
        return String(decoding: UnsafeBufferPointer(start: units, count: count), as: UTF16.self)
    }

    /// An array of `owner`'s objects, as a local reference.
    static func array(of owner: jclass, _ objects: [jobject]) -> jobjectArray? {
        let array = jni.NewObjectArray(env, jsize(objects.count), owner, nil)
        for (index, object) in objects.enumerated() {
            jni.SetObjectArrayElement(env, array, jsize(index), object)
        }
        check("an array")
        return array
    }

    /// A Java float array of `values`, as a local reference.
    static func floats(_ values: [Float]) -> jfloatArray? {
        let array = jni.NewFloatArray(env, jsize(values.count))
        values.withUnsafeBufferPointer { jni.SetFloatArrayRegion(env, array, 0, jsize(values.count), $0.baseAddress) }
        return array
    }

    /// A Java int array of `values`, as a local reference.
    static func ints(_ values: [Int32]) -> jintArray? {
        let array = jni.NewIntArray(env, jsize(values.count))
        values.withUnsafeBufferPointer { jni.SetIntArrayRegion(env, array, 0, jsize(values.count), $0.baseAddress) }
        return array
    }

    /// The strings of a Java string array.
    static func texts(_ array: jobjectArray?) -> [String] {
        guard let array else { return [] }

        return (0..<jni.GetArrayLength(env, array)).map { index in
            let string = jni.GetObjectArrayElement(env, array, index)
            defer { release(local: string) }
            return text(string)
        }
    }

    /// Lets a local reference go before its frame ends.
    static func release(local: jobject?) {
        if let local { jni.DeleteLocalRef(env, local) }
    }
}

/// A Java object Swift holds: a global reference, deleted when this is released.
/// Design: docs/design/platforms/android/jni.md#global-references
@MainActor
final class JavaObject {
    /// The global reference.
    let reference: jobject

    /// Holds `local` globally, and lets the local reference go.
    init(_ local: jobject) {
        reference = Java.jni.NewGlobalRef(Java.env, local)!
        Java.jni.DeleteLocalRef(Java.env, local)
    }

    isolated deinit {
        Java.jni.DeleteGlobalRef(Java.env, reference)
    }
}

extension jvalue {
    /// An int argument.
    static func int(_ value: Int32) -> jvalue { jvalue(i: value) }

    /// A long argument.
    static func long(_ value: Int64) -> jvalue { jvalue(j: value) }

    /// A float argument.
    static func float(_ value: Float) -> jvalue { jvalue(f: value) }

    /// A boolean argument.
    static func bool(_ value: Bool) -> jvalue { jvalue(z: value ? 1 : 0) }

    /// An object argument.
    static func object(_ value: jobject?) -> jvalue { jvalue(l: value) }
}
