// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

// The Android head: the APK around the Swift libraries the stateui tool builds.
// The tool names every path below and what the application's stateui.json
// says - its id, version and build; Gradle compiles the host's Java layer and
// packages what the Swift build left.

plugins {
    id("com.android.application") version "9.2.1"
}

fun stated(name: String): String =
    providers.gradleProperty(name).orNull
        ?: error("$name is not given - build this head with stateui build --host android")

layout.buildDirectory.set(file(stated("stateui.build")))

android {
    namespace = "com.stateui.helloworld"
    compileSdk = 36

    defaultConfig {
        applicationId = stated("stateui.identifier")
        minSdk = 28
        targetSdk = 36
        versionCode = stated("stateui.versionCode").toInt()
        versionName = stated("stateui.version")
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

// The recycler an ItemsView stands on, and the swipe to refresh a scroller or a list stands in.
dependencies {
    implementation("androidx.recyclerview:recyclerview:1.4.0")
    implementation("androidx.swiperefreshlayout:swiperefreshlayout:1.1.0")
}
