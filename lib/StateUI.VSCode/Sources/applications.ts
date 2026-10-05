// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

// The applications a workspace holds: a StateUI checkout keeps them in apps/,
// and a workspace may be one itself.

import * as fs from "fs";
import * as path from "path";
import { checkoutNamedBy } from "./checkouts";
import { Host } from "./hosts";

/** One application, and the heads it has. */
export interface Application {
    /** The application's name - `Gallery` - which its products are named after. */
    readonly name: string;

    /** The directory holding its Package.swift. */
    readonly directory: string;

    readonly hasAppKitHead: boolean;

    /** Whether it has a UIKit head: `Platforms/UIKit/main.swift`. */
    readonly hasUIKitHead: boolean;

    /** Whether it has an Android head: the Gradle build in `Platforms/Android`. */
    readonly hasAndroidHead: boolean;

    /** Whether it has a WinUI head: `Platforms/WinUI/main.swift`. */
    readonly hasWinUIHead: boolean;

    /** Whether it has a GTK head: `Platforms/GTK/main.swift`. */
    readonly hasGTKHead: boolean;

    /** Whether it has a Web head: `Platforms/Web/main.swift`. */
    readonly hasWebHead: boolean;

    /**
     * The script that builds the application's AppKit bundle, where it has one
     * - `.scripts/AppKit/build-gallery-appkit.sh`. Without one the head is
     * built by SwiftPM alone.
     */
    readonly bundleScript?: string;

    /**
     * The StateUI checkout its Package.swift names by path - the library it
     * builds with, whose `.scripts` build and run its heads - where it names one.
     */
    readonly checkout?: string;
}

/** The applications under `root`, the workspace itself first. */
export function findApplications(root: string): Application[] {
    const candidates = [root];
    const apps = path.join(root, "apps");

    if (isDirectory(apps)) {
        for (const entry of fs.readdirSync(apps).sort()) {
            candidates.push(path.join(apps, entry));
        }
    }

    return candidates.flatMap((directory) => {
        const application = describeApplication(root, directory);
        return application ? [application] : [];
    });
}

function describeApplication(root: string, directory: string): Application | undefined {
    if (!fs.existsSync(path.join(directory, "Package.swift"))) {
        return undefined;
    }

    const hasAppKitHead = fs.existsSync(path.join(directory, "Platforms", "AppKit", "main.swift"));
    const hasUIKitHead = fs.existsSync(path.join(directory, "Platforms", "UIKit", "main.swift"));
    const hasAndroidHead = fs.existsSync(path.join(directory, "Platforms", "Android", "build.gradle.kts"));
    const hasWinUIHead = fs.existsSync(path.join(directory, "Platforms", "WinUI", "main.swift"));
    const hasGTKHead = fs.existsSync(path.join(directory, "Platforms", "GTK", "main.swift"));
    const hasWebHead = fs.existsSync(path.join(directory, "Platforms", "Web", "main.swift"));

    if (!hasAppKitHead && !hasUIKitHead && !hasAndroidHead && !hasWinUIHead && !hasGTKHead && !hasWebHead) {
        return undefined;
    }

    const name = path.basename(directory);
    const script = path.join(root, ".scripts", "AppKit", `build-${name.toLowerCase()}-appkit.sh`);

    return {
        name,
        directory,
        hasAppKitHead,
        hasUIKitHead,
        hasAndroidHead,
        hasWinUIHead,
        hasGTKHead,
        hasWebHead,
        bundleScript: fs.existsSync(script) ? script : undefined,
        checkout: checkoutNamedBy(directory),
    };
}


/** Whether `application` has a head for `host`. */
export function hasHead(application: Application, host: Host): boolean {
    switch (host) {
    case "appkit": return application.hasAppKitHead;
    case "uikit": return application.hasUIKitHead;
    case "android": return application.hasAndroidHead;
    case "winui": return application.hasWinUIHead;
    case "gtk": return application.hasGTKHead;
    case "web": return application.hasWebHead;
    }
}

/** Whether `folder` keeps applications in apps/ - a StateUI checkout, or a project group. */
export function keepsApps(folder: string): boolean {
    return isDirectory(path.join(folder, "apps"));
}

function isDirectory(candidate: string): boolean {
    return fs.existsSync(candidate) && fs.statSync(candidate).isDirectory();
}

/** Where an application's AppKit head is, once built in `configuration`. */
export function appKitProgram(application: Application, configuration: "debug" | "release"): string {
    const product = `${application.name}AppKit`;

    // Every AppKit build is on .build/appkit; a bundling script wraps the
    // executable in an application bundle there.
    const build = path.join(application.directory, ".build", "appkit", configuration);
    return application.bundleScript
        ? path.join(build, `${product}.app`, "Contents", "MacOS", product)
        : path.join(build, product);
}

/** Where an application's GTK head is, once `.scripts/GTK/run-app.sh` built it in `configuration`. */
export function gtkProgram(application: Application, configuration: "debug" | "release"): string {
    return path.join(application.directory, ".build", "gtk", configuration, `${application.name}GTK`);
}

/** Where an application's Web page is laid out, once `.scripts/Web/run-app.sh` built it in `configuration`. */
export function webSite(application: Application, configuration: "debug" | "release"): string {
    return path.join(application.directory, ".build", "web", "site", configuration);
}

/** Where an application's WinUI head is, once `.scripts/WinUI/run-app.ps1` built it in `configuration`. */
export function winUIProgram(application: Application, configuration: "debug" | "release"): string {
    return path.join(application.directory, ".build", "winui", configuration, `${application.name}WinUI.exe`);
}
