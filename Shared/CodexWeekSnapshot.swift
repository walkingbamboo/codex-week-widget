import Foundation
import Darwin

struct CodexWeekSnapshot: Codable, Hashable {
    let generatedAt: Date
    let remainingPercent: Int
    let theoreticalRemainingPercent: Int
    let endOfDayTheoreticalRemainingPercent: Int?
    let cycleStartAt: Date?
    let resetAt: Date
    let runtimeSeconds: Int
    let previousRuntimeSeconds: Int?
    let forecastRuntimeSeconds: Int?
    let completedTasks: Int
    let previousCompletedTasks: Int?
    let forecastCompletedTasks: Int?
    let todayRuntimeSeconds: Int?
    let todayCompletedTasks: Int?
    let closureCompletedTasks: Int?
    let closureAbandonedTasks: Int?
    let closureInProgressTasks: Int?
    let todayTokens: Int64
    let weekTokens: Int64
    let previousTokens: Int64?
    let forecastTokens: Int64?
    let dailyTokens: [Int64]

    static let preview = CodexWeekSnapshot(
        generatedAt: ISO8601DateFormatter().date(from: "2026-08-12T01:25:00Z")!,
        remainingPercent: 77,
        theoreticalRemainingPercent: 85,
        endOfDayTheoreticalRemainingPercent: 79,
        cycleStartAt: ISO8601DateFormatter().date(from: "2026-08-11T02:08:00Z")!,
        resetAt: ISO8601DateFormatter().date(from: "2026-08-18T02:08:00Z")!,
        runtimeSeconds: 23_879,
        previousRuntimeSeconds: 43_920,
        forecastRuntimeSeconds: 33_600,
        completedTasks: 138,
        previousCompletedTasks: 249,
        forecastCompletedTasks: 214,
        todayRuntimeSeconds: 8_412,
        todayCompletedTasks: 41,
        closureCompletedTasks: 98,
        closureAbandonedTasks: 15,
        closureInProgressTasks: 25,
        todayTokens: 72_718_396,
        weekTokens: 238_406_743,
        previousTokens: 298_900_000,
        forecastTokens: 338_200_000,
        dailyTokens: [96_342_071, 69_346_276, 72_718_396, 0, 0, 0, 0]
    )

    static func load() -> CodexWeekSnapshot {
        let realHomeDirectory: URL = {
            guard let passwordEntry = getpwuid(getuid()) else {
                return FileManager.default.homeDirectoryForCurrentUser
            }
            return URL(fileURLWithPath: String(cString: passwordEntry.pointee.pw_dir), isDirectory: true)
        }()
        let url = realHomeDirectory
            .appendingPathComponent("Library/Application Support/CodexWeek/codex-week-snapshot.json")
        guard let data = try? Data(contentsOf: url) else { return .preview }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return (try? decoder.decode(CodexWeekSnapshot.self, from: data)) ?? .preview
    }
}
