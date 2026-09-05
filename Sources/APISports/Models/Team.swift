//
//  Team.swift
//  APISports
//
//  Created by David Sherlock on 2026.
//

import Foundation

/// A team, or — on a fight card — a fighter.
///
/// MMA has no teams: `/fighters` returns people, with a nickname and a
/// win/loss record where a team would have a founding year and a venue. Both
/// land here rather than in two near-identical types, because every caller
/// asking "who competes in this?" wants one answer shape.
public struct Team: Sendable, Codable, Equatable, Identifiable {
    public let id: Int
    public let name: String
    public let logo: String?
    public let country: Country?
    /// Year founded, for a club.
    public let founded: Int?
    /// Whether the entry is a national side.
    public let isNational: Bool?
    /// A fighter's nickname.
    public let nickname: String?
    /// A fighter's record, `"W-L-D"`.
    public let record: String?

    public init(id: Int, name: String, logo: String? = nil, country: Country? = nil,
                founded: Int? = nil, isNational: Bool? = nil,
                nickname: String? = nil, record: String? = nil) {
        self.id = id
        self.name = name
        self.logo = logo
        self.country = country
        self.founded = founded
        self.isNational = isNational
        self.nickname = nickname
        self.record = record
    }

    private enum CodingKeys: String, CodingKey {
        case id, name, logo, country, founded, national, nickname, team, photo
        case wins, losses, draws
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        // Football v3 wraps: {"team": {…}, "venue": {…}}.
        let nested = Decode.nested(container, .team, keyedBy: CodingKeys.self)
        let source = nested ?? container

        self.id = Decode.int(source, .id) ?? 0
        self.name = Decode.string(source, .name) ?? ""
        // A fighter's image is `photo`, a club's is `logo`.
        self.logo = Decode.string(source, .logo) ?? Decode.string(source, .photo)
        self.country = Decode.value(Country.self, source, .country)
        self.founded = Decode.int(source, .founded)
        self.isNational = Decode.bool(source, .national)
        self.nickname = Decode.string(source, .nickname)
        self.record = Team.record(from: source)
    }

    /// Assembles `"W-L-D"` when the fighter endpoint supplies the parts.
    ///
    /// Draws are appended only when the other two are present, so a club —
    /// which has none of these fields — gets `nil` rather than an empty dash.
    private static func record(from container: KeyedDecodingContainer<CodingKeys>) -> String? {
        let wins = Decode.int(container, .wins)
        let losses = Decode.int(container, .losses)
        let draws = Decode.int(container, .draws)
        guard wins != nil || losses != nil else { return nil }
        return [wins, losses, draws].compactMap { $0 }.map(String.init).joined(separator: "-")
    }
}
