#!/usr/bin/env bash
set -euo pipefail

PLUGIN_ID="imagineit.klm"
SOURCE_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
TARGET_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/omarchy/plugins/$PLUGIN_ID"
STATE_FILE="${XDG_CONFIG_HOME:-$HOME/.config}/imagineit-klm/config.json"
HAD_SAVED_STATE=false
[[ -f "$STATE_FILE" ]] && HAD_SAVED_STATE=true

printf '\nimagineit KLM installer\n'
printf '%s\n' '----------------------'

for cmd in hyprctl python3; do
  if ! command -v "$cmd" >/dev/null 2>&1; then
    echo "Missing required command: $cmd" >&2
    exit 1
  fi
done

if ! command -v xkbcli >/dev/null 2>&1 && [[ ! -f /usr/share/X11/xkb/rules/base.lst ]]; then
  echo "Missing XKB layout data. Install xkeyboard-config/libxkbcommon first." >&2
  exit 1
fi

if [[ "$SOURCE_DIR" != "$TARGET_DIR" ]]; then
  mkdir -p "$TARGET_DIR"
  # Keep the target deterministic without copying git/build junk.
  find "$TARGET_DIR" -mindepth 1 -maxdepth 1 -exec rm -rf {} +
  cp -a "$SOURCE_DIR"/. "$TARGET_DIR"/
fi

chmod +x "$TARGET_DIR/bin/klmctl" "$TARGET_DIR/install.sh" "$TARGET_DIR/uninstall.sh"

# Prime state from the user's current Hyprland keyboard configuration. This does
# not modify input.lua until the user actually changes a KLM setting.
"$TARGET_DIR/bin/klmctl" snapshot >/dev/null || true

# On upgrades, immediately re-apply the saved state. v1.0.2 migrates the old
# order-sensitive XKB Alt+Shift action to symmetric native Hyprland binds.
if [[ "$HAD_SAVED_STATE" == true ]]; then
  "$TARGET_DIR/bin/klmctl" apply >/dev/null 2>&1 || true
fi

if command -v omarchy-shell >/dev/null 2>&1; then
  omarchy-shell shell rescanPlugins >/dev/null 2>&1 || true
  # Omarchy 4 already ships a minimal keyboard-layout label. Replace it to avoid
  # duplicate language labels in the bar, then place KLM in the right section.
  omarchy-shell shell setPluginEnabled omarchy.keyboard-layout false >/dev/null 2>&1 || true
  omarchy-shell shell enablePlugin "$PLUGIN_ID" '{"section":"right"}' >/dev/null 2>&1 || true
fi

cat <<EOF

Installed: $TARGET_DIR

imagineit KLM is ready.
- Left-click the language name in the Omarchy bar to manage layouts.
- Add a second language, then enable Alt + Shift in the panel (either press order works).
- Right-click the language name to switch immediately.

If the widget is not visible yet:
  omarchy-shell shell rescanPlugins
  omarchy plugin enable $PLUGIN_ID

EOF
