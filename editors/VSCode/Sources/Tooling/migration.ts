// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

// The hosts the stateui tool builds, runs, deploys and tests; the others still by their checkout's .scripts, until
// their row of the migration moves them. Read where one code serves every host; gone once every host has moved.

import { Host } from "../hosts";

/** The hosts whose build, launch, deploy and own suite go through the stateui tool. */
const byTool: ReadonlySet<Host> = new Set<Host>(["appkit", "uikit"]);

/** Whether `host` goes through the stateui tool. */
export function builtByTool(host: Host): boolean {
    return byTool.has(host);
}
