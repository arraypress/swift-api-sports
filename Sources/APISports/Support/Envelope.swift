//
//  Envelope.swift
//  APISports
//
//  Created by David Sherlock on 2026.
//
//  Every API-Sports response — success or failure, all eleven sports — is the
//  same wrapper around a `response` array. Two things about it are traps.
//
//  ONE: `errors` changes TYPE with the outcome. A successful call returns an
//  empty ARRAY (`"errors": []`); a failed one returns an OBJECT keyed by
//  what went wrong (`"errors": {"token": "Missing application key…"}`).
//  A decoder that assumes either one fails on half the responses. Verified
//  live 2026-09-05 against v1.basketball and v3.football.
//
//  TWO: authentication failures arrive as HTTP 200. The refusal is in the
//  body, so status-code checking alone reports success on a missing key.
//

import Foundation

/// The wrapper every endpoint returns.
struct Envelope<Item: Decodable & Sendable>: Decodable, Sendable {

    /// The endpoint that answered.
    let get: String
    /// How many items came back. Occasionally a string; normalised here.
    let results: Int
    /// Paging, when the endpoint pages.
    let paging: Paging?
    /// Problems reported inside a 200.
    let errors: [String: String]
    /// The payload.
    let response: [Item]

    struct Paging: Decodable, Sendable {
        let current: Int?
        let total: Int?
    }

    private enum CodingKeys: String, CodingKey {
        case get, results, paging, errors, response
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.get = (try? container.decode(String.self, forKey: .get)) ?? ""
        self.results = Envelope.decodeResults(from: container)
        self.paging = try? container.decodeIfPresent(Paging.self, forKey: .paging)
        self.errors = Envelope.decodeErrors(from: container)
        self.response = (try? container.decode([Item].self, forKey: .response)) ?? []
    }

    /// `results` is an integer on every endpoint observed, but the service has
    /// shipped it as a string before; accept both rather than fail the call.
    private static func decodeResults(from container: KeyedDecodingContainer<CodingKeys>) -> Int {
        if let number = try? container.decode(Int.self, forKey: .results) { return number }
        if let text = try? container.decode(String.self, forKey: .results) { return Int(text) ?? 0 }
        return 0
    }

    /// Reads `errors` whichever shape it arrived in — see the file note.
    ///
    /// An object becomes its own key/value pairs. An array is either the empty
    /// success case or, rarely, a list of bare strings; those are indexed so
    /// nothing is silently dropped.
    private static func decodeErrors(from container: KeyedDecodingContainer<CodingKeys>) -> [String: String] {
        if let object = try? container.decode([String: String].self, forKey: .errors) {
            return object
        }
        if let list = try? container.decode([String].self, forKey: .errors) {
            return Dictionary(uniqueKeysWithValues: list.enumerated().map { (String($0.offset), $0.element) })
        }
        return [:]
    }

    /// The failure this envelope reports, if it reports one.
    ///
    /// The `token` key is the service's own name for both "no key" and "bad
    /// key", so it maps to `.unauthorized`; a `requests` key is the quota.
    var failure: APISportsError? {
        guard !errors.isEmpty else { return nil }
        if let token = errors["token"] ?? errors["Token"] {
            return .unauthorized(token)
        }
        if errors["requests"] != nil || errors["rateLimit"] != nil {
            return .rateLimited(retryAfter: nil)
        }
        // Anything else: report every key so nothing is hidden behind the first.
        let detail = errors
            .sorted { $0.key < $1.key }
            .map { $0.key.isEmpty ? $0.value : "\($0.key): \($0.value)" }
            .joined(separator: "; ")
        return .upstream(detail)
    }
}
