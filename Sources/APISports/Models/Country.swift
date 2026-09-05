//
//  Country.swift
//  APISports
//
//  Created by David Sherlock on 2026.
//

import Foundation

/// A country a competition belongs to.
public struct Country: Sendable, Codable, Equatable {
    /// Numeric id on the unified sports; football identifies countries by name.
    public let id: Int?
    public let name: String
    /// ISO-ish code — `GB`, `US`. Absent for supranational competitions.
    public let code: String?
    /// URL of the flag image.
    public let flag: String?

    public init(id: Int? = nil, name: String, code: String? = nil, flag: String? = nil) {
        self.id = id
        self.name = name
        self.code = code
        self.flag = flag
    }

    public init(from decoder: Decoder) throws {
        // Formula 1 nests a location rather than a country object, and some
        // endpoints give the country as a bare string. Both paths delegate to
        // the memberwise initialiser: Swift forbids an initialiser that
        // delegates on one branch and assigns properties on another.
        if let single = try? decoder.singleValueContainer(), let name = try? single.decode(String.self) {
            self.init(name: name)
            return
        }
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.init(
            id: ((try? container.decodeIfPresent(Int.self, forKey: .id)) ?? nil),
            name: (try? container.decode(String.self, forKey: .name)) ?? "",
            code: ((try? container.decodeIfPresent(String.self, forKey: .code)) ?? nil),
            flag: ((try? container.decodeIfPresent(String.self, forKey: .flag)) ?? nil)
        )
    }
}
