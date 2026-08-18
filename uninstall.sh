#!/usr/bin/env bash
set -euo pipefail

PLUGIN_ID="imagineit.klm"
DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"

# Remove only KLM's marked Lua block. User input settings outside the block stay untouched.
if [[ -x "$DIR/bin/klmctl" ]]; then
  "$DIR/bin/klmctl" clean >/dev/null || true
fi

if command -v omarchy-shell >/dev/null 2>&1; then
  omarchy-shell shell setPluginEnabled "$PLUGIN_ID" false >/dev/null 2>&1 || true
  omarchy-shell shell setPluginEnabled omarchy.keyboard-layout true >/dev/null 2>&1 || true
fi

echo "imagineit KLM configuration removed."
echo "You can now remove: $DIR"
