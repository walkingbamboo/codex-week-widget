import SwiftUI
import WidgetKit

@main
struct CodexWeekApp: App {
    var body: some Scene {
        WindowGroup {
            DashboardView()
                .frame(minWidth: 620, minHeight: 520)
        }
        .windowResizability(.contentSize)
    }
}

struct DashboardView: View {
    @State private var snapshot = CodexWeekSnapshot.load()

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Codex Week")
                .font(.largeTitle.bold())
            Text("Your local Codex activity stays on this Mac. No API key or cloud upload is used.")
                .foregroundStyle(.secondary)

            HStack(spacing: 14) {
                card("Quota left", "\(snapshot.remainingPercent)%")
                card("Pacing target", "\(snapshot.theoreticalRemainingPercent)%")
                card("Tasks this week", "\(snapshot.completedTasks)")
            }

            HStack(spacing: 14) {
                card("Tokens today", tokenText(snapshot.todayTokens))
                card("Tokens this week", tokenText(snapshot.weekTokens))
            }

            Divider()
            Text("Add the widget")
                .font(.headline)
            Text("Right-click the desktop → Edit Widgets → search for “Codex Week” → choose a size.")

            HStack {
                Button("Refresh now") {
                    refresh()
                }
                Spacer()
                Text("Updated \(snapshot.generatedAt.formatted(date: .omitted, time: .shortened))")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(28)
    }

    private func refresh() {
        guard let script = Bundle.main.url(forResource: "collect_codex_week", withExtension: "sh") else {
            snapshot = CodexWeekSnapshot.load()
            return
        }
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/zsh")
        process.arguments = [script.path]
        try? process.run()
        process.waitUntilExit()
        snapshot = CodexWeekSnapshot.load()
        WidgetCenter.shared.reloadAllTimelines()
    }

    private func card(_ label: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(value)
                .font(.title2.bold())
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(.quaternary.opacity(0.55), in: RoundedRectangle(cornerRadius: 14))
    }

    private func tokenText(_ value: Int64) -> String {
        value >= 1_000_000
            ? String(format: "%.1fM", Double(value) / 1_000_000)
            : String(value)
    }
}
