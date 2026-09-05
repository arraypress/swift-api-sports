//
//  SupportTests.swift
//  APISportsTests
//
//  Created by David Sherlock on 2026.
//
//  The extracted utilities on their own: the envelope's shape-shifting
//  `errors` field, URL building without a network, the three standings
//  nestings, and the sport table.
//

import Foundation
import XCTest
@testable import APISports

final class SupportTests: XCTestCase {

    // MARK: - Envelope

    /// The trap this library exists to absorb. Verified live 2026-09-05:
    /// a failure returns `errors` as an OBJECT, a success as an empty ARRAY.
    func testErrorsDecodeWhetherObjectOrArray() throws {
        let failure = try JSONDecoder().decode(Envelope<Team>.self, from: Data("""
        { "get": "status", "parameters": [],
          "errors": { "token": "Missing application key" },
          "results": 0, "paging": { "current": 1, "total": 1 }, "response": [] }
        """.utf8))
        XCTAssertEqual(failure.errors["token"], "Missing application key")
        XCTAssertEqual(failure.failure, .unauthorized("Missing application key"),
                       "the service's own `token` key means auth, not a generic upstream error")

        let success = try JSONDecoder().decode(Envelope<Team>.self, from: Data("""
        { "get": "teams", "parameters": [], "errors": [], "results": 1,
          "paging": { "current": 1, "total": 1 },
          "response": [ { "id": 33, "name": "Manchester United" } ] }
        """.utf8))
        XCTAssertTrue(success.errors.isEmpty, "an empty ARRAY must decode as no errors, not as a failure")
        XCTAssertNil(success.failure)
        XCTAssertEqual(success.response.first?.name, "Manchester United")
    }

    func testQuotaErrorIsReportedAsRateLimitedNotAsAGenericFailure() throws {
        let envelope = try JSONDecoder().decode(Envelope<Team>.self, from: Data("""
        { "errors": { "requests": "You have exceeded your daily quota." },
          "results": 0, "response": [] }
        """.utf8))
        XCTAssertEqual(envelope.failure, .rateLimited(retryAfter: nil))
    }

    func testResultsCountSurvivesArrivingAsAString() throws {
        let envelope = try JSONDecoder().decode(Envelope<Team>.self, from: Data("""
        { "errors": [], "results": "2", "response": [] }
        """.utf8))
        XCTAssertEqual(envelope.results, 2)
    }

    // MARK: - Endpoints

    func testURLBuildingDropsBlanksAndOrdersQueryStably() throws {
        let url = try Endpoints.url(sport: .basketball, path: "games", query: [
            "league": "12", "season": nil, "team": "", "date": "2026-09-05",
        ])
        XCTAssertEqual(url.absoluteString,
                       "https://v1.basketball.api-sports.io/games?date=2026-09-05&league=12",
                       "nil and blank parameters are dropped, and the rest sort by name")
    }

    func testFootballAloneSitsOnV3() throws {
        let football = try Endpoints.url(sport: .football, path: "status")
        let rugby = try Endpoints.url(sport: .rugby, path: "status")
        XCTAssertEqual(football.host, "v3.football.api-sports.io")
        XCTAssertEqual(rugby.host, "v1.rugby.api-sports.io")
    }

    func testDayIsGregorianUTCWhateverTheDeviceCalendar() {
        let date = Date(timeIntervalSince1970: 1_788_651_000)  // 2026-09-05T23:30:00Z
        XCTAssertEqual(Endpoints.day(date), "2026-09-05")
    }

    func testDatesParseOffsetFractionalAndBareDayForms() {
        XCTAssertNotNil(Dates.parse("2026-09-05T14:00:00+00:00"))
        XCTAssertNotNil(Dates.parse("2026-09-05T14:00:00.250Z"))
        XCTAssertNotNil(Dates.parse("2026-09-05"), "a fixture with no known kick-off time is still a date")
        XCTAssertNil(Dates.parse("not a date"))
        XCTAssertNil(Dates.parse(""))
        XCTAssertNil(Dates.day("2026-13-05"), "month 13 must not roll over into next year")
        XCTAssertNil(Dates.fromUnix(0), "the service's zero means unknown, not 1970")
    }

    // MARK: - Sport table

    func testAliasesAcceptTheNamesPeopleActuallyType() {
        XCTAssertEqual(Sport(alias: "nfl"), .americanFootball)
        XCTAssertEqual(Sport(alias: "f1"), .formula1)
        XCTAssertEqual(Sport(alias: "NBA"), .basketball)
        XCTAssertEqual(Sport(alias: "soccer"), .football)
        XCTAssertEqual(Sport(alias: "ufc"), .mma)
        XCTAssertEqual(Sport(alias: "american_football"), .americanFootball)
        XCTAssertNil(Sport(alias: "quidditch"))
    }

    func testEachFamilySpellsItsMatchEndpointDifferently() {
        XCTAssertEqual(Sport.football.gamesPath, "fixtures")
        XCTAssertEqual(Sport.rugby.gamesPath, "games")
        XCTAssertEqual(Sport.formula1.gamesPath, "races")
        XCTAssertEqual(Sport.mma.gamesPath, "fights")
        XCTAssertEqual(Sport.mma.teamsPath, "fighters", "a fight card has fighters, not teams")
        XCTAssertEqual(Sport.formula1.leaguesPath, "competitions")
        XCTAssertNil(Sport.mma.standingsPath, "a fight card has no table")
        XCTAssertTrue(Sport.football.supportsLiveFilter)
        XCTAssertFalse(Sport.formula1.supportsLiveFilter)
    }

    func testEverySportHasAReachableHost() {
        for sport in Sport.allCases {
            XCTAssertNoThrow(try Endpoints.url(sport: sport, path: "status"), "\(sport.rawValue)")
            XCTAssertFalse(sport.displayName.isEmpty)
        }
        XCTAssertEqual(Sport.allCases.count, 11, "the catalogue is eleven sports")
    }

    // MARK: - Standings nestings

    func testFootballStandingsUnwrapTwoLevelsOfNesting() throws {
        let rows = try Standings.rows(from: Data("""
        { "errors": [], "results": 1, "response": [
            { "league": { "id": 39, "standings": [ [
                { "rank": 1, "team": { "id": 50, "name": "Manchester City" }, "points": 89,
                  "goalsDiff": 61, "form": "WWWDW", "group": "Premier League",
                  "all": { "played": 38, "win": 28, "draw": 5, "lose": 5,
                           "goals": { "for": 96, "against": 35 } } }
            ] ] } } ] }
        """.utf8))

        XCTAssertEqual(rows.count, 1)
        let row = try XCTUnwrap(rows.first)
        XCTAssertEqual(row.rank, 1)
        XCTAssertEqual(row.team?.name, "Manchester City")
        XCTAssertEqual(row.points, 89)
        XCTAssertEqual(row.played, 38)
        XCTAssertEqual(row.won, 28)
        XCTAssertEqual(row.goalsFor, 96)
        XCTAssertEqual(row.goalDifference, 61, "computed, because only football ships goalsDiff")
        XCTAssertEqual(row.group, "Premier League")
    }

    func testUnifiedStandingsUnwrapTheirGroupArrays() throws {
        let rows = try Standings.rows(from: Data("""
        { "errors": [], "results": 2, "response": [ [
            { "position": 1, "team": { "id": 141, "name": "Boston Celtics" },
              "group": { "name": "Eastern Conference" }, "form": "WWLWW",
              "games": { "played": 82, "win": { "total": 60 }, "lose": { "total": 22 } },
              "points": { "for": 9520, "against": 8900 } }
          ], [
            { "position": 1, "team": { "id": 145, "name": "Denver Nuggets" },
              "group": { "name": "Western Conference" },
              "games": { "played": 82, "win": { "total": 57 }, "lose": { "total": 25 } } }
          ] ] }
        """.utf8))

        XCTAssertEqual(rows.count, 2, "both conference groups flatten into one list")
        XCTAssertEqual(rows[0].team?.name, "Boston Celtics")
        XCTAssertEqual(rows[0].won, 60, "a win count nested under `total` must be found")
        XCTAssertEqual(rows[0].points, 9520, "the unified sports put the ranking number in points.for")
        XCTAssertEqual(rows[0].group, "Eastern Conference", "group is an object here, a string on football")
        XCTAssertEqual(rows[1].team?.name, "Denver Nuggets")
    }

    func testFormulaOneRankingIsFlatAndKeepsTheConstructorBesideTheDriver() throws {
        let rows = try Standings.rows(from: Data("""
        { "errors": [], "results": 1, "response": [
            { "position": 1, "driver": { "id": 25, "name": "Max Verstappen" },
              "team": { "id": 5, "name": "Red Bull Racing" }, "points": 575 } ] }
        """.utf8))

        let row = try XCTUnwrap(rows.first)
        XCTAssertEqual(row.team?.name, "Max Verstappen", "the driver is the competitor being ranked")
        XCTAssertEqual(row.constructor?.name, "Red Bull Racing", "the team rides alongside, not instead")
        XCTAssertEqual(row.points, 575)
    }

    func testStandingsSurfaceAnAuthFailureRatherThanReportingAnEmptyTable() {
        let data = Data("""
        { "errors": { "token": "Missing application key" }, "results": 0, "response": [] }
        """.utf8)
        XCTAssertThrowsError(try Standings.rows(from: data)) { error in
            XCTAssertEqual(error as? APISportsError, .unauthorized("Missing application key"))
        }
    }
}
