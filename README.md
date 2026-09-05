# swift-api-sports

Eleven sports behind one verb set.

```swift
import APISports

let sports = APISports(key: myKey)

try await sports.games(.football, date: .now)     // fixtures
try await sports.games(.formula1, season: "2026") // races
try await sports.games(.mma, date: .now)          // fights
```

Same call, same `[Game]` back — whichever sport, whichever shape the service used.

## The eleven

| Sport | Host | Matches are called |
|---|---|---|
| Football (soccer) | `v3.football.api-sports.io` | `fixtures` |
| Basketball (NBA) | `v1.basketball.…` | `games` |
| Baseball (MLB) | `v1.baseball.…` | `games` |
| Hockey (NHL) | `v1.hockey.…` | `games` |
| American football (NFL) | `v1.american-football.…` | `games` |
| Rugby | `v1.rugby.…` | `games` |
| Handball | `v1.handball.…` | `games` |
| Volleyball | `v1.volleyball.…` | `games` |
| AFL | `v1.afl.…` | `games` |
| Formula 1 | `v1.formula-1.…` | `races` |
| MMA | `v1.mma.…` | `fights` |

One key covers all eleven. `Sport(alias:)` accepts what people type — `nfl`, `f1`, `nba`, `soccer`, `ufc`.

## Why this exists

API-Sports gives each sport its own subdomain and its own vocabulary, and the
differences are not cosmetic:

```
football   {"fixture":{"id","date"}, "goals":{"home":2,"away":1}, "teams":{…}}
unified    {"id","date",             "scores":{"home":{"total":110}}, "teams":{…}}
formula 1  {"id","date","competition":{"name"}}          — no opponents, no score
mma        {"id","date","category","fighters":{"first","second"}}
```

Without normalisation every caller writes the same four branches. `Game` writes
them once:

```swift
let game = try await sports.games(.basketball, date: .now).first
game?.home?.name     // "Boston Celtics"
game?.homeScore      // 118  — from scores.home.total
game?.status.isLive  // false
```

Decoding is tolerant of all four shapes; **encoding emits only the normalised
one**, so a `Game` re-serialised as JSON never carries `goals` or `fixture`.

## Verbs

```swift
try await sports.status()                                        // plan + allowance
try await sports.leagues(.rugby, country: "England")             // competitions
try await sports.teams(.mma, search: "Adesanya")                 // teams, or fighters
try await sports.standings(.football, league: 39, season: "2025") // a table
try await sports.games(.hockey, date: .now, league: 57)          // a day's card
try await sports.live(.football)                                 // in progress now
```

Where a sport has no such thing, the call refuses **before spending a request**:
MMA standings throw `.unsupported` rather than fetching a 404. On a 100-a-day
free tier that distinction is the difference between a wasted day and none.

## Three things that will bite you

**`errors` changes type with the outcome.** Success returns an empty *array*
(`"errors": []`); failure returns an *object* (`"errors": {"token": "…"}`). A
decoder written against either one fails on half the responses. Verified live
2026-09-05 against both `v1.basketball` and `v3.football`.

**A rejected key arrives as HTTP 200.** The refusal is in the body. Checking the
status code alone reports success on a missing key, and a caller that treats an
empty `response` as "no results" will report "no games today" when what actually
happened is that the key is wrong. This library throws `.unauthorized`.

**The free tier is 100 requests a day.** Pass `onRateLimit:` and you are told
what is left after every call:

```swift
let sports = APISports(key: myKey) { allowance in
    print("\(allowance.dailyRemaining ?? 0) requests left today")
}
```

## The key

Required — the service takes no anonymous requests. It travels in the
`x-apisports-key` header and never in a query string, so it stays out of proxy
logs, shell history and error messages.

Free key: [dashboard.api-football.com](https://dashboard.api-football.com/register)
(one registration covers all eleven sports).

## Built to be tested without a network

The transport is injectable, so nothing here needs a key or a socket to test:

```swift
let sports = APISports(key: "k", transport: { request in
    (recordedBody, HTTPURLResponse(url: request.url!, statusCode: 200,
                                   httpVersion: nil, headerFields: [:])!)
})
```

30 tests, all offline. They pin each of the four shapes, both spellings of
`errors`, all three standings nestings, and that a key never reaches a URL.

## Scope, honestly

The response shapes are modelled from API-Sports' documented shapes and from a
live probe of the shared envelope. **The per-endpoint field mappings have not
yet been validated against keyed responses** — that happens when a key lands,
and any correction will be a patch release. The envelope, the hosts, the error
behaviour and the normaliser are pinned by tests today.

## Requirements

macOS 14+ / iOS 16+ · Swift 6

## Installation

```swift
.package(url: "https://github.com/arraypress/swift-api-sports.git", from: "0.1.0")
```

## Licence

MIT
