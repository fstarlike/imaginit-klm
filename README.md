# imagineit KLM

<img width="387" height="586" alt="image" src="https://github.com/user-attachments/assets/d6ba6ba7-f5b8-46a1-976d-4d13acf4fcdf" />


**Keyboard Language Manager for Omarchy 4 / Quattro.**

imagineit KLM replaces the basic Omarchy keyboard-layout label with a small language manager designed to feel native to the new Quickshell bar.

## Features

- Current keyboard language as **text in the bar** (`English`, `Persian`, ...), not an icon.
- Click the label to open a clean language manager.
- Add/remove any layout provided by the system XKB database.
- `Alt + Shift` switching, enabled from the UI, with **both press orders supported** (`Alt → Shift` and `Shift → Alt`).
- Immediate Hyprland `activelayout` event tracking — no fast polling loop.
- macOS-inspired centered OSD whenever the active language changes.
- Right-click the bar label to switch to the next language.
- Mouse wheel over the label switches previous/next.
- Multi-keyboard awareness: explicit selections are synchronized across physical keyboards.
- Persists through `~/.config/hypr/input.lua` using Omarchy 4's current Lua config syntax.
- Preserves unrelated `kb_options` such as Compose settings.
- Does not overwrite the rest of the user's `input.lua`.
- Searchable XKB language/layout picker.
- Automatic state persistence and safe atomic config writes.

## Important terminology

On Linux/Omarchy there normally is no separate package to install for each keyboard language. Layouts are supplied by **xkeyboard-config**. In KLM, “Add language” means enable one of those installed XKB layouts for Hyprland.

## Install from this folder

```bash
chmod +x install.sh
./install.sh
```

The plugin is installed to:

```text
~/.config/omarchy/plugins/imagineit.klm/
```

The installer disables Omarchy's built-in `omarchy.keyboard-layout` widget to prevent two language labels from appearing at once.

If needed, enable manually:

```bash
omarchy-shell shell rescanPlugins
omarchy plugin enable imagineit.klm
```

## Persian + English

Open **imagineit KLM** from the bar:

1. `Add language`
2. Search for `Persian` or `ir`
3. Add it
4. Enable **Alt + Shift**

KLM writes a managed block equivalent to:

```lua
hl.config({
  input = {
    kb_layout = "us,ir",
    kb_variant = ",",
    kb_options = "compose:caps", -- unrelated options are preserved
  },
})

local ctl = (os.getenv("HOME") or "") .. "/.config/omarchy/plugins/imagineit.klm/bin/klmctl"
hl.bind("ALT + SHIFT + SHIFT_L", hl.dsp.exec_cmd(ctl .. " switch next"), { release = true, non_consuming = true })
hl.bind("ALT + SHIFT + SHIFT_R", hl.dsp.exec_cmd(ctl .. " switch next"), { release = true, non_consuming = true })
hl.bind("ALT + SHIFT + ALT_L",   hl.dsp.exec_cmd(ctl .. " switch next"), { release = true, non_consuming = true })
hl.bind("ALT + SHIFT + ALT_R",   hl.dsp.exec_cmd(ctl .. " switch next"), { release = true, non_consuming = true })
```

The native Hyprland bindings intentionally replace XKB `grp:alt_shift_toggle` for this shortcut. That avoids the real-world press-order asymmetry where only one of `Alt → Shift` or `Shift → Alt` may switch.

The exact block is merged into `~/.config/hypr/input.lua`; existing settings outside the marked block are not replaced.

## CLI

```bash
~/.config/omarchy/plugins/imagineit.klm/bin/klmctl snapshot
~/.config/omarchy/plugins/imagineit.klm/bin/klmctl diagnose
~/.config/omarchy/plugins/imagineit.klm/bin/klmctl available
~/.config/omarchy/plugins/imagineit.klm/bin/klmctl add-layout ir
~/.config/omarchy/plugins/imagineit.klm/bin/klmctl set-shortcut alt-shift
~/.config/omarchy/plugins/imagineit.klm/bin/klmctl switch next
```

## Files created by KLM

```text
~/.config/imagineit-klm/config.json
~/.local/state/imagineit-klm/klm.log
~/.config/hypr/input.lua.imagineit-klm.bak   # one-time safety backup, if input.lua existed
```

KLM also inserts a clearly marked managed block into `~/.config/hypr/input.lua` after the first configuration change.

## Uninstall

Run:

```bash
./uninstall.sh
```

The uninstaller removes only the managed KLM block and re-enables Omarchy's stock keyboard-layout widget. It does not replace the rest of `input.lua` with the backup.

## Requirements

- Omarchy 4 / Quattro
- Hyprland
- Omarchy Shell / Quickshell
- Python 3
- XKB layout data (`xkeyboard-config`; `xkbcli` preferred)

No background daemon is required.

## v1.0.2 Alt+Shift order fix

KLM no longer uses XKB `grp:alt_shift_toggle` for the Alt+Shift mode. It installs native Hyprland modifier-only release bindings for both possible terminal keys, so **Alt then Shift** and **Shift then Alt** behave the same. Existing v1.0.0/v1.0.1 state is migrated automatically on upgrade; the legacy XKB group option is cleared before the new bindings are loaded.

The settings footer also includes a clickable **Imagine it · imagineit.online** link.

Manual repair command:

```bash
~/.config/omarchy/plugins/imagineit.klm/bin/klmctl repair-shortcut
```
