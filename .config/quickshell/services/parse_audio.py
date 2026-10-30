#!/usr/bin/env python3
import sys
import os
import json
import time
import select
import subprocess

def extract_volume_and_mute(info, card_info=None):
    volume = None
    muted = False

    params = (info or {}).get("params") or {}
    props_list = params.get("Props") or []
    for p in props_list:
        v_val = None
        if "channelVolumes" in p and p["channelVolumes"]:
            v_val = p["channelVolumes"][0]
        elif "softVolumes" in p and p["softVolumes"]:
            v_val = p["softVolumes"][0]
        elif "volume" in p:
            v_val = p["volume"]

        if v_val is not None:
            cubic_volume = max(0.0, float(v_val)) ** (1.0 / 3.0)
            volume = int(round(cubic_volume * 100))
            muted = bool(p.get("mute", p.get("softMute", False)))
            break

    # Fallback to Route params on parent card if node Props had no volume (common on some BlueZ/ALSA nodes)
    if volume is None and card_info:
        card_params = (card_info.get("info") or {}).get("params") or {}
        for route in card_params.get("Route") or []:
            r_props = route.get("props") or {}
            v_val = None
            if "channelVolumes" in r_props and r_props["channelVolumes"]:
                v_val = r_props["channelVolumes"][0]
            elif "volume" in r_props:
                v_val = r_props["volume"]
            if v_val is not None:
                cubic_volume = max(0.0, float(v_val)) ** (1.0 / 3.0)
                volume = int(round(cubic_volume * 100))
                muted = bool(r_props.get("mute", False))
                break

    return (volume if volume is not None else 100), muted


def get_audio_state():
    try:
        raw = subprocess.check_output(["pw-dump"], text=True, stderr=subprocess.DEVNULL)
        data = json.loads(raw)
    except Exception:
        data = []

    default_sink_name = None
    default_source_name = None
    configured_sink_name = None
    configured_source_name = None

    for x in data:
        if x.get("type") == "PipeWire:Interface:Metadata":
            m_props = x.get("props") or {}
            if m_props.get("metadata.name") == "default":
                for entry in x.get("metadata") or []:
                    key = entry.get("key")
                    val = entry.get("value")
                    name_val = val.get("name") if isinstance(val, dict) else None
                    if key == "default.audio.sink" and name_val:
                        default_sink_name = name_val
                    elif key == "default.audio.source" and name_val:
                        default_source_name = name_val
                    elif key == "default.configured.audio.sink" and name_val:
                        configured_sink_name = name_val
                    elif key == "default.configured.audio.source" and name_val:
                        configured_source_name = name_val

    if not default_sink_name:
        default_sink_name = configured_sink_name
    if not default_source_name:
        default_source_name = configured_source_name

    # Map PipeWire Devices (cards) by ID
    cards = {}
    for item in data:
        if item.get("type") == "PipeWire:Interface:Device":
            cards[item["id"]] = item

    sinks = []
    sources = []
    sink_card_ids = set()
    source_card_ids = set()

    for item in data:
        if item.get("type") != "PipeWire:Interface:Node":
            continue

        info = item.get("info") or {}
        props = {**(item.get("props") or {}), **(info.get("props") or {})}
        media_class = props.get("media.class", "")

        is_sink = media_class in ("Audio/Sink", "Audio/Sink/Virtual", "Audio/Duplex")
        is_source = media_class in ("Audio/Source", "Audio/Source/Virtual")

        if not is_sink and not is_source:
            continue

        device_id = item["id"]
        name = props.get("node.name") or ""
        if is_source and name.endswith(".monitor"):
            continue

        card_id = props.get("device.id")
        card_item = cards.get(card_id) if card_id is not None else None
        card_props = {}
        if card_item:
            card_props = {**(card_item.get("props") or {}), **((card_item.get("info") or {}).get("props") or {})}

        desc = (
            props.get("node.description")
            or props.get("node.nick")
            or card_props.get("device.description")
            or card_props.get("device.nick")
            or name
        )

        is_bt = (
            props.get("device.api") == "bluez5"
            or card_props.get("device.api") == "bluez5"
            or "bluez" in name.lower()
            or "bluetooth" in name.lower()
        )

        volume, muted = extract_volume_and_mute(info, card_item)

        if is_sink:
            if card_id is not None:
                sink_card_ids.add(card_id)
            is_default = (name == default_sink_name)
            sinks.append({
                "id": device_id,
                "name": desc,
                "nodeName": name,
                "isDefault": is_default,
                "volume": volume,
                "muted": muted,
                "isBluetooth": is_bt
            })
        elif is_source:
            if card_id is not None:
                source_card_ids.add(card_id)
            is_default = (name == default_source_name)
            sources.append({
                "id": device_id,
                "name": desc,
                "nodeName": name,
                "isDefault": is_default,
                "volume": volume,
                "muted": muted,
                "isBluetooth": is_bt
            })

    # Check if any connected Bluetooth audio card (bluez5) has no active Sink/Source node yet
    # (e.g., profile set to 'off' or 'a2dp-source' / 'headset-head-unit' needing profile switch)
    for card_id, card_item in cards.items():
        c_info = card_item.get("info") or {}
        c_props = {**(card_item.get("props") or {}), **(c_info.get("props") or {})}
        if c_props.get("device.api") != "bluez5":
            continue

        c_desc = c_props.get("device.description") or c_props.get("device.nick") or c_props.get("device.name") or f"Bluetooth ({card_id})"
        c_params = c_info.get("params") or {}
        enum_profiles = c_params.get("EnumProfile") or []

        if card_id not in sink_card_ids:
            best_sink_prof = None
            for prof in enum_profiles:
                p_name = (prof.get("name") or "").lower()
                if p_name == "off" or prof.get("available") == "no":
                    continue
                classes = prof.get("classes") or []
                has_sink_class = any(isinstance(c, list) and len(c) > 1 and "Audio/Sink" in str(c[1]) for c in classes)
                if "a2dp-sink" in p_name or "headset" in p_name or "speaker" in p_name or has_sink_class:
                    best_sink_prof = prof.get("index")
                    if "a2dp-sink" in p_name:
                        break
            if best_sink_prof is not None:
                sinks.append({
                    "id": f"card:{card_id}:{best_sink_prof}",
                    "name": c_desc,
                    "nodeName": c_props.get("device.name", ""),
                    "isDefault": False,
                    "volume": 100,
                    "muted": False,
                    "isBluetooth": True
                })

        if card_id not in source_card_ids:
            best_src_prof = None
            for prof in enum_profiles:
                p_name = (prof.get("name") or "").lower()
                if p_name == "off" or prof.get("available") == "no":
                    continue
                classes = prof.get("classes") or []
                has_src_class = any(isinstance(c, list) and len(c) > 1 and "Audio/Source" in str(c[1]) for c in classes)
                if "headset-head-unit" in p_name or "input" in p_name or has_src_class:
                    best_src_prof = prof.get("index")
                    if "headset-head-unit" in p_name:
                        break
            if best_src_prof is not None:
                sources.append({
                    "id": f"card:{card_id}:{best_src_prof}",
                    "name": c_desc,
                    "nodeName": c_props.get("device.name", ""),
                    "isDefault": False,
                    "volume": 100,
                    "muted": False,
                    "isBluetooth": True
                })

    # Fallback if no sink/source matched default_sink_name
    if sinks and not any(x["isDefault"] for x in sinks):
        sinks[0]["isDefault"] = True
    if sources and not any(x["isDefault"] for x in sources):
        sources[0]["isDefault"] = True

    default_sink = next((x for x in sinks if x["isDefault"]), None)
    default_source = next((x for x in sources if x["isDefault"]), None)

    return {
        "volume": default_sink["volume"] if default_sink else 50,
        "muted": default_sink["muted"] if default_sink else False,
        "sourceVolume": default_source["volume"] if default_source else 50,
        "sourceMuted": default_source["muted"] if default_source else False,
        "outputs": sinks,
        "inputs": sources
    }


def push_state(last_json):
    state_json = json.dumps(get_audio_state())
    if state_json != last_json:
        sys.stdout.write(state_json + "\n")
        sys.stdout.flush()
    return state_json


def run_daemon():
    last_json = push_state(None)

    env = {**os.environ, "LC_ALL": "C"}
    sub_proc = None
    try:
        sub_proc = subprocess.Popen(
            ["pactl", "subscribe"],
            stdout=subprocess.PIPE,
            stderr=subprocess.DEVNULL,
            text=True,
            bufsize=1,
            env=env
        )
    except Exception:
        sub_proc = None

    if not sub_proc or not sub_proc.stdout:
        # Fallback loop if pactl is unavailable
        while True:
            time.sleep(0.5)
            last_json = push_state(last_json)
        return

    poller = select.poll()
    poller.register(sub_proc.stdout.fileno(), select.POLLIN | select.POLLHUP)
    poller.register(sys.stdin.fileno(), select.POLLIN | select.POLLHUP)

    pending_update = False
    last_event_time = 0.0
    DEBOUNCE_SEC = 0.035

    try:
        while True:
            timeout_ms = int(DEBOUNCE_SEC * 1000) if pending_update else 2000
            events = poller.poll(timeout_ms)

            now = time.monotonic()
            for fd, flag in events:
                if fd == sys.stdin.fileno():
                    if flag & select.POLLHUP:
                        return
                    line = sys.stdin.readline()
                    if not line:
                        return
                    pending_update = True
                    last_event_time = 0.0  # Immediate update on explicit refresh command
                elif fd == sub_proc.stdout.fileno():
                    if flag & select.POLLHUP:
                        return
                    line = sub_proc.stdout.readline()
                    if not line:
                        return
                    # Ignore client and stream-level noise so pw-dump doesn't self-trigger
                    if any(t in line for t in ("on sink ", "on source ", "on server", "on card")):
                        pending_update = True
                        last_event_time = now

            if pending_update and (time.monotonic() - last_event_time >= DEBOUNCE_SEC):
                last_json = push_state(last_json)
                pending_update = False
    except KeyboardInterrupt:
        pass
    finally:
        if sub_proc:
            try:
                sub_proc.terminate()
            except Exception:
                pass


if __name__ == "__main__":
    if "--once" in sys.argv:
        print(json.dumps(get_audio_state()))
    else:
        run_daemon()
