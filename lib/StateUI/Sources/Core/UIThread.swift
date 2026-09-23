// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

// The UI thread's executor: `MainActor`'s on every platform but Apple's, drained
// by the host through `stateui_run_jobs`, and the doorbell that tells the host
// to ask.
// Design: docs/design/core/concurrency.md#mainactor-on-every-platform

import Dispatch
#if canImport(Darwin)
import Darwin
#elseif canImport(Android)
import Android
#elseif canImport(Glibc)
import Glibc
#elseif canImport(WinSDK)
import WinSDK
#endif
#if !canImport(Darwin)
@_spi(ExperimentalCustomExecutors) import _Concurrency
#endif

/// Which thread this is, as a number to compare - spelled per platform.
private func currentThread() -> UInt64 {
    #if canImport(WinSDK)
    UInt64(GetCurrentThreadId())
    #else
    UInt64(UInt(bitPattern: pthread_self().hashValue))
    #endif
}

/// The executor whose jobs the host runs on its UI thread, and the doorbell. Its
/// queue is guarded; the rest rests on the host draining from one thread.
/// Design: docs/design/core/concurrency.md#the-doorbell
final class UIThreadExecutor: SerialExecutor, @unchecked Sendable {
    /// The one executor. There is one host, and one thread it draws on.
    static let shared = UIThreadExecutor()

    /// Makes this `MainActor`'s executor where nothing drains the main queue - once,
    /// before the first task.
    static func install() {
        _ = installed
    }

    private static let installed: Void = {
        #if !canImport(Darwin)
        _createExecutors(factory: UIThreadExecutorFactory.self)
        #endif
    }()

    /// Guards the queue, the doorbell's flag and the flags below.
    private let guarded = Lock()

    /// Jobs waiting for the host to run them.
    private var pending: [UnownedJob] = []

    /// What the host's parked thread waits on, signalled at most once per park.
    private let wake = DispatchSemaphore(value: 0)

    /// Whether a wake is signalled that the parked thread has not collected.
    private var wakeArmed = false

    /// Whether a drain is posted to the platform's main queue and has not run - for
    /// processes where something turns that queue.
    /// Design: docs/design/core/concurrency.md#draining-jobs
    private var mainQueueAsked = false

    /// Whether a drain is running; a second one entered meanwhile returns at once.
    private var draining = false

    /// Whether `run()` has been told to return.
    private var stopped = false

    /// The thread the last drain ran on - the UI thread, and this executor's
    /// isolation.
    /// Design: docs/design/core/concurrency.md#isolation-checks
    private var uiThread = currentThread()

    /// Takes a job and wakes the host; it runs nothing, the calling thread being any
    /// thread. The signal and the post happen outside the lock.
    func enqueue(_ job: consuming ExecutorJob) {
        let job = UnownedJob(job)

        let (signal, post): (Bool, Bool) = guarded.withLock {
            pending.append(job)

            let post = !mainQueueAsked
            mainQueueAsked = true

            guard !wakeArmed else { return (false, post) }
            wakeArmed = true
            return (true, post)
        }

        if signal { wake.signal() }

        if post {
            // A work item, not a closure: a closure on the main queue is `MainActor`'s, and
            // the runtime would check its isolation on the queue's own thread.
            // Design: docs/design/core/concurrency.md#draining-jobs
            DispatchQueue.main.async(execute: DispatchWorkItem {
                UIThreadExecutor.shared.drainFromTheMainQueue()
            })
        }
    }

    /// Wakes the host's parked thread for work this queue cannot see - an act sent
    /// from the pool, a state write.
    /// Design: docs/design/core/acts.md#waking-the-host-for-an-act
    func poke() {
        let signal: Bool = guarded.withLock {
            guard !wakeArmed else { return false }
            wakeArmed = true
            return true
        }

        if signal { wake.signal() }
    }

    /// Parks the calling thread until work lands and answers how many jobs wait -
    /// what `stateui_wait_work` runs.
    func waitForWork() -> Int {
        wake.wait()

        return guarded.withLock {
            wakeArmed = false
            return pending.count
        }
    }

    /// Runs every waiting job on the calling thread and answers how many ran - in a
    /// loop, since a job can queue another, and bounded.
    @discardableResult
    func drain() -> Int {
        let entered: Bool = guarded.withLock {
            guard !draining else { return false }
            draining = true
            return true
        }

        guard entered else { return 0 }

        // Jobs run on this thread, so this is where MainActor stands.
        guarded.withLock { uiThread = currentThread() }

        var ran = 0

        for _ in 0..<64 {
            let taken: [UnownedJob] = guarded.withLock {
                let taken = pending
                pending.removeAll(keepingCapacity: true)
                return taken
            }

            if taken.isEmpty { break }

            // Outside the lock: a job that queues another would deadlock on it.
            for job in taken {
                job.runSynchronously(on: asUnownedSerialExecutor())
                ran += 1
            }
        }

        guarded.withLock { draining = false }
        return ran
    }

    /// The drain the platform's main queue runs, where something turns it.
    private func drainFromTheMainQueue() {
        guarded.withLock { mainQueueAsked = false }
        drain()
    }

    /// This executor, in the form the runtime stores.
    func asUnownedSerialExecutor() -> UnownedSerialExecutor {
        UnownedSerialExecutor(ordinary: self)
    }

    /// Whether the calling thread is this executor's isolation - the UI thread. The
    /// runtime's default answer would stop the process.
    func isIsolatingCurrentContext() -> Bool? {
        let thread = currentThread()

        return guarded.withLock { thread == uiThread }
    }

    /// The same question, where the runtime wants a stop rather than an answer.
    func checkIsolated() {
        precondition(
            isIsolatingCurrentContext() == true,
            "this is not the UI thread, whose jobs are MainActor's - see Core/UIThread.swift")
    }

    /// How many jobs are waiting, without running any - what a test waits on, beside
    /// `resumesPending`, for a queue gone quiet.
    var pendingCount: Int {
        guarded.withLock { pending.count }
    }

    /// Runs the UI thread's loop here until `stop()` - what an `async main` asks of
    /// `MainActor`'s executor; a host drains through `stateui_run_jobs` instead.
    func runTheLoop() {
        while !guarded.withLock({ stopped }) {
            _ = waitForWork()
            drain()
        }

        guarded.withLock { stopped = false }
    }

    /// Makes `runTheLoop()` return after the drain it is in.
    func stopTheLoop() {
        guarded.withLock { stopped = true }
        poke()
    }
}

#if !canImport(Darwin)
extension UIThreadExecutor: MainExecutor {
    func run() throws {
        runTheLoop()
    }

    func stop() {
        stopTheLoop()
    }
}

/// MainActor's executor where nothing drains the platform's main queue, and
/// the platform's own for every other task.
private struct UIThreadExecutorFactory: ExecutorFactory {
    static var mainExecutor: any MainExecutor { UIThreadExecutor.shared }
    static var defaultExecutor: any TaskExecutor { PlatformExecutorFactory.defaultExecutor }
}
#endif

/// Runs whatever the Swift side has waiting, on the caller's thread - what the
/// host calls at the start of every turn. Answers 0 when there is nothing, which
/// on Apple is almost always.
@discardableResult
func stateUIRunJobs() -> Int {
    UIThreadExecutor.shared.drain()
}
