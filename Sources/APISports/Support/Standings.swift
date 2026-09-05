//
//  Standings.swift
//  APISports
//
//  Created by David Sherlock on 2026.
//
//  Unwrapping the three standings nestings into one flat list. Kept apart
//  from the client so each nesting can be asserted from a fixture.
//

import Foundation

/// Flattens whatever a `/standings` endpoint returned.
enum Standings {

    /// Rows, in the order the service gave them.
    ///
    /// Tries, in order: football's `league.standings` groups, the unified
    /// sports' array of groups, and Formula 1's flat ranking.
    static func rows(from data: Data) throws -> [Standing] {
        let decoder = JSONDecoder()

        // Football: {"response": [{"league": {"standings": [[row, …], …]}}]}
        if let wrapped = try? decoder.decode(Envelope<FootballStandings>.self, from: data) {
            if let failure = wrapped.failure { throw failure }
            let rows = wrapped.response.flatMap { $0.league.standings.flatMap { $0 } }
            if !rows.isEmpty { return rows }
        }
        // Unified: {"response": [[row, …], …]}
        if let grouped = try? decoder.decode(Envelope<[Standing]>.self, from: data) {
            if let failure = grouped.failure { throw failure }
            let rows = grouped.response.flatMap { $0 }
            if !rows.isEmpty { return rows }
        }
        // Formula 1: {"response": [row, …]}
        let flat = try decoder.decode(Envelope<Standing>.self, from: data)
        if let failure = flat.failure { throw failure }
        return flat.response
    }

    /// Football's extra wrapper, which exists nowhere else.
    private struct FootballStandings: Decodable, Sendable {
        let league: LeagueBlock
        struct LeagueBlock: Decodable, Sendable {
            let standings: [[Standing]]
            private enum CodingKeys: String, CodingKey { case standings }
            init(from decoder: Decoder) throws {
                let container = try decoder.container(keyedBy: CodingKeys.self)
                self.standings = ((try? container.decodeIfPresent([[Standing]].self, forKey: .standings)) ?? nil) ?? []
            }
        }
    }
}
