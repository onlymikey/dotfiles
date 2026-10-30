#!/usr/bin/env python3
import os
import sys
import json
import time
import re
import subprocess
import threading

last_state = {}

def check_kdeconnect():
    kc_info = {
        "available": False,
        "paired": False,
        "reachable": False,
        "deviceId": "",
        "deviceName": "",
        "canRing": False,
        "battery": -1,
        "isCharging": False
    }

    # Query KDE Connect via DBus (fast, non-blocking)
    try:
        res = subprocess.check_output(
            ["busctl", "--user", "call", "org.kde.kdeconnect", "/modules/kdeconnect",
             "org.kde.kdeconnect.daemon", "devices", "bb", "false", "false"],
            stderr=subprocess.DEVNULL,
            timeout=1
        ).decode()
        ids = re.findall(r'"([^"]+)"', res)
        for dev_id in ids:
            try:
                props = subprocess.check_output(
                    ["busctl", "--user", "get-property", "org.kde.kdeconnect",
                     f"/modules/kdeconnect/devices/{dev_id}", "org.kde.kdeconnect.device",
                     "name", "isPaired", "isReachable", "type"],
                    stderr=subprocess.DEVNULL,
                    timeout=1
                ).decode().splitlines()

                name = ""
                paired = False
                reachable = False

                for p in props:
                    p = p.strip()
                    if p.startswith('s "') and not name:
                        name = p[3:-1]
                    elif p == "b true":
                        if not paired:
                            paired = True
                        else:
                            reachable = True
                    elif p == "b false":
                        pass

                if name:
                    kc_info["available"] = True
                    kc_info["deviceName"] = name
                    kc_info["deviceId"] = dev_id
                    if paired:
                        kc_info["paired"] = True
                    if reachable:
                        kc_info["reachable"] = True

                    if paired and reachable:
                        kc_info["canRing"] = True
                        # If paired and reachable, this is our primary device
                        break
            except Exception:
                pass
    except Exception:
        pass

    return kc_info

def check_adb():
    adb_info = {
        "available": False,
        "authorized": False,
        "deviceId": "",
        "deviceName": "",
        "connectionType": "Desconectado",
        "batteryLevel": -1,
        "isCharging": False,
        "networkType": "Sin red",
        "signalStrength": "Sin señal",
        "signalLevel": 0,
        "notificationsCount": 0,
        "canScrcpy": False,
        "scrcpyRunning": False
    }

    # 1. Check existing connected devices
    devices = []
    try:
        adb_out = subprocess.check_output(["adb", "devices", "-l"], stderr=subprocess.DEVNULL, timeout=2).decode()
        lines = [l.strip() for l in adb_out.strip().split("\n")[1:] if l.strip()]
        for line in lines:
            parts = line.split()
            if len(parts) >= 2:
                devices.append((parts[0], parts[1], line))
    except Exception:
        pass

    # If no authorized device, try connecting to discovered mdns if available
    has_auth = any(d[1] == "device" for d in devices)
    if not has_auth:
        try:
            mdns_out = subprocess.check_output(["adb", "mdns", "services"], stderr=subprocess.DEVNULL, timeout=2).decode()
            for mline in mdns_out.splitlines():
                if "_adb-tls-connect._tcp" in mline:
                    mparts = mline.split()
                    if len(mparts) >= 3:
                        addr = mparts[2]
                        subprocess.run(["adb", "connect", addr], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, timeout=3)
                        break
        except Exception:
            pass

        # Re-check devices after connect
        try:
            adb_out = subprocess.check_output(["adb", "devices", "-l"], stderr=subprocess.DEVNULL, timeout=2).decode()
            lines = [l.strip() for l in adb_out.strip().split("\n")[1:] if l.strip()]
            devices = []
            for line in lines:
                parts = line.split()
                if len(parts) >= 2:
                    devices.append((parts[0], parts[1], line))
        except Exception:
            pass

    for dev_id, status, line in devices:
        if status == "device":
            adb_info["available"] = True
            adb_info["authorized"] = True
            adb_info["deviceId"] = dev_id
            adb_info["canScrcpy"] = True
            m_match = re.search(r"model:(\S+)", line)
            if m_match:
                adb_info["deviceName"] = m_match.group(1).replace("_", " ")
            adb_info["connectionType"] = "Wi-Fi" if ("tcp" in dev_id or ":" in dev_id) else "USB"
            break
        elif status == "unauthorized":
            adb_info["available"] = True
            adb_info["authorized"] = False
            adb_info["deviceId"] = dev_id

    # If authorized, query details via ADB shell
    if adb_info["canScrcpy"]:
        dev_id = adb_info["deviceId"]
        try:
            # Query battery, telephony and notifications
            # Use separate queries to avoid broken pipes and capture clean outputs
            script = "dumpsys battery; dumpsys telephony.registry; dumpsys notification --noredact 2>/dev/null | grep -c NotificationRecord"
            res = subprocess.check_output(["adb", "-s", dev_id, "shell", script], stderr=subprocess.DEVNULL, timeout=4).decode()

            for line in res.splitlines():
                line = line.strip()
                if line.startswith("level:"):
                    try:
                        adb_info["batteryLevel"] = int(line.split(":")[1].strip())
                    except Exception:
                        pass
                elif line.startswith("status:"):
                    try:
                        st = int(line.split(":")[1].strip())
                        adb_info["isCharging"] = (st == 2 or st == 5)
                    except Exception:
                        pass
                elif "CellSignalStrengthLte" in line or "mLte:" in line:
                    adb_info["networkType"] = "LTE"
                    lvl_m = re.search(r"CellSignalStrengthLte:[^,\n]+level=(\d+)", line)
                    if lvl_m:
                        lvl = int(lvl_m.group(1))
                        adb_info["signalLevel"] = lvl
                        desc_map = ["Sin señal", "Débil", "Aceptable", "Buena", "Excelente"]
                        adb_info["signalStrength"] = desc_map[min(lvl, 4)]
                elif "CellSignalStrengthNr" in line or "mNr:" in line:
                    adb_info["networkType"] = "5G"
                    lvl_m = re.search(r"CellSignalStrengthNr:[^,\n]+level=(\d+)", line)
                    if lvl_m:
                        lvl = int(lvl_m.group(1))
                        adb_info["signalLevel"] = lvl
                        desc_map = ["Sin señal", "Débil", "Aceptable", "Buena", "Excelente"]
                        adb_info["signalStrength"] = desc_map[min(lvl, 4)]
                elif "CellSignalStrengthWcdma" in line or "mWcdma:" in line:
                    adb_info["networkType"] = "3G"
                elif line.startswith("mSignalStrength"):
                    lvl_m = re.search(r"level=(\d+)", line)
                    if lvl_m and adb_info["signalLevel"] == 0:
                        lvl = int(lvl_m.group(1))
                        adb_info["signalLevel"] = lvl
                        desc_map = ["Sin señal", "Débil", "Aceptable", "Buena", "Excelente"]
                        adb_info["signalStrength"] = desc_map[min(lvl, 4)]
                elif line.isdigit():
                    adb_info["notificationsCount"] = int(line)

            # Fallback if network type is still Sin red but device is connected
            if adb_info["networkType"] == "Sin red":
                adb_info["networkType"] = "Wi-Fi" if adb_info["connectionType"] == "Wi-Fi" else "Móvil"
        except Exception:
            pass

    # Check if scrcpy is currently running
    try:
        pg_out = subprocess.check_output(["pgrep", "-f", "scrcpy"]).decode().strip()
        adb_info["scrcpyRunning"] = bool(pg_out)
    except Exception:
        adb_info["scrcpyRunning"] = False

    return adb_info

def get_phone_state():
    adb_data = check_adb()
    kc_data = check_kdeconnect()

    has_device = adb_data["available"] or kc_data["available"]
    connected = (adb_data["authorized"]) or (kc_data["paired"] and kc_data["reachable"])

    # Determine display name
    name = "Teléfono Android"
    if adb_data["deviceName"]:
        name = adb_data["deviceName"]
    elif kc_data["deviceName"]:
        name = kc_data["deviceName"]

    # Connection type
    conn_type = "Desconectado"
    if adb_data["authorized"]:
        conn_type = adb_data["connectionType"]
    elif kc_data["reachable"]:
        conn_type = "Wi-Fi (KDE Connect)"

    battery_level = adb_data["batteryLevel"]
    is_charging = adb_data["isCharging"]

    network_type = adb_data["networkType"]
    signal_strength = adb_data["signalStrength"]
    signal_level = adb_data["signalLevel"]
    notifications = adb_data["notificationsCount"]

    return {
        "hasDevice": has_device,
        "deviceName": name,
        "connected": connected,
        "connectionType": conn_type,
        "batteryLevel": battery_level,
        "isCharging": is_charging,
        "networkType": network_type,
        "signalStrength": signal_strength,
        "signalLevel": signal_level,
        "notificationsCount": notifications,
        "kdeconnect": kc_data,
        "adb": adb_data
    }

def emit_state(state):
    global last_state
    last_state = state
    sys.stdout.write(json.dumps(state) + "\n")
    sys.stdout.flush()

def handle_command(cmd_obj):
    action = cmd_obj.get("action")
    if action == "ring":
        dev_id = cmd_obj.get("deviceId") or (last_state.get("kdeconnect", {}).get("deviceId"))
        try:
            if dev_id:
                subprocess.Popen(["kdeconnect-cli", "-d", dev_id, "--ring"])
            else:
                subprocess.Popen(["kdeconnect-cli", "--ring"])
        except Exception:
            pass

    elif action == "scrcpy":
        # Check if already running -> focus window
        try:
            pg = subprocess.check_output(["pgrep", "-f", "scrcpy"]).decode().strip()
            if pg:
                subprocess.run(["hyprctl", "dispatch", "focuswindow", "title:^scrcpy.*"], capture_output=True)
                return
        except Exception:
            pass

        # Not running -> launch scrcpy
        dev_id = cmd_obj.get("deviceId") or (last_state.get("adb", {}).get("deviceId"))
        args = [
            "scrcpy",
            "--window-title=scrcpy-phone",
            "--stay-awake",
            "--video-codec=h264",
            "-m", "1920"
        ]
        if dev_id:
            args.extend(["-s", dev_id])
        try:
            subprocess.Popen(args, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, start_new_session=True)
        except Exception:
            pass

    elif action == "refresh":
        state = get_phone_state()
        emit_state(state)

def poll_loop():
    while True:
        try:
            state = get_phone_state()
            emit_state(state)
        except Exception:
            pass
        time.sleep(5)

def stdin_loop():
    while True:
        try:
            line = sys.stdin.readline()
            if not line:
                time.sleep(1)
                continue
            line = line.strip()
            if not line:
                continue
            cmd_obj = json.loads(line)
            handle_command(cmd_obj)
        except Exception:
            time.sleep(1)

if __name__ == "__main__":
    try:
        emit_state(get_phone_state())
    except Exception:
        pass

    t_in = threading.Thread(target=stdin_loop, daemon=True)
    t_in.start()

    poll_loop()
