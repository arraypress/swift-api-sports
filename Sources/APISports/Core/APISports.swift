//
//  APISports.swift
//  APISports
//
//  Created by David Sherlock on 2026.
//
//  Eleven sports behind one verb set. The service gives each sport its own
//  host and its own vocabulary — `fixtures` here, `games` there, `races`
//  and `fights` elsewhere — and ``Sport`` maps that away, so a caller asks
//  for `games(.rugby)` and `games(.formula1)` the same way.
//
//  The key is required: API-Sports takes no anonymous requests. It travels
//  in the `x-apisports-key` header, never in a query string, so it stays out
//  of proxy logs and shell history.
//

import Foundation

/// A client for API-Sports.
public struct APISports: Sendable {

    /// How requests are performed — injectable so tests run on recordings.
    public typealias Transport = @Sendable (URLRequest) async throws -> (Data, HTTPURLResponse)

    /// Called with the allowance after every request, when the service
    /// reports one. The free plan is 100 requests a DAY, so a caller that
    /// cannot see this will spend it without noticing.
    public typealias RateLimitObserver = @Sendable (RateLimit) -> Void

    private let key: String
    private let transport: Transport
    private let observer: RateLimitObserver?

    /// A client.
    ///
    /// - Parameters:
    ///   - key: An API-Sports key. Free tier is 100 requests a day.
    ///   - transport: Leave `nil` for the shared URLSession.
    ///   - onRateLimit: Notified of the remaining allowance after each call.
    public init(key: String, transport: Transport? = nil, onRateLimit: RateLimitObserver? = nil) {
        self.key = key
        self.observer = onRateLimit
        self.transport = transport ?? { request in
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse else {
                throw APISportsError.malformed("not an HTTP response")
            }
            return (data, http)
        }
    }

    // MARK: - Verbs

    /// The plan and what is left of today's allowance.
    ///
    /// Costs a request itself, and is the cheapest way to prove a key works.
    public func status(_ sport: Sport = .football) async throws -> Account {
        let data = try await get(sport, path: "status")
        do {
            return try JSONDecoder().decode(Account.self, from: data)
        } catch {
            throw APISportsError.malformed("status: \(error.localizedDescription)")
        }
    }

    /// Competitions: leagues, cups, race calendars or weight categories.
    ///
    /// - Parameters:
    ///   - sport: Which sport.
    ///   - country: Filter by country name, e.g. `England`.
    ///   - season: Filter by season — `2025` or `2025-2026`.
    ///   - search: Free-text search on the competition name (3+ characters).
    public func leagues(_ sport: Sport, country: String? = nil, season: String? = nil,
                        search: String? = nil) async throws -> [League] {
        // MMA's `/categories` answers with bare strings, not objects.
        if sport == .mma {
            return try await categories(sport)
        }
        let data = try await get(sport, path: sport.leaguesPath, query: [
            "country": country,
            "season": Endpoints.season(season),
            "search": search,
        ])
        return try decode([League].self, from: data)
    }

    /// Teams, or — for MMA — fighters.
    ///
    /// - Parameters:
    ///   - league: Restrict to one competition.
    ///   - season: Required alongside `league` on most sports.
    ///   - search: Free-text search on the name (3+ characters).
    public func teams(_ sport: Sport, league: Int? = nil, season: String? = nil,
                      search: String? = nil) async throws -> [Team] {
        let data = try await get(sport, path: sport.teamsPath, query: [
            "league": league.map(String.init),
            "season": Endpoints.season(season),
            "search": search,
        ])
        return try decode([Team].self, from: data)
    }

    /// A league table, or a Formula 1 driver ranking.
    ///
    /// - Throws: ``APISportsError/unsupported(_:)`` for MMA, which has no
    ///   table — a fight card is not a season.
    public func standings(_ sport: Sport, league: Int? = nil, season: String,
                          team: Int? = nil) async throws -> [Standing] {
        guard let path = sport.standingsPath else {
            throw APISportsError.unsupported("\(sport.displayName) has no standings — try `games` for the card")
        }
        // Formula 1 ranks by season alone; every other sport needs a league.
        var query: [String: String?] = ["season": season, "team": team.map(String.init)]
        if sport.family != .formula1 {
            guard let league else {
                throw APISportsError.unsupported("\(sport.displayName) standings need a --league id")
            }
            query["league"] = String(league)
        }
        let data = try await get(sport, path: path, query: query)
        return try Standings.rows(from: data)
    }

    /// Matches, races or fights.
    ///
    /// - Parameters:
    ///   - date: One day's card. The service wants UTC.
    ///   - league: Restrict to one competition.
    ///   - season: Restrict to one season.
    ///   - team: Restrict to one team's matches.
    public func games(_ sport: Sport, date: Date? = nil, league: Int? = nil,
                      season: String? = nil, team: Int? = nil) async throws -> [Game] {
        let data = try await get(sport, path: sport.gamesPath, query: [
            "date": date.map(Endpoints.day),
            "league": league.map(String.init),
            "season": Endpoints.season(season),
            "team": team.map(String.init),
        ])
        return try decode([Game].self, from: data)
    }

    /// Matches under way right now.
    ///
    /// Football and the unified sports filter this server-side. A race series
    /// and a fight card cannot, so those are filtered here from today's card —
    /// one request either way.
    public func live(_ sport: Sport, league: Int? = nil) async throws -> [Game] {
        guard sport.supportsLiveFilter else {
            return try await games(sport, date: Date()).filter { $0.status.isLive }
        }
        let data = try await get(sport, path: sport.gamesPath, query: [
            "live": "all",
            "league": league.map(String.init),
        ])
        return try decode([Game].self, from: data)
    }

    /// MMA weight categories, which arrive as bare strings.
    private func categories(_ sport: Sport) async throws -> [League] {
        let data = try await get(sport, path: "categories")
        let envelope = try JSONDecoder().decode(Envelope<String>.self, from: data)
        if let failure = envelope.failure { throw failure }
        return envelope.response.enumerated().map { League(id: $0.offset, name: $0.element) }
    }

    // MARK: - Transport

    /// Performs a request and returns its body, having checked both the HTTP
    /// status and the error block inside it.
    private func get(_ sport: Sport, path: String, query: [String: String?] = [:]) async throws -> Data {
        var request = URLRequest(url: try Endpoints.url(sport: sport, path: path, query: query))
        // The header form, never a query parameter: a key in a URL ends up in
        // proxy logs, shell history and error messages.
        request.setValue(key, forHTTPHeaderField: "x-apisports-key")
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        let (data, response) = try await transport(request)

        let allowance = RateLimit(headers: response)
        if !allowance.isEmpty { observer?(allowance) }

        switch response.statusCode {
        case 200:
            break
        case 429:
            let after = response.value(forHTTPHeaderField: "Retry-After").flatMap(Int.init)
            throw APISportsError.rateLimited(retryAfter: after)
        case 401, 403:
            throw APISportsError.unauthorized("API-Sports rejected the key")
        default:
            throw APISportsError.http(response.statusCode)
        }
        return data
    }

    /// Decodes an envelope, surfacing the in-body error first.
    ///
    /// The order matters: API-Sports answers a missing or rejected key with
    /// HTTP 200 and the refusal in the body, so a decoder that reports
    /// "no results" would hide an auth failure as an empty list.
    private func decode<Item: Decodable & Sendable>(_ type: [Item].Type, from data: Data) throws -> [Item] {
        let envelope: Envelope<Item>
        do {
            envelope = try JSONDecoder().decode(Envelope<Item>.self, from: data)
        } catch {
            throw APISportsError.malformed(error.localizedDescription)
        }
        if let failure = envelope.failure { throw failure }
        return envelope.response
    }
}
