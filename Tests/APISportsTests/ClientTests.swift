//
//  ClientTests.swift
//  APISportsTests
//
//  Created by David Sherlock on 2026.
//
//  The client on recorded transports — no network, no key, no CI secret.
//  What is pinned here is the behaviour that is easy to get wrong and
//  expensive to discover later: that a refusal wearing an HTTP 200 is
//  reported as a refusal, that the key travels in a header and never in a
//  URL, and that the sports with no such endpoint fail before spending a
//  request rather than after.
//

import Foundation
import XCTest
@testable import APISports

final class ClientTests: XCTestCase {

    /// A transport that replays one body and records what it was asked for.
    private final class Recorder: @unchecked Sendable {
        var requests: [URLRequest] = []
        let body: String
        let status: Int
        let headers: [String: String]

        init(body: String, status: Int = 200, headers: [String: String] = [:]) {
            self.body = body
            self.status = status
            self.headers = headers
        }

        var transport: APISports.Transport {
            { [self] request in
                requests.append(request)
                let response = HTTPURLResponse(
                    url: request.url!, statusCode: status,
                    httpVersion: nil, headerFields: headers
                )!
                return (Data(body.utf8), response)
            }
        }
    }

    // MARK: - The 200-shaped refusal

    func testAMissingKeyIsReportedAsAuthNotAsAnEmptyResult() async throws {
        // Exactly what the service returned to an unkeyed probe on 2026-09-05.
        let recorder = Recorder(body: """
        { "get": "", "parameters": [],
          "errors": { "token": "Missing application key, Check our documentation on how to add your API key in headers.",
                      "error": "4xHe" },
          "results": 0, "paging": { "current": 1, "total": 1 }, "response": [] }
        """)
        let client = APISports(key: "", transport: recorder.transport)

        do {
            _ = try await client.teams(.basketball)
            XCTFail("a refusal carried inside a 200 must not surface as an empty list")
        } catch let error as APISportsError {
            guard case .unauthorized = error else {
                return XCTFail("expected .unauthorized, got \(error)")
            }
        }
    }

    // MARK: - The key never reaches a URL

    func testTheKeyTravelsInAHeaderAndNeverInTheQueryString() async throws {
        let recorder = Recorder(body: #"{ "errors": [], "results": 0, "response": [] }"#)
        let client = APISports(key: "s3cret-key", transport: recorder.transport)
        _ = try await client.games(.rugby, league: 16, season: "2026")

        let request = try XCTUnwrap(recorder.requests.first)
        XCTAssertEqual(request.value(forHTTPHeaderField: "x-apisports-key"), "s3cret-key")
        let url = try XCTUnwrap(request.url?.absoluteString)
        XCTAssertFalse(url.contains("s3cret-key"), "a key in a URL leaks into proxy logs and shell history")
        XCTAssertEqual(request.url?.host, "v1.rugby.api-sports.io")
        XCTAssertTrue(url.contains("/games"), "rugby is a unified sport and says `games`")
    }

    func testFootballAsksForFixturesWhereTheUnifiedSportsAskForGames() async throws {
        let recorder = Recorder(body: #"{ "errors": [], "results": 0, "response": [] }"#)
        let client = APISports(key: "k", transport: recorder.transport)
        _ = try await client.games(.football, league: 39, season: "2025")

        let url = try XCTUnwrap(recorder.requests.first?.url?.absoluteString)
        XCTAssertTrue(url.hasPrefix("https://v3.football.api-sports.io/fixtures"), url)
    }

    // MARK: - Refusing before spending a request

    func testMMAStandingsFailWithoutMakingARequest() async {
        let recorder = Recorder(body: "{}")
        let client = APISports(key: "k", transport: recorder.transport)

        do {
            _ = try await client.standings(.mma, season: "2026")
            XCTFail("MMA has no table")
        } catch let error as APISportsError {
            guard case .unsupported = error else {
                return XCTFail("expected .unsupported, got \(error)")
            }
        } catch {
            XCTFail("unexpected \(error)")
        }
        XCTAssertTrue(recorder.requests.isEmpty,
                      "the free tier is 100 requests a day — a call that cannot work must not cost one")
    }

    func testUnifiedStandingsWithoutALeagueFailBeforeSpendingARequest() async {
        let recorder = Recorder(body: "{}")
        let client = APISports(key: "k", transport: recorder.transport)
        do {
            _ = try await client.standings(.basketball, season: "2025-2026")
            XCTFail("a league table needs a league")
        } catch {
            XCTAssertTrue(recorder.requests.isEmpty)
        }
    }

    func testFormulaOneStandingsNeedNoLeagueAndRankDrivers() async throws {
        let recorder = Recorder(body: #"{ "errors": [], "results": 0, "response": [] }"#)
        let client = APISports(key: "k", transport: recorder.transport)
        _ = try await client.standings(.formula1, season: "2026")

        let url = try XCTUnwrap(recorder.requests.first?.url?.absoluteString)
        XCTAssertTrue(url.contains("/rankings/drivers"), url)
        XCTAssertFalse(url.contains("league="), "a race series ranks by season alone")
    }

    // MARK: - Allowance

    func testTheRemainingAllowanceIsReportedToTheObserver() async throws {
        let recorder = Recorder(
            body: #"{ "errors": [], "results": 0, "response": [] }"#,
            headers: [
                "x-ratelimit-requests-limit": "100",
                "x-ratelimit-requests-remaining": "3",
                "X-RateLimit-Limit": "10",
                "X-RateLimit-Remaining": "9",
            ]
        )
        let box = Box()
        let client = APISports(key: "k", transport: recorder.transport) { box.value = $0 }
        _ = try await client.teams(.hockey)

        let seen = try XCTUnwrap(box.value)
        XCTAssertEqual(seen.dailyRemaining, 3, "an agent that cannot see this will spend the day's 100 blind")
        XCTAssertEqual(seen.dailyLimit, 100)
        XCTAssertEqual(seen.minuteRemaining, 9)
    }

    func testATooManyRequestsStatusBecomesRateLimitedWithItsRetryAfter() async {
        let recorder = Recorder(body: "", status: 429, headers: ["Retry-After": "30"])
        let client = APISports(key: "k", transport: recorder.transport)
        do {
            _ = try await client.teams(.handball)
            XCTFail("429 must not pass")
        } catch let error as APISportsError {
            XCTAssertEqual(error, .rateLimited(retryAfter: 30))
        } catch {
            XCTFail("unexpected \(error)")
        }
    }

    // MARK: - MMA categories

    func testMMACategoriesArriveAsBareStringsAndBecomeLeagues() async throws {
        let recorder = Recorder(body: """
        { "errors": [], "results": 2, "response": [ "Middleweight", "Heavyweight" ] }
        """)
        let client = APISports(key: "k", transport: recorder.transport)
        let leagues = try await client.leagues(.mma)

        XCTAssertEqual(leagues.map(\.name), ["Middleweight", "Heavyweight"])
        let url = try XCTUnwrap(recorder.requests.first?.url?.absoluteString)
        XCTAssertTrue(url.contains("/categories"), url)
    }

    // MARK: - Status

    func testStatusReadsThePlanAndWhatIsLeftOfIt() async throws {
        let recorder = Recorder(body: """
        { "get": "status", "errors": [], "results": 1, "response": {
            "account": { "firstname": "D", "lastname": "S", "email": "x@example.com" },
            "subscription": { "plan": "Free", "end": "2027-01-01", "active": true },
            "requests": { "current": 17, "limit_day": 100 } } }
        """)
        let client = APISports(key: "k", transport: recorder.transport)
        let account = try await client.status()

        XCTAssertEqual(account.plan, "Free")
        XCTAssertEqual(account.used, 17)
        XCTAssertEqual(account.dailyLimit, 100)
        XCTAssertEqual(account.remaining, 83, "the number an agent actually needs")
        XCTAssertEqual(account.isActive, true)
    }

    /// A mutable box so the observer closure can report back.
    private final class Box: @unchecked Sendable {
        var value: RateLimit?
    }
}
