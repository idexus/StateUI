// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

// Runs a task and waits for it - how the extension builds a head and runs a
// suite, with the output where a task's always is: the terminal.

import * as vscode from "vscode";

/**
 * Runs `task` and answers its exit code. The listener is in place before the
 * task starts, so one that ends at once is not missed.
 */
export function runTask(task: vscode.Task): Promise<number | undefined> {
    return new Promise((resolve, reject) => {
        let started: vscode.TaskExecution | undefined;
        let ended = false;

        const listener = vscode.tasks.onDidEndTaskProcess((event) => {
            if (started ? event.execution === started : event.execution.task.definition === task.definition) {
                listener.dispose();
                ended = true;
                resolve(event.exitCode);
            }
        });

        vscode.tasks.executeTask(task).then(
            (execution) => { started = execution; },
            (error) => { listener.dispose(); if (!ended) { reject(error); } });
    });
}
