// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

// The Android head: the APK around the Swift libraries .scripts/Android/run-app.sh
// builds. The script names every path below; Gradle compiles the host's Java
// layer and packages what the Swift build left.

plugins {
    id("com.android.application") version "9.2.1"
}

fun stated(name: String): String =
    providers.gradleProperty(name).orNull
        ?: error("$name is not given - build this head with .scripts/Android/run-app.sh")

layout.buildDirectory.set(file(stated("stateui.build")))

android {
    namespace = "com.stateui.helloworld"
    compileSdk = 36

    defaultConfig {
        applicationId = "com.stateui.helloworld"
        minSdk = 28
        targetSdk = 36
        versionCode = 1
        versionName = "0.4.0"
    }

    sourceSets {
        getByName("main") {
            manifest.srcFile("AndroidManifest.xml")
            java.srcDir(stated("stateui.java"))
            jniLibs.srcDir(stated("stateui.libraries"))
            assets.srcDir(stated("stateui.assets"))
            res.srcDir(stated("stateui.res"))
        }
    }

    buildTypes {
        getByName("release") {
            isMinifyEnabled = false
            signingConfig = signingConfigs.getByName("debug")
        }
    }

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    // The script strips the libraries and keeps their symbols beside them.
    packaging {
        jniLibs.keepDebugSymbols += "**/*.so"
    }
}
