import SwiftUI
import WidgetKit

struct CodexWeekEntry: TimelineEntry {
    let date: Date
    let snapshot: CodexWeekSnapshot
}

struct CodexWeekProvider: TimelineProvider {
    func placeholder(in context: Context) -> CodexWeekEntry {
        CodexWeekEntry(date: .now, snapshot: .preview)
    }

    func getSnapshot(in context: Context, completion: @escaping (CodexWeekEntry) -> Void) {
        completion(CodexWeekEntry(date: .now, snapshot: .load()))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<CodexWeekEntry>) -> Void) {
        let entry = CodexWeekEntry(date: .now, snapshot: .load())
        completion(Timeline(entries: [entry], policy: .after(.now.addingTimeInterval(30 * 60))))
    }
}

struct CodexWeekView: View {
    let entry: CodexWeekEntry

    @Environment(\.widgetFamily) private var family

    private let weekdayLabels = ["M", "T", "W", "T", "F", "S", "S"]
    private let primaryText = Color.white.opacity(0.96)
    private let secondaryText = Color.white.opacity(0.64)
    private let tertiaryText = Color.white.opacity(0.42)

    private func runtimeText(_ seconds: Int) -> String {
        let hours = seconds / 3600
        let minutes = (seconds % 3600) / 60
        return "\(hours)h \(minutes)m"
    }

    private var weekRuntimeText: String { runtimeText(entry.snapshot.runtimeSeconds) }
    private var todayRuntimeText: String { runtimeText(entry.snapshot.todayRuntimeSeconds ?? 0) }

    private var currentDayIndex: Int {
        let weekday = Calendar.current.component(.weekday, from: entry.date)
        return (weekday + 5) % 7
    }

    private var theoreticalTodayShare: Double {
        var calendar = Calendar(identifier: .iso8601)
        calendar.timeZone = .current
        let dayStart = calendar.startOfDay(for: entry.date)
        guard let weekStart = calendar.dateInterval(of: .weekOfYear, for: entry.date)?.start else {
            return 0
        }
        let elapsedToday = max(entry.date.timeIntervalSince(dayStart), 0)
        let elapsedWeek = max(entry.date.timeIntervalSince(weekStart), 1)
        return max(0, min(elapsedToday / elapsedWeek, 1))
    }

    private func tokenText(_ value: Int64) -> String {
        if value >= 1_000_000 {
            return String(format: "%.1fM", Double(value) / 1_000_000)
        }
        if value >= 1_000 {
            return String(format: "%.1fK", Double(value) / 1_000)
        }
        return "\(value)"
    }

    var body: some View {
        Group {
            if family == .systemSmall {
                compactBody
            } else if family == .systemExtraLarge {
                extraLargeBody
            } else {
                largeBody
            }
        }
        .foregroundStyle(primaryText)
        .containerBackground(for: .widget) {
            LinearGradient(
                colors: [Color(red: 0.075, green: 0.10, blue: 0.17),
                         Color(red: 0.14, green: 0.15, blue: 0.25)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
    }

    private var largeBody: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Label("CODEX THIS WEEK", systemImage: "sparkles")
                    .font(.system(size: 14, weight: .semibold))
                Spacer()
                Text(entry.snapshot.generatedAt, style: .time)
                    .font(.caption2)
                    .foregroundStyle(tertiaryText)
            }

            HStack(spacing: 22) {
                VStack(spacing: 6) {
                    quotaRing
                        .frame(width: 112, height: 112)
                }

                VStack(alignment: .leading, spacing: 13) {
                    HStack(spacing: 22) {
                        metric(value: weekRuntimeText, label: "Runtime")
                        metric(value: "\(entry.snapshot.completedTasks)", label: "Tasks run")
                    }
                    HStack(spacing: 4) {
                        Image(systemName: "arrow.clockwise")
                        Text("Quota resets")
                        Spacer()
                        Text(entry.snapshot.resetAt, format: .dateTime.month().day().hour().minute())
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)
                    }
                    .font(.caption2)
                    .foregroundStyle(secondaryText)
                }
            }

            Divider().opacity(0.25)

            HStack(alignment: .firstTextBaseline) {
                Text("TOKEN USAGE")
                    .font(.system(size: 12, weight: .semibold))
                Spacer()
                Text("Today \(tokenText(entry.snapshot.todayTokens))")
                    .font(.caption.weight(.semibold))
                Text("Week \(tokenText(entry.snapshot.weekTokens))")
                    .font(.caption)
                    .foregroundStyle(secondaryText)
            }

            tokenChart
                .frame(maxWidth: .infinity, minHeight: 94)
        }
    }

    private var extraLargeBody: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label("CODEX THIS WEEK", systemImage: "sparkles")
                    .font(.system(size: 15, weight: .semibold))
                Spacer()
                Text("Updated ") + Text(entry.snapshot.generatedAt, style: .time)
            }
            .font(.caption)
            .foregroundStyle(secondaryText)

            HStack(alignment: .top, spacing: 24) {
                VStack(spacing: 8) {
                    quotaRing
                        .frame(width: 186, height: 186)
                }
                .frame(width: 190)
                .padding(.top, 12)

                VStack(alignment: .leading, spacing: 19) {
                    Text("ACTIVITY")
                        .font(.system(size: 12, weight: .semibold))
                    activityComparison(
                        title: "RUNTIME",
                        today: todayRuntimeText,
                        week: weekRuntimeText,
                        progress: Double(entry.snapshot.todayRuntimeSeconds ?? 0) / Double(max(entry.snapshot.runtimeSeconds, 1)),
                        targetProgress: theoreticalTodayShare,
                        color: Color(red: 0.42, green: 0.92, blue: 0.82)
                    )
                    activityComparison(
                        title: "TASKS RUN",
                        today: "\(entry.snapshot.todayCompletedTasks ?? 0)",
                        week: "\(entry.snapshot.completedTasks)",
                        progress: Double(entry.snapshot.todayCompletedTasks ?? 0) / Double(max(entry.snapshot.completedTasks, 1)),
                        targetProgress: theoreticalTodayShare,
                        color: Color(red: 0.48, green: 0.62, blue: 1.0)
                    )
                    VStack(alignment: .leading, spacing: 4) {
                        Label("QUOTA RESETS", systemImage: "arrow.clockwise")
                            .font(.caption2)
                            .foregroundStyle(secondaryText)
                        Text(entry.snapshot.resetAt, format: .dateTime.month(.abbreviated).day().hour().minute())
                            .font(.system(size: 11, weight: .medium, design: .rounded))
                            .foregroundStyle(secondaryText)
                            .lineLimit(1)
                    }
                }
                .frame(width: 190, alignment: .leading)

                Divider().opacity(0.25)

                VStack(alignment: .leading, spacing: 12) {
                    Text("TOKEN USAGE")
                        .font(.system(size: 12, weight: .semibold))
                    HStack(alignment: .firstTextBaseline, spacing: 12) {
                        Text("Today \(tokenText(entry.snapshot.todayTokens))")
                            .font(.caption.weight(.semibold))
                        Text("Week \(tokenText(entry.snapshot.weekTokens))")
                            .font(.caption)
                            .foregroundStyle(secondaryText)
                        Spacer(minLength: 0)
                    }
                    tokenChart
                        .frame(maxWidth: .infinity, minHeight: 216)
                }
                .frame(maxWidth: .infinity)
            }
            .frame(maxHeight: .infinity, alignment: .top)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private var compactBody: some View {
        VStack(spacing: 8) {
            quotaRing
                .frame(width: 92, height: 92)
            HStack(spacing: 8) {
                VStack(alignment: .leading, spacing: 1) {
                    Text("TODAY")
                        .font(.system(size: 9))
                        .foregroundStyle(secondaryText)
                    Text(tokenText(entry.snapshot.todayTokens))
                        .font(.caption.weight(.semibold))
                }
                Spacer(minLength: 0)
                VStack(alignment: .trailing, spacing: 1) {
                    Text("WEEK")
                        .font(.system(size: 9))
                        .foregroundStyle(secondaryText)
                    Text(tokenText(entry.snapshot.weekTokens))
                        .font(.caption.weight(.semibold))
                }
            }
        }
    }

    private var quotaRing: some View {
        ZStack {
            Circle()
                .stroke(.white.opacity(0.10), lineWidth: 10)
            Circle()
                .trim(from: 0, to: Double(entry.snapshot.remainingPercent) / 100)
                .stroke(
                    AngularGradient(
                        colors: [Color(red: 0.42, green: 0.92, blue: 0.82),
                                 Color(red: 0.48, green: 0.62, blue: 1.0)],
                        center: .center
                    ),
                    style: StrokeStyle(lineWidth: 10, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
            RingMarker(percent: Double(entry.snapshot.theoreticalRemainingPercent) / 100)
                .stroke(.white, style: StrokeStyle(lineWidth: 2.5, lineCap: .round))
                .shadow(color: .black.opacity(0.55), radius: 1)
            VStack(spacing: 0) {
                Text("\(entry.snapshot.remainingPercent)%")
                    .font(.system(size: 29, weight: .semibold, design: .rounded))
                Text("LEFT")
                    .font(.caption2.weight(.medium))
                    .foregroundStyle(secondaryText)
                Text("TARGET \(entry.snapshot.theoreticalRemainingPercent)%")
                    .font(.system(size: 7, weight: .semibold, design: .rounded))
                    .tracking(0.3)
                    .foregroundStyle(secondaryText)
                    .padding(.top, 5)
            }
        }
    }

    private var tokenChart: some View {
        let maximum = max(entry.snapshot.dailyTokens.max() ?? 1, 1)
        let maximumBarHeight: CGFloat = family == .systemExtraLarge ? 138 : 61
        return HStack(alignment: .bottom, spacing: 10) {
            ForEach(Array(entry.snapshot.dailyTokens.prefix(7).enumerated()), id: \.offset) { index, value in
                VStack(spacing: 4) {
                    if value > 0 {
                        Text(tokenText(value))
                            .font(.system(size: 8, weight: .medium, design: .rounded))
                            .foregroundStyle(index == currentDayIndex ? primaryText : secondaryText)
                            .lineLimit(1)
                            .minimumScaleFactor(0.65)
                            .allowsTightening(true)
                            .fixedSize(horizontal: true, vertical: false)
                    }
                    RoundedRectangle(cornerRadius: 4)
                        .fill(index == currentDayIndex
                              ? Color(red: 0.42, green: 0.92, blue: 0.82)
                              : Color.white.opacity(value == 0 ? 0.06 : 0.18))
                        .frame(height: max(7, maximumBarHeight * CGFloat(value) / CGFloat(maximum)))
                    Text(weekdayLabels[index])
                        .font(.system(size: 9, weight: index == currentDayIndex ? .semibold : .regular))
                        .foregroundStyle(index == currentDayIndex ? primaryText : secondaryText)
                }
                .frame(maxWidth: .infinity)
            }
        }
    }

    private func metric(value: String, label: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(value)
                .font(.system(size: 18, weight: .semibold, design: .rounded))
                .lineLimit(1)
                .minimumScaleFactor(0.8)
            Text(label)
                .font(.caption2)
                .foregroundStyle(secondaryText)
        }
    }

    private func activityComparison(
        title: String,
        today: String,
        week: String,
        progress: Double,
        targetProgress: Double,
        color: Color
    ) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(title)
                .font(.caption2)
                .foregroundStyle(secondaryText)
            HStack(alignment: .firstTextBaseline) {
                Text("Today \(today)")
                    .font(.caption.weight(.semibold))
                Spacer()
                Text("Week \(week)")
                    .font(.caption2)
                    .foregroundStyle(secondaryText)
            }
            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color.white.opacity(0.10))
                    Capsule()
                        .fill(color)
                        .frame(width: proxy.size.width * max(0, min(progress, 1)))
                    Rectangle()
                        .fill(primaryText.opacity(0.9))
                        .frame(width: 1.5, height: family == .systemExtraLarge ? 17 : 11)
                        .offset(x: max(0, min(proxy.size.width - 1.5, proxy.size.width * targetProgress - 0.75)))
                }
            }
            .frame(height: family == .systemExtraLarge ? 13 : 7)
        }
    }
}

private struct RingMarker: Shape {
    let percent: Double

    func path(in rect: CGRect) -> Path {
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let angle = Angle.degrees(-90 + 360 * percent)
        let innerRadius = min(rect.width, rect.height) * 0.40
        let outerRadius = min(rect.width, rect.height) * 0.52
        let dx = CGFloat(cos(angle.radians))
        let dy = CGFloat(sin(angle.radians))
        var path = Path()
        path.move(to: CGPoint(x: center.x + innerRadius * dx, y: center.y + innerRadius * dy))
        path.addLine(to: CGPoint(x: center.x + outerRadius * dx, y: center.y + outerRadius * dy))
        return path
    }
}

@main
struct CodexWeekWidget: Widget {
    let kind = "CodexWeekWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: CodexWeekProvider()) { entry in
            CodexWeekView(entry: entry)
        }
        .configurationDisplayName("Codex This Week")
        .description("Track weekly quota, runtime, tasks, and token usage.")
        .supportedFamilies([.systemSmall, .systemLarge, .systemExtraLarge])
    }
}

#if canImport(PreviewsMacros)
#Preview(as: .systemLarge) {
    CodexWeekWidget()
} timeline: {
    CodexWeekEntry(date: .now, snapshot: .preview)
}

#Preview("Extra Large", as: .systemExtraLarge) {
    CodexWeekWidget()
} timeline: {
    CodexWeekEntry(date: .now, snapshot: .preview)
}
#endif
