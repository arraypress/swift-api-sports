//
//  ShapeTests.swift
//  APISportsTests
//
//  Created by David Sherlock on 2026.
//
//  The normaliser, pinned against all four service shapes.
//
//  These fixtures are trimmed from API-Sports' documented response shapes for
//  each family. They exist because the whole point of `Game` is that a caller
//  never sees the difference between `goals.home` and `scores.home.total`, and
//  the only way that claim stays true is if all four decode here.
//

import Foundation
import XCTest
@testable import APISports

final class ShapeTests: XCTestCase {

    private func game(_ json: String) throws -> Game {
        try JSONDecoder().decode(Game.self, from: Data(json.utf8))
    }

    // MARK: - Football (v3): nested fixture, `goals`

    func testFootballFixtureDecodesThroughItsNestedWrapper() throws {
        let decoded = try game("""
        {
          "fixture": {
            "id": 1035037,
            "date": "2026-09-05T14:00:00+00:00",
            "venue": { "name": "Old Trafford", "city": "Manchester" },
            "status": { "long": "Match Finished", "short": "FT", "elapsed": 90 }
          },
          "league": { "id": 39, "name": "Premier League", "season": 2025, "round": "Regular Season - 4" },
          "teams": {
            "home": { "id": 33, "name": "Manchester United", "winner": true },
            "away": { "id": 40, "name": "Liverpool", "winner": false }
          },
          "goals": { "home": 2, "away": 1 }
        }
        """)

        XCTAssertEqual(decoded.id, 1035037, "id comes from the nested fixture object, not the top level")
        XCTAssertEqual(decoded.home?.name, "Manchester United")
        XCTAssertEqual(decoded.away?.name, "Liverpool")
        XCTAssertEqual(decoded.homeScore, 2, "football spells the score `goals`")
        XCTAssertEqual(decoded.awayScore, 1)
        XCTAssertEqual(decoded.status.short, "FT")
        XCTAssertEqual(decoded.status.elapsed, 90)
        XCTAssertTrue(decoded.status.isFinished)
        XCTAssertFalse(decoded.status.isLive)
        XCTAssertEqual(decoded.venue, "Old Trafford")
        XCTAssertEqual(decoded.stage, "Regular Season - 4")
        XCTAssertEqual(decoded.league?.season, "2025", "an integer season is normalised to its string form")
        XCTAssertNotNil(decoded.date)
    }

    // MARK: - Unified (v1): flat, `scores.home.total`

    func testUnifiedGameReadsThePerPeriodScoreObject() throws {
        let decoded = try game("""
        {
          "id": 380953,
          "date": "2026-09-05T23:30:00+00:00",
          "timestamp": 1788651000,
          "status": { "long": "Game Finished", "short": "FT", "timer": null },
          "league": { "id": 12, "name": "NBA", "type": "League", "season": "2025-2026" },
          "teams": {
            "home": { "id": 141, "name": "Boston Celtics" },
            "away": { "id": 145, "name": "Los Angeles Lakers" }
          },
          "scores": {
            "home": { "quarter_1": 30, "quarter_2": 28, "total": 118 },
            "away": { "quarter_1": 25, "quarter_2": 31, "total": 110 }
          }
        }
        """)

        XCTAssertEqual(decoded.id, 380953, "the unified sports keep id at the top level")
        XCTAssertEqual(decoded.homeScore, 118, "the match total is pulled out of the per-period object")
        XCTAssertEqual(decoded.awayScore, 110)
        XCTAssertEqual(decoded.league?.season, "2025-2026", "a split-year season must survive as a string")
        XCTAssertEqual(decoded.home?.name, "Boston Celtics")
    }

    func testVolleyballStyleFlatScoresAlsoDecode() throws {
        // Some unified sports ship bare integers where the rest nest an object.
        let decoded = try game("""
        {
          "id": 4411,
          "date": "2026-09-05T17:00:00+00:00",
          "status": { "long": "Finished", "short": "FT" },
          "teams": { "home": { "id": 1, "name": "Italy" }, "away": { "id": 2, "name": "Poland" } },
          "scores": { "home": 3, "away": 1 }
        }
        """)
        XCTAssertEqual(decoded.homeScore, 3, "a bare integer score must not be missed")
        XCTAssertEqual(decoded.awayScore, 1)
    }

    // MARK: - Formula 1: a race, with no opponents and no score

    func testRaceDecodesWithoutOpponentsAndTakesItsNameFromTheCompetition() throws {
        let decoded = try game("""
        {
          "id": 1141,
          "competition": { "id": 3, "name": "Italian Grand Prix" },
          "circuit": { "id": 3, "name": "Autodromo Nazionale Monza" },
          "season": 2026,
          "type": "Race",
          "laps": { "current": null, "total": 53 },
          "date": "2026-09-06T13:00:00+00:00",
          "status": "Scheduled"
        }
        """)

        XCTAssertEqual(decoded.id, 1141)
        XCTAssertNil(decoded.home, "a race has no home side")
        XCTAssertNil(decoded.away)
        XCTAssertNil(decoded.homeScore, "a race is not scored — a finishing order is a different endpoint")
        XCTAssertEqual(decoded.title, "Italian Grand Prix", "with no opponents, the competition names the event")
        XCTAssertEqual(decoded.status.long, "Scheduled", "Formula 1 ships status as a bare string")
        XCTAssertFalse(decoded.status.isFinished)
    }

    // MARK: - MMA: fighters under `first`/`second`

    func testFightMapsFirstAndSecondFighterOntoHomeAndAway() throws {
        let decoded = try game("""
        {
          "id": 812,
          "date": "2026-09-05T22:00:00+00:00",
          "category": "Middleweight",
          "is_main": true,
          "status": { "long": "Finished", "short": "FT" },
          "fighters": {
            "first": { "id": 41, "name": "Israel Adesanya", "winner": true },
            "second": { "id": 88, "name": "Sean Strickland", "winner": false }
          }
        }
        """)

        XCTAssertEqual(decoded.home?.name, "Israel Adesanya", "`first` is the home slot on a fight card")
        XCTAssertEqual(decoded.away?.name, "Sean Strickland")
        XCTAssertEqual(decoded.home?.winner, true)
        XCTAssertEqual(decoded.title, "Middleweight", "a fight is titled by its weight category")
        XCTAssertNil(decoded.homeScore, "a fight has no score")
    }

    // MARK: - Encoding

    func testEncodingEmitsTheNormalisedShapeNotTheServiceShape() throws {
        let decoded = try game("""
        { "fixture": { "id": 7, "status": { "short": "FT" } },
          "teams": { "home": { "id": 1, "name": "A" }, "away": { "id": 2, "name": "B" } },
          "goals": { "home": 3, "away": 0 } }
        """)
        let data = try JSONEncoder().encode(decoded)
        let object = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])

        XCTAssertEqual(object["homeScore"] as? Int, 3, "re-emitted JSON uses our field names")
        XCTAssertNil(object["goals"], "the service's own spelling must not survive a round trip")
        XCTAssertNil(object["fixture"], "nor its wrapper")
        XCTAssertNil(object["venue"], "absent fields are omitted rather than written as null")
    }
}
