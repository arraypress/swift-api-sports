//
//  Standing.swift
//  APISports
//
//  Created by David Sherlock on 2026.
//
//  A row of a league table. Three shapes again, plus a nesting trap:
//  standings do not arrive as a flat list on ANY sport.
//
//    football   response[0].league.standings -> [[row]]   (groups)
//    unified    response -> [[row]]                       (groups)
//    formula 1  response -> [row]                         (a ranking, flat)
//
//  ``Standings`` unwraps all three; this type is one row of the result.
//

import Foundation

/// One row of a table, or one place in a ranking.
public struct Standing: Sendable, Codable, Equatable {

    /// Where the competitor sits, 1-based.
    public let rank: Int?
    /// The competitor. For Formula 1 rankings this is the driver.
    public let team: Game.Competitor?
    /// The constructor, on a Formula 1 driver ranking.
    public let constructor: Game.Competitor?
    public let points: Int?
    public let played: Int?
    public let won: Int?
    public let drawn: Int?
    public let lost: Int?
    public let goalsFor: Int?
    public let goalsAgainst: Int?
    /// Recent results, newest last — `"WWDLW"`.
    public let form: String?
    /// Conference, division or group name.
    public let group: String?
    /// The service's own note: `Promotion`, `Relegation`, and so on.
    public let note: String?

    private enum CodingKeys: String, CodingKey {
        case rank, position, team, driver, points, form, group, description, status
        case goalsDiff, all, games, goals
    }
    private enum RecordKeys: String, CodingKey {
        case played, win, draw, lose, loss, goals, wins, losses, drawn
    }
    private enum TotalKeys: String, CodingKey { case total, `for`, against }
    private enum GroupKeys: String, CodingKey { case name }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        // Football says `rank`; the unified sports and Formula 1 say `position`.
        self.rank = Decode.int(container, .rank) ?? Decode.int(container, .position)

        // A Formula 1 ranking's competitor is the driver, with the constructor
        // beside it; every other sport has only a team.
        let driver = Decode.value(Game.Competitor.self, container, .driver)
        let team = Decode.value(Game.Competitor.self, container, .team)
        self.team = driver ?? team
        self.constructor = driver == nil ? nil : team

        self.points = Standing.points(from: container)
        self.form = Decode.string(container, .form)
        self.group = Standing.group(from: container)
        self.note = Decode.string(container, .description) ?? Decode.string(container, .status)

        // Football nests the record under `all`; the unified sports under `games`.
        let all = Decode.nested(container, .all, keyedBy: RecordKeys.self)
        let record = all ?? Decode.nested(container, .games, keyedBy: RecordKeys.self)
        self.played = Decode.int(record, .played)
        self.won = Standing.count(in: record, key: .win) ?? Standing.count(in: record, key: .wins)
        self.drawn = Standing.count(in: record, key: .draw) ?? Standing.count(in: record, key: .drawn)
        self.lost = Standing.count(in: record, key: .lose) ?? Standing.count(in: record, key: .losses)

        let goals = Standing.goals(container: container, record: record)
        self.goalsFor = goals.for
        self.goalsAgainst = goals.against
    }

    /// Points are a bare integer on football and Formula 1, and an object of
    /// `for`/`against` on the unified sports — where the ranking number is
    /// the `for` side.
    private static func points(from container: KeyedDecodingContainer<CodingKeys>) -> Int? {
        if let flat = Decode.int(container, .points) { return flat }
        return Decode.int(Decode.nested(container, .points, keyedBy: TotalKeys.self), .for)
    }

    /// A win/loss count is either a bare integer or an object with `total`.
    private static func count(in record: KeyedDecodingContainer<RecordKeys>?, key: RecordKeys) -> Int? {
        guard let record else { return nil }
        if let flat = Decode.int(record, key) { return flat }
        return Decode.int(Decode.nested(record, key, keyedBy: TotalKeys.self), .total)
    }

    /// Goals scored and conceded, wherever the sport files them.
    private static func goals(container: KeyedDecodingContainer<CodingKeys>,
                              record: KeyedDecodingContainer<RecordKeys>?) -> (for: Int?, against: Int?) {
        if let nested = Decode.nested(record, .goals, keyedBy: TotalKeys.self) {
            return (Decode.int(nested, .for), Decode.int(nested, .against))
        }
        guard let nested = Decode.nested(container, .points, keyedBy: TotalKeys.self) else {
            return (nil, nil)
        }
        return (Decode.int(nested, .for), Decode.int(nested, .against))
    }

    /// Group is a bare string on football and an object on the unified sports.
    private static func group(from container: KeyedDecodingContainer<CodingKeys>) -> String? {
        if let text = Decode.string(container, .group) { return text }
        return Decode.string(Decode.nested(container, .group, keyedBy: GroupKeys.self), .name)
    }

    /// Goal difference, computed rather than read — football ships
    /// `goalsDiff` but the unified sports do not, and a caller sorting a
    /// mixed table needs the same field to exist everywhere.
    public var goalDifference: Int? {
        guard let goalsFor, let goalsAgainst else { return nil }
        return goalsFor - goalsAgainst
    }
}
