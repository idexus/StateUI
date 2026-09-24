// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

// The applications a workspace holds: a StateUI checkout keeps them in apps/,
// and a workspace may be one itself.

import * as fs from "fs";
import * as path from "path";
import { Host } from "./hosts";

/** One application, and the heads it has. */
export interface Application {
    /** The application's name - `Gallery` - which its products are named after. */
    readonly name: string;

    /** The directory holding its Package.swift. */
    readonly directory: string;

    readonly hasAppKitHead: boolean;

    /** Whether it has an Android head: the Gradle build in `Platforms/Android`. */
    readonly hasAndroidHead: boolean;

    /** Whether it has a WinUI head: `Platforms/WinUI/main.swift`. */
    readonly hasWinUIHead: boolean;

    /**
     * The script that builds the application's AppKit bundle, where it has one
     * - `.scripts/AppKit/build-gallery-appkit.sh`. Without one the head is
     * built by SwiftPM alone.
     */
    readonly bundleScript?: string;
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
    const hasAndroidHead = fs.existsSync(path.join(directory, "Platforms", "Android", "build.gradle.kts"));
    const hasWinUIHead = fs.existsSync(path.join(directory, "Platforms", "WinUI", "main.swift"));

    if (!hasAppKitHead && !hasAndroidHead && !hasWinUIHead) {
        return undefined;
    }

    const name = path.basename(directory);
    const script = path.join(root, ".scripts", "AppKit", `build-${name.toLowerCase()}-appkit.sh`);

    return {
        name,
        directory,
        hasAppKitHead,
        hasAndroidHead,
        hasWinUIHead,
        bundleScript: fs.existsSync(script) ? script : undefined,
    };
}

/** Whether `application` has a head for `host`. */
export function hasHead(application: Application, host: Host): boolean {
    switch (host) {
    case "appkit": return application.hasAppKitHead;
    case "android": return application.hasAndroidHead;
    case "winui": return application.hasWinUIHead;
    }
}

function isDirectory(candidate: string): boolean {
    return fs.existsSync(candidate) && fs.statSync(candidate).isDirectory();
}

/** Where an application's AppKit head is, once built in `configuration`. */
export function appKitProgram(application: Application, configuration: "debug" | "release"): string {
    const product = `${application.name}AppKit`;

    // A bundling script builds on a directory of its own and wraps the
    // executable in an application bundle.
    return application.bundleScript
        ? path.join(application.directory, ".build-appkit", configuration, `${product}.app`, "Contents", "MacOS", product)
        : path.join(application.directory, ".build", configuration, product);
}
