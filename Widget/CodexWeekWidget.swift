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
    private let endOfDayTarget = Color(red: 1.0, green: 0.72, blue: 0.30)
    private let runtimeColor = Color(red: 0.42, green: 0.92, blue: 0.82)
    private let taskColor = Color(red: 0.48, green: 0.62, blue: 1.0)

    private var endOfDayTheoreticalRemainingPercent: Int {
        entry.snapshot.endOfDayTheoreticalRemainingPercent
            ?? entry.snapshot.theoreticalRemainingPercent
    }

    private func runtimeText(_ seconds: Int) -> String {
        let hours = seconds / 3600
        let minutes = (seconds % 3600) / 60
        return "\(hours)h \(minutes)m"
    }

    private var weekRuntimeText: String { runtimeText(entry.snapshot.runtimeSeconds) }
    private var todayRuntimeText: String { runtimeText(entry.snapshot.todayRuntimeSeconds ?? 0) }

    private var currentDayIndex: Int {
        guard let weekStart = entry.snapshot.activityWeekStartAt else {
            let weekday = Calendar.current.component(.weekday, from: entry.date)
            return (weekday + 5) % 7
        }
        return max(0, min(6, Int(entry.date.timeIntervalSince(weekStart) / 86_400)))
    }

    private var weekRangeText: String {
        guard let weekStart = entry.snapshot.activityWeekStartAt else { return "MONDAY — SUNDAY" }
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = .current
        formatter.dateFormat = "MMM d"
        let weekEnd = Calendar.current.date(byAdding: .day, value: 6, to: weekStart) ?? weekStart
        return "\(formatter.string(from: weekStart)) — \(formatter.string(from: weekEnd))"
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
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Label("CODEX THIS WEEK", systemImage: "sparkles")
                    .font(.system(size: 15, weight: .semibold))
                Spacer()
                Text("Updated ") + Text(entry.snapshot.generatedAt, style: .time)
            }
            .font(.caption)
            .foregroundStyle(secondaryText)

            HStack(alignment: .top, spacing: 18) {
                VStack(spacing: 5) {
                    quotaRing
                        .frame(width: 176, height: 176)
                    Text("EOD = END OF DAY")
                        .font(.system(size: 7, weight: .medium))
                        .foregroundStyle(tertiaryText)
                    Label("QUOTA RESETS", systemImage: "arrow.clockwise")
                        .font(.system(size: 8, weight: .semibold))
                        .foregroundStyle(tertiaryText)
                        .padding(.top, 8)
                    Text(entry.snapshot.resetAt, format: .dateTime.month(.abbreviated).day().hour().minute())
                        .font(.system(size: 9, weight: .medium, design: .rounded))
                        .foregroundStyle(secondaryText)
                        .lineLimit(1)
                }
                .frame(width: 180)
                .padding(.top, 8)

                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("ACTIVITY")
                            .font(.system(size: 12, weight: .semibold))
                        Spacer()
                        Text("THIS WEEK")
                            .font(.system(size: 7, weight: .semibold))
                            .foregroundStyle(secondaryText)
                            .padding(.horizontal, 7)
                            .padding(.vertical, 3)
                            .background(Color.white.opacity(0.08), in: Capsule())
                    }
                    Text(weekRangeText.uppercased())
                        .font(.system(size: 7, weight: .medium))
                        .foregroundStyle(tertiaryText)
                        .lineLimit(1)

                    cycleComparison(
                        title: "RUNTIME",
                        nowText: runtimeText(entry.snapshot.runtimeSeconds),
                        forecastText: runtimeText(entry.snapshot.forecastRuntimeSeconds ?? entry.snapshot.runtimeSeconds),
                        lastText: runtimeText(entry.snapshot.previousRuntimeSeconds ?? entry.snapshot.runtimeSeconds),
                        now: Double(entry.snapshot.runtimeSeconds),
                        forecast: Double(entry.snapshot.forecastRuntimeSeconds ?? entry.snapshot.runtimeSeconds),
                        last: Double(entry.snapshot.previousRuntimeSeconds ?? entry.snapshot.runtimeSeconds),
                        color: runtimeColor
                    )
                    cycleComparison(
                        title: "TASKS RUN",
                        nowText: "\(entry.snapshot.completedTasks)",
                        forecastText: "\(entry.snapshot.forecastCompletedTasks ?? entry.snapshot.completedTasks)",
                        lastText: "\(entry.snapshot.previousCompletedTasks ?? entry.snapshot.completedTasks)",
                        now: Double(entry.snapshot.completedTasks),
                        forecast: Double(entry.snapshot.forecastCompletedTasks ?? entry.snapshot.completedTasks),
                        last: Double(entry.snapshot.previousCompletedTasks ?? entry.snapshot.completedTasks),
                        color: taskColor
                    )
                    closureBar
                }
                .frame(width: 224, alignment: .leading)

                Divider().opacity(0.25)

                VStack(alignment: .leading, spacing: 9) {
                    Text("TOKEN USAGE")
                        .font(.system(size: 12, weight: .semibold))
                    cycleComparison(
                        title: "WEEK TOTAL",
                        nowText: tokenText(entry.snapshot.weekTokens),
                        forecastText: tokenText(entry.snapshot.forecastTokens ?? entry.snapshot.weekTokens),
                        lastText: tokenText(entry.snapshot.previousTokens ?? entry.snapshot.weekTokens),
                        now: Double(entry.snapshot.weekTokens),
                        forecast: Double(entry.snapshot.forecastTokens ?? entry.snapshot.weekTokens),
                        last: Double(entry.snapshot.previousTokens ?? entry.snapshot.weekTokens),
                        color: runtimeColor
                    )
                    HStack {
                        Text("DAILY TOKENS")
                        Spacer()
                        HStack(spacing: 3) {
                            Rectangle().fill(primaryText.opacity(0.75)).frame(width: 12, height: 1.5)
                            Rectangle().fill(endOfDayTarget).frame(width: 12, height: 1.5)
                            Text("3-DAY AVG + WEEK EST.")
                        }
                    }
                    .font(.system(size: 7, weight: .semibold))
                    .foregroundStyle(tertiaryText)
                    cycleTokenChart
                        .frame(maxWidth: .infinity, minHeight: 142)
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
            RingMarker(percent: Double(endOfDayTheoreticalRemainingPercent) / 100)
                .stroke(endOfDayTarget, style: StrokeStyle(lineWidth: 2.5, lineCap: .round))
                .shadow(color: .black.opacity(0.45), radius: 1)
            VStack(spacing: 0) {
                Text("\(entry.snapshot.remainingPercent)%")
                    .font(.system(size: 29, weight: .semibold, design: .rounded))
                Text("LEFT")
                    .font(.caption2.weight(.medium))
                    .foregroundStyle(secondaryText)
                HStack(spacing: 4) {
                    Text("NOW \(entry.snapshot.theoreticalRemainingPercent)%")
                        .foregroundStyle(secondaryText)
                    Text("EOD \(endOfDayTheoreticalRemainingPercent)%")
                        .foregroundStyle(endOfDayTarget)
                }
                .font(.system(size: 7, weight: .semibold, design: .rounded))
                .tracking(0.15)
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

    private func cycleComparison(
        title: String,
        nowText: String,
        forecastText: String,
        lastText: String,
        now: Double,
        forecast: Double,
        last: Double,
        color: Color
    ) -> some View {
        let maximum = max(now, forecast, last, 1)
        let nowRatio = max(0, min(now / maximum, 1))
        let forecastRatio = max(0, min(forecast / maximum, 1))
        let lastRatio = max(0, min(last / maximum, 1))

        return VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.system(size: 8, weight: .semibold, design: .rounded))
                .foregroundStyle(secondaryText)

            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color.white.opacity(0.10))
                    Capsule()
                        .fill(color)
                        .frame(width: proxy.size.width * nowRatio)
                    Path { path in
                        let x = proxy.size.width * forecastRatio
                        path.move(to: CGPoint(x: x, y: -3))
                        path.addLine(to: CGPoint(x: x, y: 15))
                    }
                    .stroke(endOfDayTarget, style: StrokeStyle(lineWidth: 1.5, dash: [2.5, 2]))
                    Rectangle()
                        .fill(primaryText.opacity(0.9))
                        .frame(width: 1.5, height: 18)
                        .offset(x: max(0, min(proxy.size.width - 1.5, proxy.size.width * lastRatio - 0.75)))
                }
            }
            .frame(height: 12)

            HStack(alignment: .top, spacing: 4) {
                comparisonValue(
                    label: "SO FAR",
                    value: nowText,
                    color: color,
                    horizontalAlignment: .leading,
                    frameAlignment: .leading
                )
                comparisonValue(
                    label: "WEEK EST.",
                    value: forecastText,
                    color: endOfDayTarget,
                    horizontalAlignment: .center,
                    frameAlignment: .center
                )
                comparisonValue(
                    label: "LAST WEEK",
                    value: lastText,
                    color: primaryText.opacity(0.88),
                    horizontalAlignment: .trailing,
                    frameAlignment: .trailing
                )
            }
        }
    }

    private func comparisonValue(
        label: String,
        value: String,
        color: Color,
        horizontalAlignment: HorizontalAlignment,
        frameAlignment: Alignment
    ) -> some View {
        VStack(alignment: horizontalAlignment, spacing: 1) {
            Text(label)
                .font(.system(size: 6, weight: .medium))
                .foregroundStyle(tertiaryText)
            Text(value)
                .font(.system(size: 7.5, weight: .semibold, design: .rounded))
                .foregroundStyle(color)
                .lineLimit(1)
                .minimumScaleFactor(0.72)
        }
        .frame(maxWidth: .infinity, alignment: frameAlignment)
    }

    private var closureBar: some View {
        let completed = entry.snapshot.closureCompletedTasks ?? entry.snapshot.completedTasks
        let inProgress = entry.snapshot.closureInProgressTasks ?? 0
        let abandoned = entry.snapshot.closureAbandonedTasks ?? 0
        let total = max(completed + inProgress + abandoned, 1)
        let notClosed = inProgress + abandoned
        let closedPercent = Int((Double(completed) / Double(total) * 100).rounded())
        let notClosedPercent = 100 - closedPercent

        return VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text("WEEKLY CLOSURE")
                    .foregroundStyle(secondaryText)
                Spacer()
                Text("\(closedPercent)% CLOSED")
                    .foregroundStyle(primaryText)
            }
            .font(.system(size: 8, weight: .semibold))

            GeometryReader { proxy in
                HStack(spacing: 0) {
                    Rectangle()
                        .fill(runtimeColor)
                        .frame(width: proxy.size.width * CGFloat(completed) / CGFloat(total))
                    Rectangle()
                        .fill(taskColor)
                        .frame(width: proxy.size.width * CGFloat(inProgress) / CGFloat(total))
                    Rectangle()
                        .fill(endOfDayTarget)
                        .frame(width: proxy.size.width * CGFloat(abandoned) / CGFloat(total))
                }
                .clipShape(Capsule())
                .background(Color.white.opacity(0.08), in: Capsule())
            }
            .frame(height: 10)

            HStack(spacing: 7) {
                closureLegend("Done", color: runtimeColor)
                closureLegend("Active", color: taskColor)
                closureLegend("Stopped", color: endOfDayTarget)
                Spacer(minLength: 0)
            }
            HStack {
                Text("\(completed) closed")
                    .foregroundStyle(secondaryText)
                Spacer()
                Text("NOT CLOSED \(notClosedPercent)% · \(notClosed)")
                    .foregroundStyle(endOfDayTarget)
            }
            .font(.system(size: 7, weight: .semibold, design: .rounded))
        }
    }

    private func closureLegend(_ text: String, color: Color) -> some View {
        HStack(spacing: 2) {
            Circle().fill(color).frame(width: 4, height: 4)
            Text(text)
        }
        .font(.system(size: 6.5, weight: .medium))
        .foregroundStyle(secondaryText)
    }

    private var cycleTokenChart: some View {
        let values = Array(entry.snapshot.dailyTokens.prefix(7)).map(Double.init)
            + Array(repeating: 0, count: max(0, 7 - entry.snapshot.dailyTokens.count))
        let visibleValues = Array(values.prefix(7))
        let dayIndex = currentDayIndex
        let movingAverages: [Double] = visibleValues.indices.map { index in
            let start = max(0, index - 2)
            let slice = visibleValues[start...index]
            return slice.reduce(0, +) / Double(slice.count)
        }
        let forecastAverage = Double(entry.snapshot.forecastTokens ?? entry.snapshot.weekTokens) / 7.0
        let lastActualAverage = movingAverages[dayIndex]
        let projected: [Double] = visibleValues.indices.map { index in
            guard index > dayIndex else { return movingAverages[index] }
            let remaining = max(6 - dayIndex, 1)
            let progress = Double(index - dayIndex) / Double(remaining)
            return lastActualAverage + (forecastAverage - lastActualAverage) * progress
        }
        let maximum = max(visibleValues.max() ?? 0, projected.max() ?? 0, 1)

        return Canvas { context, size in
            let labelHeight: CGFloat = 17
            let topPadding: CGFloat = 11
            let plotHeight = max(size.height - labelHeight - topPadding, 1)
            let slotWidth = size.width / 7
            let barWidth = min(22, slotWidth * 0.54)

            func point(index: Int, value: Double) -> CGPoint {
                CGPoint(
                    x: slotWidth * (CGFloat(index) + 0.5),
                    y: topPadding + plotHeight * (1 - CGFloat(value / maximum))
                )
            }

            for index in 0..<7 {
                let value = visibleValues[index]
                let barHeight = value > 0 ? max(5, plotHeight * CGFloat(value / maximum)) : 5
                let barRect = CGRect(
                    x: slotWidth * (CGFloat(index) + 0.5) - barWidth / 2,
                    y: topPadding + plotHeight - barHeight,
                    width: barWidth,
                    height: barHeight
                )
                let barColor = index == dayIndex
                    ? runtimeColor
                    : Color.white.opacity(value > 0 ? 0.22 : 0.07)
                context.fill(Path(roundedRect: barRect, cornerRadius: 4), with: .color(barColor))

                if value > 0 {
                    context.draw(
                        Text(tokenText(Int64(value)))
                            .font(.system(size: 7, weight: .semibold))
                            .foregroundColor(index == dayIndex ? primaryText : secondaryText),
                        at: CGPoint(x: barRect.midX, y: max(4, barRect.minY - 5)),
                        anchor: .bottom
                    )
                }
                context.draw(
                    Text(weekdayLabels[index])
                        .font(.system(size: 7, weight: index == dayIndex ? .semibold : .regular))
                        .foregroundColor(index == dayIndex ? primaryText : secondaryText),
                    at: CGPoint(x: barRect.midX, y: size.height - 1),
                    anchor: .bottom
                )
            }

            var actualPath = Path()
            for index in 0...dayIndex {
                let currentPoint = point(index: index, value: movingAverages[index])
                if index == 0 {
                    actualPath.move(to: currentPoint)
                } else {
                    actualPath.addLine(to: currentPoint)
                }
            }
            context.stroke(actualPath, with: .color(primaryText.opacity(0.78)), style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round))

            for index in 0...dayIndex {
                let dot = point(index: index, value: movingAverages[index])
                context.fill(Path(ellipseIn: CGRect(x: dot.x - 2.3, y: dot.y - 2.3, width: 4.6, height: 4.6)), with: .color(primaryText.opacity(0.85)))
            }

            if dayIndex < 6 {
                var forecastPath = Path()
                forecastPath.move(to: point(index: dayIndex, value: movingAverages[dayIndex]))
                for index in (dayIndex + 1)..<7 {
                    forecastPath.addLine(to: point(index: index, value: projected[index]))
                }
                context.stroke(forecastPath, with: .color(endOfDayTarget), style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round, dash: [4, 3]))
            }
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
