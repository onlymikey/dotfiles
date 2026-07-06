#!/usr/bin/env python3
import sys
import os
import json
import time
import shutil
import subprocess

class SensorDaemon:
    def __init__(self):
        self.cpu_temp_path = None
        self.gpu_temp_path = None
        self.ssd_temp_path = None
        self.gpu_power_path = None
        self.cpu_power_path = None
        self.fan_speed_path = None
        self.gpu_busy_path = None
        
        self.has_nvidia = False
        self.prev_idle = 0.0
        self.prev_total = 0.0
        
        self.discover_sensors()
        self.init_cpu_times()

    def discover_sensors(self):
        hwmon_dir = '/sys/class/hwmon'
        if os.path.exists(hwmon_dir):
            for d in os.listdir(hwmon_dir):
                path = os.path.join(hwmon_dir, d)
                if not os.path.isdir(path):
                    continue
                try:
                    with open(os.path.join(path, 'name'), 'r') as f:
                        name = f.read().strip()
                except:
                    name = ""

                # CPU Temperature detection (k10temp, coretemp, zenpower, cpu)
                if name in ('k10temp', 'coretemp', 'zenpower', 'cpu'):
                    for f in os.listdir(path):
                        if f.startswith('temp') and f.endswith('_input'):
                            num = f[4:-6]
                            label_file = os.path.join(path, f'temp{num}_label')
                            label = ""
                            if os.path.exists(label_file):
                                try:
                                    with open(label_file, 'r') as lf:
                                        label = lf.read().strip().lower()
                                except:
                                    pass
                            # Prefer Package or Tctl
                            if 'tctl' in label or 'package' in label or 'core' in label or not self.cpu_temp_path:
                                self.cpu_temp_path = os.path.join(path, f)

                # GPU Temperature and Power detection (amdgpu, nouveau, radeon)
                if name in ('amdgpu', 'nouveau', 'radeon'):
                    for f in os.listdir(path):
                        if f.startswith('temp') and f.endswith('_input') and not self.gpu_temp_path:
                            self.gpu_temp_path = os.path.join(path, f)
                        if f.startswith('power') and f.endswith('_input') and not self.gpu_power_path:
                            self.gpu_power_path = os.path.join(path, f)

                # NVMe SSD Temperature detection (nvme)
                if name == 'nvme':
                    for f in os.listdir(path):
                        if f.startswith('temp') and f.endswith('_input'):
                            num = f[4:-6]
                            label_file = os.path.join(path, f'temp{num}_label')
                            label = ""
                            if os.path.exists(label_file):
                                try:
                                    with open(label_file, 'r') as lf:
                                        label = lf.read().strip().lower()
                                except:
                                    pass
                            if 'composite' in label or not self.ssd_temp_path:
                                self.ssd_temp_path = os.path.join(path, f)

                # Fan detection (generic first found fan)
                for f in os.listdir(path):
                    if f.startswith('fan') and f.endswith('_input') and not self.fan_speed_path:
                        self.fan_speed_path = os.path.join(path, f)

        # NVIDIA GPU fallback
        if not self.gpu_temp_path and shutil.which('nvidia-smi'):
            self.has_nvidia = True

        # GPU Busy detection (AMD)
        self.gpu_busy_path = None
        for i in range(5):
            path = f"/sys/class/drm/card{i}/device/gpu_busy_percent"
            if os.path.exists(path):
                self.gpu_busy_path = path
                break

    def init_cpu_times(self):
        try:
            with open('/proc/stat', 'r') as f:
                line = f.readline()
            parts = [float(x) for x in line.split()[1:]]
            self.prev_idle = parts[3] + parts[4]
            self.prev_total = sum(parts)
        except:
            self.prev_idle = 0.0
            self.prev_total = 0.0

    def calculate_cpu_usage(self):
        try:
            with open('/proc/stat', 'r') as f:
                line = f.readline()
            parts = [float(x) for x in line.split()[1:]]
            idle = parts[3] + parts[4]
            total = sum(parts)
            
            idle_delta = idle - self.prev_idle
            total_delta = total - self.prev_total
            
            self.prev_idle = idle
            self.prev_total = total
            
            if total_delta > 0:
                return int((1.0 - idle_delta / total_delta) * 100.0)
        except:
            pass
        return 0

    def get_ram_usage(self):
        try:
            mem_total = 0
            mem_avail = 0
            with open('/proc/meminfo', 'r') as f:
                for line in f:
                    if line.startswith('MemTotal:'):
                        mem_total = int(line.split()[1])
                    elif line.startswith('MemAvailable:'):
                        mem_avail = int(line.split()[1])
            if mem_total > 0:
                return int((mem_total - mem_avail) / mem_total * 100)
        except:
            pass
        return 0

    def get_disk_usage(self):
        try:
            total, used, free = shutil.disk_usage('/')
            return int(used / total * 100)
        except:
            return 0

    def read_file_val(self, path):
        if not path:
            return None
        try:
            with open(path, 'r') as f:
                return float(f.read().strip())
        except:
            return None

    def get_nvidia_data(self):
        if not self.has_nvidia:
            return None, None, None
        try:
            res = subprocess.run([
                "nvidia-smi",
                "--query-gpu=temperature.gpu,power.draw,utilization.gpu",
                "--format=csv,noheader,nounits"
            ], capture_output=True, text=True)
            if res.returncode == 0:
                parts = res.stdout.strip().split(',')
                temp = float(parts[0].strip())
                power = float(parts[1].strip())
                util = float(parts[2].strip())
                return temp, power, util
        except:
            pass
        return None, None, None

    def collect(self):
        cpu_use = self.calculate_cpu_usage()
        ram_use = self.get_ram_usage()
        disk_use = self.get_disk_usage()
        
        # Read temperatures (in millidegrees, converted to Celsius)
        cpu_t_raw = self.read_file_val(self.cpu_temp_path)
        cpu_temp = int(cpu_t_raw / 1000.0) if cpu_t_raw is not None else None
        
        ssd_t_raw = self.read_file_val(self.ssd_temp_path)
        ssd_temp = int(ssd_t_raw / 1000.0) if ssd_t_raw is not None else None
        
        gpu_temp = None
        gpu_power = None
        gpu_usage = None
        
        if self.gpu_temp_path:
            gpu_t_raw = self.read_file_val(self.gpu_temp_path)
            gpu_temp = int(gpu_t_raw / 1000.0) if gpu_t_raw is not None else None
            
        if self.gpu_power_path:
            gpu_p_raw = self.read_file_val(self.gpu_power_path)
            # AMDGPU power is in microwatts
            gpu_power = int(gpu_p_raw / 1000000.0) if gpu_p_raw is not None else None
            
        if self.gpu_busy_path:
            gpu_usage = self.read_file_val(self.gpu_busy_path)
            
        if self.has_nvidia:
            nv_temp, nv_power, nv_util = self.get_nvidia_data()
            if nv_temp is not None:
                gpu_temp = int(nv_temp)
            if nv_power is not None:
                gpu_power = int(nv_power)
            if nv_util is not None:
                gpu_usage = int(nv_util)

        # Read fans
        fan_raw = self.read_file_val(self.fan_speed_path)
        fan_speed = int(fan_raw) if fan_raw is not None else None

        # Read cpu power (if any)
        cpu_p_raw = self.read_file_val(self.cpu_power_path)
        cpu_power = int(cpu_p_raw / 1000000.0) if cpu_p_raw is not None else None

        # Gather list of available sensors for API discovery
        available = []
        if cpu_temp is not None: available.append("cpuTemperature")
        if gpu_temp is not None: available.append("gpuTemperature")
        if ssd_temp is not None: available.append("ssdTemperature")
        if fan_speed is not None: available.append("fanSpeed")
        if cpu_power is not None: available.append("cpuPower")
        if gpu_power is not None: available.append("gpuPower")
        if gpu_usage is not None: available.append("gpuUsage")

        state = {
            "cpuUsage": cpu_use,
            "ramUsage": ram_use,
            "diskUsage": disk_use,
            "gpuUsage": gpu_usage,
            "cpuTemperature": cpu_temp,
            "gpuTemperature": gpu_temp,
            "ssdTemperature": ssd_temp,
            "fanSpeed": fan_speed,
            "cpuPower": cpu_power,
            "gpuPower": gpu_power,
            "availableSensors": available
        }
        return state

    def run(self):
        while True:
            state = self.collect()
            print(json.dumps(state))
            sys.stdout.flush()
            time.sleep(2.0)

if __name__ == "__main__":
    daemon = SensorDaemon()
    daemon.run()
