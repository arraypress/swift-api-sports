//
//  Decode.swift
//  APISports
//
//  Created by David Sherlock on 2026.
//
//  Tolerant field reads, in one place.
//
//  Every model here decodes a service that spells the same field four ways
//  and omits it on a fifth sport, so every read is "try this, fall back to
//  that". Written inline, each one is `((try? c.decodeIfPresent(T.self,
//  forKey: k)) ?? nil)` — a double optional that has to be flattened, reads
//  badly, and chained often enough to time out the type-checker outright.
//
//  These helpers flatten it once. They never throw: a field that is absent,
//  null, or of the wrong type is `nil`, which is exactly the semantics a
//  multi-shape decoder wants.
//

import Foundation

/// Flattened, non-throwing reads from a keyed container.
enum Decode {

    /// A string, or `nil` if it is absent or not a string.
    static func string<K: CodingKey>(_ container: KeyedDecodingContainer<K>?, _ key: K) -> String? {
        guard let container else { return nil }
        return (try? container.decodeIfPresent(String.self, forKey: key)) ?? nil
    }

    /// An integer, accepting the string form the service sometimes ships.
    static func int<K: CodingKey>(_ container: KeyedDecodingContainer<K>?, _ key: K) -> Int? {
        guard let container else { return nil }
        if let number = (try? container.decodeIfPresent(Int.self, forKey: key)) ?? nil { return number }
        guard let text = (try? container.decodeIfPresent(String.self, forKey: key)) ?? nil else { return nil }
        return Int(text.prefix(while: { $0.isNumber || $0 == "-" }))
    }

    /// A boolean, or `nil`.
    static func bool<K: CodingKey>(_ container: KeyedDecodingContainer<K>?, _ key: K) -> Bool? {
        guard let container else { return nil }
        return (try? container.decodeIfPresent(Bool.self, forKey: key)) ?? nil
    }

    /// A decodable value, or `nil`.
    static func value<T: Decodable, K: CodingKey>(
        _ type: T.Type, _ container: KeyedDecodingContainer<K>?, _ key: K
    ) -> T? {
        guard let container else { return nil }
        return (try? container.decodeIfPresent(T.self, forKey: key)) ?? nil
    }

    /// A nested container, or `nil` when the key is absent or not an object.
    static func nested<Outer: CodingKey, Inner: CodingKey>(
        _ container: KeyedDecodingContainer<Outer>?, _ key: Outer, keyedBy: Inner.Type
    ) -> KeyedDecodingContainer<Inner>? {
        guard let container else { return nil }
        return try? container.nestedContainer(keyedBy: Inner.self, forKey: key)
    }

    /// A season label, which arrives as a string on some sports and a number
    /// on others. Shared because three models read it.
    static func season<K: CodingKey>(_ container: KeyedDecodingContainer<K>?, _ key: K) -> String? {
        guard let container else { return nil }
        if let text = (try? container.decodeIfPresent(String.self, forKey: key)) ?? nil { return text }
        guard let year = (try? container.decodeIfPresent(Int.self, forKey: key)) ?? nil else { return nil }
        return String(year)
    }
}
