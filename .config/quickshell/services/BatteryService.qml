import Quickshell
import Quickshell.Io
import QtQuick

Item {
    id: service

    // Capability flag: true when any power_supply device reports type=Battery
    property bool available: false
    property bool initialProbeDone: false

    // Raw battery data from sysfs + upower
    property int capacity: 100
    property string status: "Unknown"
    property string batteryPath: ""
    property string timeRemaining: ""
    property bool isCharging: status === "Charging"
    property string batteryClass: {
        if (isCharging) return "charging"
        if (capacity <= 10) return "critical"
        if (capacity <= 25) return "warning"
        return ""
    }

    // Controls polling from outside
    property bool pollingEnabled: true

    // Low battery threshold state tracking
    property int warningThreshold: 20
    property int criticalThreshold: 10
    property int actionThreshold: 5
    property bool warnedLow: false
    property bool warnedCritical: false
    property bool actionTriggered: false

    function refresh() {
        if (!batteryPollProc.running) {
            batteryPollProc.running = true
        }
    }

    function checkThresholds() {
        if (!service.available) return

        if (service.status !== "Discharging") {
            if (service.capacity > service.warningThreshold) service.warnedLow = false
            if (service.capacity > service.criticalThreshold) service.warnedCritical = false
            if (service.capacity > service.actionThreshold) service.actionTriggered = false
            return
        }

        if (service.capacity <= service.actionThreshold && !service.actionTriggered) {
            service.actionTriggered = true
            service.warnedCritical = true
            service.warnedLow = true
            criticalActionProc.running = true
        } else if (service.capacity <= service.criticalThreshold && !service.warnedCritical) {
            service.warnedCritical = true
            service.warnedLow = true
            notifyCriticalProc.running = true
        } else if (service.capacity <= service.warningThreshold && !service.warnedLow) {
            service.warnedLow = true
            notifyLowProc.running = true
        }
    }

    Process {
        id: notifyLowProc
        command: [
            "notify-send", "-u", "normal", "-a", "Battery",
            "Batería baja (" + service.capacity + "%)",
            "Conecta el cargador pronto."
        ]
    }

    Process {
        id: notifyCriticalProc
        command: [
            "notify-send", "-u", "critical", "-a", "Battery",
            "Batería crítica (" + service.capacity + "%)",
            "El sistema entrará en suspensión/hibernación al llegar al " + service.actionThreshold + "%."
        ]
    }

    Process {
        id: criticalActionProc
        command: [
            "bash", "-c",
            "notify-send -u critical -a 'Battery' 'Batería agotándose (" + service.capacity + "%)' 'Suspendiendo/hibernando el sistema para evitar pérdida de datos...'; sleep 2; (pidof hyprlock >/dev/null || hyprlock &) && sleep 0.3; if [ \"$(wc -l < /proc/swaps 2>/dev/null || echo 0)\" -gt 1 ] && grep -q disk /sys/power/state 2>/dev/null; then systemctl hibernate || systemctl suspend; else systemctl suspend; fi"
        ]
    }

    Process {
        id: batteryPollProc
        command: [
            "bash",
            "-c",
            "bat_path=$(for d in /sys/class/power_supply/*; do [ -d \"$d\" ] || continue; t=$(cat \"$d/type\" 2>/dev/null); [ \"$t\" = \"Battery\" ] && { echo \"$d\"; break; }; done); if [ -n \"$bat_path\" ]; then cap=$(cat \"$bat_path/capacity\" 2>/dev/null || echo 100); st=$(cat \"$bat_path/status\" 2>/dev/null || echo Unknown); time_str=''; if command -v upower >/dev/null 2>&1; then up_dev=$(upower -e 2>/dev/null | grep -m1 BAT); if [ -n \"$up_dev\" ]; then if [ \"$st\" = \"Discharging\" ]; then time_str=$(upower -i \"$up_dev\" 2>/dev/null | awk '/time to empty/ {print $4 \" \" $5}'); elif [ \"$st\" = \"Charging\" ]; then time_str=$(upower -i \"$up_dev\" 2>/dev/null | awk '/time to full/ {print $4 \" \" $5}'); fi; fi; fi; echo \"1|$cap|$st|$bat_path|$time_str\"; else echo \"0|100|Unknown||\"; fi"
        ]
        stdout: SplitParser {
            onRead: data => {
                var parts = data.trim().split("|")
                service.initialProbeDone = true
                if (parts.length < 4) {
                    service.available = false
                    service.capacity = 100
                    service.status = "Unknown"
                    service.batteryPath = ""
                    service.timeRemaining = ""
                    return
                }

                service.available = parts[0] === "1"
                service.capacity = parseInt(parts[1]) || 100
                service.status = parts[2] || "Unknown"
                service.batteryPath = parts[3] || ""
                service.timeRemaining = parts.length > 4 ? (parts[4] || "") : ""
                service.checkThresholds()
            }
        }
    }

    Component.onCompleted: refresh()

    Timer {
        interval: 5000
        running: service.pollingEnabled && (!service.initialProbeDone || service.available)
        repeat: true
        triggeredOnStart: true
        onTriggered: service.refresh()
    }
}
