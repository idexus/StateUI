// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

// The test APK: the host's tests, its Java layer, and the instrumentation that
// runs them. .scripts/Android/test-android.sh names every path below.

plugins {
    id("com.android.application") version "9.2.1"
}

fun stated(name: String): String =
    providers.gradleProperty(name).orNull
        ?: error("$name is not given - build the tests with .scripts/Android/test-android.sh")

layout.buildDirectory.set(file(stated("stateui.build")))

android {
    namespace = "com.stateui.androidtests"
    compileSdk = 36

    defaultConfig {
        applicationId = "com.stateui.androidtests"
        minSdk = 28
        targetSdk = 36
        versionCode = 1
        versionName = "0.4.0"
    }

    sourceSets {
        getByName("main") {
            manifest.srcFile("AndroidManifest.xml")
            java.srcDir(stated("stateui.java"))
            java.srcDir("Java")
            jniLibs.srcDir(stated("stateui.libraries"))
        }
    }

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    packaging {
        jniLibs.keepDebugSymbols += "**/*.so"
    }
}
