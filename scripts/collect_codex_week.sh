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

week_start="$({ TZ="$timezone_name" date -v-monday -v0H -v0M -v0S '+%s'; } 2>/dev/null)"
rollout_files=("${(@f)$(sqlite3 "$codex_root/state_5.sqlite" \
  "select rollout_path from threads where updated_at >= $((week_start - 86400)) order by updated_at desc;")}")
rollout_files=("${(@)rollout_files:#}")

summary="$(jq -c --argjson start "$week_start" '
  select(type=="object" and .type=="event_msg")
  | if .payload.type=="task_complete" and (.payload.completed_at // 0) >= $start then
      ((.timestamp[0:19]+"Z")|fromdateiso8601) as $ts
      | {kind:"task",day:($ts|localtime|strftime("%Y-%m-%d")),duration_ms:(.payload.duration_ms // 0)}
    elif .payload.type=="token_count" then
      ((.timestamp[0:19]+"Z")|fromdateiso8601) as $ts
      | if $ts >= $start then
          {kind:"token",timestamp:.timestamp,day:($ts|localtime|strftime("%Y-%m-%d")),tokens:(.payload.info.last_token_usage.total_tokens // 0),limits:.payload.rate_limits}
        elif .payload.rate_limits != null then
          {kind:"limit",timestamp:.timestamp,limits:.payload.rate_limits}
        else empty end
    else empty end' "${rollout_files[@]}" 2>/dev/null | jq -s \
    --arg today "$(TZ="$timezone_name" date '+%Y-%m-%d')" \
    '{completedTasks:(map(select(.kind=="task"))|length),
      runtimeSeconds:((map(select(.kind=="task")|.duration_ms)|add // 0)/1000|floor),
      todayCompletedTasks:(map(select(.kind=="task" and .day==$today))|length),
      todayRuntimeSeconds:((map(select(.kind=="task" and .day==$today)|.duration_ms)|add // 0)/1000|floor),
      weekTokens:(map(select(.kind=="token")|.tokens)|add // 0),
      todayTokens:(map(select(.kind=="token" and .day==$today)|.tokens)|add // 0),
      byDay:(map(select(.kind=="token"))|group_by(.day)|map({key:.[0].day,value:(map(.tokens)|add)})|from_entries),
      latestLimits:(map(select(.limits != null))|max_by(.timestamp).limits)}')"

latest_limits="$(jq -c '.latestLimits' <<<"$summary")"
primary_used="$(jq -r '.primary.used_percent // 0' <<<"$latest_limits")"
reset_epoch="$(jq -r '.primary.resets_at // 0' <<<"$latest_limits")"

daily_tokens=()
for offset in {0..6}; do
  day_key="$(TZ="$timezone_name" date -r "$week_start" -v+${offset}d '+%Y-%m-%d')"
  daily_tokens+=("$(jq -r --arg day "$day_key" '.byDay[$day] // 0' <<<"$summary")")
done

generated_at="$(date -u '+%Y-%m-%dT%H:%M:%SZ')"
reset_at="$(date -u -r "$reset_epoch" '+%Y-%m-%dT%H:%M:%SZ')"
now_epoch="$(date '+%s')"
window_seconds="$((7 * 24 * 60 * 60))"
theoretical_remaining="$(( (reset_epoch - now_epoch) * 100 / window_seconds ))"
(( theoretical_remaining < 0 )) && theoretical_remaining=0
(( theoretical_remaining > 100 )) && theoretical_remaining=100

temporary_output="${output_path}.tmp.$$"
jq -n \
  --arg generatedAt "$generated_at" \
  --arg resetAt "$reset_at" \
  --argjson remainingPercent "$((100 - ${primary_used%.*}))" \
  --argjson theoreticalRemainingPercent "$theoretical_remaining" \
  --argjson runtimeSeconds "$(jq '.runtimeSeconds' <<<"$summary")" \
  --argjson completedTasks "$(jq '.completedTasks' <<<"$summary")" \
  --argjson todayRuntimeSeconds "$(jq '.todayRuntimeSeconds' <<<"$summary")" \
  --argjson todayCompletedTasks "$(jq '.todayCompletedTasks' <<<"$summary")" \
  --argjson todayTokens "$(jq '.todayTokens' <<<"$summary")" \
  --argjson weekTokens "$(jq '.weekTokens' <<<"$summary")" \
  --argjson dailyTokens "$(printf '%s\n' "${daily_tokens[@]}" | jq -s '.')" \
  '{generatedAt:$generatedAt,remainingPercent:$remainingPercent,theoreticalRemainingPercent:$theoreticalRemainingPercent,resetAt:$resetAt,runtimeSeconds:$runtimeSeconds,completedTasks:$completedTasks,todayRuntimeSeconds:$todayRuntimeSeconds,todayCompletedTasks:$todayCompletedTasks,todayTokens:$todayTokens,weekTokens:$weekTokens,dailyTokens:$dailyTokens}' \
  > "$temporary_output"
mv -f "$temporary_output" "$output_path"

echo "$output_path"
