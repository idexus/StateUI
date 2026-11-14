// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

// StateUI: Deploy - an application built for release on a host and laid, with
// what it runs with, in artifacts/<application>/<platform> of its workspace -
// the folder of the stateui.json listing it - else of its own folder. A WinUI head is laid
// per architecture - this machine's own, and on an ARM64 machine x64 too,
// which Windows runs emulated. The stateui tool packages it - a WinUI head
// its checkout's .scripts/WinUI/deploy.ps1.

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
 * The command that builds `application`'s WinUI head for release for `architecture` and lays it at `destination`: its
 * checkout's .scripts/WinUI/deploy.ps1. Undefined where the application names no checkout. Every other host is
 * packaged by the stateui tool.
 */
export function winUIDeployCommand(
    application: Application, destination: string, architecture?: Architecture,
): { command: string; args: string[]; script: string } | undefined {
    if (!application.checkout) {
        return undefined;
    }
    const script = path.join(application.checkout, ".scripts", "WinUI", "deploy.ps1");
    return {
        command: "powershell", script,
        args: ["-NoProfile", "-ExecutionPolicy", "Bypass", "-File", script, "-App", application.directory,
            "-Destination", destination, ...(architecture ? ["-Architecture", architecture] : [])],
    };
}
