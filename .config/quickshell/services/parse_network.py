#!/usr/bin/env python3
import sys
import os
import json
import uuid
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
        
        self.ethernet_devices = {}  # path -> {iface, state, carrier, speed}
        self.scanning = False
        self.scan_safety_timer_id = 0
        
        self.setup_devices()
        self.setup_listeners()
        self.push_state()

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
            # Monitor NM manager property changes
            self.bus.add_signal_receiver(
                self.handle_manager_properties_changed,
                signal_name="PropertiesChanged",
                dbus_interface="org.freedesktop.DBus.Properties",
                path="/org/freedesktop/NetworkManager"
            )
            # Monitor device additions/removals
            self.bus.add_signal_receiver(
                self.handle_device_added,
                signal_name="DeviceAdded",
                dbus_interface="org.freedesktop.NetworkManager",
                path="/org/freedesktop/NetworkManager"
            )
            self.bus.add_signal_receiver(
                self.handle_device_removed,
                signal_name="DeviceRemoved",
                dbus_interface="org.freedesktop.NetworkManager",
                path="/org/freedesktop/NetworkManager"
            )
            # Monitor wifi device property changes
            if self.wifi_device_path:
                self.bus.add_signal_receiver(
                    self.handle_wifi_properties_changed,
                    signal_name="PropertiesChanged",
                    dbus_interface="org.freedesktop.DBus.Properties",
                    path=self.wifi_device_path
                )
        except Exception as e:
            sys.stderr.write(f"Error setting up listeners: {e}\n")

    def handle_manager_properties_changed(self, interface, changed, invalidated):
        if interface == 'org.freedesktop.NetworkManager':
            self.push_state()

    def handle_device_added(self, path):
        self.setup_devices()
        self.push_state()

    def handle_device_removed(self, path):
        self.setup_devices()
        self.push_state()

    def handle_wifi_properties_changed(self, interface, changed, invalidated):
        if interface == 'org.freedesktop.NetworkManager.Device.Wireless':
            if 'LastScan' in changed:
                self.scanning = False
                if self.scan_safety_timer_id > 0:
                    GLib.source_remove(self.scan_safety_timer_id)
                    self.scan_safety_timer_id = 0
            self.push_state()
        elif interface == 'org.freedesktop.NetworkManager.Device':
            self.push_state()

    def get_saved_connections(self):
        saved = {}
        try:
            conns = self.settings_iface.ListConnections()
            for conn_path in conns:
                conn_obj = self.bus.get_object('org.freedesktop.NetworkManager', conn_path)
                conn_iface = dbus.Interface(conn_obj, 'org.freedesktop.NetworkManager.Settings.Connection')
                settings_dict = conn_iface.GetSettings()
                
                connection_details = settings_dict.get('connection', {})
                cid = str(connection_details.get('id', ''))
                ctype = str(connection_details.get('type', ''))
                uuid_str = str(connection_details.get('uuid', ''))
                autoconnect = bool(connection_details.get('autoconnect', True))
                
                if ctype == '802-11-wireless':
                    wifi_details = settings_dict.get('802-11-wireless', {})
                    ssid_bytes = wifi_details.get('ssid')
                    ssid = ""
                    if ssid_bytes:
                        ssid = bytes(ssid_bytes).decode('utf-8', errors='ignore')
                    
                    security_details = settings_dict.get('802-11-wireless-security', {})
                    key_mgmt = str(security_details.get('key-mgmt', ''))
                    
                    sec_type = "Open"
                    if "wpa" in key_mgmt:
                        sec_type = "WPA3" if "sae" in key_mgmt else "WPA2"
                    elif "wep" in key_mgmt:
                        sec_type = "WEP"
                    elif "enterprise" in key_mgmt:
                        sec_type = "Enterprise"
                        
                    saved[ssid] = {
                        "ssid": ssid,
                        "name": cid,
                        "path": str(conn_path),
                        "uuid": uuid_str,
                        "autoconnect": autoconnect,
                        "security": sec_type
                    }
        except Exception as e:
            sys.stderr.write(f"Error fetching saved connections: {e}\n")
        return saved

    def decode_security(self, rsn, wpa):
        if rsn & 1024:
            return "WPA3"
        elif rsn & 512:
            return "Enterprise"
        elif rsn & 256:
            return "WPA2"
        elif wpa & 256:
            return "WPA"
        elif wpa & 2:
            return "WEP"
        return "Open"

    def decode_frequency(self, freq):
        if 4900 <= freq <= 5900:
            return "5 GHz"
        elif 2400 <= freq <= 2500:
            return "2.4 GHz"
        return "6 GHz"

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
            if ip4_path and ip4_path != '/':
                ip4_obj = self.bus.get_object('org.freedesktop.NetworkManager', ip4_path)
                ip4_props = dbus.Interface(ip4_obj, 'org.freedesktop.DBus.Properties')
                
                addr_data = ip4_props.Get('org.freedesktop.NetworkManager.IP4Config', 'AddressData')
                if addr_data and len(addr_data) > 0:
                    details["ipv4"] = str(addr_data[0].get('address', ''))
                
                try:
                    details["gateway"] = str(ip4_props.Get('org.freedesktop.NetworkManager.IP4Config', 'Gateway'))
                except Exception:
                    pass
                    
                try:
                    dns_vals = ip4_props.Get('org.freedesktop.NetworkManager.IP4Config', 'Nameservers')
                    import socket, struct
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
            if ip6_path and ip6_path != '/':
                ip6_obj = self.bus.get_object('org.freedesktop.NetworkManager', ip6_path)
                ip6_props = dbus.Interface(ip6_obj, 'org.freedesktop.DBus.Properties')
                
                addr_data = ip6_props.Get('org.freedesktop.NetworkManager.IP6Config', 'AddressData')
                if addr_data and len(addr_data) > 0:
                    details["ipv6"] = str(addr_data[0].get('address', ''))
                
                try:
                    gateway6 = ip6_props.Get('org.freedesktop.NetworkManager.IP6Config', 'Gateway')
                    if gateway6:
                        import socket
                        ip6_bytes = bytes(gateway6)
                        if len(ip6_bytes) == 16:
                            details["gateway"] = socket.inet_ntop(socket.AF_INET6, ip6_bytes)
                except Exception:
                    pass
        except Exception as e:
            sys.stderr.write(f"Error getting ip6 details: {e}\n")
            
        return details

    def fetch_wifi_networks(self, saved_connections):
        networks = {}
        active_ssid = ""
        active_ap_path = None
        
        if not self.wifi_iface:
            return [], None
            
        try:
            active_ap_path = str(self.wifi_device_props.Get('org.freedesktop.NetworkManager.Device.Wireless', 'ActiveAccessPoint'))
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
                    
                    sec = self.decode_security(rsn, wpa)
                    band = self.decode_frequency(freq)
                    quality = self.get_signal_quality(strength)
                    is_saved = ssid in saved_connections
                    autoconnect = saved_connections[ssid]["autoconnect"] if is_saved else True
                    
                    is_active = (str(ap_path) == active_ap_path)
                    if is_active:
                        active_ssid = ssid
                    
                    if ssid not in networks or strength > networks[ssid]["signal"]:
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
            wifi_enabled = bool(self.nm_props.Get('org.freedesktop.NetworkManager', 'WirelessEnabled'))
            saved_conns = self.get_saved_connections()
            avail_nets, connected_net = self.fetch_wifi_networks(saved_conns)
            
            # Extract IP details for active Wi-Fi
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
                
                eth_list.append({
                    "interface": dev["interface"],
                    "connected": dev["state"] == 100,
                    "carrier": dev["carrier"],
                    "speed": f"{dev['speed']} Mbps" if dev["carrier"] and dev["speed"] > 0 else "0 Mbps",
                    "details": dev_ip_info
                })
                if dev["state"] == 100 or dev["carrier"]:
                    ethernet_enabled = True

            vpn_list = self.get_active_vpn_connections()
            airplane_mode = not wifi_enabled

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

    def push_state(self):
        state = self.build_network_state()
        sys.stdout.write(json.dumps(state) + "\n")
        sys.stdout.flush()

    def handle_scan_safety_timeout(self):
        self.scanning = False
        self.scan_safety_timer_id = 0
        self.push_state()
        return False

    def scan(self):
        if not self.wifi_iface:
            return
        if self.scanning:
            return
        try:
            self.scanning = True
            self.wifi_iface.RequestScan(dbus.Dictionary({}, signature='sv'))
            if self.scan_safety_timer_id > 0:
                GLib.source_remove(self.scan_safety_timer_id)
            self.scan_safety_timer_id = GLib.timeout_add(10000, self.handle_scan_safety_timeout)
            self.push_state()
        except Exception as e:
            sys.stderr.write(f"Scan failed: {e}\n")
            self.scanning = False
            self.push_state()

    def connect(self, ssid, password):
        if not self.wifi_device_path:
            return
            
        saved_conns = self.get_saved_connections()
        try:
            if ssid in saved_conns:
                profile_path = saved_conns[ssid]["path"]
                self.nm_iface.ActivateConnection(
                    dbus.ObjectPath(profile_path),
                    dbus.ObjectPath(self.wifi_device_path),
                    dbus.ObjectPath('/')
                )
            else:
                s_con = {
                    'connection': {
                        'id': ssid,
                        'type': '802-11-wireless',
                        'uuid': str(uuid.uuid4()),
                        'autoconnect': True
                    },
                    '802-11-wireless': {
                        'ssid': dbus.ByteArray(ssid.encode('utf-8')),
                        'mode': 'infrastructure'
                    }
                }
                if password:
                    s_con['802-11-wireless-security'] = {
                        'key-mgmt': 'wpa-psk',
                        'psk': password
                    }
                self.nm_iface.AddAndActivateConnection(
                    s_con,
                    dbus.ObjectPath(self.wifi_device_path),
                    dbus.ObjectPath('/')
                )
        except Exception as e:
            sys.stderr.write(f"Connection failed: {e}\n")

    def disconnect(self):
        if not self.wifi_device:
            return
        try:
            wifi_dev_iface = dbus.Interface(self.wifi_device, 'org.freedesktop.NetworkManager.Device')
            wifi_dev_iface.Disconnect()
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
            self.push_state()
        except Exception as e:
            sys.stderr.write(f"Forget failed: {e}\n")

    def toggle_wifi(self, enabled):
        try:
            self.nm_props.Set(
                'org.freedesktop.NetworkManager',
                'WirelessEnabled',
                dbus.Boolean(enabled)
            )
            self.push_state()
        except Exception as e:
            sys.stderr.write(f"Toggle wifi failed: {e}\n")

    def toggle_ethernet(self, interface, enabled):
        try:
            cmd = "connect" if enabled else "disconnect"
            os.system(f"nmcli device {cmd} {interface} >/dev/null 2>&1")
            self.push_state()
        except Exception as e:
            sys.stderr.write(f"Toggle ethernet failed: {e}\n")

    def toggle_autoconnect(self, ssid, enabled):
        try:
            conns = self.settings_iface.ListConnections()
            for conn_path in conns:
                conn_obj = self.bus.get_object('org.freedesktop.NetworkManager', conn_path)
                conn_iface = dbus.Interface(conn_obj, 'org.freedesktop.NetworkManager.Settings.Connection')
                settings_dict = conn_iface.GetSettings()
                
                connection_details = settings_dict.get('connection', {})
                ctype = str(connection_details.get('type', ''))
                
                if ctype == '802-11-wireless':
                    wifi_details = settings_dict.get('802-11-wireless', {})
                    ssid_bytes = wifi_details.get('ssid')
                    conn_ssid = ""
                    if ssid_bytes:
                        conn_ssid = bytes(ssid_bytes).decode('utf-8', errors='ignore')
                        
                    if conn_ssid == ssid:
                        connection_details['autoconnect'] = dbus.Boolean(enabled)
                        settings_dict['connection'] = connection_details
                        conn_iface.Update(settings_dict)
            self.push_state()
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
    GLib.io_add_watch(0, GLib.IO_IN | GLib.IO_HUP, handle_stdin, daemon)
    loop = GLib.MainLoop()
    try:
        loop.run()
    except KeyboardInterrupt:
        pass
