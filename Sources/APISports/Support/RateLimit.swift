//
//  RateLimit.swift
//  APISports
//
//  Created by David Sherlock on 2026.
//
//  The allowance, read from response headers. Surfacing it matters more here
//  than on a keyless service: the free tier is 100 requests a DAY, so an agent
//  that cannot see the remaining count will spend it without noticing.
//

import Foundation

/// What the service says is left of the allowance.
public struct RateLimit: Sendable, Equatable {

    /// Requests allowed per day on this plan.
    public let dailyLimit: Int?
    /// Requests left today.
    public let dailyRemaining: Int?
    /// Requests allowed per minute.
    public let minuteLimit: Int?
    /// Requests left this minute.
    public let minuteRemaining: Int?

    /// Reads the allowance from a response's headers.
    ///
    /// API-Sports spells these four headers in mixed case and has changed the
    /// casing before; `HTTPURLResponse.value(forHTTPHeaderField:)` is
    /// case-insensitive, which is why the lookup goes through it.
    public init(headers response: HTTPURLResponse) {
        func number(_ name: String) -> Int? {
            response.value(forHTTPHeaderField: name).flatMap { Int($0.trimmingCharacters(in: .whitespaces)) }
        }
        self.dailyLimit = number("x-ratelimit-requests-limit")
        self.dailyRemaining = number("x-ratelimit-requests-remaining")
        self.minuteLimit = number("X-RateLimit-Limit")
        self.minuteRemaining = number("X-RateLimit-Remaining")
    }

    /// True when the response carried no allowance headers at all.
    public var isEmpty: Bool {
        dailyLimit == nil && dailyRemaining == nil && minuteLimit == nil && minuteRemaining == nil
    }
}
