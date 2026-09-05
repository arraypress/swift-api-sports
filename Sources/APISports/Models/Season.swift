//
//  Season.swift
//  APISports
//
//  Created by David Sherlock on 2026.
//

import Foundation

/// One season of a competition.
///
/// The label is a string on purpose: the unified sports use `2025-2026` where
/// football uses `2025`, and flattening both to an integer loses the split-year
/// leagues entirely.
public struct Season: Sendable, Codable, Equatable {
    /// `2025` or `2025-2026`, as the sport spells it.
    public let label: String
    /// First day of the season, `yyyy-MM-dd`.
    public let start: String?
    /// Last day of the season, `yyyy-MM-dd`.
    public let end: String?
    /// Whether this is the season in progress.
    public let isCurrent: Bool

    public init(label: String, start: String? = nil, end: String? = nil, isCurrent: Bool = false) {
        self.label = label
        self.start = start
        self.end = end
        self.isCurrent = isCurrent
    }

    private enum CodingKeys: String, CodingKey {
        case season, year, start, end, current
    }

    public init(from decoder: Decoder) throws {
        // A season is sometimes just the label: `"seasons": [2023, 2024]`.
        if let single = try? decoder.singleValueContainer() {
            if let number = try? single.decode(Int.self) {
                self.init(label: String(number)); return
            }
            if let text = try? single.decode(String.self) {
                self.init(label: text); return
            }
        }
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.init(
            label: Season.label(from: container),
            start: ((try? container.decodeIfPresent(String.self, forKey: .start)) ?? nil),
            end: ((try? container.decodeIfPresent(String.self, forKey: .end)) ?? nil),
            isCurrent: ((try? container.decodeIfPresent(Bool.self, forKey: .current)) ?? nil) ?? false
        )
    }

    /// The season label, wherever the sport files it and whatever type it
    /// used: unified sports key it `season`, football keys it `year`, and
    /// either can arrive as a string or a number.
    private static func label(from container: KeyedDecodingContainer<CodingKeys>) -> String {
        if let text = ((try? container.decodeIfPresent(String.self, forKey: .season)) ?? nil) { return text }
        if let number = ((try? container.decodeIfPresent(Int.self, forKey: .season)) ?? nil) { return String(number) }
        if let number = ((try? container.decodeIfPresent(Int.self, forKey: .year)) ?? nil) { return String(number) }
        if let text = ((try? container.decodeIfPresent(String.self, forKey: .year)) ?? nil) { return text }
        return ""
    }
}
