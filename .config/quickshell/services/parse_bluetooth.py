#!/usr/bin/env python3
import sys
import os
import json
import subprocess
import threading
import dbus
from dbus.mainloop.glib import DBusGMainLoop
from gi.repository import GLib

# Set up the D-Bus main loop for python-dbus
DBusGMainLoop(set_as_default=True)
try:
    bus = dbus.SystemBus()
except Exception:
    print(json.dumps({"powered": False, "discovering": False, "connectingMac": "", "devices": []}))
    sys.exit(1)

connecting_mac = ""
scan_timer_id = 0


def dbus_to_python(data):
    if isinstance(data, dbus.Dictionary):
        return {dbus_to_python(key): dbus_to_python(value) for key, value in data.items()}
    elif isinstance(data, dbus.Array):
        return [dbus_to_python(value) for value in data]
    elif isinstance(data, dbus.Boolean):
        return bool(data)
    elif isinstance(data, (dbus.Int16, dbus.Int32, dbus.Int64, dbus.UInt16, dbus.UInt32, dbus.UInt64, dbus.Byte)):
        return int(data)
    elif isinstance(data, (dbus.String, dbus.ObjectPath)):
        return str(data)
    elif isinstance(data, dbus.Double):
        return float(data)
    else:
        return data


def get_device_info(properties):
    device_type = "unknown"
    icon = "󰂲"

    icon_prop = properties.get("Icon")
    class_prop = properties.get("Class")
    uuids_prop = properties.get("UUIDs", [])
    name_prop = properties.get("Name", properties.get("Alias", ""))

    cod_type = None
    cod_icon = None
    if class_prop:
        cod = int(class_prop)
        major_class = (cod >> 8) & 0x1F
        minor_class = (cod >> 2) & 0x3F

        if major_class == 0x01:
            cod_type = "computer"
            cod_icon = "󰌢"
        elif major_class == 0x02:
            cod_type = "phone"
            cod_icon = "󰏲"
        elif major_class == 0x04:
            if minor_class in (0x01, 0x02, 0x06, 0x07):
                cod_type = "headphones"
                cod_icon = "󰋋"
            elif minor_class in (0x14, 0x18):
                cod_type = "speaker"
                cod_icon = "󰓃"
            elif minor_class in (0x09, 0x0a, 0x0b, 0x0c):
                cod_type = "tv"
                cod_icon = "󰍹"
            else:
                cod_type = "audio"
                cod_icon = "󰋋"
        elif major_class == 0x05:
            is_keyboard = bool(minor_class & 0x10)
            is_pointer = bool(minor_class & 0x20)
            if is_keyboard:
                cod_type = "keyboard"
                cod_icon = "󰌌"
            elif is_pointer:
                cod_type = "mouse"
                cod_icon = "󰍽"
            else:
                sub_class = minor_class & 0x0F
                if sub_class in (0x01, 0x02, 0x03, 0x04):
                    cod_type = "gamepad"
                    cod_icon = "󰖺"
                else:
                    cod_type = "peripheral"
                    cod_icon = "󰖺"
        elif major_class == 0x07:
            cod_type = "wearable"
            cod_icon = "󰥍"

    if icon_prop:
        icon_prop = str(icon_prop)
        if icon_prop in ("audio-headphones", "audio-headset"):
            device_type = "headphones"
            icon = "󰋋"
        elif icon_prop in ("audio-speakers", "audio-speaker"):
            device_type = "speaker"
            icon = "󰓃"
        elif icon_prop in ("input-keyboard", "keyboard"):
            device_type = "keyboard"
            icon = "󰌌"
        elif icon_prop in ("input-mouse", "mouse", "input-tablet"):
            device_type = "mouse"
            icon = "󰍽"
        elif icon_prop in ("input-gaming", "joystick", "gamepad"):
            device_type = "gamepad"
            icon = "󰖺"
        elif icon_prop in ("phone", "cellular"):
            device_type = "phone"
            icon = "󰏲"
        elif icon_prop in ("computer", "laptop"):
            device_type = "computer"
            icon = "󰌢"
        elif icon_prop == "audio-card":
            if cod_type in ("headphones", "speaker", "tv"):
                device_type = cod_type
                icon = cod_icon
            else:
                device_type = "audio"
                icon = "󰋋"

    if device_type == "unknown" or icon == "󰂲":
        if cod_type:
            device_type = cod_type
            icon = cod_icon

    if device_type == "unknown" or icon == "󰂲":
        for uuid in uuids_prop:
            uuid_str = str(uuid).lower()
            if "1124" in uuid_str:
                device_type = "keyboard"
                icon = "󰌌"
                break
            elif any(u in uuid_str for u in ("110b", "110d", "1108", "111e", "110a")):
                device_type = "headphones"
                icon = "󰋋"
                break

    if (device_type == "unknown" or icon == "󰂲") and name_prop:
        name_lower = str(name_prop).lower()
        if "keyboard" in name_lower or "kb" in name_lower:
            device_type = "keyboard"
            icon = "󰌌"
        elif "mouse" in name_lower or "trackpad" in name_lower:
            device_type = "mouse"
            icon = "󰍽"
        elif "controller" in name_lower or "gamepad" in name_lower or "joy" in name_lower:
            device_type = "gamepad"
            icon = "󰖺"
        elif any(k in name_lower for k in ("headphone", "headset", "buds", "wh-", "wf-", "auricular", "airpods")):
            device_type = "headphones"
            icon = "󰋋"
        elif any(k in name_lower for k in ("speaker", "parlante", "audio", "echo", "srs-")):
            device_type = "speaker"
            icon = "󰓃"

    return device_type, icon


def get_rssi_strength(rssi):
    if rssi is None:
        return ""
    try:
        val = int(rssi)
    except (ValueError, TypeError):
        return ""

    if val >= -60:
        return "▂▄▆█"
    elif val >= -75:
        return "▂▄▆"
    elif val >= -90:
        return "▂▄"
    else:
        return "▂"


def sort_devices(devices):
    devices.sort(key=lambda x: x["name"].lower())
    devices.sort(key=lambda x: x["paired"], reverse=True)
    devices.sort(key=lambda x: x["connected"], reverse=True)
    return devices


def get_managed_objects():
    bluez_obj = bus.get_object("org.bluez", "/")
    manager = dbus.Interface(bluez_obj, "org.freedesktop.DBus.ObjectManager")
    return dbus_to_python(manager.GetManagedObjects())


def find_adapter_path(objects=None):
    if objects is None:
        try:
            objects = get_managed_objects()
        except Exception:
            return None
    for path, interfaces in objects.items():
        if "org.bluez.Adapter1" in interfaces:
            return path
    return None


def find_device_path(mac, objects=None):
    if not mac:
        return None
    if objects is None:
        try:
            objects = get_managed_objects()
        except Exception:
            return None
    mac_upper = mac.strip().upper()
    for path, interfaces in objects.items():
        if "org.bluez.Device1" in interfaces:
            addr = str(interfaces["org.bluez.Device1"].get("Address", "")).upper()
            if addr == mac_upper:
                return path
    return None


def print_bluetooth_state():
    global connecting_mac
    try:
        objects = get_managed_objects()
    except Exception:
        print(json.dumps({"powered": False, "discovering": False, "connectingMac": "", "devices": []}))
        sys.stdout.flush()
        return

    powered = False
    discovering = False
    devices = []

    for path, interfaces in objects.items():
        if "org.bluez.Adapter1" in interfaces:
            adapter = interfaces["org.bluez.Adapter1"]
            if adapter.get("Powered"):
                powered = True
            if adapter.get("Discovering"):
                discovering = True

    for path, interfaces in objects.items():
        if "org.bluez.Device1" in interfaces:
            dev_props = interfaces["org.bluez.Device1"]

            mac = dev_props.get("Address", "")
            name = dev_props.get("Alias", dev_props.get("Name", ""))
            if not name:
                name = mac

            paired = bool(dev_props.get("Paired", False))
            connected = bool(dev_props.get("Connected", False))
            trusted = bool(dev_props.get("Trusted", False))
            rssi = dev_props.get("RSSI", None)

            # Ignore unnamed non-paired BLE advertisements without RSSI or real Alias
            raw_name = dev_props.get("Name", "")
            if not paired and not connected and not raw_name and name.replace(":", "-") == mac.replace(":", "-"):
                continue

            battery = None
            if "org.bluez.Battery1" in interfaces:
                battery = interfaces["org.bluez.Battery1"].get("Percentage", None)

            device_type, icon = get_device_info(dev_props)
            signal_str = get_rssi_strength(rssi)

            if connected and connecting_mac.upper() == mac.upper():
                connecting_mac = ""

            devices.append({
                "mac": mac,
                "name": name,
                "paired": paired,
                "connected": connected,
                "trusted": trusted,
                "battery": battery,
                "rssi": rssi,
                "signalStrength": signal_str,
                "icon": icon,
                "type": device_type
            })

    sorted_devs = sort_devices(devices)

    state = {
        "powered": powered,
        "discovering": discovering,
        "connectingMac": connecting_mac,
        "devices": sorted_devs
    }

    print(json.dumps(state))
    sys.stdout.flush()


def stop_discovery_cb():
    global scan_timer_id
    scan_timer_id = 0
    adapter_path = find_adapter_path()
    if adapter_path:
        try:
            adapter_obj = bus.get_object("org.bluez", adapter_path)
            adapter_iface = dbus.Interface(adapter_obj, "org.bluez.Adapter1")
            adapter_iface.StopDiscovery()
        except Exception:
            pass
    print_bluetooth_state()
    return False


def start_discovery():
    global scan_timer_id
    adapter_path = find_adapter_path()
    if not adapter_path:
        return
    try:
        adapter_obj = bus.get_object("org.bluez", adapter_path)
        adapter_iface = dbus.Interface(adapter_obj, "org.bluez.Adapter1")
        adapter_iface.StartDiscovery()
        if scan_timer_id > 0:
            GLib.source_remove(scan_timer_id)
        scan_timer_id = GLib.timeout_add(8000, stop_discovery_cb)
        print_bluetooth_state()
    except Exception as e:
        if "InProgress" in str(e):
            if scan_timer_id > 0:
                GLib.source_remove(scan_timer_id)
            scan_timer_id = GLib.timeout_add(8000, stop_discovery_cb)
        print_bluetooth_state()


def set_power(enabled):
    if enabled:
        subprocess.run(["rfkill", "unblock", "bluetooth"], stderr=subprocess.DEVNULL, stdout=subprocess.DEVNULL)
    adapter_path = find_adapter_path()
    if not adapter_path:
        return
    try:
        adapter_obj = bus.get_object("org.bluez", adapter_path)
        props_iface = dbus.Interface(adapter_obj, "org.freedesktop.DBus.Properties")
        props_iface.Set("org.bluez.Adapter1", "Powered", dbus.Boolean(enabled))
    except Exception:
        subprocess.run(["bluetoothctl", "power", "on" if enabled else "off"], stderr=subprocess.DEVNULL, stdout=subprocess.DEVNULL)
    print_bluetooth_state()


def async_device_op(mac, op):
    global connecting_mac

    def worker():
        global connecting_mac
        try:
            dev_path = find_device_path(mac)
            if op == "connect":
                if dev_path:
                    dev_obj = bus.get_object("org.bluez", dev_path)
                    props_iface = dbus.Interface(dev_obj, "org.freedesktop.DBus.Properties")
                    dev_iface = dbus.Interface(dev_obj, "org.bluez.Device1")
                    try:
                        props_iface.Set("org.bluez.Device1", "Trusted", dbus.Boolean(True))
                    except Exception:
                        pass
                    try:
                        dev_iface.Connect()
                    except Exception:
                        subprocess.run(["bluetoothctl", "connect", mac], stderr=subprocess.DEVNULL, stdout=subprocess.DEVNULL, timeout=12)
                else:
                    subprocess.run(["bluetoothctl", "connect", mac], stderr=subprocess.DEVNULL, stdout=subprocess.DEVNULL, timeout=12)
            elif op == "disconnect":
                if dev_path:
                    dev_obj = bus.get_object("org.bluez", dev_path)
                    dev_iface = dbus.Interface(dev_obj, "org.bluez.Device1")
                    try:
                        dev_iface.Disconnect()
                    except Exception:
                        subprocess.run(["bluetoothctl", "disconnect", mac], stderr=subprocess.DEVNULL, stdout=subprocess.DEVNULL, timeout=8)
                else:
                    subprocess.run(["bluetoothctl", "disconnect", mac], stderr=subprocess.DEVNULL, stdout=subprocess.DEVNULL, timeout=8)
            elif op == "pair":
                if dev_path:
                    dev_obj = bus.get_object("org.bluez", dev_path)
                    props_iface = dbus.Interface(dev_obj, "org.freedesktop.DBus.Properties")
                    dev_iface = dbus.Interface(dev_obj, "org.bluez.Device1")
                    try:
                        dev_iface.Pair()
                    except Exception:
                        subprocess.run(["bluetoothctl", "pair", mac], stderr=subprocess.DEVNULL, stdout=subprocess.DEVNULL, timeout=15)
                    try:
                        props_iface.Set("org.bluez.Device1", "Trusted", dbus.Boolean(True))
                    except Exception:
                        pass
                    try:
                        dev_iface.Connect()
                    except Exception:
                        subprocess.run(["bluetoothctl", "connect", mac], stderr=subprocess.DEVNULL, stdout=subprocess.DEVNULL, timeout=12)
            elif op == "forget":
                adapter_path = find_adapter_path()
                if adapter_path and dev_path:
                    adapter_obj = bus.get_object("org.bluez", adapter_path)
                    adapter_iface = dbus.Interface(adapter_obj, "org.bluez.Adapter1")
                    try:
                        adapter_iface.RemoveDevice(dbus.ObjectPath(dev_path))
                    except Exception:
                        subprocess.run(["bluetoothctl", "remove", mac], stderr=subprocess.DEVNULL, stdout=subprocess.DEVNULL, timeout=8)
                else:
                    subprocess.run(["bluetoothctl", "remove", mac], stderr=subprocess.DEVNULL, stdout=subprocess.DEVNULL, timeout=8)
        finally:
            if connecting_mac.upper() == mac.upper():
                connecting_mac = ""
            GLib.idle_add(lambda: (print_bluetooth_state(), False)[1])

    if op in ("connect", "pair"):
        connecting_mac = mac
        print_bluetooth_state()
    threading.Thread(target=worker, daemon=True).start()


def handle_stdin(channel, cond):
    line = sys.stdin.readline()
    if not line:
        sys.exit(0)
    parts = line.strip().split("|")
    cmd = parts[0]
    arg = parts[1] if len(parts) > 1 else ""

    if cmd == "scan":
        start_discovery()
    elif cmd == "stop_scan":
        stop_discovery_cb()
    elif cmd == "power":
        set_power(arg.lower() == "true")
    elif cmd in ("connect", "disconnect", "pair", "forget") and arg:
        async_device_op(arg, cmd)
    elif cmd == "refresh":
        print_bluetooth_state()
    return True


def properties_changed(interface, changed, invalidated, path):
    if interface in ("org.bluez.Adapter1", "org.bluez.Device1", "org.bluez.Battery1", "org.bluez.MediaControl1", "org.bluez.MediaTransport1"):
        print_bluetooth_state()


def interfaces_added(path, interfaces):
    print_bluetooth_state()


def interfaces_removed(path, interfaces):
    print_bluetooth_state()


# Listen to signals on system bus
bus.add_signal_receiver(
    properties_changed,
    dbus_interface="org.freedesktop.DBus.Properties",
    signal_name="PropertiesChanged",
    path_keyword="path"
)
bus.add_signal_receiver(
    interfaces_added,
    dbus_interface="org.freedesktop.DBus.ObjectManager",
    signal_name="InterfacesAdded"
)
bus.add_signal_receiver(
    interfaces_removed,
    dbus_interface="org.freedesktop.DBus.ObjectManager",
    signal_name="InterfacesRemoved"
)

if __name__ == "__main__":
    print_bluetooth_state()
    if "--once" in sys.argv:
        sys.exit(0)
    GLib.io_add_watch(0, GLib.IO_IN | GLib.IO_HUP, handle_stdin)
    loop = GLib.MainLoop()
    try:
        loop.run()
    except KeyboardInterrupt:
        pass
