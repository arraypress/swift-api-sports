//
//  Models+Encoding.swift
//  APISports
//
//  Created by David Sherlock on 2026.
//
//  These types decode four different service shapes and encode exactly one:
//  their own. A caller re-emitting a `Game` as JSON gets the normalised
//  field names, not whichever spelling that sport happened to use — which is
//  the entire point of normalising in the first place.
//
//  Writing these by hand is not optional: a custom `init(from:)` suppresses
//  `Encodable` synthesis, and the coding keys used for reading name fields
//  (`fixture`, `goals`, `fighters`) that do not exist on the way out.
//
//  Nils are omitted rather than written as `null`, so a sport that does not
//  carry a field simply has no key for it.
//

import Foundation

// MARK: - Season

extension Season {
    private enum OutputKeys: String, CodingKey { case label, start, end, isCurrent }

    /// Writes the unified shape, not the per-sport one the service sends.
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: OutputKeys.self)
        try container.encode(label, forKey: .label)
        try container.encodeIfPresent(start, forKey: .start)
        try container.encodeIfPresent(end, forKey: .end)
        try container.encode(isCurrent, forKey: .isCurrent)
    }
}

// MARK: - League

extension League {
    private enum OutputKeys: String, CodingKey { case id, name, type, logo, country, seasons }

    /// Writes the unified shape, not the per-sport one the service sends.
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: OutputKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(name, forKey: .name)
        try container.encodeIfPresent(type, forKey: .type)
        try container.encodeIfPresent(logo, forKey: .logo)
        try container.encodeIfPresent(country, forKey: .country)
        if !seasons.isEmpty { try container.encode(seasons, forKey: .seasons) }
    }
}

// MARK: - Team

extension Team {
    private enum OutputKeys: String, CodingKey {
        case id, name, logo, country, founded, isNational, nickname, record
    }

    /// Writes the unified shape, not the per-sport one the service sends.
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: OutputKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(name, forKey: .name)
        try container.encodeIfPresent(logo, forKey: .logo)
        try container.encodeIfPresent(country, forKey: .country)
        try container.encodeIfPresent(founded, forKey: .founded)
        try container.encodeIfPresent(isNational, forKey: .isNational)
        try container.encodeIfPresent(nickname, forKey: .nickname)
        try container.encodeIfPresent(record, forKey: .record)
    }
}

// MARK: - Game

extension Game.Status {
    private enum OutputKeys: String, CodingKey { case long, short, elapsed }

    /// Writes the unified shape, not the per-sport one the service sends.
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: OutputKeys.self)
        try container.encodeIfPresent(long, forKey: .long)
        try container.encodeIfPresent(short, forKey: .short)
        try container.encodeIfPresent(elapsed, forKey: .elapsed)
    }
}

extension Game.Competitor {
    private enum OutputKeys: String, CodingKey { case id, name, logo, winner }

    /// Writes the unified shape, not the per-sport one the service sends.
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: OutputKeys.self)
        try container.encodeIfPresent(id, forKey: .id)
        try container.encodeIfPresent(name, forKey: .name)
        try container.encodeIfPresent(logo, forKey: .logo)
        try container.encodeIfPresent(winner, forKey: .winner)
    }
}

extension Game {
    private enum OutputKeys: String, CodingKey {
        case id, date, status, league, home, away, homeScore, awayScore, title, stage, venue
    }

    /// Writes the unified shape, not the per-sport one the service sends.
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: OutputKeys.self)
        try container.encode(id, forKey: .id)
        try container.encodeIfPresent(date, forKey: .date)
        try container.encode(status, forKey: .status)
        try container.encodeIfPresent(league, forKey: .league)
        try container.encodeIfPresent(home, forKey: .home)
        try container.encodeIfPresent(away, forKey: .away)
        try container.encodeIfPresent(homeScore, forKey: .homeScore)
        try container.encodeIfPresent(awayScore, forKey: .awayScore)
        try container.encodeIfPresent(title, forKey: .title)
        try container.encodeIfPresent(stage, forKey: .stage)
        try container.encodeIfPresent(venue, forKey: .venue)
    }
}

// MARK: - Standing

extension Standing {
    private enum OutputKeys: String, CodingKey {
        case rank, team, constructor, points, played, won, drawn, lost
        case goalsFor, goalsAgainst, goalDifference, form, group, note
    }

    /// Writes the unified shape, not the per-sport one the service sends.
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: OutputKeys.self)
        try container.encodeIfPresent(rank, forKey: .rank)
        try container.encodeIfPresent(team, forKey: .team)
        try container.encodeIfPresent(constructor, forKey: .constructor)
        try container.encodeIfPresent(points, forKey: .points)
        try container.encodeIfPresent(played, forKey: .played)
        try container.encodeIfPresent(won, forKey: .won)
        try container.encodeIfPresent(drawn, forKey: .drawn)
        try container.encodeIfPresent(lost, forKey: .lost)
        try container.encodeIfPresent(goalsFor, forKey: .goalsFor)
        try container.encodeIfPresent(goalsAgainst, forKey: .goalsAgainst)
        try container.encodeIfPresent(goalDifference, forKey: .goalDifference)
        try container.encodeIfPresent(form, forKey: .form)
        try container.encodeIfPresent(group, forKey: .group)
        try container.encodeIfPresent(note, forKey: .note)
    }
}
