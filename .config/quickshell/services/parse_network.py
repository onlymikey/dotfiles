#!/usr/bin/env python3
import sys
import os
import json
import uuid
import socket
import struct
import subprocess
import traceback
import dbus
from dbus.mainloop.glib import DBusGMainLoop
from gi.repository import GLib

# Initialize D-Bus loop
DBusGMainLoop(set_as_default=True)


class NetworkManagerDaemon:
    def __init__(self):
        self.bus = dbus.SystemBus()
        self.nm = self.bus.get_object('org.freedesktop.NetworkManager', '/org/freedesktop/NetworkManager')
        self.nm_props = dbus.Interface(self.nm, 'org.freedesktop.DBus.Properties')
        self.nm_iface = dbus.Interface(self.nm, 'org.freedesktop.NetworkManager')
        self.settings = self.bus.get_object('org.freedesktop.NetworkManager', '/org/freedesktop/NetworkManager/Settings')
        self.settings_iface = dbus.Interface(self.settings, 'org.freedesktop.NetworkManager.Settings')

        self.wifi_device_path = None
        self.wifi_device = None
        self.wifi_iface = None
        self.wifi_device_props = None

        self.ethernet_devices = {}
        self.scanning = False
        self.scan_safety_timer_id = 0
        self.push_debounce_id = 0
        self.last_pushed_json = None

        self.setup_devices()
        self.setup_listeners()
        self.push_state(force=True)

    def clean_val(self, val):
        if isinstance(val, (dbus.String, dbus.UTF8String)):
            return str(val)
        elif isinstance(val, dbus.Boolean):
            return bool(val)
        elif isinstance(val, (dbus.Byte, dbus.Int16, dbus.UInt16, dbus.Int32, dbus.UInt32, dbus.Int64, dbus.UInt64)):
            return int(val)
        elif isinstance(val, dbus.Double):
            return float(val)
        elif isinstance(val, dbus.Array):
            if val.signature == 'y':
                try:
                    return bytes(val).decode('utf-8', errors='ignore')
                except Exception:
                    pass
            return [self.clean_val(x) for x in val]
        elif isinstance(val, dbus.Dictionary):
            return {str(k): self.clean_val(v) for k, v in val.items()}
        elif isinstance(val, dbus.ObjectPath):
            return str(val)
        elif isinstance(val, (bytes, bytearray)):
            return val.decode('utf-8', errors='ignore')
        return val

    def setup_devices(self):
        try:
            devices = self.nm_props.Get('org.freedesktop.NetworkManager', 'Devices')
            self.ethernet_devices.clear()
            self.wifi_device_path = None
            self.wifi_device = None
            self.wifi_iface = None
            self.wifi_device_props = None

            for dev_path in devices:
                dev_obj = self.bus.get_object('org.freedesktop.NetworkManager', dev_path)
                dev_props = dbus.Interface(dev_obj, 'org.freedesktop.DBus.Properties')
                dev_type = int(dev_props.Get('org.freedesktop.NetworkManager.Device', 'DeviceType'))
                dev_iface = str(dev_props.Get('org.freedesktop.NetworkManager.Device', 'Interface'))
                dev_state = int(dev_props.Get('org.freedesktop.NetworkManager.Device', 'State'))

                if dev_type == 2:  # Wi-Fi
                    self.wifi_device_path = str(dev_path)
                    self.wifi_device = dev_obj
                    self.wifi_iface = dbus.Interface(dev_obj, 'org.freedesktop.NetworkManager.Device.Wireless')
                    self.wifi_device_props = dev_props
                elif dev_type == 1:  # Ethernet
                    # Ignore unmanaged virtual/docker veth interfaces
                    if dev_iface.startswith("veth") or dev_state <= 10:
                        continue
                    carrier = False
                    speed = 0
                    try:
                        carrier = bool(dev_props.Get('org.freedesktop.NetworkManager.Device.Wired', 'Carrier'))
                        speed = int(dev_props.Get('org.freedesktop.NetworkManager.Device.Wired', 'Speed'))
                    except Exception:
                        pass
                    self.ethernet_devices[str(dev_path)] = {
                        "path": str(dev_path),
                        "interface": dev_iface,
                        "state": dev_state,
                        "carrier": carrier,
                        "speed": speed
                    }
        except Exception as e:
            sys.stderr.write(f"Error in setup_devices: {e}\n")

    def setup_listeners(self):
        try:
            # Listen to PropertiesChanged across all NetworkManager objects (Manager, Devices, ActiveConnections, IP4Config, APs)
            self.bus.add_signal_receiver(
                self.handle_any_properties_changed,
                signal_name="PropertiesChanged",
                dbus_interface="org.freedesktop.DBus.Properties",
                bus_name="org.freedesktop.NetworkManager",
                path_keyword="path"
            )
            # Monitor device additions/removals
            self.bus.add_signal_receiver(
                self.handle_device_changed,
                signal_name="DeviceAdded",
                dbus_interface="org.freedesktop.NetworkManager"
            )
            self.bus.add_signal_receiver(
                self.handle_device_changed,
                signal_name="DeviceRemoved",
                dbus_interface="org.freedesktop.NetworkManager"
            )
            # Monitor AP additions/removals
            self.bus.add_signal_receiver(
                self.handle_ap_changed,
                signal_name="AccessPointAdded",
                dbus_interface="org.freedesktop.NetworkManager.Device.Wireless"
            )
            self.bus.add_signal_receiver(
                self.handle_ap_changed,
                signal_name="AccessPointRemoved",
                dbus_interface="org.freedesktop.NetworkManager.Device.Wireless"
            )
            # Monitor saved connections changes
            self.bus.add_signal_receiver(
                self.handle_settings_changed,
                signal_name="NewConnection",
                dbus_interface="org.freedesktop.NetworkManager.Settings"
            )
            self.bus.add_signal_receiver(
                self.handle_settings_changed,
                signal_name="ConnectionRemoved",
                dbus_interface="org.freedesktop.NetworkManager.Settings"
            )
            self.bus.add_signal_receiver(
                self.handle_settings_updated,
                signal_name="Updated",
                dbus_interface="org.freedesktop.NetworkManager.Settings.Connection"
            )
        except Exception as e:
            sys.stderr.write(f"Error setting up listeners: {e}\n")

    def schedule_push(self, delay_ms=60):
        if self.push_debounce_id > 0:
            GLib.source_remove(self.push_debounce_id)
        self.push_debounce_id = GLib.timeout_add(delay_ms, self._debounced_push)

    def _debounced_push(self):
        self.push_debounce_id = 0
        self.push_state()
        return False

    def handle_any_properties_changed(self, interface, changed, invalidated, path=None):
        if interface == 'org.freedesktop.NetworkManager.Device.Wireless':
            if 'LastScan' in changed:
                self.scanning = False
                if self.scan_safety_timer_id > 0:
                    GLib.source_remove(self.scan_safety_timer_id)
                    self.scan_safety_timer_id = 0
            if 'AccessPoints' in changed or 'ActiveAccessPoint' in changed or 'LastScan' in changed:
                self.schedule_push(40)
                return

        if interface == 'org.freedesktop.NetworkManager.Device':
            if 'State' in changed:
                new_state = int(changed['State'])
                # When Wi-Fi device transitions from Unavailable (20) to Disconnected (30), trigger a scan automatically
                if path == self.wifi_device_path and new_state == 30:
                    GLib.timeout_add(200, lambda: (self.scan(), False)[1])
            self.schedule_push(40)
            return

        if interface in (
            'org.freedesktop.NetworkManager',
            'org.freedesktop.NetworkManager.Device.Wired',
            'org.freedesktop.NetworkManager.Connection.Active',
            'org.freedesktop.NetworkManager.IP4Config',
            'org.freedesktop.NetworkManager.IP6Config',
            'org.freedesktop.NetworkManager.Settings.Connection'
        ):
            self.schedule_push(50)
        elif interface == 'org.freedesktop.NetworkManager.AccessPoint':
            # Signal strength updates on APs can be frequent; debounce slightly longer
            self.schedule_push(250)

    def handle_device_changed(self, path):
        self.setup_devices()
        self.schedule_push(50)

    def handle_ap_changed(self, path):
        self.schedule_push(100)

    def handle_settings_changed(self, path):
        self.schedule_push(50)

    def handle_settings_updated(self):
        self.schedule_push(50)

    def get_saved_connections(self):
        saved = {}
        try:
            conns = self.settings_iface.ListConnections()
            for conn_path in conns:
                try:
                    conn_obj = self.bus.get_object('org.freedesktop.NetworkManager', conn_path)
                    conn_iface = dbus.Interface(conn_obj, 'org.freedesktop.NetworkManager.Settings.Connection')
                    settings_dict = conn_iface.GetSettings()

                    connection_details = settings_dict.get('connection', {})
                    cid = str(connection_details.get('id', ''))
                    ctype = str(connection_details.get('type', ''))
                    uuid_str = str(connection_details.get('uuid', ''))
                    autoconnect = bool(connection_details.get('autoconnect', True))
                    timestamp = int(connection_details.get('timestamp', 0))

                    if ctype == '802-11-wireless':
                        wifi_details = settings_dict.get('802-11-wireless', {})
                        ssid_bytes = wifi_details.get('ssid')
                        ssid = ""
                        if ssid_bytes:
                            ssid = bytes(ssid_bytes).decode('utf-8', errors='ignore')
                        if not ssid:
                            ssid = cid

                        security_details = settings_dict.get('802-11-wireless-security', {})
                        key_mgmt = str(security_details.get('key-mgmt', '')).lower()

                        sec_type = "Open"
                        if "sae" in key_mgmt:
                            sec_type = "WPA3"
                        elif "wpa-eap" in key_mgmt or "enterprise" in key_mgmt:
                            sec_type = "Enterprise"
                        elif "wpa" in key_mgmt:
                            sec_type = "WPA2"
                        elif "wep" in key_mgmt or "none" in key_mgmt:
                            sec_type = "WEP"

                        # Prefer the most recently used profile if duplicate profiles exist for the same SSID
                        if ssid not in saved or timestamp >= saved[ssid].get("timestamp", 0):
                            saved[ssid] = {
                                "ssid": ssid,
                                "name": cid,
                                "path": str(conn_path),
                                "uuid": uuid_str,
                                "autoconnect": autoconnect,
                                "security": sec_type,
                                "timestamp": timestamp
                            }
                except Exception:
                    pass
        except Exception as e:
            sys.stderr.write(f"Error fetching saved connections: {e}\n")
        return saved

    def decode_security(self, rsn, wpa, flags=0):
        if rsn & 1024:
            return "WPA3"
        elif (rsn & 512) or (wpa & 512):
            return "Enterprise"
        elif rsn > 0:
            return "WPA2"
        elif wpa > 0:
            return "WPA"
        elif flags & 1:
            return "WEP"
        return "Open"

    def decode_frequency(self, freq):
        if 4900 <= freq <= 5900:
            return "5 GHz"
        elif 2400 <= freq <= 2500:
            return "2.4 GHz"
        elif freq > 5900:
            return "6 GHz"
        return ""

    def get_signal_quality(self, strength):
        if strength >= 75:
            return "Excellent"
        elif strength >= 50:
            return "Good"
        elif strength >= 25:
            return "Fair"
        return "Weak"

    def get_active_vpn_connections(self):
        vpns = []
        try:
            active_conns = self.nm_props.Get('org.freedesktop.NetworkManager', 'ActiveConnections')
            for conn_path in active_conns:
                conn_obj = self.bus.get_object('org.freedesktop.NetworkManager', conn_path)
                conn_props = dbus.Interface(conn_obj, 'org.freedesktop.DBus.Properties')
                cid = str(conn_props.Get('org.freedesktop.NetworkManager.Connection.Active', 'Id'))
                ctype = str(conn_props.Get('org.freedesktop.NetworkManager.Connection.Active', 'Type'))
                cstate = int(conn_props.Get('org.freedesktop.NetworkManager.Connection.Active', 'State'))

                if ctype in ('vpn', 'tun', 'wireguard') or cid.startswith('tailscale') or cid.startswith('wg'):
                    vpns.append({
                        "name": cid,
                        "type": ctype,
                        "connected": cstate == 2
                    })
        except Exception as e:
            sys.stderr.write(f"Error fetching VPNs: {e}\n")
        return vpns

    def get_ip_details(self, dev_path, dev_props):
        details = {
            "ipv4": "",
            "ipv6": "",
            "gateway": "",
            "dns": [],
            "mac": ""
        }
        try:
            details["mac"] = str(dev_props.Get('org.freedesktop.NetworkManager.Device', 'HwAddress'))
        except Exception:
            pass

        try:
            ip4_path = dev_props.Get('org.freedesktop.NetworkManager.Device', 'Ip4Config')
            if ip4_path and str(ip4_path) != '/':
                ip4_obj = self.bus.get_object('org.freedesktop.NetworkManager', ip4_path)
                ip4_props = dbus.Interface(ip4_obj, 'org.freedesktop.DBus.Properties')

                addr_data = ip4_props.Get('org.freedesktop.NetworkManager.IP4Config', 'AddressData')
                if addr_data and len(addr_data) > 0:
                    details["ipv4"] = str(addr_data[0].get('address', ''))

                try:
                    gw = str(ip4_props.Get('org.freedesktop.NetworkManager.IP4Config', 'Gateway'))
                    if gw:
                        details["gateway"] = gw
                except Exception:
                    pass

                try:
                    dns_vals = ip4_props.Get('org.freedesktop.NetworkManager.IP4Config', 'Nameservers')
                    dns_list = []
                    for d in dns_vals:
                        try:
                            dns_list.append(socket.inet_ntoa(struct.pack('<I', int(d))))
                        except Exception:
                            dns_list.append(str(d))
                    details["dns"] = dns_list
                except Exception:
                    pass
        except Exception as e:
            sys.stderr.write(f"Error getting ip4 details: {e}\n")

        try:
            ip6_path = dev_props.Get('org.freedesktop.NetworkManager.Device', 'Ip6Config')
            if ip6_path and str(ip6_path) != '/':
                ip6_obj = self.bus.get_object('org.freedesktop.NetworkManager', ip6_path)
                ip6_props = dbus.Interface(ip6_obj, 'org.freedesktop.DBus.Properties')

                addr_data = ip6_props.Get('org.freedesktop.NetworkManager.IP6Config', 'AddressData')
                if addr_data and len(addr_data) > 0:
                    details["ipv6"] = str(addr_data[0].get('address', ''))

                if not details["gateway"]:
                    try:
                        gateway6 = ip6_props.Get('org.freedesktop.NetworkManager.IP6Config', 'Gateway')
                        if gateway6:
                            if isinstance(gateway6, (dbus.String, str)):
                                details["gateway"] = str(gateway6)
                            else:
                                ip6_bytes = bytes(gateway6)
                                if len(ip6_bytes) == 16:
                                    details["gateway"] = socket.inet_ntop(socket.AF_INET6, ip6_bytes)
                    except Exception:
                        pass
        except Exception as e:
            sys.stderr.write(f"Error getting ip6 details: {e}\n")

        return details

    def get_active_wifi_connection_ssid(self):
        if not self.wifi_device_props:
            return None
        try:
            dev_state = int(self.wifi_device_props.Get('org.freedesktop.NetworkManager.Device', 'State'))
            if dev_state != 100:  # NM_DEVICE_STATE_ACTIVATED
                return None
            act_conn_path = self.wifi_device_props.Get('org.freedesktop.NetworkManager.Device', 'ActiveConnection')
            if not act_conn_path or str(act_conn_path) == '/':
                return None
            act_obj = self.bus.get_object('org.freedesktop.NetworkManager', act_conn_path)
            act_props = dbus.Interface(act_obj, 'org.freedesktop.DBus.Properties')
            conn_path = act_props.Get('org.freedesktop.NetworkManager.Connection.Active', 'Connection')
            if conn_path and str(conn_path) != '/':
                conn_obj = self.bus.get_object('org.freedesktop.NetworkManager', conn_path)
                conn_iface = dbus.Interface(conn_obj, 'org.freedesktop.NetworkManager.Settings.Connection')
                s_dict = conn_iface.GetSettings()
                w_dict = s_dict.get('802-11-wireless', {})
                if 'ssid' in w_dict:
                    return bytes(w_dict['ssid']).decode('utf-8', errors='ignore')
            return str(act_props.Get('org.freedesktop.NetworkManager.Connection.Active', 'Id'))
        except Exception:
            return None

    def fetch_wifi_networks(self, saved_connections):
        networks = {}
        active_ap_path = None
        active_conn_ssid = self.get_active_wifi_connection_ssid()

        if not self.wifi_iface or not self.wifi_device_props:
            return [], None

        try:
            ap_val = str(self.wifi_device_props.Get('org.freedesktop.NetworkManager.Device.Wireless', 'ActiveAccessPoint'))
            if ap_val and ap_val != '/':
                active_ap_path = ap_val
        except Exception:
            pass

        try:
            aps = self.wifi_iface.GetAllAccessPoints()
            for ap_path in aps:
                try:
                    ap_obj = self.bus.get_object('org.freedesktop.NetworkManager', ap_path)
                    ap_props = dbus.Interface(ap_obj, 'org.freedesktop.DBus.Properties')

                    ssid_bytes = ap_props.Get('org.freedesktop.NetworkManager.AccessPoint', 'Ssid')
                    ssid = bytes(ssid_bytes).decode('utf-8', errors='ignore')
                    if not ssid:
                        continue

                    strength = int(ap_props.Get('org.freedesktop.NetworkManager.AccessPoint', 'Strength'))
                    freq = int(ap_props.Get('org.freedesktop.NetworkManager.AccessPoint', 'Frequency'))
                    rsn = int(ap_props.Get('org.freedesktop.NetworkManager.AccessPoint', 'RsnFlags'))
                    wpa = int(ap_props.Get('org.freedesktop.NetworkManager.AccessPoint', 'WpaFlags'))
                    flags = int(ap_props.Get('org.freedesktop.NetworkManager.AccessPoint', 'Flags'))

                    sec = self.decode_security(rsn, wpa, flags)
                    band = self.decode_frequency(freq)
                    quality = self.get_signal_quality(strength)
                    is_saved = ssid in saved_connections
                    autoconnect = saved_connections[ssid]["autoconnect"] if is_saved else True

                    is_active = (str(ap_path) == active_ap_path) or (not active_ap_path and active_conn_ssid == ssid)

                    # Critical fix: never let a stronger non-active BSSID overwrite the currently active BSSID!
                    should_replace = False
                    if ssid not in networks:
                        should_replace = True
                    elif is_active and not networks[ssid]["active"]:
                        should_replace = True
                    elif is_active == networks[ssid]["active"] and strength > networks[ssid]["signal"]:
                        should_replace = True

                    if should_replace:
                        networks[ssid] = {
                            "ssid": ssid,
                            "signal": strength,
                            "quality": quality,
                            "security": sec,
                            "frequency": band,
                            "saved": is_saved,
                            "autoconnect": autoconnect,
                            "active": is_active
                        }
                except Exception:
                    pass
        except Exception as e:
            sys.stderr.write(f"Error fetching APs: {e}\n")

        # Fallback if connected to Wi-Fi but AP list hasn't populated the active AP yet
        if active_conn_ssid and not any(n["active"] for n in networks.values()):
            is_saved = active_conn_ssid in saved_connections
            saved_info = saved_connections.get(active_conn_ssid, {})
            if active_conn_ssid in networks:
                networks[active_conn_ssid]["active"] = True
            else:
                networks[active_conn_ssid] = {
                    "ssid": active_conn_ssid,
                    "signal": 80,
                    "quality": "Good",
                    "security": saved_info.get("security", "WPA2"),
                    "frequency": "",
                    "saved": is_saved,
                    "autoconnect": saved_info.get("autoconnect", True),
                    "active": True
                }

        avail_list = []
        connected_ap_details = None

        for ssid, net in networks.items():
            if net["active"]:
                connected_ap_details = net
            else:
                avail_list.append(net)

        avail_list.sort(key=lambda x: (not x["saved"], -x["signal"]))
        return avail_list, connected_ap_details

    def build_network_state(self):
        try:
            self.setup_devices()
            wifi_enabled = bool(self.nm_props.Get('org.freedesktop.NetworkManager', 'WirelessEnabled'))
            saved_conns = self.get_saved_connections()
            avail_nets, connected_net = self.fetch_wifi_networks(saved_conns)

            if connected_net and self.wifi_device_props:
                ip_info = self.get_ip_details(self.wifi_device_path, self.wifi_device_props)
                connected_net.update(ip_info)

            eth_list = []
            ethernet_enabled = False
            for path, dev in self.ethernet_devices.items():
                dev_ip_info = {}
                try:
                    dev_obj = self.bus.get_object('org.freedesktop.NetworkManager', path)
                    dev_props = dbus.Interface(dev_obj, 'org.freedesktop.DBus.Properties')
                    dev["state"] = int(dev_props.Get('org.freedesktop.NetworkManager.Device', 'State'))
                    dev["carrier"] = bool(dev_props.Get('org.freedesktop.NetworkManager.Device.Wired', 'Carrier'))
                    dev["speed"] = int(dev_props.Get('org.freedesktop.NetworkManager.Device.Wired', 'Speed'))
                    dev_ip_info = self.get_ip_details(path, dev_props)
                except Exception:
                    pass

                is_conn = (dev["state"] == 100)
                eth_list.append({
                    "interface": dev["interface"],
                    "connected": is_conn,
                    "carrier": dev["carrier"],
                    "speed": f"{dev['speed']} Mbps" if dev["carrier"] and dev["speed"] > 0 else "0 Mbps",
                    "details": dev_ip_info
                })
                if is_conn:
                    ethernet_enabled = True

            vpn_list = self.get_active_vpn_connections()
            # Only report airplaneMode when both Wi-Fi and Ethernet are inactive/disabled
            airplane_mode = (not wifi_enabled) and (not ethernet_enabled)

            return {
                "wifiEnabled": wifi_enabled,
                "ethernetEnabled": ethernet_enabled,
                "wifiScanning": self.scanning,
                "connectedNetwork": connected_net,
                "availableNetworks": avail_nets,
                "savedNetworks": list(saved_conns.values()),
                "ethernetDevices": eth_list,
                "vpnConnections": vpn_list,
                "airplaneMode": airplane_mode
            }
        except Exception as e:
            sys.stderr.write(f"Error building state: {str(e)}\n{traceback.format_exc()}\n")
            return {}

    def push_state(self, force=False):
        state = self.build_network_state()
        if not state:
            return
        state_json = json.dumps(state)
        if force or state_json != self.last_pushed_json:
            self.last_pushed_json = state_json
            sys.stdout.write(state_json + "\n")
            sys.stdout.flush()

    def handle_scan_safety_timeout(self):
        self.scanning = False
        self.scan_safety_timer_id = 0
        self.push_state(force=True)
        return False

    def scan(self):
        if not self.wifi_iface:
            self.setup_devices()
        if not self.wifi_iface or self.scanning:
            return
        try:
            self.scanning = True
            self.push_state(force=True)
            self.wifi_iface.RequestScan(dbus.Dictionary({}, signature='sv'))
            if self.scan_safety_timer_id > 0:
                GLib.source_remove(self.scan_safety_timer_id)
            self.scan_safety_timer_id = GLib.timeout_add(8000, self.handle_scan_safety_timeout)
        except Exception as e:
            sys.stderr.write(f"Scan failed: {e}\n")
            self.scanning = False
            self.push_state(force=True)

    def connect(self, ssid, password):
        if not self.wifi_device_path:
            self.setup_devices()
        if not self.wifi_device_path:
            return

        saved_conns = self.get_saved_connections()
        try:
            if ssid in saved_conns and not password:
                profile_path = saved_conns[ssid]["path"]
                self.nm_iface.ActivateConnection(
                    dbus.ObjectPath(profile_path),
                    dbus.ObjectPath(self.wifi_device_path),
                    dbus.ObjectPath('/')
                )
            else:
                # Use nmcli for new connections or password updates so WPA2/WPA3 (SAE) negotiation is handled natively by NM
                cmd = ["nmcli", "device", "wifi", "connect", ssid]
                if password:
                    cmd += ["password", password]
                subprocess.Popen(
                    cmd,
                    stdout=subprocess.DEVNULL,
                    stderr=subprocess.DEVNULL
                )
            self.schedule_push(300)
            GLib.timeout_add(1500, lambda: (self.push_state(force=True), False)[1])
        except Exception as e:
            sys.stderr.write(f"Connection failed: {e}\n")
            self.push_state(force=True)

    def disconnect(self):
        if not self.wifi_device:
            return
        try:
            wifi_dev_iface = dbus.Interface(self.wifi_device, 'org.freedesktop.NetworkManager.Device')
            wifi_dev_iface.Disconnect()
            self.schedule_push(100)
        except Exception as e:
            sys.stderr.write(f"Disconnect failed: {e}\n")

    def forget(self, ssid):
        try:
            conns = self.settings_iface.ListConnections()
            for conn_path in conns:
                conn_obj = self.bus.get_object('org.freedesktop.NetworkManager', conn_path)
                conn_iface = dbus.Interface(conn_obj, 'org.freedesktop.NetworkManager.Settings.Connection')
                settings_dict = conn_iface.GetSettings()
                connection_details = settings_dict.get('connection', {})
                cid = str(connection_details.get('id', ''))
                ctype = str(connection_details.get('type', ''))

                if ctype == '802-11-wireless':
                    wifi_details = settings_dict.get('802-11-wireless', {})
                    ssid_bytes = wifi_details.get('ssid')
                    conn_ssid = ""
                    if ssid_bytes:
                        conn_ssid = bytes(ssid_bytes).decode('utf-8', errors='ignore')

                    if conn_ssid == ssid or cid == ssid:
                        conn_iface.Delete()
            self.push_state(force=True)
        except Exception as e:
            sys.stderr.write(f"Forget failed: {e}\n")

    def toggle_wifi(self, enabled):
        try:
            if enabled:
                subprocess.run(["rfkill", "unblock", "wifi"], stderr=subprocess.DEVNULL, stdout=subprocess.DEVNULL)
            self.nm_props.Set(
                'org.freedesktop.NetworkManager',
                'WirelessEnabled',
                dbus.Boolean(enabled)
            )
            self.schedule_push(100)
            if enabled:
                GLib.timeout_add(800, lambda: (self.scan(), False)[1])
        except Exception as e:
            sys.stderr.write(f"Toggle wifi failed: {e}\n")

    def toggle_ethernet(self, interface, enabled):
        try:
            cmd = "connect" if enabled else "disconnect"
            subprocess.Popen(
                ["nmcli", "device", cmd, interface],
                stdout=subprocess.DEVNULL,
                stderr=subprocess.DEVNULL
            )
            self.schedule_push(200)
        except Exception as e:
            sys.stderr.write(f"Toggle ethernet failed: {e}\n")

    def toggle_autoconnect(self, ssid, enabled):
        try:
            saved_conns = self.get_saved_connections()
            val = "yes" if enabled else "no"
            if ssid in saved_conns and saved_conns[ssid].get("uuid"):
                # Using nmcli connection modify preserves saved Wi-Fi secrets (PSK) that GetSettings()+Update() would wipe
                subprocess.run(
                    ["nmcli", "connection", "modify", "uuid", saved_conns[ssid]["uuid"], "connection.autoconnect", val],
                    stdout=subprocess.DEVNULL,
                    stderr=subprocess.DEVNULL
                )
            else:
                subprocess.run(
                    ["nmcli", "connection", "modify", ssid, "connection.autoconnect", val],
                    stdout=subprocess.DEVNULL,
                    stderr=subprocess.DEVNULL
                )
            self.push_state(force=True)
        except Exception as e:
            sys.stderr.write(f"Toggle autoconnect failed: {e}\n")


def handle_stdin(channel, cond, daemon):
    line = sys.stdin.readline()
    if not line:
        sys.exit(0)

    parts = line.strip().split('|')
    cmd = parts[0]

    try:
        if cmd == "scan":
            daemon.scan()
        elif cmd == "refresh":
            daemon.push_state(force=True)
        elif cmd == "connect":
            ssid = parts[1]
            password = parts[2] if len(parts) > 2 else ""
            daemon.connect(ssid, password)
        elif cmd == "disconnect":
            daemon.disconnect()
        elif cmd == "forget":
            ssid = parts[1]
            daemon.forget(ssid)
        elif cmd == "toggle_wifi":
            enabled = parts[1] == "true"
            daemon.toggle_wifi(enabled)
        elif cmd == "toggle_ethernet":
            iface = parts[1]
            enabled = parts[2] == "true"
            daemon.toggle_ethernet(iface, enabled)
        elif cmd == "toggle_autoconnect":
            ssid = parts[1]
            enabled = parts[2] == "true"
            daemon.toggle_autoconnect(ssid, enabled)
    except Exception as e:
        sys.stderr.write(f"Command error: {e}\n")
    return True


if __name__ == "__main__":
    daemon = NetworkManagerDaemon()
    if "--once" in sys.argv:
        sys.exit(0)
    GLib.io_add_watch(0, GLib.IO_IN | GLib.IO_HUP, handle_stdin, daemon)
    loop = GLib.MainLoop()
    try:
        loop.run()
    except KeyboardInterrupt:
        pass
