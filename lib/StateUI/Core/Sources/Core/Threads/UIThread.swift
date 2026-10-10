// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

// The UI thread's executor: `MainActor`'s on every platform but Apple's, drained
// by the host through `HostBoundary.runJobs`, and the doorbell that posts the
// host a turn.
// Design: docs/design/core/concurrency.md#mainactor-on-every-platform

import Synchronization
#if !os(WASI)
import Dispatch
#endif
#if canImport(Darwin)
import Darwin
#elseif canImport(Android)
import Android
#elseif canImport(Glibc)
import Glibc
#elseif canImport(WinSDK)
import WinSDK
#elseif canImport(WASILibc)
import WASILibc
#endif
#if !canImport(Darwin)
@_spi(ExperimentalCustomExecutors) import _Concurrency
#endif
#if os(WASI)
@_spi(ExperimentalScheduling) import _Concurrency
#endif

/// Which thread this is, as a number to compare - spelled per platform.
private func currentThread() -> UInt64 {
    #if canImport(WinSDK)
    UInt64(GetCurrentThreadId())
    #elseif os(WASI)
    0
    #else
    UInt64(UInt(bitPattern: pthread_self().hashValue))
    #endif
}

/// The executor whose jobs the host runs on its UI thread, and the doorbell. What
/// its threads share stands inside its one lock.
/// Design: docs/design/core/concurrency.md#the-doorbell
final class UIThreadExecutor: SerialExecutor, Sendable {
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

    /// The jobs, the host's way to post a turn and the flags below, which any thread touches.
    private struct Queue {
        /// Jobs waiting for the host to run them.
        var pending: [UnownedJob] = []

        #if os(WASI)
        /// Jobs waiting for their time - a sleep's - on the page's one thread.
        var later = Timetable<UnownedJob, ContinuousClock.Instant>()
        #endif

        /// How the host puts a turn on its UI thread's queue; nil where its loop turns by itself.
        /// Design: docs/design/core/concurrency.md#the-doorbell
        var postTurn: (@Sendable () -> Void)?

        /// Whether a turn is posted and its drain has not begun.
        var turnAsked = false

        /// The way to post a turn, taken once until the turn's drain begins; nil where one waits or none is said.
        mutating func turnToPost() -> (@Sendable () -> Void)? {
            guard !turnAsked, let postTurn else { return nil }
            turnAsked = true
            return postTurn
        }

        /// Whether a drain is posted to the platform's main queue and has not run - for
        /// processes where something turns that queue.
        /// Design: docs/design/core/concurrency.md#draining-jobs
        var mainQueueAsked = false

        /// Whether a drain is running; a second one entered meanwhile returns at once.
        var draining = false

        #if !canImport(Darwin)
        /// Whether `run()` has been told to return.
        var stopped = false
        #endif

        /// The thread the last drain ran on - the UI thread, and this executor's
        /// isolation.
        /// Design: docs/design/core/concurrency.md#isolation-checks
        var uiThread = currentThread()
    }

    private let queue = Mutex(Queue())

    #if !canImport(Darwin) && !os(WASI)
    /// What `run()` waits on: the turn it posts itself.
    private let wake = DispatchSemaphore(value: 0)
    #endif

    /// Takes a job and asks the host for a turn, on the calling thread, which is any
    /// thread; it runs nothing. The posts happen outside the lock.
    /// Design: docs/design/core/concurrency.md#the-doorbell
    func enqueue(_ job: consuming ExecutorJob) {
        let job = UnownedJob(job)

        // One thread, and the browser's event loop around it: the host drains as every entry ends.
        // Design: docs/design/core/concurrency.md#webassembly
        #if os(WASI)
        queue.withLock { $0.pending.append(job) }
        #else
        let (turn, post): ((@Sendable () -> Void)?, Bool) = queue.withLock { queue in
            queue.pending.append(job)

            let post = !queue.mainQueueAsked
            queue.mainQueueAsked = true
            return (queue.turnToPost(), post)
        }

        turn?()

        if post {
            // A work item, not a closure: a closure on the main queue is `MainActor`'s, and
            // the runtime would check its isolation on the queue's own thread.
            // Design: docs/design/core/concurrency.md#draining-jobs
            DispatchQueue.main.async(execute: DispatchWorkItem {
                UIThreadExecutor.shared.drainFromTheMainQueue()
            })
        }
        #endif
    }

    /// Says how the host puts a turn on its UI thread's queue, from any thread - and posts one at once, for what
    /// came before the host said.
    func postTurns(with post: (@Sendable () -> Void)?) {
        queue.withLock { queue in
            queue.postTurn = post
            queue.turnAsked = false
        }
        askForTurn()
    }

    /// Puts one turn on the host's UI thread's queue unless one is there whose drain has not begun - for work the
    /// UI thread made, or a job queued.
    /// Design: docs/design/core/concurrency.md#the-doorbell
    func askForTurn() {
        queue.withLock { $0.turnToPost() }?()
    }

    /// Runs every waiting job on the calling thread and answers how many ran - in a
    /// loop, since a job can queue another, and bounded.
    @discardableResult
    func drain() -> Int {
        // Jobs run on this thread, so this is where MainActor stands.
        let thread = currentThread()
        let entered: Bool = queue.withLock { queue in
            guard !queue.draining else { return false }
            queue.draining = true
            queue.turnAsked = false
            queue.uiThread = thread
            return true
        }

        guard entered else { return 0 }

        var ran = 0

        for _ in 0..<64 {
            let taken: [UnownedJob] = queue.withLock { queue in
                #if os(WASI)
                queue.pending += queue.later.takeDue(at: .now)
                #endif
                let taken = queue.pending
                queue.pending.removeAll(keepingCapacity: true)
                return taken
            }

            if taken.isEmpty { break }

            // Outside the lock: a job that queues another would deadlock on it.
            for job in taken {
                job.runSynchronously(on: asUnownedSerialExecutor())
                ran += 1
            }
        }

        queue.withLock { $0.draining = false }
        return ran
    }

    #if !os(WASI)
    /// The drain the platform's main queue runs, where something turns it.
    private func drainFromTheMainQueue() {
        queue.withLock { $0.mainQueueAsked = false }
        drain()
    }
    #endif

    /// This executor, in the form the runtime stores.
    func asUnownedSerialExecutor() -> UnownedSerialExecutor {
        UnownedSerialExecutor(ordinary: self)
    }

    /// Whether the calling thread is this executor's isolation - the UI thread. The
    /// runtime's default answer would stop the process.
    func isIsolatingCurrentContext() -> Bool? {
        let thread = currentThread()

        return queue.withLock { thread == $0.uiThread }
    }

    /// The same question, where the runtime wants a stop rather than an answer.
    func checkIsolated() {
        precondition(
            isIsolatingCurrentContext() == true,
            "this is not the UI thread, whose jobs are MainActor's - see UIThread.swift")
    }

    /// How many jobs are waiting, without running any - what a test waits on, beside
    /// `resumesPending`, for a queue gone quiet.
    var pendingCount: Int {
        queue.withLock { $0.pending.count }
    }

}

#if !canImport(Darwin)
extension UIThreadExecutor: MainExecutor {
    /// Runs the UI thread's loop here until `stop()` - what an `async main` asks of
    /// `MainActor`'s executor; a host drains through `HostBoundary.runJobs` instead.
    func run() throws {
        #if os(WASI)
        // No thread waits for work on WebAssembly: the browser's event loop is the loop.
        drain()
        #else
        // The loop is the host here: its turn is a signal it waits for.
        postTurns(with: { [wake] in wake.signal() })
        while !queue.withLock({ $0.stopped }) {
            wake.wait()
            drain()
        }

        queue.withLock { $0.stopped = false }
        #endif
    }

    /// Makes `run()` return after the drain it is in.
    func stop() {
        queue.withLock { $0.stopped = true }
        #if !os(WASI)
        wake.signal()
        #endif
    }
}

/// MainActor's executor where nothing drains the platform's main queue, and
/// the platform's own for every other task.
private struct UIThreadExecutorFactory: ExecutorFactory {
    static var mainExecutor: any MainExecutor { UIThreadExecutor.shared }
    #if os(WASI)
    static var defaultExecutor: any TaskExecutor { UIThreadExecutor.shared }
    #else
    static var defaultExecutor: any TaskExecutor { PlatformExecutorFactory.defaultExecutor }
    #endif
}
#endif

#if os(WASI)
/// On WebAssembly every task's executor, and a sleep's: one thread runs them all, and a job kept for later waits in
/// the timetable until a drain finds it due.
/// Design: docs/design/core/concurrency.md#webassembly
extension UIThreadExecutor: TaskExecutor, SchedulingExecutor {
    func enqueue<C: Clock>(_ job: consuming ExecutorJob, after delay: C.Duration, tolerance: C.Duration?, clock: C) {
        keep(UnownedJob(job), for: delay)
    }

    func enqueue<C: Clock>(_ job: consuming ExecutorJob, at instant: C.Instant, tolerance: C.Duration?, clock: C) {
        keep(UnownedJob(job), for: clock.now.duration(to: instant))
    }

    private func keep<Wait>(_ job: UnownedJob, for wait: Wait) {
        let due = ContinuousClock.now.advanced(by: (wait as? Duration) ?? .zero)
        queue.withLock { $0.later.add(job, due: due) }
    }

    /// How long until a job kept for later comes due; nil with none waiting.
    var nextDue: Duration? {
        queue.withLock { $0.later.nextDue }.map { ContinuousClock.now.duration(to: $0) }
    }
}
#endif

/// Runs whatever the Swift side has waiting, on the caller's thread - what the
/// host calls at the start of every turn. Answers 0 when there is nothing, which
/// on Apple is almost always.
@discardableResult
func stateUIRunJobs() -> Int {
    UIThreadExecutor.shared.drain()
}
