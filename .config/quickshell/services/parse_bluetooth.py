#!/usr/bin/env python3
import sys
import json
import dbus
from dbus.mainloop.glib import DBusGMainLoop
from gi.repository import GLib

# Set up the D-Bus main loop for python-dbus
DBusGMainLoop(set_as_default=True)
try:
    bus = dbus.SystemBus()
except Exception as e:
    print(json.dumps({"powered": False, "discovering": False, "devices": []}))
    sys.exit(1)

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
    # Default fallback values
    device_type = "unknown"
    icon = "󰂲" # generic bluetooth disconnected / paired
    
    icon_prop = properties.get("Icon")
    class_prop = properties.get("Class")
    uuids_prop = properties.get("UUIDs", [])
    name_prop = properties.get("Name", properties.get("Alias", ""))
    
    # 1. Parse Class (CoD) first if available to get precise type for fallback/specialization
    cod_type = None
    cod_icon = None
    if class_prop:
        cod = int(class_prop)
        major_class = (cod >> 8) & 0x1F
        minor_class = (cod >> 2) & 0x3F
        
        if major_class == 0x01: # Computer
            cod_type = "computer"
            cod_icon = "󰌢"
        elif major_class == 0x02: # Phone
            cod_type = "phone"
            cod_icon = "󰏲"
        elif major_class == 0x04: # Audio/Video
            if minor_class in (0x01, 0x02, 0x06, 0x07): # Headset, Handsfree, Headphones, Portable Audio
                cod_type = "headphones"
                cod_icon = "󰋋"
            elif minor_class in (0x14, 0x18): # HiFi, Loudspeaker
                cod_type = "speaker"
                cod_icon = "󰓃"
            elif minor_class in (0x09, 0x0a, 0x0b, 0x0c): # Set-top box, TV, Reflector, etc.
                cod_type = "tv"
                cod_icon = "󰍹"
            else:
                cod_type = "audio"
                cod_icon = "󰋋"
        elif major_class == 0x05: # Peripheral
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
                if sub_class in (0x01, 0x02, 0x03, 0x04): # Joystick, Gamepad
                    cod_type = "gamepad"
                    cod_icon = "󰖺"
                else:
                    cod_type = "peripheral"
                    cod_icon = "󰖺"
        elif major_class == 0x07: # Wearable
            cod_type = "wearable"
            cod_icon = "󰥍"

    # 2. Check specific native Icon property from BlueZ
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
            # Generic A/V card: specialize using CoD if CoD found tv/speaker/headphones
            if cod_type in ("headphones", "speaker", "tv"):
                device_type = cod_type
                icon = cod_icon
            else:
                device_type = "audio"
                icon = "󰋋"

    # 3. Fallback to CoD if no specific Icon matched
    if device_type == "unknown" or icon == "󰂲":
        if cod_type:
            device_type = cod_type
            icon = cod_icon

    # 4. Fallback to Service UUIDs (lowest priority now)
    if device_type == "unknown" or icon == "󰂲":
        for uuid in uuids_prop:
            uuid_str = str(uuid).lower()
            if "1124" in uuid_str: # HID
                device_type = "keyboard"
                icon = "󰌌"
                break
            elif "110b" in uuid_str or "110d" in uuid_str or "1108" in uuid_str or "111e" in uuid_str: # A2DP / Handsfree
                device_type = "headphones"
                icon = "󰋋"
                break

    # 5. Fallback based on name keywords
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
        elif "headphone" in name_lower or "headset" in name_lower or "buds" in name_lower or "wh-" in name_lower or "wf-" in name_lower or "auricular" in name_lower:
            device_type = "headphones"
            icon = "󰋋"
        elif "speaker" in name_lower or "parlante" in name_lower or "audio" in name_lower:
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
    # Sort alphabetically first (stable sort)
    devices.sort(key=lambda x: x['name'].lower())
    # Then sort by paired state (paired devices first)
    devices.sort(key=lambda x: x['paired'], reverse=True)
    # Then sort by connected state (connected devices first)
    devices.sort(key=lambda x: x['connected'], reverse=True)
    return devices

def print_bluetooth_state():
    try:
        bluez_obj = bus.get_object('org.bluez', '/')
        manager = dbus.Interface(bluez_obj, 'org.freedesktop.DBus.ObjectManager')
        objects = dbus_to_python(manager.GetManagedObjects())
    except Exception as e:
        print(json.dumps({"powered": False, "discovering": False, "devices": []}))
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
                
            paired = dev_props.get("Paired", False)
            connected = dev_props.get("Connected", False)
            rssi = dev_props.get("RSSI", None)
            
            # Check battery level if available
            battery = None
            if "org.bluez.Battery1" in interfaces:
                battery = interfaces["org.bluez.Battery1"].get("Percentage", None)
                
            device_type, icon = get_device_info(dev_props)
            signal_str = get_rssi_strength(rssi)
            
            devices.append({
                "mac": mac,
                "name": name,
                "paired": paired,
                "connected": connected,
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
        "devices": sorted_devs
    }
    
    print(json.dumps(state))

def properties_changed(interface, changed, invalidated, path):
    if interface in ("org.bluez.Adapter1", "org.bluez.Device1", "org.bluez.Battery1"):
        print_bluetooth_state()
        sys.stdout.flush()

def interfaces_added(path, interfaces):
    print_bluetooth_state()
    sys.stdout.flush()

def interfaces_removed(path, interfaces):
    print_bluetooth_state()
    sys.stdout.flush()

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

# Print initial state
print_bluetooth_state()
sys.stdout.flush()

# Start GLib main loop
loop = GLib.MainLoop()
try:
    loop.run()
except KeyboardInterrupt:
    pass
