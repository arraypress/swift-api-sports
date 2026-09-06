//
//  APISportsError.swift
//  APISports
//
//  Created by David Sherlock on 2026.
//

import Foundation

/// What can go wrong talking to API-Sports.
public enum APISportsError: Error, LocalizedError, Sendable, Equatable {
    /// No key was supplied, or the key was rejected. HTTP is 200 either way —
    /// the refusal lives in the body, which is why this is not `.http`.
    case unauthorized(String)
    /// The daily or per-minute allowance is spent.
    case rateLimited(retryAfter: Int?)
    /// The service answered with an HTTP failure.
    case http(Int)
    /// The service reported an error inside an otherwise-200 envelope.
    case upstream(String)
    /// A response did not have the shape the service documents.
    case malformed(String)
    /// The request cannot be made — a sport that has no such endpoint, or a
    /// missing parameter the endpoint requires.
    case unsupported(String)

    /// A one-line reason, for a CLI or a log.
    public var errorDescription: String? {
        switch self {
        case .unauthorized(let detail): return detail
        case .rateLimited(let after):
            return "API-Sports allowance exhausted" + (after.map { " (retry after \($0)s)" } ?? "")
        case .http(let code): return "API-Sports answered HTTP \(code)"
        case .upstream(let message): return "API-Sports error: \(message)"
        case .malformed(let what): return "unexpected response shape: \(what)"
        case .unsupported(let what): return what
        }
    }
}
