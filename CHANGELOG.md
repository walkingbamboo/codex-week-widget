# Changelog

All notable changes to Codex Week are documented here.

## [2.3] - 2026-09-07

### Added

- Reset-cycle forecasting for runtime, tasks, and token usage.
- Previous-cycle comparisons with dynamically positioned `FORECAST` and `LAST`
  markers.
- A weekly closure-status bar for completed, stopped, and in-progress tasks.
- An end-of-day quota marker alongside the current theoretical quota marker.
- A combined token chart with daily bars, a three-day moving average, and a
  projected trend for the remainder of the reset cycle.

### Changed

- Quota pacing now starts from the actual reset-cycle boundary, including when
  a reset is used early instead of waiting for the scheduled reset.
- Runtime, task, and token scales now adapt to the largest of current,
  forecast, or previous-cycle values.
- Token bars now follow reset-cycle days (`D1` through `D7`) instead of calendar
  weekdays.
- Chart labels and colors now match their corresponding fills and markers to
  make current, forecast, and previous values easier to distinguish.
- Reset information is positioned below the quota ring for a more balanced
  Extra Large layout.

### Fixed

- The theoretical quota line now uses the live quota window duration instead
  of assuming a fixed seven-day cycle.
- Automatic refresh can locate `rg` when launched by macOS with a restricted
  `PATH`, and falls back to system `grep` when needed.
- Log collection now prefilters relevant events, substantially reducing refresh
  time on large local Codex histories.
- The 30-minute background refresh job now completes successfully outside an
  interactive shell.
- Installation and repair commands now use an explicit shell invocation so
  they also work from archives that do not preserve executable permissions.

### Privacy

- All processing remains local. No API key, PAT, or external service is
  required.
