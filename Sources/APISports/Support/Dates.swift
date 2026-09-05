//
//  Dates.swift
//  APISports
//
//  Created by David Sherlock on 2026.
//
//  Date parsing, kept pure and tolerant. API-Sports stamps games with an
//  offset ISO 8601 string on most sports, sometimes with fractional seconds,
//  and occasionally with a bare `yyyy-MM-dd` on fixtures with no known time.
//  A single strict parser drops whichever form it was not built for.
//
//  Everything here is a value type on purpose: `ISO8601DateFormatter` is a
//  class and is not `Sendable`, so holding one in a `static let` will not
//  compile under Swift 6 strict concurrency.
//

import Foundation

/// Reads the timestamp forms the service emits.
enum Dates {

    private static let offsetStyle = Date.ISO8601FormatStyle(includingFractionalSeconds: false)
    private static let fractionalStyle = Date.ISO8601FormatStyle(includingFractionalSeconds: true)

    /// Parses a service timestamp, or `nil` if it is not one.
    static func parse(_ text: String?) -> Date? {
        guard let text else { return nil }
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        if let date = try? offsetStyle.parse(trimmed) { return date }
        if let date = try? fractionalStyle.parse(trimmed) { return date }
        return day(trimmed)
    }

    /// Reads a bare `yyyy-MM-dd` as midnight UTC.
    ///
    /// Split by hand rather than through a `DateFormatter`: no formatter means
    /// no shared mutable state, and no chance of a device's own calendar
    /// turning 2026 into a Buddhist or Japanese year.
    static func day(_ text: String) -> Date? {
        let parts = text.prefix(10).split(separator: "-")
        guard parts.count == 3,
              let year = Int(parts[0]), let month = Int(parts[1]), let dayOfMonth = Int(parts[2]),
              (1...12).contains(month), (1...31).contains(dayOfMonth)
        else { return nil }
        var components = DateComponents()
        components.year = year
        components.month = month
        components.day = dayOfMonth
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC") ?? .gmt
        return calendar.date(from: components)
    }

    /// A Unix timestamp as a date, ignoring the zero the service uses for
    /// "unknown" — 1970 is never a real kick-off.
    static func fromUnix(_ seconds: Int?) -> Date? {
        guard let seconds, seconds > 0 else { return nil }
        return Date(timeIntervalSince1970: TimeInterval(seconds))
    }
}
