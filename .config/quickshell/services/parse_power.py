#!/usr/bin/env python3
import sys
import json
import dbus
import subprocess
import shutil
from dbus.mainloop.glib import DBusGMainLoop
from gi.repository import GLib

# Set up the D-Bus main loop for python-dbus
DBusGMainLoop(set_as_default=True)

class PowerDaemon:
    def __init__(self):
        try:
            self.bus = dbus.SystemBus()
        except Exception as e:
            sys.stderr.write(f"Failed to connect to System Bus: {e}\n")
            self.bus = None

        self.supported = False
        self.backend_name = "None"
        self.current_profile = ""
        self.available_profiles = []
        self.driver = ""
        
        self.ppd_obj = None
        self.ppd_props = None
        
        self.detect_backend()
        
    def detect_backend(self):
        if not self.bus:
            self.detect_fallback_backends()
            return

        # 1. Check power-profiles-daemon on D-Bus
        try:
            if self.bus.name_has_owner('net.hadess.PowerProfiles'):
                self.ppd_obj = self.bus.get_object('net.hadess.PowerProfiles', '/net/hadess/PowerProfiles')
                self.ppd_props = dbus.Interface(self.ppd_obj, 'org.freedesktop.DBus.Properties')
                
                # Listen to PropertiesChanged signal
                self.bus.add_signal_receiver(
                    self.on_properties_changed,
                    dbus_interface="org.freedesktop.DBus.Properties",
                    signal_name="PropertiesChanged",
                    path="/net/hadess/PowerProfiles"
                )
                
                self.supported = True
                self.backend_name = "power-profiles-daemon"
                self.update_ppd_state()
                return
        except Exception as e:
            sys.stderr.write(f"Error checking power-profiles-daemon D-Bus: {e}\n")
            
        self.detect_fallback_backends()

    def detect_fallback_backends(self):
        # 2. Check TLP
        if shutil.which('tlp'):
            self.supported = True
            self.backend_name = "TLP"
            self.available_profiles = ["ac", "bat"]
            self.update_tlp_state()
            return
            
        # 3. Check auto-cpufreq
        if shutil.which('auto-cpufreq'):
            self.supported = True
            self.backend_name = "auto-cpufreq"
            self.available_profiles = ["powersave", "performance"]
            self.update_autocpufreq_state()
            return

        # Unsupported
        self.supported = False
        self.backend_name = "None"
        self.available_profiles = []
        self.current_profile = ""
        self.driver = ""

    def update_ppd_state(self):
        try:
            props = self.ppd_props.GetAll('net.hadess.PowerProfiles')
            active = str(props.get('ActiveProfile', ''))
            
            raw_profiles = props.get('Profiles', [])
            profiles = []
            driver_info = ""
            
            for p in raw_profiles:
                p_name = str(p.get('Profile', ''))
                if p_name:
                    profiles.append(p_name)
                if p_name == active:
                    driver = p.get('Driver') or p.get('CpuDriver') or p.get('PlatformDriver') or ""
                    driver_info = str(driver)
            
            self.current_profile = active
            self.available_profiles = profiles
            self.driver = driver_info
            
        except Exception as e:
            sys.stderr.write(f"Error updating PPD state: {e}\n")
            self.supported = False
            
    def update_tlp_state(self):
        try:
            res = subprocess.run(["tlp-stat", "-s"], capture_output=True, text=True)
            mode = "ac"
            if "Mode = battery" in res.stdout:
                mode = "bat"
            self.current_profile = mode
            self.driver = "TLP Active"
        except Exception as e:
            sys.stderr.write(f"Error updating TLP state: {e}\n")
            self.current_profile = "ac"
            self.driver = "TLP"

    def update_autocpufreq_state(self):
        try:
            res = subprocess.run(["auto-cpufreq", "--get-state"], capture_output=True, text=True)
            mode = "powersave"
            if "performance" in res.stdout.lower():
                mode = "performance"
            self.current_profile = mode
            self.driver = "auto-cpufreq"
        except Exception as e:
            sys.stderr.write(f"Error updating auto-cpufreq state: {e}\n")
            self.current_profile = "powersave"
            self.driver = "auto-cpufreq"

    def on_properties_changed(self, interface, changed, invalidated):
        if interface == 'net.hadess.PowerProfiles':
            self.update_ppd_state()
            self.push_state()

    def set_profile(self, profile):
        if not self.supported:
            return
            
        if self.backend_name == "power-profiles-daemon":
            try:
                self.ppd_props.Set('net.hadess.PowerProfiles', 'ActiveProfile', dbus.String(profile))
                self.update_ppd_state()
                self.push_state()
            except Exception as e:
                sys.stderr.write(f"Failed to set D-Bus profile: {e}\n")
        elif self.backend_name == "TLP":
            try:
                if profile in ("ac", "bat"):
                    subprocess.run(["tlp", profile], capture_output=True)
                    self.update_tlp_state()
                    self.push_state()
            except Exception as e:
                sys.stderr.write(f"Failed to set TLP profile: {e}\n")
        elif self.backend_name == "auto-cpufreq":
            try:
                if profile in ("powersave", "performance"):
                    subprocess.run(["auto-cpufreq", f"--set-state={profile}"], capture_output=True)
                    self.update_autocpufreq_state()
                    self.push_state()
            except Exception as e:
                sys.stderr.write(f"Failed to set auto-cpufreq profile: {e}\n")

    def push_state(self):
        state = {
            "supported": self.supported,
            "backendName": self.backend_name,
            "currentProfile": self.current_profile,
            "availableProfiles": self.available_profiles,
            "driver": self.driver
        }
        print(json.dumps(state))
        sys.stdout.flush()

def handle_stdin(channel, cond, daemon):
    line = sys.stdin.readline()
    if not line:
        sys.exit(0)
    
    parts = line.strip().split('|')
    cmd = parts[0]
    
    try:
        if cmd == "set_profile":
            profile = parts[1]
            daemon.set_profile(profile)
        elif cmd == "refresh":
            if daemon.backend_name == "power-profiles-daemon":
                daemon.update_ppd_state()
            elif daemon.backend_name == "TLP":
                daemon.update_tlp_state()
            elif daemon.backend_name == "auto-cpufreq":
                daemon.update_autocpufreq_state()
            daemon.push_state()
    except Exception as e:
        sys.stderr.write(f"Command error: {e}\n")
    return True

if __name__ == "__main__":
    daemon = PowerDaemon()
    GLib.io_add_watch(0, GLib.IO_IN | GLib.IO_HUP, handle_stdin, daemon)
    daemon.push_state()
    loop = GLib.MainLoop()
    try:
        loop.run()
    except KeyboardInterrupt:
        pass
