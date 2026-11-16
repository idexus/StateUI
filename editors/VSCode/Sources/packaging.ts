// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

// StateUI: Package - an application built for release on a host and laid, with
// what it runs with, in artifacts/<application>/<platform> of its workspace -
// the folder of the stateui-workspace.json listing it - else of its own folder. A WinUI head is laid
// per architecture - this machine's own, and on an ARM64 machine x64 too,
// which Windows runs emulated. The stateui tool packages it.

import * as os from "os";
import * as path from "path";
import { Application } from "./applications";
import { describe, Host } from "./hosts";

/** What a WinUI head is built for. */
export type Architecture = "arm64" | "x64";

/** The architectures a WinUI head is packaged for on a machine of `machine`: its own, and x64 too on an ARM64 one. */
export function winUIArchitectures(machine: string = os.arch()): Architecture[] {
    return machine === "arm64" ? ["arm64", "x64"] : ["x64"];
}

/** The folder `application`'s artifacts/ stands in: its workspace's, else its own. */
export function artifactsFolder(application: Application): string {
    return application.workspace ?? application.directory;
}

/** Where `application` lands: artifacts/<application>/<platform>[/<architecture>] in its artifacts folder. */
export function packageDestination(application: Application, host: Host, architecture?: Architecture): string {
    return path.join(artifactsFolder(application), "artifacts", application.name, describe(host).label, ...(architecture ? [architecture] : []));
}

/** Windows' word for an architecture, as the stateui tool names it: `x64` is `x86_64`. */
export function toolArchitecture(architecture: Architecture): "arm64" | "x86_64" {
    return architecture === "x64" ? "x86_64" : "arm64";
}
