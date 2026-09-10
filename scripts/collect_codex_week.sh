#!/bin/zsh
set -euo pipefail

config_path="${CODEX_WEEK_CONFIG:-$HOME/Library/Application Support/CodexWeek/config.env}"
if [[ -r "$config_path" ]]; then
  source "$config_path"
fi

codex_root="${CODEX_ROOT:-$HOME/.codex}"
snapshot_dir="$HOME/Library/Application Support/CodexWeek"
output_path="${1:-$snapshot_dir/codex-week-snapshot.json}"
timezone_name="${CODEX_WEEK_TIMEZONE:-}"
if [[ -z "$timezone_name" ]]; then
  timezone_link="$(readlink /etc/localtime 2>/dev/null || true)"
  timezone_name="${timezone_link#*/zoneinfo/}"
  [[ "$timezone_name" == "$timezone_link" || -z "$timezone_name" ]] && timezone_name="UTC"
fi
export TZ="$timezone_name"

mkdir -p "${output_path:h}"

now_epoch="$(date '+%s')"
scan_start="$((now_epoch - 35 * 24 * 60 * 60))"
rollout_files=("${(@f)$(sqlite3 "$codex_root/state_5.sqlite" \
  "select rollout_path from threads where updated_at >= $scan_start order by updated_at desc;")}")
rollout_files=("${(@)rollout_files:#}")

event_filter=()
for rg_path in \
  /opt/homebrew/bin/rg \
  /usr/local/bin/rg \
  /Applications/ChatGPT.app/Contents/Resources/rg \
  /Applications/Codex.app/Contents/Resources/rg; do
  if [[ -x "$rg_path" ]]; then
    event_filter=("$rg_path" --no-filename)
    break
  fi
done
(( ${#event_filter[@]} > 0 )) || event_filter=(/usr/bin/grep -hE)

events="$("${event_filter[@]}" '"type":"(task_started|task_complete|turn_aborted|token_count)"' "${rollout_files[@]}" 2>/dev/null | jq -c '
  select(type=="object" and .type=="event_msg")
  | ((.timestamp[0:19]+"Z")|fromdateiso8601) as $eventTimestamp
  | if .payload.type=="task_started" then
      {kind:"taskStarted",timestamp:(.payload.started_at // $eventTimestamp),turnId:(.payload.turn_id // "")}
    elif .payload.type=="task_complete" then
      {kind:"taskCompleted",timestamp:(.payload.completed_at // $eventTimestamp),turnId:(.payload.turn_id // ""),durationMs:(.payload.duration_ms // 0)}
    elif .payload.type=="turn_aborted" then
      {kind:"taskAbandoned",timestamp:(.payload.completed_at // $eventTimestamp),turnId:(.payload.turn_id // ""),durationMs:(.payload.duration_ms // 0)}
    elif .payload.type=="token_count" then
      {kind:"token",timestamp:$eventTimestamp,tokens:(.payload.info.last_token_usage.total_tokens // 0),limits:.payload.rate_limits}
    else empty end' 2>/dev/null | jq -s '.')"

latest_limits="$(jq -c '[.[] | select(.limits != null)] | max_by(.timestamp).limits // {}' <<<"$events")"
primary_used="$(jq -r '.primary.used_percent // 0' <<<"$latest_limits")"
reset_epoch="$(jq -r '.primary.resets_at // 0' <<<"$latest_limits")"
window_minutes="$(jq -r '.primary.window_minutes // 10080' <<<"$latest_limits")"
[[ "$window_minutes" == <-> && "$window_minutes" -gt 0 ]] || window_minutes=10080

window_seconds="$((window_minutes * 60))"
cycle_start_epoch="$((reset_epoch - window_seconds))"
weekday_number="$(date '+%u')"
week_start_epoch="$(date -v-"$((weekday_number - 1))"d -v0H -v0M -v0S '+%s')"
week_end_epoch="$((week_start_epoch + 7 * 24 * 60 * 60))"
previous_week_start_epoch="$((week_start_epoch - 7 * 24 * 60 * 60))"
elapsed_week_seconds="$((now_epoch - week_start_epoch))"
(( elapsed_week_seconds < 1 )) && elapsed_week_seconds=1
(( elapsed_week_seconds > 7 * 24 * 60 * 60 )) && elapsed_week_seconds="$((7 * 24 * 60 * 60))"
today_start_epoch="$(date -v0H -v0M -v0S '+%s')"
day_end_epoch="$(date -v+1d -v0H -v0M -v0S '+%s')"

summary="$(jq -c \
  --argjson currentStart "$week_start_epoch" \
  --argjson currentEnd "$week_end_epoch" \
  --argjson previousStart "$previous_week_start_epoch" \
  --argjson previousEnd "$week_start_epoch" \
  --argjson todayStart "$today_start_epoch" '
  . as $events
  | ([$events[] | select(.kind=="taskStarted" or .kind=="taskCompleted" or .kind=="taskAbandoned")]
      | sort_by(.turnId)
      | group_by(.turnId)
      | map({
          turnId: .[0].turnId,
          startedAt: ([.[] | select(.kind=="taskStarted") | .timestamp] | min // null),
          durationMs: ([.[] | select(.kind=="taskCompleted" or .kind=="taskAbandoned") | .durationMs] | add // 0),
          status: (if any(.[]; .kind=="taskCompleted") then "completed"
                   elif any(.[]; .kind=="taskAbandoned") then "abandoned"
                   else "inProgress" end)
        })
      | map(select(.startedAt != null))) as $turns
  | ($turns | map(select(.startedAt >= $currentStart and .startedAt < $currentEnd))) as $currentTurns
  | ($turns | map(select(.startedAt >= $previousStart and .startedAt < $previousEnd))) as $previousTurns
  | ([$events[] | select(.kind=="token" and .timestamp >= $currentStart and .timestamp < $currentEnd)]) as $currentTokens
  | ([$events[] | select(.kind=="token" and .timestamp >= $previousStart and .timestamp < $previousEnd)]) as $previousTokens
  | {
      runtimeSeconds:(($currentTurns | map(.durationMs) | add // 0) / 1000 | floor),
      previousRuntimeSeconds:(($previousTurns | map(.durationMs) | add // 0) / 1000 | floor),
      completedTasks:($currentTurns | length),
      previousCompletedTasks:($previousTurns | length),
      todayRuntimeSeconds:(($currentTurns | map(select(.startedAt >= $todayStart) | .durationMs) | add // 0) / 1000 | floor),
      todayCompletedTasks:($currentTurns | map(select(.startedAt >= $todayStart)) | length),
      closureCompletedTasks:($currentTurns | map(select(.status=="completed")) | length),
      closureAbandonedTasks:($currentTurns | map(select(.status=="abandoned")) | length),
      closureInProgressTasks:($currentTurns | map(select(.status=="inProgress")) | length),
      weekTokens:($currentTokens | map(.tokens) | add // 0),
      previousTokens:($previousTokens | map(.tokens) | add // 0),
      todayTokens:($currentTokens | map(select(.timestamp >= $todayStart) | .tokens) | add // 0),
      dailyTokens:([range(0;7) as $day
        | ($currentStart + ($day * 86400)) as $start
        | ($start + 86400) as $end
        | ($currentTokens | map(select(.timestamp >= $start and .timestamp < $end) | .tokens) | add // 0)])
    }' <<<"$events")"

forecast_values="$(jq -n \
  --argjson elapsed "$elapsed_week_seconds" \
  --argjson window "$((7 * 24 * 60 * 60))" \
  --argjson runtime "$(jq '.runtimeSeconds' <<<"$summary")" \
  --argjson tasks "$(jq '.completedTasks' <<<"$summary")" \
  --argjson tokens "$(jq '.weekTokens' <<<"$summary")" \
  '{runtime:($runtime*$window/$elapsed|floor),tasks:($tasks*$window/$elapsed|floor),tokens:($tokens*$window/$elapsed|floor)}')"

generated_at="$(date -u '+%Y-%m-%dT%H:%M:%SZ')"
reset_at="$(date -u -r "$reset_epoch" '+%Y-%m-%dT%H:%M:%SZ')"
cycle_start_at="$(date -u -r "$cycle_start_epoch" '+%Y-%m-%dT%H:%M:%SZ')"
activity_week_start_at="$(date -u -r "$week_start_epoch" '+%Y-%m-%dT%H:%M:%SZ')"
theoretical_remaining="$(( (reset_epoch - now_epoch) * 100 / window_seconds ))"
(( theoretical_remaining < 0 )) && theoretical_remaining=0
(( theoretical_remaining > 100 )) && theoretical_remaining=100
end_of_day_theoretical_remaining="$(( (reset_epoch - day_end_epoch) * 100 / window_seconds ))"
(( end_of_day_theoretical_remaining < 0 )) && end_of_day_theoretical_remaining=0
(( end_of_day_theoretical_remaining > 100 )) && end_of_day_theoretical_remaining=100

temporary_output="${output_path}.tmp.$$"
jq -n \
  --arg generatedAt "$generated_at" \
  --arg cycleStartAt "$cycle_start_at" \
  --arg activityWeekStartAt "$activity_week_start_at" \
  --arg resetAt "$reset_at" \
  --argjson remainingPercent "$((100 - ${primary_used%.*}))" \
  --argjson theoreticalRemainingPercent "$theoretical_remaining" \
  --argjson endOfDayTheoreticalRemainingPercent "$end_of_day_theoretical_remaining" \
  --argjson runtimeSeconds "$(jq '.runtimeSeconds' <<<"$summary")" \
  --argjson previousRuntimeSeconds "$(jq '.previousRuntimeSeconds' <<<"$summary")" \
  --argjson forecastRuntimeSeconds "$(jq '.runtime' <<<"$forecast_values")" \
  --argjson completedTasks "$(jq '.completedTasks' <<<"$summary")" \
  --argjson previousCompletedTasks "$(jq '.previousCompletedTasks' <<<"$summary")" \
  --argjson forecastCompletedTasks "$(jq '.tasks' <<<"$forecast_values")" \
  --argjson todayRuntimeSeconds "$(jq '.todayRuntimeSeconds' <<<"$summary")" \
  --argjson todayCompletedTasks "$(jq '.todayCompletedTasks' <<<"$summary")" \
  --argjson closureCompletedTasks "$(jq '.closureCompletedTasks' <<<"$summary")" \
  --argjson closureAbandonedTasks "$(jq '.closureAbandonedTasks' <<<"$summary")" \
  --argjson closureInProgressTasks "$(jq '.closureInProgressTasks' <<<"$summary")" \
  --argjson todayTokens "$(jq '.todayTokens' <<<"$summary")" \
  --argjson weekTokens "$(jq '.weekTokens' <<<"$summary")" \
  --argjson previousTokens "$(jq '.previousTokens' <<<"$summary")" \
  --argjson forecastTokens "$(jq '.tokens' <<<"$forecast_values")" \
  --argjson dailyTokens "$(jq '.dailyTokens' <<<"$summary")" \
  '{generatedAt:$generatedAt,cycleStartAt:$cycleStartAt,activityWeekStartAt:$activityWeekStartAt,remainingPercent:$remainingPercent,theoreticalRemainingPercent:$theoreticalRemainingPercent,endOfDayTheoreticalRemainingPercent:$endOfDayTheoreticalRemainingPercent,resetAt:$resetAt,runtimeSeconds:$runtimeSeconds,previousRuntimeSeconds:$previousRuntimeSeconds,forecastRuntimeSeconds:$forecastRuntimeSeconds,completedTasks:$completedTasks,previousCompletedTasks:$previousCompletedTasks,forecastCompletedTasks:$forecastCompletedTasks,todayRuntimeSeconds:$todayRuntimeSeconds,todayCompletedTasks:$todayCompletedTasks,closureCompletedTasks:$closureCompletedTasks,closureAbandonedTasks:$closureAbandonedTasks,closureInProgressTasks:$closureInProgressTasks,todayTokens:$todayTokens,weekTokens:$weekTokens,previousTokens:$previousTokens,forecastTokens:$forecastTokens,dailyTokens:$dailyTokens}' \
  > "$temporary_output"
mv -f "$temporary_output" "$output_path"

echo "$output_path"
