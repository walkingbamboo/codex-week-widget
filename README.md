# Codex Week Widget

A native macOS WidgetKit dashboard for local Codex usage. It shows quota pacing,
runtime, completed tasks, and daily/weekly token activity in Small, Large, and
Extra Large widgets.

**No OpenAI API key is required.** The app reads Codex activity logs already
stored on your Mac and never uploads conversation content or usage data.

## Screenshots

![Codex Week extra-large widget](screenshots/codex-week-extra-large.png)

<p align="center">
  <img src="screenshots/codex-week-quota-activity.png" alt="Quota and activity detail" width="62%">
  <img src="screenshots/codex-week-token-usage.png" alt="Token usage detail" width="31%">
</p>

## What it shows

- Remaining weekly Codex quota and reset time
- A pacing marker based on elapsed time in the quota window
- Runtime and completed-task counts for today and this week
- Token activity for today, this week, and each weekday
- Automatic refresh through a per-user LaunchAgent

## Requirements

- macOS 14 or newer
- Codex desktop app or CLI with local data in `~/.codex`
- Full Xcode installed in `/Applications/Xcode.app`
- An Apple Development team selected in Xcode (a personal team is sufficient
  for local installation)
- [Homebrew](https://brew.sh), XcodeGen, and jq

Install the command-line dependencies:

```bash
brew install xcodegen jq
```

## Install

Clone the repository and run the guided installer:

```bash
git clone https://github.com/walkingbamboo/codex-week-widget.git
cd codex-week-widget
chmod +x scripts/*.sh
./scripts/install.sh
```

The installer asks for:

1. Your 10-character Apple Developer Team ID
2. A unique bundle prefix such as `com.yourname`
3. Your Codex data directory (default: `~/.codex`)
4. Refresh interval (default: 30 minutes)
5. Your IANA timezone (automatically detected by default)

These values stay in local build settings or
`~/Library/Application Support/CodexWeek/config.env`; they are never committed.

The app is installed to `~/Applications/CodexWeek.app`. After installation,
right-click the desktop, choose **Edit Widgets**, search for **Codex Week**, and
pick a size.

## Find your Apple Developer Team ID

Open **Xcode → Settings → Accounts**, select your Apple ID and team, then copy
the Team ID. If necessary, create a simple macOS project once and let Xcode
manage signing for your personal team.

## Privacy and data source

Codex Week processes local rollout JSONL files and `state_5.sqlite` from the
configured Codex data directory. It extracts only timestamps, task completion
durations, token counters, and quota-rate-limit values. It does not send data
over the network and does not require a PAT or API credential.

The generated snapshot is atomically written to:

```text
~/Library/Application Support/CodexWeek/codex-week-snapshot.json
```

The Widget extension has read-only access to that directory. Automatic refresh
is managed by `~/Library/LaunchAgents/io.github.codexweek.refresh.plist`.

## Troubleshooting

### Widget is blank or disappears after changing size

```bash
./scripts/repair_widget.sh
```

If that does not help, remove the widget from the desktop, run the repair
script, and add it again.

### Data does not refresh

Check the background job and snapshot:

```bash
launchctl print gui/$(id -u)/io.github.codexweek.refresh
stat "$HOME/Library/Application Support/CodexWeek/codex-week-snapshot.json"
```

Refresh logs are stored in `~/Library/Logs/CodexWeek/`.

### Build signing fails

Verify the Team ID, use a unique bundle prefix, and confirm Xcode has downloaded
the signing certificate for that team. Re-run `./scripts/install.sh` after
correcting the value.

## Uninstall

```bash
./scripts/uninstall.sh
```

The app, LaunchAgent, and configuration are moved to Trash so they remain
recoverable.

## Project structure

- `App/` — macOS host app and manual refresh UI
- `Widget/` — WidgetKit views for all supported sizes
- `Shared/` — snapshot model and local file loading
- `scripts/collect_codex_week.sh` — local Codex log aggregation
- `scripts/install.sh` — guided build, signing, install, and background setup
- `project.yml` — XcodeGen project definition

## Notes

Codex log schemas are internal implementation details and may change in future
Codex releases. If metrics stop updating after a Codex update, open an issue
with the non-sensitive error output from `~/Library/Logs/CodexWeek/`.

## License

[MIT](LICENSE)
