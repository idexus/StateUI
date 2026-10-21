// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

// The Android head: the APK around the Swift libraries .scripts/Android/run-app.sh
// builds. The script names every path below; Gradle compiles the host's Java
// layer and packages what the Swift build left.

import java.util.Properties

plugins {
    id("com.android.application") version "9.2.1"
}

fun stated(name: String): String =
    providers.gradleProperty(name).orNull
        ?: error("$name is not given - build this head with .scripts/Android/run-app.sh")

layout.buildDirectory.set(file(stated("stateui.build")))

// The Maps SDK's key is the application's own, never the repository's: google-maps-key.properties beside this file,
// which git keeps out, says `key=...`. Without it the map draws its grid and no tiles.
val googleMapsKey: String = file("google-maps-key.properties").takeIf { it.exists() }?.let { keyFile ->
    Properties().apply { keyFile.inputStream().use { load(it) } }.getProperty("key")
} ?: ""

android {
    namespace = "com.stateui.gallery"
    compileSdk = 36

    defaultConfig {
        applicationId = "com.stateui.gallery"
        minSdk = 28
        targetSdk = 36
        versionCode = 1
        versionName = "0.7.1"
        manifestPlaceholders["googleMapsKey"] = googleMapsKey
    }

    sourceSets {
        getByName("main") {
            manifest.srcFile("AndroidManifest.xml")
            java.srcDir(stated("stateui.java"))
            java.srcDir("Java")
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

// The recycler an ItemsView stands on, the swipe to refresh a scroller or a list stands in, and the gallery's own map.
dependencies {
    implementation("androidx.recyclerview:recyclerview:1.4.0")
    implementation("androidx.swiperefreshlayout:swiperefreshlayout:1.1.0")
    implementation("com.google.android.gms:play-services-maps:20.0.0")
}
