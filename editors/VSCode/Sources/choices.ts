// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

// What was chosen on this machine. The stateui tool keeps it out of git in each project's `.stateui/` (`settings/get`,
// `settings/set`): the workspace's application to start, and the application's host and each host's device. The
// window keeps its own only for what no project holds - which application of several folders it works on, and the
// host and devices of a window holding no application.

import type { Application } from "./applications";
import type { Host } from "./hosts";

/** Where the device chosen for each host stands. */
export interface DeviceStore {
    /** The device chosen for `host`: its name, or an id the tool knows it by. */
    device(host: Host): string | undefined;
    /** Chooses `device`, by its name, for `host`. */
    choose(host: Host, device: string): Promise<void>;
}

/**
 * The application a window works on among `applications`: the one it remembers, where that stands in no workspace or
 * its workspace starts it or none; else a workspace's application to start (`startups`, by the workspace's folder);
 * else the only application.
 */
export function chosenApplication(
    applications: readonly Application[], startups: ReadonlyMap<string, string>, remembered?: string,
): Application | undefined {
    const started = (each: Application): boolean => each.workspace !== undefined && startups.get(each.workspace) === each.name;
    const kept = applications.find((each) =>
        each.name === remembered && (each.workspace === undefined || !startups.has(each.workspace) || started(each)));
    return kept ?? applications.find(started) ?? (applications.length === 1 ? applications[0] : undefined);
}
