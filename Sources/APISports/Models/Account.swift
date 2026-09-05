//
//  Account.swift
//  APISports
//
//  Created by David Sherlock on 2026.
//

import Foundation

/// What `/status` reports: the plan, and how much of it is spent.
///
/// Note that `/status` is the one endpoint whose `response` is an OBJECT
/// rather than an array, so it does not travel through ``Envelope``.
public struct Account: Sendable, Codable, Equatable {

    /// The plan's name — `Free`, `Pro`.
    public let plan: String?
    /// Whether the subscription is active.
    public let isActive: Bool?
    /// When the subscription ends, `yyyy-MM-dd`.
    public let ends: String?
    /// Requests made today.
    public let used: Int?
    /// Requests allowed per day.
    public let dailyLimit: Int?

    /// Requests left today, when both numbers are known.
    public var remaining: Int? {
        guard let used, let dailyLimit else { return nil }
        return max(0, dailyLimit - used)
    }

    private enum Root: String, CodingKey { case response }
    private enum Body: String, CodingKey { case subscription, requests }
    private enum Subscription: String, CodingKey { case plan, active, end }
    private enum Requests: String, CodingKey { case current, limitDay = "limit_day" }

    public init(plan: String?, isActive: Bool?, ends: String?, used: Int?, dailyLimit: Int?) {
        self.plan = plan
        self.isActive = isActive
        self.ends = ends
        self.used = used
        self.dailyLimit = dailyLimit
    }

    public init(from decoder: Decoder) throws {
        let root = try decoder.container(keyedBy: Root.self)
        let body = try root.nestedContainer(keyedBy: Body.self, forKey: .response)
        let subscription = try? body.nestedContainer(keyedBy: Subscription.self, forKey: .subscription)
        let requests = try? body.nestedContainer(keyedBy: Requests.self, forKey: .requests)
        self.plan = subscription.flatMap { ((try? $0.decodeIfPresent(String.self, forKey: .plan)) ?? nil) }
        self.isActive = subscription.flatMap { ((try? $0.decodeIfPresent(Bool.self, forKey: .active)) ?? nil) }
        self.ends = subscription.flatMap { ((try? $0.decodeIfPresent(String.self, forKey: .end)) ?? nil) }
        self.used = requests.flatMap { ((try? $0.decodeIfPresent(Int.self, forKey: .current)) ?? nil) }
        self.dailyLimit = requests.flatMap { ((try? $0.decodeIfPresent(Int.self, forKey: .limitDay)) ?? nil) }
    }
}
