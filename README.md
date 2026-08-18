# imagineit KLM

<img width="387" height="586" alt="imagineit KLM panel" src="https://github.com/user-attachments/assets/d6ba6ba7-f5b8-46a1-976d-4d13acf4fcdf" />

**Keyboard Language Manager for Omarchy 4 / Quattro.**

imagineit KLM replaces the basic keyboard-layout label with a compact language manager designed for the Omarchy Quickshell bar.

## Features

- Current keyboard language as **text in the bar** (`English`, `Persian`, ...).
- Click the label to open the language manager.
- Add or remove layouts from the installed XKB database.
- Optional **Alt + Shift** switching with both press orders supported (`Alt → Shift` and `Shift → Alt`).
- Immediate Hyprland `activelayout` event tracking; no fast polling loop.
- Centered OSD when the active language changes.
- Right-click the bar label to switch to the next language.
- Mouse wheel over the label switches previous/next.
- Multi-keyboard awareness: explicit selections are synchronized across physical keyboards.
- Persists the managed keyboard configuration in Omarchy 4's `~/.config/hypr/input.lua`.
- Preserves unrelated `kb_options`, such as Compose settings.
- Updates only its own clearly marked block in `input.lua`; unrelated user configuration is left untouched.
- Searchable XKB language/layout picker.
- Atomic writes and a one-time safety backup before the first managed `input.lua` change.
- No background daemon.

## Requirements

- Omarchy 4 / Quattro
- Hyprland
- Omarchy Shell / Quickshell
- Python 3
- XKB layout data from `xkeyboard-config`
- `xkbcli` is preferred; KLM falls back to the installed XKB rules files when it is unavailable

## Install

Use Omarchy's native plugin manager:

```bash
omarchy plugin add https://github.com/fstarlike/imaginit-klm.git --enable
```

The manifest requests the **right** section of the bar by default.

Omarchy already ships its own `omarchy.keyboard-layout` widget. If you do not want two layout labels in the bar, disable the stock widget explicitly:

```bash
omarchy plugin disable omarchy.keyboard-layout
```

KLM does **not** disable or rewrite other Omarchy plugins automatically.

## Persian + English quick start

Open **imagineit KLM** from the bar:

1. Choose **Add language**.
2. Search for `Persian` or `ir`.
3. Add the layout.
4. Enable **Alt + Shift**.

For Alt+Shift, KLM uses native Hyprland modifier-only release bindings instead of XKB `grp:alt_shift_toggle`. This avoids the press-order asymmetry seen on some keyboards, so both `Alt → Shift` and `Shift → Alt` can switch the layout.

## What KLM changes

KLM stores its own state in:

```text
~/.config/imagineit-klm/config.json
```

and logs diagnostic messages in:

```text
~/.local/state/imagineit-klm/klm.log
```

KLM does not modify `~/.config/hypr/input.lua` merely because the widget was loaded. The managed block is written after an explicit configuration change such as adding/removing a language or changing the shortcut.

Before the first managed change, an existing input file is backed up once as:

```text
~/.config/hypr/input.lua.imagineit-klm.bak
```

The inserted block is delimited by:

```text
-- >>> imagineit KLM (managed) >>>
...
-- <<< imagineit KLM (managed) <<<
```

Everything outside that block is preserved.

## CLI

```bash
~/.config/omarchy/plugins/imagineit.klm/bin/klmctl snapshot
~/.config/omarchy/plugins/imagineit.klm/bin/klmctl diagnose
~/.config/omarchy/plugins/imagineit.klm/bin/klmctl available
~/.config/omarchy/plugins/imagineit.klm/bin/klmctl add-layout ir
~/.config/omarchy/plugins/imagineit.klm/bin/klmctl set-shortcut alt-shift
~/.config/omarchy/plugins/imagineit.klm/bin/klmctl switch next
~/.config/omarchy/plugins/imagineit.klm/bin/klmctl repair-shortcut
```

## Update

```bash
omarchy plugin update imagineit.klm
```

## Remove

KLM writes a managed block into `input.lua` only after you change its keyboard settings, so clean that block before removing the plugin:

```bash
~/.config/omarchy/plugins/imagineit.klm/bin/klmctl clean
omarchy plugin remove imagineit.klm
```

If you disabled Omarchy's stock keyboard-layout widget during setup, you can restore it afterward:

```bash
omarchy plugin enable omarchy.keyboard-layout
```

The plugin removal command removes the plugin checkout. KLM's own state/log files are intentionally left in place so an update or reinstall can retain preferences; they can be deleted manually if a full reset is desired.

## Privacy and network access

KLM performs no analytics and sends no keyboard, layout, or system information to a remote service.

The panel contains a clickable **Imagine it · imagineit.online** link. Network access happens only when the user explicitly opens that link in the default browser.

## Version 1.0.3

- Prepared the repository for the current Omarchy Plugins submission rules.
- Switched the documentation to Omarchy's native plugin add/update/remove flow.
- Added explicit MIT license metadata to the plugin manifest.
- Documented user-configuration boundaries and safe removal.
- Added automated repository checks while keeping the runtime dependency-free.

## License

MIT — see [LICENSE](LICENSE).
