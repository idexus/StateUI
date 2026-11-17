// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

// StateUI: Package - an application built for release on a host and laid, with
// what it runs with, in artifacts/<application>/<platform> of its workspace -
// the folder of the stateui-workspace.json listing it - else of its own folder. A WinUI head is laid
// per architecture - the ones the stateui tool says its machine or guest runs:
// its own, and on an ARM64 one x64 too, which Windows runs emulated. The
// stateui tool packages it.

import * as path from "path";
import { Application } from "./applications";
import { describe, Host } from "./hosts";
import type { Architecture as ToolArchitecture } from "./Tooling/protocol";

/** What a WinUI head is built for. */
export type Architecture = "arm64" | "x64";

/** Windows' word for an architecture the stateui tool names - `x86_64` is `x64` - or nothing for one Windows runs not. */
export function windowsArchitecture(architecture: ToolArchitecture): Architecture | undefined {
    return architecture === "x86_64" ? "x64" : architecture === "arm64" ? "arm64" : undefined;
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
