#!/bin/zsh
set -euo pipefail

user_app="$HOME/Applications/CodexWeek.app"
system_app="/Applications/CodexWeek.app"
if [[ -d "$user_app" ]]; then
  installed_app="$user_app"
elif [[ -d "$system_app" ]]; then
  installed_app="$system_app"
else
  print -u2 "CodexWeek.app is not installed. Run zsh ./scripts/install.sh first."
  exit 1
fi

widget_bundle_id="$(defaults read "$installed_app/Contents/PlugIns/CodexWeekWidgetExtension.appex/Contents/Info" CFBundleIdentifier)"
installed_extension="$installed_app/Contents/PlugIns/CodexWeekWidgetExtension.appex"
lsregister="/System/Library/Frameworks/CoreServices.framework/Versions/Current/Frameworks/LaunchServices.framework/Versions/Current/Support/lsregister"

# Old build folders can leave several copies of the same widget registered.
# Unregister every duplicate before registering the installed copy again.
registered_extensions=("${(@f)$(pluginkit -m -A -D -v -i "$widget_bundle_id" 2>/dev/null \
  | sed -nE 's@^.*[[:space:]](/.*\.appex)$@\1@p')}")
for extension_path in "${registered_extensions[@]}"; do
  [[ -n "$extension_path" && "$extension_path" != "$installed_extension" ]] || continue
  pluginkit -r "$extension_path" >/dev/null 2>&1 || true
done

"$lsregister" -f -R -trusted "$installed_app"
pluginkit -a "$installed_extension"
killall chronod >/dev/null 2>&1 || true
killall NotificationCenter >/dev/null 2>&1 || true
open "$installed_app"
print "Widget registration and caches were refreshed for: $installed_app"
