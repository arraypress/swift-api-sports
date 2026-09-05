//
//  Game.swift
//  APISports
//
//  Created by David Sherlock on 2026.
//
//  One match, normalised across four incompatible shapes. This type is the
//  reason the library exists: without it, every caller writes the same four
//  branches. The shapes, as the service ships them:
//
//    football   {"fixture":{"id","date","status"},"goals":{"home":2,"away":1},
//                "teams":{"home":{…},"away":{…}}}
//    unified    {"id","date","status","teams":{…},
//                "scores":{"home":{"total":110},"away":{…}}}
//    formula 1  {"id","date","competition":{"name"},"circuit":{…},"laps":{…}}
//                — a race has no opponents and no score
//    mma        {"id","date","category","fighters":{"first":{…},"second":{…}}}
//
//  Scores are the sharpest edge: football keys them `goals` with bare
//  integers, most unified sports key them `scores` with a per-period object
//  carrying `total`, and volleyball keys `scores` with bare integers. All
//  three are read here.
//

import Foundation

/// A match, race or fight.
public struct Game: Sendable, Codable, Equatable, Identifiable {

    public let id: Int
    /// Kick-off, in UTC.
    public let date: Date?
    public let status: Status
    /// The competition this belongs to.
    public let league: Reference?
    /// The home side, the first fighter — absent for a race.
    public let home: Competitor?
    /// The away side, the second fighter — absent for a race.
    public let away: Competitor?
    public let homeScore: Int?
    public let awayScore: Int?
    /// What to call the event when there are no opponents: the Grand Prix
    /// name for a race, the weight category for a fight.
    public let title: String?
    /// Round, week or stage, as the sport names it.
    public let stage: String?
    public let venue: String?

    // MARK: - Nested

    /// How far along the match is.
    public struct Status: Sendable, Codable, Equatable {
        /// `Match Finished`, `Not Started`.
        public let long: String?
        /// `FT`, `NS`, `1H`.
        public let short: String?
        /// Minutes played, where the sport counts them.
        public let elapsed: Int?

        public init(long: String? = nil, short: String? = nil, elapsed: Int? = nil) {
            self.long = long
            self.short = short
            self.elapsed = elapsed
        }

        private enum CodingKeys: String, CodingKey { case long, short, elapsed, timer }

        public init(from decoder: Decoder) throws {
            // Formula 1 gives a bare string: "status": "Completed".
            if let single = try? decoder.singleValueContainer(), let text = try? single.decode(String.self) {
                self.init(long: text, short: nil, elapsed: nil)
                return
            }
            let container = try? decoder.container(keyedBy: CodingKeys.self)
            self.init(
                long: Decode.string(container, .long),
                short: Decode.string(container, .short),
                // Football counts `elapsed`; the unified sports count `timer`.
                elapsed: Decode.int(container, .elapsed) ?? Decode.int(container, .timer)
            )
        }

        /// Whether the match has finished.
        public var isFinished: Bool {
            guard let code = short?.uppercased() else {
                return (long ?? "").lowercased().contains("finish")
                    || (long ?? "").lowercased().contains("complet")
            }
            return ["FT", "AET", "PEN", "AOT", "AP", "END", "FIN"].contains(code)
        }

        /// Whether the match is under way.
        public var isLive: Bool {
            guard let code = short?.uppercased() else { return false }
            return ["1H", "2H", "HT", "ET", "P", "LIVE", "Q1", "Q2", "Q3", "Q4",
                    "OT", "BT", "IN", "INTR"].contains(code)
        }
    }

    /// A named thing the service points at — a league, a competition.
    public struct Reference: Sendable, Codable, Equatable {
        public let id: Int?
        public let name: String?
        /// The season label, as the sport spells it.
        public let season: String?

        public init(id: Int? = nil, name: String? = nil, season: String? = nil) {
            self.id = id
            self.name = name
            self.season = season
        }

        private enum CodingKeys: String, CodingKey { case id, name, season }

        public init(from decoder: Decoder) throws {
            let container = try? decoder.container(keyedBy: CodingKeys.self)
            self.init(
                id: Decode.int(container, .id),
                name: Decode.string(container, .name),
                // Football's season is an integer, the unified sports' a string.
                season: Decode.season(container, .season)
            )
        }
    }

    /// One side of a match.
    public struct Competitor: Sendable, Codable, Equatable {
        public let id: Int?
        public let name: String?
        public let logo: String?
        /// Whether this side won, where the service says so directly.
        public let winner: Bool?

        public init(id: Int? = nil, name: String? = nil, logo: String? = nil, winner: Bool? = nil) {
            self.id = id
            self.name = name
            self.logo = logo
            self.winner = winner
        }

        private enum CodingKeys: String, CodingKey { case id, name, logo, winner, photo }

        public init(from decoder: Decoder) throws {
            let container = try? decoder.container(keyedBy: CodingKeys.self)
            self.init(
                id: Decode.int(container, .id),
                name: Decode.string(container, .name),
                // A fighter's image is `photo`, a club's is `logo`.
                logo: Decode.string(container, .logo) ?? Decode.string(container, .photo),
                winner: Decode.bool(container, .winner)
            )
        }
    }

    // MARK: - Decoding

    private enum CodingKeys: String, CodingKey {
        case id, date, timestamp, status, league, teams, goals, scores, fighters
        case fixture, competition, circuit, category, stage, week, round, venue
        case isMain = "is_main"
    }

    private enum SideKeys: String, CodingKey { case home, away, first, second }
    private enum WrapKeys: String, CodingKey { case id, date, status, timestamp, venue, name, city }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        // Football hides id, date and status one level down under `fixture`;
        // every other sport keeps them at the top.
        let fixture = Decode.nested(container, .fixture, keyedBy: WrapKeys.self)

        self.id = Decode.int(fixture, .id) ?? Decode.int(container, .id) ?? 0

        let stamp = Decode.string(fixture, .date) ?? Decode.string(container, .date)
        let unix = Decode.int(fixture, .timestamp) ?? Decode.int(container, .timestamp)
        self.date = Dates.parse(stamp) ?? Dates.fromUnix(unix)

        let fixtureStatus = Decode.value(Status.self, fixture, .status)
        self.status = fixtureStatus ?? Decode.value(Status.self, container, .status) ?? Status()

        let leagueRef = Decode.value(Reference.self, container, .league)
        self.league = leagueRef ?? Decode.value(Reference.self, container, .competition)

        // Opponents: `teams` for football and the unified sports, `fighters`
        // for MMA, neither for a race.
        let teams = Decode.nested(container, .teams, keyedBy: SideKeys.self)
        let sides = teams ?? Decode.nested(container, .fighters, keyedBy: SideKeys.self)
        let firstSide = Decode.value(Competitor.self, sides, .home)
        let secondSide = Decode.value(Competitor.self, sides, .away)
        self.home = firstSide ?? Decode.value(Competitor.self, sides, .first)
        self.away = secondSide ?? Decode.value(Competitor.self, sides, .second)

        let scores = Game.scores(from: container)
        self.homeScore = scores.home
        self.awayScore = scores.away

        // A race is named by its competition; a fight, by its category.
        let category = Decode.string(container, .category)
        self.title = category ?? (self.home == nil ? self.league?.name : nil)

        // Round, week and stage name the same thing in three sports' words —
        // and football files `round` INSIDE its league block, not beside it.
        let leagueBlock = Decode.nested(container, .league, keyedBy: CodingKeys.self)
        let round = Decode.string(container, .round) ?? Decode.string(leagueBlock, .round)
        let stage = round ?? Decode.string(container, .stage)
        self.stage = stage ?? Decode.string(container, .week)

        self.venue = Game.venue(from: container, fixture: fixture)
    }

    /// Reads the three score spellings. Returns `nil`s for a race, which has
    /// no score at all — a finishing order is a different endpoint.
    private static func scores(from container: KeyedDecodingContainer<CodingKeys>) -> (home: Int?, away: Int?) {
        // Football: {"goals": {"home": 2, "away": 1}}
        if let goals = Decode.nested(container, .goals, keyedBy: SideKeys.self) {
            let home = Decode.int(goals, .home)
            let away = Decode.int(goals, .away)
            if home != nil || away != nil { return (home, away) }
        }
        guard let side = Decode.nested(container, .scores, keyedBy: SideKeys.self) else {
            return (nil, nil)
        }
        // Volleyball and friends: {"scores": {"home": 3, "away": 1}}
        let flatHome = Decode.int(side, .home)
        let flatAway = Decode.int(side, .away)
        if flatHome != nil || flatAway != nil { return (flatHome, flatAway) }
        // Most unified sports: {"scores": {"home": {"total": 110}, …}}
        return (total(in: side, forKey: .home), total(in: side, forKey: .away))
    }

    private enum TotalKeys: String, CodingKey { case total, score, points }

    /// Pulls the match total out of a per-period score object.
    private static func total(in container: KeyedDecodingContainer<SideKeys>, forKey key: SideKeys) -> Int? {
        guard let side = Decode.nested(container, key, keyedBy: TotalKeys.self) else { return nil }
        let total = Decode.int(side, .total)
        let score = total ?? Decode.int(side, .score)
        return score ?? Decode.int(side, .points)
    }

    /// The venue, from football's nested object or a bare string elsewhere.
    private static func venue(from container: KeyedDecodingContainer<CodingKeys>,
                              fixture: KeyedDecodingContainer<WrapKeys>?) -> String? {
        if let nested = Decode.nested(fixture, .venue, keyedBy: WrapKeys.self) {
            return Decode.string(nested, .name)
        }
        return Decode.string(container, .venue)
    }
}
