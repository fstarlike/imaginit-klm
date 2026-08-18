# Omarchy Plugins submission

Recommended values for the Omarchy Plugins marketplace submission form.

- **Title:** `[Plugin]: imagineit KLM`
- **Repository URL:** `https://github.com/fstarlike/imaginit-klm`
- **Category:** `Productivity`
- **Tags:** `Bar`, `Quickshell`, `System`

## Maintainer notes

imagineit KLM is a source-only Omarchy Quattro bar widget. It uses Python 3 and the system XKB data already present on Omarchy/Arch systems. `xkbcli` is preferred, with a fallback to `/usr/share/X11/xkb/rules/base.lst` or `evdev.lst`.

The plugin does not install packages, request elevated privileges, start services, or execute downloaded code. It writes only its own state/log files and, after an explicit keyboard-setting change, a clearly delimited managed block in `~/.config/hypr/input.lua`. Existing configuration outside that block is preserved and a one-time backup is created before the first managed edit.

Installation, update, cleanup, and removal instructions are documented in the root README. The repository contains exactly one root `manifest.json`, a root `LICENSE`, and no symlinks are required by the plugin.

## Submission checklist

- [x] The repository is public and contains installation and removal instructions.
- [x] I have documented the plugin license and any external dependencies.
- [x] I confirm that I own or have permission to submit this plugin and its preview assets.
- [x] The plugin does not overwrite user configuration without explicit consent.
- [x] I understand that approval is for listing and is not a security review.
