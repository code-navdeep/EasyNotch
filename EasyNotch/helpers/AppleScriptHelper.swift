//
//  AppleScriptHelper.swift
//  EasyNotch
//

import Foundation

class AppleScriptHelper {
    /// NSAppleScript is not thread-safe and must not run on arbitrary threads.
    /// All scripts execute on this single long-lived worker thread, which owns
    /// its own run loop — off the main thread, but always the same thread.
    private static let scriptThread: Thread = {
        let thread = Thread {
            // An attached port keeps the run loop from returning immediately
            // when no jobs are queued.
            RunLoop.current.add(NSMachPort(), forMode: .default)
            while !Thread.current.isCancelled {
                RunLoop.current.run(mode: .default, before: .distantFuture)
            }
        }
        thread.name = "EasyNotch.AppleScript"
        thread.qualityOfService = .userInitiated
        thread.start()
        return thread
    }()

    private final class ScriptJob: NSObject {
        private let source: String
        private let continuation: CheckedContinuation<NSAppleEventDescriptor?, Error>

        init(source: String, continuation: CheckedContinuation<NSAppleEventDescriptor?, Error>) {
            self.source = source
            self.continuation = continuation
        }

        @objc func run() {
            let script = NSAppleScript(source: source)
            var error: NSDictionary?
            if let descriptor = script?.executeAndReturnError(&error) {
                continuation.resume(returning: descriptor)
            } else if let error = error {
                continuation.resume(throwing: NSError(domain: "AppleScriptError", code: 1, userInfo: error as? [String: Any]))
            } else {
                continuation.resume(throwing: NSError(domain: "AppleScriptError", code: 1, userInfo: [NSLocalizedDescriptionKey: "Unknown error"]))
            }
        }
    }

    @discardableResult
    class func execute(_ scriptText: String) async throws -> NSAppleEventDescriptor? {
        try await withCheckedThrowingContinuation { continuation in
            let job = ScriptJob(source: scriptText, continuation: continuation)
            // perform(_:on:...) retains the job until it has run on the target thread.
            job.perform(#selector(ScriptJob.run), on: scriptThread, with: nil, waitUntilDone: false)
        }
    }

    class func executeVoid(_ scriptText: String) async throws {
        _ = try await execute(scriptText)
    }
}
