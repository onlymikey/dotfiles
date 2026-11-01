import Quickshell
import Quickshell.Io
import QtCore
import QtQuick

Item {
    id: service

    // Reactive properties for system state
    property bool supported: false
    property int brightness: 100
    property int pendingBrightness: -1

    // Set brightness using brightnessctl
    function setBrightness(percent) {
        if (!service.supported) return
        percent = Math.max(1, Math.min(100, Math.round(percent)))
        service.brightness = percent // Optimistic update
        service.pendingBrightness = percent
        if (!brightSetProc.running) {
            runNextBrightness()
        }
    }

    function runNextBrightness() {
        if (service.pendingBrightness < 0) return
        var percent = service.pendingBrightness
        service.pendingBrightness = -1
        brightSetProc.command = ["brightnessctl", "-q", "set", percent + "%"]
        brightSetProc.running = true
    }

    Process {
        id: brightSetProc
        onExited: {
            if (service.pendingBrightness >= 0) {
                service.runNextBrightness()
            }
        }
    }

    // Hardware capability check
    Process {
        id: checkSupportProc
        command: ["bash", "-c", "[ -d /sys/class/backlight ] && [ \"$(ls -A /sys/class/backlight 2>/dev/null)\" ] && echo true || echo false"]
        stdout: SplitParser {
            onRead: data => {
                service.supported = (data.trim() === "true")
                if (service.supported) {
                    // Trigger initial poll if supported
                    if (!brightPollProc.running) brightPollProc.running = true
                }
            }
        }
    }

    // Read current brightness level
    Process {
        id: brightPollProc
        command: ["bash", "-c", "brightnessctl -m 2>/dev/null | awk -F, 'NR==1 {gsub(/%/, \"\", $4); print $4}'"]
        stdout: SplitParser {
            onRead: data => {
                var val = parseInt(data.trim(), 10)
                if (!isNaN(val) && service.pendingBrightness < 0) {
                    service.brightness = Math.max(0, Math.min(100, val))
                }
            }
        }
    }

    // Refresh brightness level periodically when dashboard is visible
    Timer {
        id: pollTimer
        interval: 2000
        running: root.dashboardVisible && service.supported
        repeat: true
        triggeredOnStart: true
        onTriggered: {
            if (!brightPollProc.running && !brightSetProc.running && service.pendingBrightness < 0) {
                brightPollProc.running = true
            }
        }
    }

    Component.onCompleted: {
        checkSupportProc.running = true
    }
}
