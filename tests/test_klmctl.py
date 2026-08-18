import importlib.machinery
import importlib.util
import os
import subprocess
import tempfile
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
loader = importlib.machinery.SourceFileLoader("klmctl", str(ROOT / "bin" / "klmctl"))
spec = importlib.util.spec_from_loader(loader.name, loader)
klm = importlib.util.module_from_spec(spec)
loader.exec_module(klm)


def test_marker_roundtrip():
    state = klm.sanitize_state({
        "layouts": [{"code": "us", "variant": ""}, {"code": "ir", "variant": ""}],
        "shortcut": "alt-shift",
        "preservedOptions": ["compose:caps"],
        "osd": True,
    })
    original = "-- user config\nhl.config({ input = { repeat_rate = 40 } })\n"
    block = klm.render_block(state)
    merged = klm.upsert_block(original, block)
    assert original.strip() in merged
    assert 'kb_layout = "us,ir"' in merged
    assert 'kb_options = "compose:caps"' in merged
    assert 'ALT + SHIFT + SHIFT_L' in merged
    assert 'ALT + SHIFT + ALT_L' in merged
    assert 'grp:alt_shift_toggle' not in merged
    changed = merged.replace('kb_layout = "us,ir"', 'kb_layout = "us,de"')
    merged2 = klm.upsert_block(changed, block)
    assert merged2.count(klm.BEGIN) == 1
    cleaned = klm.remove_block_text(merged2)
    assert klm.BEGIN not in cleaned
    assert "repeat_rate = 40" in cleaned


def test_xkbcli_parser():
    sample = """
- layout: 'us'
  variant: ''
  brief: 'en'
  description: English (US)
- layout: 'us'
  variant: 'intl'
  brief: 'en'
  description: English (US, intl.)
- layout: 'ir'
  variant: ''
  brief: 'fa'
  description: Persian
"""
    got = klm.parse_xkbcli(sample)
    assert got == [
        {"code": "us", "name": "English (US)", "brief": "en"},
        {"code": "ir", "name": "Persian", "brief": "fa"},
    ]


def test_state_sanitization():
    state = klm.sanitize_state({
        "layouts": [
            {"code": "us", "variant": ""},
            {"code": "ir", "variant": ""},
            {"code": "bad,inject", "variant": ""},
        ],
        "shortcut": "not-real",
        "osdDuration": 99999,
    })
    assert [x["code"] for x in state["layouts"]] == ["us", "ir"]
    assert state["shortcut"] == "none"
    assert state["osdDuration"] == 3000


def test_render_variants_are_aligned():
    state = klm.sanitize_state({
        "layouts": [
            {"code": "us", "variant": "intl"},
            {"code": "ir", "variant": ""},
        ],
        "shortcut": "alt-shift",
    })
    text = klm.render_block(state)
    assert 'kb_layout = "us,ir"' in text
    assert 'kb_variant = "intl,"' in text


def test_live_apply_resets_and_reapplies_options():
    state = klm.sanitize_state({
        "layouts": [{"code": "us", "variant": ""}, {"code": "ir", "variant": ""}],
        "shortcut": "alt-shift",
        "preservedOptions": ["compose:caps"],
    })
    calls = []
    old_which = klm.shutil.which
    old_run = klm.run
    old_status = klm.runtime_status
    try:
        klm.shutil.which = lambda name: "/usr/bin/hyprctl" if name == "hyprctl" else old_which(name)
        def fake_run(cmd, timeout=4.0):
            calls.append(cmd)
            return subprocess.CompletedProcess(cmd, 0, "ok", "")
        klm.run = fake_run
        klm.runtime_status = lambda _state=None: {
            "expectedShortcutOption": "",
            "shortcutActive": True,
            "shortcutBackend": "hyprland-order-neutral-bind",
            "kbLayout": "us,ir",
            "expectedKbLayout": "us,ir",
            "layoutMatches": True,
            "kbOptions": "compose:caps",
        }
        ok, message = klm.live_apply_state(state, reset_options=True)
        assert ok and message == "ok"
        assert len(calls) == 2
        assert calls[0][:2] == ["hyprctl", "eval"]
        assert 'kb_options = ""' in calls[0][2]
        assert 'kb_layout = "us,ir"' in calls[1][2]
        assert 'kb_options = "compose:caps"' in calls[1][2]
    finally:
        klm.shutil.which = old_which
        klm.run = old_run
        klm.runtime_status = old_status


def test_get_option_prefers_dotted_path_and_falls_back_to_legacy():
    calls = []
    old_run = klm.run
    try:
        def fake_run(cmd, timeout=4.0):
            calls.append(cmd)
            if cmd[-1] == "input.kb_options":
                return subprocess.CompletedProcess(cmd, 0, '{"str":"grp:alt_shift_toggle"}', "")
            return subprocess.CompletedProcess(cmd, 1, "", "no")
        klm.run = fake_run
        assert klm.get_option("input:kb_options") == "grp:alt_shift_toggle"
        assert calls[0][-1] == "input.kb_options"
    finally:
        klm.run = old_run


def test_alt_shift_uses_symmetric_hyprland_binds_not_xkb():
    state = klm.sanitize_state({
        "layouts": [{"code": "us", "variant": ""}, {"code": "ir", "variant": ""}],
        "shortcut": "alt-shift",
        "preservedOptions": ["compose:caps"],
    })
    text = klm.render_block(state)
    assert 'grp:alt_shift_toggle' not in text
    assert text.count('imagineit KLM: switch keyboard language') == 4
    for key in ("SHIFT_L", "SHIFT_R", "ALT_L", "ALT_R"):
        assert f'ALT + SHIFT + {key}' in text
    assert 'release = true' in text
    assert 'non_consuming = true' in text


def test_detect_initial_state_migrates_legacy_alt_shift():
    old_typed = klm.typed_keyboards
    old_get = klm.get_option
    try:
        klm.typed_keyboards = lambda: [{
            "name": "kbd", "layout": "us,ir", "variant": ",",
            "active_layout_index": 0, "active_keymap": "English (US)", "main": True,
        }]
        klm.get_option = lambda name: "compose:caps,grp:alt_shift_toggle" if "kb_options" in name else ""
        state = klm.detect_initial_state()
        assert state["shortcut"] == "alt-shift"
        assert state["preservedOptions"] == ["compose:caps"]
    finally:
        klm.typed_keyboards = old_typed
        klm.get_option = old_get


def test_apply_reloads_before_live_eval_for_native_binds():
    state = klm.sanitize_state({
        "layouts": [{"code": "us", "variant": ""}, {"code": "ir", "variant": ""}],
        "shortcut": "alt-shift",
    })
    calls = []
    old_which = klm.shutil.which
    old_run = klm.run
    old_live = klm.live_apply_state
    old_state_file = klm.state_file
    old_input_file = klm.input_file
    with tempfile.TemporaryDirectory() as td:
        base = Path(td)
        try:
            klm.shutil.which = lambda name: "/usr/bin/hyprctl" if name == "hyprctl" else old_which(name)
            klm.state_file = lambda: base / "config.json"
            klm.input_file = lambda: base / "input.lua"
            def fake_run(cmd, timeout=4.0):
                calls.append(cmd)
                return subprocess.CompletedProcess(cmd, 0, "ok", "")
            klm.run = fake_run
            klm.live_apply_state = lambda _state, reset_options=True: (True, "ok")
            ok, msg = klm.apply_state(state)
            assert ok and msg == "ok"
            assert calls and calls[0] == ["hyprctl", "reload"]
            rendered = (base / "input.lua").read_text()
            assert 'ALT + SHIFT + SHIFT_L' in rendered
            assert 'grp:alt_shift_toggle' not in rendered
        finally:
            klm.shutil.which = old_which
            klm.run = old_run
            klm.live_apply_state = old_live
            klm.state_file = old_state_file
            klm.input_file = old_input_file


if __name__ == "__main__":
    tests = [v for k, v in globals().items() if k.startswith("test_") and callable(v)]
    for test in tests:
        test()
        print("PASS", test.__name__)
