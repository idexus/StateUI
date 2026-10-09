// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

/// The runs of one handler of one event of one element, kept while the element handles the event: what a repeat of
/// the event does to them, by the handler's word.
/// Design: docs/design/core/runs.md#the-runs-of-a-handler
@MainActor
final class RunSlot {
    /// The runs under way, the oldest first, and the tasks they run in.
    private var running: [(run: HandlerRun, task: Task<Void, Never>?)] = []

    /// Events that wait for the runs under way, in the order they came.
    private var waiting: [() -> Void] = []

    /// Starts a run of `handler` for an event carrying `payload`, or lets the event go, or keeps it waiting - as
    /// `repeated` says, where a run is under way.
    func start(_ handler: @escaping EventHandler, _ repeated: RepeatedEvent, payload: [PropValue]?) {
        if !running.isEmpty || !waiting.isEmpty {
            switch repeated {
            case .ignoreWhileRunning:
                return
            case .cancelPrevious:
                supersedeEveryRun()
            case .waitForPrevious:
                waiting.append { [weak self] in self?.launch(handler, payload: payload) }
                return
            case .overlap:
                break
            }
        }

        launch(handler, payload: payload)
    }

    /// Supersedes every run under way and lets every waiting event go - the element no longer handles the event.
    func orphan() {
        supersedeEveryRun()
        waiting.removeAll()
    }

    private func supersedeEveryRun() {
        for entry in running where !entry.run.superseded {
            entry.run.supersede()
            entry.task?.cancel()
        }
    }

    /// Runs the handler here and now, up to its first suspension, as the run it is.
    private func launch(_ handler: @escaping EventHandler, payload: [PropValue]?) {
        let run = HandlerRun()
        running.append((run, nil))

        let task = Task.immediate { @MainActor in
            await HandlerRun.$current.withValue(run) {
                if let payload { EventBuffer.current = payload }

                do {
                    try await handler()
                } catch is CancellationError where run.superseded {
                    // A superseded run ends here, as asked.
                } catch {
                    Renderer.shared.report(error)
                }
            }

            self.finished(run)
        }

        if let place = running.firstIndex(where: { $0.run === run }) {
            running[place].task = task
        }
    }

    /// A run came to its end: the next waiting event runs once none is under way.
    private func finished(_ run: HandlerRun) {
        run.ended()
        running.removeAll { $0.run === run }

        if running.isEmpty, !waiting.isEmpty {
            waiting.removeFirst()()
        }
    }
}
