//
//  Endpoints.swift
//  APISports
//
//  Created by David Sherlock on 2026.
//
//  URL construction, kept pure so every path and parameter can be asserted
//  without a network or a key.
//

import Foundation

/// Builds the URLs the client requests.
enum Endpoints {

    /// A URL for `path` on `sport`'s host, carrying `query`.
    ///
    /// Nil-valued and blank parameters are dropped rather than sent empty:
    /// API-Sports treats `?season=` as a supplied-but-invalid season and
    /// answers with an error, where omitting it succeeds.
    static func url(sport: Sport, path: String, query: [String: String?] = [:]) throws -> URL {
        var components = URLComponents()
        components.scheme = "https"
        components.host = sport.host
        components.path = "/" + path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))

        let items = query
            .compactMap { key, value -> URLQueryItem? in
                guard let value, !value.trimmingCharacters(in: .whitespaces).isEmpty else { return nil }
                return URLQueryItem(name: key, value: value)
            }
            .sorted { $0.name < $1.name }   // stable, so cache keys and tests are stable
        components.queryItems = items.isEmpty ? nil : items

        guard let url = components.url else {
            throw APISportsError.malformed("could not build a URL for \(sport.rawValue)/\(path)")
        }
        return url
    }

    /// The date format every sport's `date` parameter expects.
    static let dateFormat = "yyyy-MM-dd"

    /// Formats `date` as the service's `yyyy-MM-dd`, in UTC.
    ///
    /// Fixed locale and zone: a device on a non-Gregorian calendar otherwise
    /// sends a Buddhist or Japanese year and the endpoint returns nothing.
    static func day(_ date: Date) -> String {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC") ?? .gmt
        let parts = calendar.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", parts.year ?? 0, parts.month ?? 0, parts.day ?? 0)
    }

    /// A season as the service wants it. Football and the unified sports take
    /// a four-digit year; several unified sports also accept `2025-2026`, and
    /// that form is passed through untouched when given.
    static func season(_ season: String?) -> String? {
        guard let season, !season.isEmpty else { return nil }
        return season
    }
}
