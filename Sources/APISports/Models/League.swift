//
//  League.swift
//  APISports
//
//  Created by David Sherlock on 2026.
//

import Foundation

/// A competition: a league, a cup, a race calendar, a weight category.
///
/// Football nests the competition under a `league` key with the country
/// alongside it; the unified sports put the same fields at the top level.
/// Both shapes land here.
public struct League: Sendable, Codable, Equatable, Identifiable {
    public let id: Int
    public let name: String
    /// `League`, `Cup` — absent on sports that do not distinguish.
    public let type: String?
    public let logo: String?
    public let country: Country?
    /// Seasons the service holds for this competition.
    public let seasons: [Season]

    public init(id: Int, name: String, type: String? = nil, logo: String? = nil,
                country: Country? = nil, seasons: [Season] = []) {
        self.id = id
        self.name = name
        self.type = type
        self.logo = logo
        self.country = country
        self.seasons = seasons
    }

    private enum CodingKeys: String, CodingKey {
        case id, name, type, logo, country, seasons, league
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        // Football v3 nests: {"league": {…}, "country": {…}, "seasons": […]}.
        // Every other sport puts the same fields at the top level.
        let nested = Decode.nested(container, .league, keyedBy: CodingKeys.self)
        let source = nested ?? container

        self.id = Decode.int(source, .id) ?? 0
        self.name = Decode.string(source, .name) ?? ""
        self.type = Decode.string(source, .type)
        self.logo = Decode.string(source, .logo)
        self.country = Decode.value(Country.self, container, .country)
        self.seasons = Decode.value([Season].self, container, .seasons) ?? []
    }

    /// The season in progress, when the service marks one.
    public var currentSeason: Season? { seasons.first(where: \.isCurrent) }
}
