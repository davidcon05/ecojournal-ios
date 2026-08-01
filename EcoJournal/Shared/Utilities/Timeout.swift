//
//  Timeout.swift
//  EcoJournal
//
//  Shared timeout helper. `EditLogView` and `LogDetailView` each carried their
//  own private copy of this plus a private `TimeoutError`; the view models
//  extracted from them share this one instead.
//

import Foundation

/// Thrown by `withTimeout(seconds:operation:)` when the operation outlives its
/// deadline.
struct OperationTimeoutError: Error {}

/// Runs `operation`, throwing `OperationTimeoutError` if it takes longer than
/// `seconds`. The losing task is cancelled.
func withTimeout<T: Sendable>(
    seconds: TimeInterval,
    operation: @escaping @Sendable () async throws -> T
) async throws -> T {
    try await withThrowingTaskGroup(of: T.self) { group in
        group.addTask {
            try await operation()
        }

        group.addTask {
            try await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
            throw OperationTimeoutError()
        }

        let result = try await group.next()!
        group.cancelAll()
        return result
    }
}
