import Quickshell
import Quickshell.Io
import QtQuick

Item {
    id: service

    // Capability flag: true when any power_supply device reports type=Battery
    property bool available: false

    // Raw battery data from sysfs
    property int capacity: 100
    property string status: "Unknown"
    property string batteryPath: ""

    // Controls polling from outside (e.g., tie to panel visibility)
    property bool pollingEnabled: true

    function refresh() {
        if (!batteryPollProc.running) {
            batteryPollProc.running = true
        }
    }

    Process {
        id: batteryPollProc
        command: [
            "bash",
            "-c",
            "bat_path=$(for d in /sys/class/power_supply/*; do [ -d \"$d\" ] || continue; t=$(cat \"$d/type\" 2>/dev/null); [ \"$t\" = \"Battery\" ] && { echo \"$d\"; break; }; done); if [ -n \"$bat_path\" ]; then cap=$(cat \"$bat_path/capacity\" 2>/dev/null || echo 100); st=$(cat \"$bat_path/status\" 2>/dev/null || echo Unknown); echo \"1|$cap|$st|$bat_path\"; else echo \"0|100|Unknown|\"; fi"
        ]
        stdout: SplitParser {
            onRead: data => {
                var parts = data.trim().split("|")
                if (parts.length < 4) {
                    service.available = false
                    service.capacity = 100
                    service.status = "Unknown"
                    service.batteryPath = ""
                    return
                }

                service.available = parts[0] === "1"
                service.capacity = parseInt(parts[1]) || 100
                service.status = parts[2] || "Unknown"
                service.batteryPath = parts[3] || ""
            }
        }
    }

    Component.onCompleted: refresh()

    Timer {
        interval: 2000
        running: service.pollingEnabled
        repeat: true
        triggeredOnStart: true
        onTriggered: service.refresh()
    }
}
