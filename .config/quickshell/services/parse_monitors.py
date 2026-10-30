#!/usr/bin/env python3
"""
Reactive Monitor & Display Management Daemon for Quickshell + Hyprland (Hyprlua).

Features:
- Connects to Hyprland IPC sockets (.socket.sock and .socket2.sock)
- Detects hotplug events (monitoradded, monitorremoved, configreloaded)
- Queries `j/monitors all` (including disabled monitors)
- Deduplicates EDID modes while preserving custom/overclocked modes (e.g. 1920x1080@73)
- Smart mode prioritization: High Refresh Rate vs High Resolution/Quality
- Supports both global projection presets and per-monitor modes (extend, mirror, only, disabled)
- Non-overlapping multi-monitor chaining when 3+ monitors share the same side (left/right/above/below)
- Applies changes directly through ~/.config/hypr/monitors.lua (hl.monitor) + Hyprland reload
- 10-second safety confirmation timer with automatic rollback of monitors.lua
- Persists confirmed state to ~/.config/quickshell/state/monitors.json and ~/.config/hypr/monitors.lua
"""

import json
import os
import re
import select
import socket
import subprocess
import sys
import time
from pathlib import Path

STATE_DIR = Path.home() / ".config" / "quickshell" / "state"
STATE_FILE = STATE_DIR / "monitors.json"
HYPR_MONITORS_LUA = Path.home() / ".config" / "hypr" / "monitors.lua"

REVERT_TIMEOUT_SECONDS = 10


def get_hypr_dir() -> Path:
    runtime_dir = os.environ.get("XDG_RUNTIME_DIR", f"/run/user/{os.getuid()}")
    sig = os.environ.get("HYPRLAND_INSTANCE_SIGNATURE", "")
    if sig:
        p = Path(runtime_dir) / "hypr" / sig
        if p.exists():
            return p
    hypr_root = Path(runtime_dir) / "hypr"
    if hypr_root.exists():
        dirs = sorted(hypr_root.iterdir(), key=lambda x: x.stat().st_mtime, reverse=True)
        for d in dirs:
            if (d / ".socket.sock").exists():
                return d
    return Path(runtime_dir) / "hypr"


def hypr_request(cmd: str) -> str:
    sock_path = get_hypr_dir() / ".socket.sock"
    try:
        with socket.socket(socket.AF_UNIX, socket.SOCK_STREAM) as s:
            s.settimeout(2.5)
            s.connect(str(sock_path))
            s.sendall(cmd.encode("utf-8"))
            chunks = []
            while True:
                data = s.recv(16384)
                if not data:
                    break
                chunks.append(data)
            return b"".join(chunks).decode("utf-8", errors="replace")
    except Exception:
        try:
            args = ["hyprctl"] + cmd.replace("j/", "-j ").split()
            res = subprocess.run(args, capture_output=True, text=True, timeout=2.5)
            return res.stdout
        except Exception:
            return ""


def hypr_reload() -> None:
    res = hypr_request("reload")
    if "ok" not in res.lower():
        try:
            subprocess.run(["hyprctl", "reload"], capture_output=True, timeout=2.5)
        except Exception:
            pass


def query_all_monitors() -> list:
    raw = hypr_request("j/monitors all")
    if not raw:
        return []
    try:
        data = json.loads(raw)
        return data if isinstance(data, list) else []
    except Exception:
        return []


def parse_lua_custom_modes() -> dict:
    """Read ~/.config/hypr/monitors.lua to preserve any custom/overclocked modes or positions."""
    custom = {}
    if not HYPR_MONITORS_LUA.exists():
        return custom
    try:
        text = HYPR_MONITORS_LUA.read_text(encoding="utf-8")
        blocks = re.findall(r"hl\.monitor\s*\(\s*\{([^}]*)\}\s*\)", text, re.DOTALL)
        for block in blocks:
            out_m = re.search(r'output\s*=\s*"([^"]+)"', block)
            mode_m = re.search(r'mode\s*=\s*"([^"]+)"', block)
            pos_m = re.search(r'position\s*=\s*"([^"]+)"', block)
            scale_m = re.search(r'scale\s*=\s*"?([0-9.]+)"?', block)
            dis_m = re.search(r'disabled\s*=\s*(true|false)', block)
            mir_m = re.search(r'mirror\s*=\s*"([^"]+)"', block)
            if out_m:
                name = out_m.group(1)
                custom[name] = {
                    "mode": mode_m.group(1) if mode_m else "",
                    "position": pos_m.group(1) if pos_m else "",
                    "scale": scale_m.group(1) if scale_m else "1",
                    "disabled": (dis_m.group(1) == "true") if dis_m else False,
                    "mirror": mir_m.group(1) if mir_m else "",
                }
    except Exception:
        pass
    return custom


def load_saved_state() -> dict:
    STATE_DIR.mkdir(parents=True, exist_ok=True)
    if STATE_FILE.exists():
        try:
            return json.loads(STATE_FILE.read_text(encoding="utf-8"))
        except Exception:
            pass
    return {}


def save_state_file(state: dict) -> None:
    STATE_DIR.mkdir(parents=True, exist_ok=True)
    try:
        STATE_FILE.write_text(json.dumps(state, indent=2), encoding="utf-8")
    except Exception:
        pass


def parse_mode_string(mode_str: str):
    """Parse '1920x1080@180.00Hz' or '1920x1080@73' into (w, h, hz)."""
    m = re.match(r"^\s*(\d+)x(\d+)(?:@([0-9.]+))?", str(mode_str).strip())
    if not m:
        return None
    w = int(m.group(1))
    h = int(m.group(2))
    hz = float(m.group(3)) if m.group(3) else 60.0
    return (w, h, hz)


def build_resolutions_for_monitor(mon: dict, custom_modes_map: dict, saved_mon_cfg: dict) -> tuple:
    raw_modes = list(mon.get("availableModes") or [])
    name = mon.get("name", "")

    cur_w = int(mon.get("width") or 0)
    cur_h = int(mon.get("height") or 0)
    cur_hz = float(mon.get("refreshRate") or 0.0)
    if cur_w > 0 and cur_h > 0 and cur_hz > 0:
        raw_modes.append(f"{cur_w}x{cur_h}@{cur_hz:.2f}Hz")

    lua_cfg = custom_modes_map.get(name, {})
    if lua_cfg.get("mode"):
        raw_modes.append(lua_cfg["mode"])

    if saved_mon_cfg.get("mode"):
        raw_modes.append(saved_mon_cfg["mode"])
    for cm in saved_mon_cfg.get("customModes", []):
        raw_modes.append(cm)

    res_dict = {}
    for rm in raw_modes:
        parsed = parse_mode_string(rm)
        if not parsed:
            continue
        w, h, hz = parsed
        if w < 640 or h < 400 or hz < 23.0:
            continue
        res_dict.setdefault((w, h), []).append(hz)

    if not res_dict and cur_w > 0 and cur_h > 0:
        res_dict[(cur_w, cur_h)] = [cur_hz if cur_hz > 0 else 60.0]

    sorted_res_keys = sorted(res_dict.keys(), key=lambda k: (k[0] * k[1], k[0]), reverse=True)

    resolutions = []
    native_w, native_h = sorted_res_keys[0] if sorted_res_keys else (1920, 1080)
    native_aspect = native_w / max(1, native_h)

    for w, h in sorted_res_keys:
        hz_list = sorted(res_dict[(w, h)], reverse=True)
        dedup_rates = []
        seen_rounded = set()
        for hz in hz_list:
            r_hz = int(round(hz))
            if r_hz not in seen_rounded:
                seen_rounded.add(r_hz)
                hz_str = f"{r_hz}" if abs(hz - r_hz) < 0.08 else f"{hz:.2f}"
                dedup_rates.append({
                    "hz": round(hz, 2),
                    "hzInt": r_hz,
                    "label": f"{r_hz} Hz",
                    "mode": f"{w}x{h}@{hz_str}",
                })
        resolutions.append({
            "res": f"{w}x{h}",
            "width": w,
            "height": h,
            "rates": dedup_rates,
        })

    best_quality_mode = "preferred"
    if resolutions and resolutions[0]["rates"]:
        best_quality_mode = resolutions[0]["rates"][0]["mode"]

    best_high_rr_mode = best_quality_mode
    if resolutions and resolutions[0]["rates"]:
        native_max_hz = resolutions[0]["rates"][0]["hz"]
        best_hz = native_max_hz
        for r_item in resolutions:
            rw, rh = r_item["width"], r_item["height"]
            if not r_item["rates"]:
                continue
            cand_hz = r_item["rates"][0]["hz"]
            cand_aspect = rw / max(1, rh)
            if rw == native_w and rh == native_h:
                continue
            if rw >= 1280 and rh >= 720 and abs(cand_aspect - native_aspect) < 0.08:
                if cand_hz >= best_hz + 24.0:
                    best_hz = cand_hz
                    best_high_rr_mode = r_item["rates"][0]["mode"]

    return resolutions, best_high_rr_mode, best_quality_mode


class MonitorDaemon:
    def __init__(self):
        self.saved = load_saved_state()
        self.custom_lua = parse_lua_custom_modes()
        self.pending_confirmation = False
        self.revert_deadline = 0.0
        self.previous_lua_content = None
        self.previous_primary = None
        self.last_connected_names = set()

        if "monitors" not in self.saved:
            self.saved["monitors"] = {}
        for name, cfg in self.custom_lua.items():
            entry = self.saved["monitors"].setdefault(name, {})
            if cfg.get("mode"):
                entry.setdefault("customModes", [])
                if cfg["mode"] not in entry["customModes"]:
                    entry["customModes"].append(cfg["mode"])
                entry.setdefault("mode", cfg["mode"])
            if cfg.get("position"):
                entry.setdefault("position", cfg["position"])
            if cfg.get("scale"):
                try:
                    entry.setdefault("scale", float(cfg["scale"]))
                except Exception:
                    pass
        save_state_file(self.saved)

    def detect_primary_name(self, mons: list) -> str:
        saved_primary = self.saved.get("primaryMonitor", "")
        names = [m.get("name", "") for m in mons]
        if saved_primary and saved_primary in names:
            return saved_primary
        for m in mons:
            if not m.get("disabled", False) and m.get("x", 0) == 0 and m.get("y", 0) == 0:
                return m.get("name", "")
        for m in mons:
            if not m.get("disabled", False):
                return m.get("name", "")
        return names[0] if names else ""

    def detect_layout_mode(self, mons: list, primary_name: str) -> str:
        if len(mons) <= 1:
            return "extend"
        enabled = [m for m in mons if not m.get("disabled", False)]
        disabled = [m for m in mons if m.get("disabled", False)]
        if any(m.get("mirrorOf", "none") not in ("none", "", None) for m in enabled):
            return "mirror"
        if disabled:
            if len(enabled) == 1 and enabled[0].get("name") == primary_name:
                return "primary_only"
            if len(enabled) == 1 and enabled[0].get("name") != primary_name:
                return "external_only"
        return "extend"

    def infer_relation(self, mon: dict, primary: dict, saved_mon: dict) -> str:
        if mon.get("name") == primary.get("name"):
            return "primary"
        if mon.get("disabled", False) or mon.get("mirrorOf", "none") not in ("none", "", None):
            return saved_mon.get("relation", "left")
        mx, my = int(mon.get("x", 0)), int(mon.get("y", 0))
        px, py = int(primary.get("x", 0)), int(primary.get("y", 0))
        dx = mx - px
        dy = my - py
        if abs(dx) >= abs(dy):
            return "left" if dx < 0 else "right"
        else:
            return "above" if dy < 0 else "below"

    def build_state_payload(self) -> dict:
        mons = query_all_monitors()
        primary_name = self.detect_primary_name(mons)
        primary_mon = next((m for m in mons if m.get("name") == primary_name), mons[0] if mons else {})
        layout_mode = self.detect_layout_mode(mons, primary_name)
        enabled_count = sum(1 for m in mons if not m.get("disabled", False))
        total_count = len(mons)

        mon_list = []
        for m in mons:
            name = m.get("name", "")
            saved_mon = self.saved.get("monitors", {}).get(name, {})
            resolutions, best_high_rr, best_quality = build_resolutions_for_monitor(
                m, self.custom_lua, saved_mon
            )
            w = int(m.get("width") or 0)
            h = int(m.get("height") or 0)
            hz = float(m.get("refreshRate") or 0.0)
            if (m.get("disabled", False) or w == 0) and saved_mon.get("mode"):
                parsed = parse_mode_string(saved_mon["mode"])
                if parsed:
                    w, h, hz = parsed
            elif (m.get("disabled", False) or w == 0) and resolutions:
                w = resolutions[0]["width"]
                h = resolutions[0]["height"]
                hz = resolutions[0]["rates"][0]["hz"] if resolutions[0]["rates"] else 60.0

            r_hz = int(round(hz))
            hz_str = f"{r_hz}" if abs(hz - r_hz) < 0.08 else f"{hz:.2f}"
            current_mode = f"{w}x{h}@{hz_str}"

            model_label = (m.get("model") or "").strip()
            make_label = (m.get("make") or "").strip()
            if not model_label:
                desc = (m.get("description") or "").strip()
                model_label = desc.split("(")[0].strip() if desc else name

            relation = self.infer_relation(m, primary_mon, saved_mon)
            is_internal = name.startswith(("eDP", "LVDS", "DSI"))
            is_disabled = bool(m.get("disabled", False))
            mirror_of = m.get("mirrorOf", "none") or "none"

            if is_disabled:
                display_mode = "disabled"
            elif mirror_of not in ("none", ""):
                display_mode = "mirror"
            elif total_count > 1 and enabled_count == 1:
                display_mode = "only"
            else:
                display_mode = "extend"

            mon_list.append({
                "id": m.get("id", -1),
                "name": name,
                "make": make_label,
                "model": model_label,
                "description": m.get("description", ""),
                "isPrimary": name == primary_name,
                "isInternal": is_internal,
                "disabled": is_disabled,
                "displayMode": display_mode,
                "focused": bool(m.get("focused", False)),
                "width": w,
                "height": h,
                "res": f"{w}x{h}",
                "refreshRate": round(hz, 2),
                "refreshRateInt": r_hz,
                "currentMode": current_mode,
                "x": int(m.get("x", 0)),
                "y": int(m.get("y", 0)),
                "scale": round(float(m.get("scale") or saved_mon.get("scale") or 1.0), 2),
                "transform": int(m.get("transform", 0)),
                "vrr": bool(m.get("vrr", False)),
                "mirrorOf": mirror_of,
                "relation": relation,
                "resolutions": resolutions,
                "bestHighRefreshMode": best_high_rr,
                "bestQualityMode": best_quality,
            })

        mon_list.sort(key=lambda item: (0 if item["isPrimary"] else 1, item["name"]))

        remaining = 0
        if self.pending_confirmation:
            remaining = max(0, int(round(self.revert_deadline - time.monotonic())))

        return {
            "monitors": mon_list,
            "primaryMonitor": primary_name,
            "layoutMode": layout_mode,
            "pendingConfirmation": self.pending_confirmation,
            "revertSeconds": remaining,
        }

    def emit_state(self) -> None:
        payload = self.build_state_payload()
        sys.stdout.write(json.dumps(payload) + "\n")
        sys.stdout.flush()

    def start_confirmation_timer(self) -> None:
        if not self.pending_confirmation:
            if HYPR_MONITORS_LUA.exists():
                try:
                    self.previous_lua_content = HYPR_MONITORS_LUA.read_text(encoding="utf-8")
                except Exception:
                    self.previous_lua_content = None
            self.previous_primary = self.saved.get("primaryMonitor")
        self.pending_confirmation = True
        self.revert_deadline = time.monotonic() + REVERT_TIMEOUT_SECONDS

    def format_monitors_lua(self, specs: list) -> str:
        lines = [
            "--------------------------------------------------",
            "-- Monitors",
            "--------------------------------------------------",
            "",
        ]
        # CRITICAL: Always write enabled monitors FIRST and disabled monitors LAST
        # so Hyprland never momentarily drops to 0 active Wayland outputs during reload!
        ordered_specs = sorted(specs, key=lambda item: (1 if item.get("disabled", False) else 0, 0 if item.get("isPrimary") else 1))
        for s in ordered_specs:
            name = s["name"]
            comment = s.get("comment") or (f"Main monitor ({name})" if s.get("isPrimary") else f"Monitor {name}")
            lines.append(f"-- {comment}")
            lines.append("hl.monitor({")
            lines.append(f'    output = "{name}",')
            if s.get("disabled", False):
                lines.append("    disabled = true,")
            else:
                mode_str = s.get("mode", "preferred")
                pos_str = s.get("position", "0x0")
                scale_val = float(s.get("scale", 1.0))
                scale_str = str(int(scale_val)) if scale_val.is_integer() else f"{scale_val:.2f}".rstrip("0").rstrip(".")
                lines.append(f'    mode = "{mode_str}",')
                lines.append(f'    position = "{pos_str}",')
                lines.append(f'    scale = "{scale_str}",')
                mirror_of = s.get("mirrorOf", "none")
                if mirror_of and mirror_of not in ("none", ""):
                    lines.append(f'    mirror = "{mirror_of}",')
            lines.append("})")
            lines.append("")
        return "\n".join(lines).rstrip() + "\n"

    def apply_specs_via_hyprlua(self, specs: list) -> None:
        lua_text = self.format_monitors_lua(specs)
        HYPR_MONITORS_LUA.write_text(lua_text, encoding="utf-8")
        hypr_reload()

    def persist_current_state(self) -> None:
        payload = self.build_state_payload()
        self.saved["primaryMonitor"] = payload["primaryMonitor"]
        self.saved["layoutMode"] = payload["layoutMode"]
        mons_map = self.saved.setdefault("monitors", {})
        for m in payload["monitors"]:
            name = m["name"]
            entry = mons_map.setdefault(name, {})
            entry["disabled"] = m["disabled"]
            if not m["disabled"]:
                entry["mode"] = m["currentMode"]
                entry["x"] = m["x"]
                entry["y"] = m["y"]
                entry["scale"] = m["scale"]
                entry["mirrorOf"] = m["mirrorOf"]
                if m["relation"] != "primary":
                    entry["relation"] = m["relation"]
                entry.setdefault("customModes", [])
                if m["currentMode"] not in entry["customModes"]:
                    entry["customModes"].append(m["currentMode"])
        save_state_file(self.saved)
        self.custom_lua = parse_lua_custom_modes()

    def layout_chained_monitors(self, primary_spec: dict, sec_specs: list) -> None:
        """
        Compute non-overlapping positions for all enabled extended secondary monitors,
        chaining multiple monitors if 2+ share the same side (left, right, above, below).
        """
        pw = int(round(primary_spec["width"] / max(0.25, primary_spec["scale"])))
        ph = int(round(primary_spec["height"] / max(0.25, primary_spec["scale"])))

        # Track cumulative offsets in each direction from primary (0, 0, pw, ph)
        cur_left_x = 0
        cur_right_x = pw
        cur_above_y = 0
        cur_below_y = ph

        for s in sec_specs:
            if s.get("disabled") or (s.get("mirrorOf") and s.get("mirrorOf") not in ("none", "")):
                continue
            sw = int(round(s["width"] / max(0.25, s["scale"])))
            sh = int(round(s["height"] / max(0.25, s["scale"])))
            rel = s.get("relation", "left")
            old_rel = s.get("oldRelation", rel)
            ex_x = s.get("existingX", 0)
            ex_y = s.get("existingY", 0)

            if rel == "left":
                target_x = cur_left_x - sw
                # Preserve custom Y alignment (like y=270 on HDMI-A-1) if it was already on the left at this X
                if rel == old_rel and ex_x == target_x:
                    target_y = ex_y
                else:
                    target_y = max(0, int(round((ph - sh) / 2)))
                s["position"] = f"{target_x}x{target_y}"
                cur_left_x = target_x

            elif rel == "right":
                target_x = cur_right_x
                if rel == old_rel and ex_x == target_x:
                    target_y = ex_y
                else:
                    target_y = max(0, int(round((ph - sh) / 2)))
                s["position"] = f"{target_x}x{target_y}"
                cur_right_x = target_x + sw

            elif rel == "above":
                target_y = cur_above_y - sh
                if rel == old_rel and ex_y == target_y:
                    target_x = ex_x
                else:
                    target_x = max(0, int(round((pw - sw) / 2)))
                s["position"] = f"{target_x}x{target_y}"
                cur_above_y = target_y

            elif rel == "below":
                target_y = cur_below_y
                if rel == old_rel and ex_y == target_y:
                    target_x = ex_x
                else:
                    target_x = max(0, int(round((pw - sw) / 2)))
                s["position"] = f"{target_x}x{target_y}"
                cur_below_y = target_y + sh

    def move_workspaces_to_monitor(self, target_monitor: str) -> None:
        if not target_monitor:
            return
        try:
            raw_ws = hypr_request("j/workspaces")
            workspaces = json.loads(raw_ws) if raw_ws else []
            for ws in workspaces:
                wid = ws.get("id")
                mon = ws.get("monitor")
                if wid is not None and wid > 0 and mon != target_monitor:
                    hypr_request(f"dispatch moveworkspacetomonitor {wid} {target_monitor}")
        except Exception:
            pass

    def handle_apply_monitor(self, cmd: dict) -> None:
        """
        Apply mode (resolution@hz), scale, relation, enabled state, or per-monitor displayMode
        ('extend', 'mirror', 'only', 'disabled') to a specific monitor via monitors.lua.
        """
        target_name = cmd.get("name", "")
        if not target_name:
            return

        state = self.build_state_payload()
        mons = {m["name"]: m for m in state["monitors"]}
        if target_name not in mons:
            return

        target = mons[target_name]
        primary_name = state["primaryMonitor"]

        req_display_mode = cmd.get("displayMode", "")
        if req_display_mode == "only":
            # "Solo esta pantalla": enable ONLY target_name at 0x0 and disable all others
            self.start_confirmation_timer()
            specs = []
            for m in state["monitors"]:
                if m["name"] == target_name:
                    saved_m = self.saved.get("monitors", {}).get(m["name"], {})
                    mode_to_use = cmd.get("mode") or m["currentMode"] or saved_m.get("mode") or m["bestHighRefreshMode"]
                    specs.append({
                        "name": m["name"],
                        "isPrimary": m["isPrimary"],
                        "disabled": False,
                        "mode": mode_to_use,
                        "position": "0x0",
                        "scale": float(cmd.get("scale") if cmd.get("scale") is not None else m["scale"]),
                        "mirrorOf": "none",
                    })
                else:
                    specs.append({
                        "name": m["name"],
                        "isPrimary": m["isPrimary"],
                        "disabled": True,
                    })
            self.apply_specs_via_hyprlua(specs)
            self.move_workspaces_to_monitor(target_name)
            time.sleep(0.2)
            self.emit_state()
            return

        if req_display_mode == "disabled":
            enabled = False
        elif req_display_mode in ("extend", "mirror"):
            enabled = True
        else:
            enabled = cmd.get("enabled", not target["disabled"])

        if not enabled:
            enabled_count = sum(1 for m in mons.values() if not m["disabled"] and m["name"] != target_name)
            if enabled_count == 0:
                return

        self.start_confirmation_timer()

        mode_str = cmd.get("mode") or target["currentMode"]
        scale_val = float(cmd.get("scale") if cmd.get("scale") is not None else target["scale"])
        parsed = parse_mode_string(mode_str)
        t_w = parsed[0] if parsed else target["width"]
        t_h = parsed[1] if parsed else target["height"]
        relation = cmd.get("relation") or target["relation"]

        if target_name != primary_name and relation != "primary":
            self.saved.setdefault("monitors", {}).setdefault(target_name, {})["relation"] = relation

        if req_display_mode == "mirror":
            mirror_target = cmd.get("mirrorOf") or (primary_name if target_name != primary_name else "")
            if not mirror_target or mirror_target == target_name:
                other_mon = next((m["name"] for m in state["monitors"] if m["name"] != target_name and not m["disabled"]), "")
                mirror_target = other_mon
        elif req_display_mode == "extend" or cmd.get("relation"):
            mirror_target = "none"
        else:
            mirror_target = target.get("mirrorOf", "none")

        # Build primary spec and secondary specs
        primary_mon = mons.get(primary_name, target)
        pri_spec = {
            "name": primary_mon["name"],
            "isPrimary": True,
            "disabled": (not enabled) if primary_mon["name"] == target_name else primary_mon["disabled"],
            "mode": mode_str if primary_mon["name"] == target_name else primary_mon["currentMode"],
            "position": "0x0",
            "scale": scale_val if primary_mon["name"] == target_name else primary_mon["scale"],
            "width": t_w if primary_mon["name"] == target_name else primary_mon["width"],
            "height": t_h if primary_mon["name"] == target_name else primary_mon["height"],
            "mirrorOf": mirror_target if primary_mon["name"] == target_name else primary_mon.get("mirrorOf", "none"),
        }
        # If target is being set to 'extend' while primary was disabled (e.g. coming out of 'only' mode), ensure at least target stays properly placed
        sec_specs = []
        for m in state["monitors"]:
            if m["name"] == primary_mon["name"]:
                continue
            saved_m = self.saved.get("monitors", {}).get(m["name"], {})
            if m["name"] == target_name:
                sec_specs.append({
                    "name": m["name"],
                    "isPrimary": False,
                    "disabled": not enabled,
                    "mode": mode_str,
                    "position": "0x0",
                    "scale": scale_val,
                    "width": t_w,
                    "height": t_h,
                    "relation": relation if relation != "primary" else saved_m.get("relation", "left"),
                    "oldRelation": m["relation"],
                    "existingX": m["x"] if not m["disabled"] else int(saved_m.get("x", -t_w)),
                    "existingY": m["y"] if not m["disabled"] else int(saved_m.get("y", 270 if m["name"] == "HDMI-A-1" else 0)),
                    "mirrorOf": mirror_target,
                })
            else:
                sec_specs.append({
                    "name": m["name"],
                    "isPrimary": False,
                    "disabled": m["disabled"],
                    "mode": m["currentMode"],
                    "position": f"{m['x']}x{m['y']}",
                    "scale": m["scale"],
                    "width": m["width"],
                    "height": m["height"],
                    "relation": m["relation"] if m["relation"] != "primary" else saved_m.get("relation", "left"),
                    "oldRelation": m["relation"],
                    "existingX": m["x"],
                    "existingY": m["y"],
                    "mirrorOf": m.get("mirrorOf", "none"),
                })

        self.layout_chained_monitors(pri_spec, sec_specs)
        all_specs = [pri_spec] + sec_specs
        self.apply_specs_via_hyprlua(all_specs)

        if not enabled:
            remaining_mon = next((s["name"] for s in all_specs if not s["disabled"]), "")
            if remaining_mon:
                self.move_workspaces_to_monitor(remaining_mon)
        time.sleep(0.2)
        self.emit_state()

    def handle_prioritize_mode(self, cmd: dict) -> None:
        priority = cmd.get("priority", "highrr")
        target_name = cmd.get("name", "")
        state = self.build_state_payload()

        self.start_confirmation_timer()
        specs = []
        for m in state["monitors"]:
            if m["disabled"]:
                specs.append({
                    "name": m["name"],
                    "isPrimary": m["isPrimary"],
                    "disabled": True,
                })
                continue
            if not target_name or m["name"] == target_name:
                chosen_mode = m["bestHighRefreshMode"] if priority == "highrr" else m["bestQualityMode"]
            else:
                chosen_mode = m["currentMode"]
            specs.append({
                "name": m["name"],
                "isPrimary": m["isPrimary"],
                "disabled": False,
                "mode": chosen_mode or m["currentMode"],
                "position": f"{m['x']}x{m['y']}",
                "scale": m["scale"],
                "mirrorOf": m.get("mirrorOf", "none"),
            })

        self.apply_specs_via_hyprlua(specs)
        time.sleep(0.2)
        self.emit_state()

    def handle_set_primary(self, cmd: dict) -> None:
        new_primary = cmd.get("name", "")
        if not new_primary:
            return
        state = self.build_state_payload()
        mons = {m["name"]: m for m in state["monitors"]}
        if new_primary not in mons:
            return

        self.start_confirmation_timer()
        self.saved["primaryMonitor"] = new_primary

        np_mon = mons[new_primary]
        pri_spec = {
            "name": new_primary,
            "isPrimary": True,
            "disabled": False,
            "mode": np_mon["currentMode"],
            "position": "0x0",
            "scale": np_mon["scale"],
            "width": np_mon["width"],
            "height": np_mon["height"],
            "mirrorOf": "none",
        }

        sec_specs = []
        for m in state["monitors"]:
            if m["name"] == new_primary:
                continue
            saved_m = self.saved.get("monitors", {}).get(m["name"], {})
            rel = m["relation"] if m["relation"] != "primary" else saved_m.get("relation", "left")
            sec_specs.append({
                "name": m["name"],
                "isPrimary": False,
                "disabled": m["disabled"],
                "mode": m["currentMode"],
                "position": "0x0",
                "scale": m["scale"],
                "width": m["width"],
                "height": m["height"],
                "relation": rel,
                "oldRelation": m["relation"],
                "existingX": m["x"],
                "existingY": m["y"],
                "mirrorOf": "none",
            })

        self.layout_chained_monitors(pri_spec, sec_specs)
        self.apply_specs_via_hyprlua([pri_spec] + sec_specs)
        time.sleep(0.2)
        self.emit_state()

    def handle_set_layout_mode(self, cmd: dict) -> None:
        """
        Switch between 'extend', 'mirror', 'primary_only', 'external_only' via monitors.lua.
        Supports optional 'targetMonitor' for 3+ monitor setups.
        """
        mode = cmd.get("layoutMode", "extend")
        target_mon_name = cmd.get("targetMonitor", "")
        state = self.build_state_payload()
        mons = state["monitors"]
        if len(mons) <= 1:
            return

        self.start_confirmation_timer()

        primary = next((m for m in mons if m["isPrimary"]), mons[0])
        secondaries = [m for m in mons if m["name"] != primary["name"]]

        specs = []
        target_ws_monitor = ""

        if mode == "extend":
            pri_spec = {
                "name": primary["name"],
                "isPrimary": True,
                "disabled": False,
                "mode": primary["currentMode"],
                "position": "0x0",
                "scale": primary["scale"],
                "width": primary["width"],
                "height": primary["height"],
                "mirrorOf": "none",
            }
            sec_specs = []
            for sec in secondaries:
                saved_sec = self.saved.get("monitors", {}).get(sec["name"], {})
                rel = saved_sec.get("relation") or (sec["relation"] if sec["relation"] != "primary" else "left")
                sec_mode = saved_sec.get("mode") or sec["bestHighRefreshMode"] or sec["currentMode"]
                sec_specs.append({
                    "name": sec["name"],
                    "isPrimary": False,
                    "disabled": False,
                    "mode": sec_mode,
                    "position": "0x0",
                    "scale": sec["scale"],
                    "width": sec["width"],
                    "height": sec["height"],
                    "relation": rel,
                    "oldRelation": rel,
                    "existingX": int(saved_sec.get("x", -sec["width"])),
                    "existingY": int(saved_sec.get("y", 270 if sec["name"] == "HDMI-A-1" else 0)),
                    "mirrorOf": "none",
                })
            self.layout_chained_monitors(pri_spec, sec_specs)
            specs = [pri_spec] + sec_specs

        elif mode == "mirror":
            specs.append({
                "name": primary["name"],
                "isPrimary": True,
                "disabled": False,
                "mode": primary["currentMode"],
                "position": "0x0",
                "scale": primary["scale"],
                "mirrorOf": "none",
            })
            for sec in secondaries:
                saved_sec = self.saved.get("monitors", {}).get(sec["name"], {})
                sec_mode = saved_sec.get("mode") or sec["bestHighRefreshMode"] or sec["currentMode"]
                specs.append({
                    "name": sec["name"],
                    "isPrimary": False,
                    "disabled": False,
                    "mode": sec_mode,
                    "position": "0x0",
                    "scale": 1.0,
                    "mirrorOf": primary["name"],
                })

        elif mode == "primary_only":
            specs.append({
                "name": primary["name"],
                "isPrimary": True,
                "disabled": False,
                "mode": primary["currentMode"],
                "position": "0x0",
                "scale": primary["scale"],
                "mirrorOf": "none",
            })
            for sec in secondaries:
                specs.append({
                    "name": sec["name"],
                    "isPrimary": False,
                    "disabled": True,
                })
            target_ws_monitor = primary["name"]

        elif mode == "external_only":
            # If user selected a specific secondary monitor in UI, isolate that one;
            # otherwise isolate external monitor(s).
            chosen_sec = next((m for m in secondaries if m["name"] == target_mon_name), None)
            if chosen_sec:
                target_enable = [chosen_sec]
                target_disable = [m for m in mons if m["name"] != chosen_sec["name"]]
            else:
                internal_mons = [m for m in mons if m["isInternal"]]
                external_mons = [m for m in mons if not m["isInternal"]]
                if internal_mons and external_mons:
                    target_enable = external_mons
                    target_disable = internal_mons
                else:
                    target_enable = [secondaries[0]]
                    target_disable = [m for m in mons if m["name"] != secondaries[0]["name"]]

            for idx, ext in enumerate(target_enable):
                saved_ext = self.saved.get("monitors", {}).get(ext["name"], {})
                ext_mode = saved_ext.get("mode") or ext["bestHighRefreshMode"] or ext["currentMode"]
                pos = "0x0" if idx == 0 else f"{idx * ext['width']}x0"
                specs.append({
                    "name": ext["name"],
                    "isPrimary": ext["isPrimary"],
                    "disabled": False,
                    "mode": ext_mode,
                    "position": pos,
                    "scale": ext["scale"],
                    "mirrorOf": "none",
                })
            for dis in target_disable:
                specs.append({
                    "name": dis["name"],
                    "isPrimary": dis["isPrimary"],
                    "disabled": True,
                })
            if target_enable:
                target_ws_monitor = target_enable[0]["name"]

        self.apply_specs_via_hyprlua(specs)
        if target_ws_monitor:
            self.move_workspaces_to_monitor(target_ws_monitor)
        time.sleep(0.2)
        self.emit_state()

    def handle_confirm(self) -> None:
        self.pending_confirmation = False
        self.previous_lua_content = None
        self.previous_primary = None
        self.persist_current_state()
        self.emit_state()

    def handle_revert(self) -> None:
        prev_lua = self.previous_lua_content
        prev_pri = self.previous_primary
        self.pending_confirmation = False
        self.previous_lua_content = None
        self.previous_primary = None
        if prev_pri:
            self.saved["primaryMonitor"] = prev_pri
        if prev_lua:
            try:
                HYPR_MONITORS_LUA.write_text(prev_lua, encoding="utf-8")
                hypr_reload()
                time.sleep(0.2)
            except Exception:
                pass
        self.emit_state()

    def handle_hotplug(self) -> None:
        mons = query_all_monitors()
        current_names = {m.get("name", "") for m in mons if m.get("name")}
        self.last_connected_names = current_names
        self.emit_state()

    def handle_stdin_line(self, line: str) -> None:
        line = line.strip()
        if not line:
            return
        try:
            cmd = json.loads(line)
        except Exception:
            cmd = {"action": line}

        action = cmd.get("action", "")
        if action == "refresh":
            self.emit_state()
        elif action == "apply_monitor":
            self.handle_apply_monitor(cmd)
        elif action == "set_layout_mode":
            self.handle_set_layout_mode(cmd)
        elif action == "set_primary":
            self.handle_set_primary(cmd)
        elif action == "prioritize_mode":
            self.handle_prioritize_mode(cmd)
        elif action == "confirm":
            self.handle_confirm()
        elif action == "revert":
            self.handle_revert()

    def run(self) -> None:
        mons = query_all_monitors()
        self.last_connected_names = {m.get("name", "") for m in mons if m.get("name")}
        self.emit_state()

        event_sock = None
        event_buf = ""
        stdin_buf = ""
        stdin_fd = sys.stdin.fileno()

        def connect_event_socket():
            nonlocal event_sock
            if event_sock is not None:
                try:
                    event_sock.close()
                except Exception:
                    pass
                event_sock = None
            sock_path = get_hypr_dir() / ".socket2.sock"
            if sock_path.exists():
                try:
                    s = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
                    s.setblocking(False)
                    s.connect(str(sock_path))
                    event_sock = s
                except Exception:
                    event_sock = None

        connect_event_socket()

        while True:
            if event_sock is None:
                connect_event_socket()

            rlist = [stdin_fd]
            if event_sock is not None:
                rlist.append(event_sock)

            timeout = 0.5 if self.pending_confirmation else 5.0
            try:
                readable, _, _ = select.select(rlist, [], [], timeout)
            except Exception:
                time.sleep(0.5)
                continue

            if stdin_fd in readable:
                try:
                    raw_in = os.read(stdin_fd, 8192)
                    if not raw_in:
                        break
                    stdin_buf += raw_in.decode("utf-8", errors="replace")
                    while "\n" in stdin_buf:
                        cmd_line, stdin_buf = stdin_buf.split("\n", 1)
                        self.handle_stdin_line(cmd_line)
                except Exception:
                    break

            if event_sock is not None and event_sock in readable:
                try:
                    chunk = event_sock.recv(8192)
                    if not chunk:
                        connect_event_socket()
                    else:
                        event_buf += chunk.decode("utf-8", errors="replace")
                        need_hotplug = False
                        need_emit = False
                        while "\n" in event_buf:
                            ev_line, event_buf = event_buf.split("\n", 1)
                            if ">>" not in ev_line:
                                continue
                            ev_name, _ = ev_line.split(">>", 1)
                            if ev_name in ("monitoradded", "monitoraddedv2", "monitorremoved", "monitorremovedv2"):
                                need_hotplug = True
                            elif ev_name in ("configreloaded", "focusedmon", "focusedmonv2"):
                                need_emit = True
                        if need_hotplug:
                            time.sleep(0.15)
                            self.handle_hotplug()
                        elif need_emit:
                            self.emit_state()
                except Exception:
                    connect_event_socket()

            if self.pending_confirmation:
                now = time.monotonic()
                if now >= self.revert_deadline:
                    self.handle_revert()
                else:
                    self.emit_state()


if __name__ == "__main__":
    daemon = MonitorDaemon()
    daemon.run()
