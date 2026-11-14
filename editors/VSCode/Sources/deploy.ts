// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

// StateUI: Deploy - an application built for release on a host and laid, with
// what it runs with, in artifacts/<application>/<platform> of its workspace -
// the folder of the stateui.json listing it - else of its own folder. A WinUI head is laid
// per architecture - this machine's own, and on an ARM64 machine x64 too,
// which Windows runs emulated. The host's own deploy script of the
// application's checkout builds and lays it.

import * as os from "os";
import * as path from "path";
import { Application } from "./applications";
import { describe, Host } from "./hosts";

/** What a WinUI head is built for. */
export type Architecture = "arm64" | "x64";

/** The architectures a WinUI head is deployed for on a machine of `machine`: its own, and x64 too on an ARM64 one. */
export function winUIArchitectures(machine: string = os.arch()): Architecture[] {
    return machine === "arm64" ? ["arm64", "x64"] : ["x64"];
}

/** The folder `application`'s artifacts/ stands in: its workspace's, else its own. */
export function deployFolder(application: Application): string {
    return application.workspace ?? application.directory;
}

/** Where `application` lands: artifacts/<application>/<platform>[/<architecture>] in its deploy folder. */
export function deployDestination(application: Application, host: Host, architecture?: Architecture): string {
    return path.join(deployFolder(application), "artifacts", application.name, describe(host).label, ...(architecture ? [architecture] : []));
}

/**
 * The command that builds `application` for release on `host` and lays it at `destination`: its checkout's
 * .scripts/<Host>/deploy.ps1 or deploy.sh - for WinUI with the architecture, for Android with the device it is
 * built for. Undefined where the application names no checkout. A host the stateui tool builds packages through it.
 */
export function deployCommand(
    application: Application, host: Host, destination: string, architecture?: Architecture, device?: string,
): { command: string; args: string[]; script: string } | undefined {
    if (!application.checkout) {
        return undefined;
    }
    const folder = path.join(application.checkout, ".scripts", describe(host).label);
    if (host === "winui") {
        const script = path.join(folder, "deploy.ps1");
        return {
            command: "powershell", script,
            args: ["-NoProfile", "-ExecutionPolicy", "Bypass", "-File", script, "-App", application.directory,
                "-Destination", destination, ...(architecture ? ["-Architecture", architecture] : [])],
        };
    }
    const script = path.join(folder, "deploy.sh");
    return { command: "bash", script, args: [script, application.directory, destination, ...(device ? [device] : [])] };
}
