//
//  Sport.swift
//  APISports
//
//  Created by David Sherlock on 2026.
//
//  The eleven sports API-Sports serves, and the three different endpoint
//  vocabularies hiding behind them. Every sport gets its own subdomain, but
//  they do NOT share a path vocabulary: football says `fixtures` where the
//  unified sports say `games`, Formula 1 says `races` and has no standings at
//  all (a race series ranks drivers, not tables), and MMA says `fights` and
//  has no league concept. Mapping that here — once, in data — is what lets the
//  client offer one verb set across all eleven.
//

import Foundation

/// A sport API-Sports covers.
public enum Sport: String, CaseIterable, Sendable, Codable {
    case football
    case basketball
    case baseball
    case hockey
    case rugby
    case handball
    case volleyball
    case afl
    case americanFootball = "american-football"
    case formula1 = "formula-1"
    case mma

    /// Which endpoint vocabulary this sport speaks.
    public var family: Family {
        switch self {
        case .football: return .football
        case .formula1: return .formula1
        case .mma: return .mma
        default: return .unified
        }
    }

    /// The API host. Football is the original product and sits on v3; every
    /// other sport is on v1 of the later, normalised API.
    public var host: String {
        self == .football
            ? "v3.football.api-sports.io"
            : "v1.\(rawValue).api-sports.io"
    }

    /// What a person calls it.
    public var displayName: String {
        switch self {
        case .football: return "Football"
        case .basketball: return "Basketball"
        case .baseball: return "Baseball"
        case .hockey: return "Hockey"
        case .rugby: return "Rugby"
        case .handball: return "Handball"
        case .volleyball: return "Volleyball"
        case .afl: return "AFL"
        case .americanFootball: return "American Football"
        case .formula1: return "Formula 1"
        case .mma: return "MMA"
        }
    }

    /// Accepts the names people actually type — `nfl` for American football,
    /// `f1` for Formula 1, `soccer` for football — alongside the raw values.
    public init?(alias: String) {
        let key = alias.lowercased().replacingOccurrences(of: "_", with: "-")
        switch key {
        case "nfl", "american-football", "americanfootball", "nfl-games":
            self = .americanFootball
        case "f1", "formula1", "formula-1", "formula one":
            self = .formula1
        case "soccer", "football":
            self = .football
        case "nba":
            self = .basketball
        case "mlb":
            self = .baseball
        case "nhl", "ice-hockey":
            self = .hockey
        case "ufc", "mma":
            self = .mma
        default:
            guard let match = Sport(rawValue: key) else { return nil }
            self = match
        }
    }

    // MARK: - Endpoint vocabulary

    /// The endpoint vocabularies. Named for the shape, not for one sport, so
    /// that a twelfth sport joining the unified set needs no new case.
    public enum Family: Sendable {
        /// Football on v3: `fixtures`, topscorers, predictions.
        case football
        /// The normalised v1 sports: `games`, `leagues`, `standings`.
        case unified
        /// A race series: `races`, `competitions`, driver/team rankings.
        case formula1
        /// A fight card: `fights`, `fighters`, no league table.
        case mma
    }

    /// The path listing competitions — leagues for most, competitions for a
    /// race series, weight categories for MMA.
    public var leaguesPath: String {
        switch family {
        case .football, .unified: return "leagues"
        case .formula1: return "competitions"
        case .mma: return "categories"
        }
    }

    /// The path listing the entities that compete. For MMA that is fighters:
    /// there are no teams on a fight card.
    public var teamsPath: String {
        family == .mma ? "fighters" : "teams"
    }

    /// The path listing matches — the name changes with every family.
    public var gamesPath: String {
        switch family {
        case .football: return "fixtures"
        case .unified: return "games"
        case .formula1: return "races"
        case .mma: return "fights"
        }
    }

    /// The path ranking competitors, when the sport has one. A fight card has
    /// no table, so MMA returns `nil` and the client refuses the call rather
    /// than requesting a 404.
    public var standingsPath: String? {
        switch family {
        case .football, .unified: return "standings"
        case .formula1: return "rankings/drivers"
        case .mma: return nil
        }
    }

    /// Whether live games can be filtered server-side. Football and the
    /// unified sports take `live=all`; a race series and a fight card do not.
    public var supportsLiveFilter: Bool {
        family == .football || family == .unified
    }
}
