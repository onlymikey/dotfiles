import Quickshell
import Quickshell.Io
import QtCore
import QtQuick

Item {
    id: service

    // Reactive properties for system state
    property bool supported: false
    property int brightness: 100

    // Set brightness using brightnessctl
    function setBrightness(percent) {
        if (!service.supported) return
        service.brightness = percent
        brightSetProc.command = ["bash", "-c", "brightnessctl set " + percent + "%"]
        brightSetProc.running = true
    }

    Process {
        id: brightSetProc
    }

    // Hardware capability check
    Process {
        id: checkSupportProc
        command: ["bash", "-c", "[ -d /sys/class/backlight ] && [ \"$(ls -A /sys/class/backlight)\" ] && echo true || echo false"]
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
        command: ["bash", "-c", "brightnessctl get | awk '{printf \"%.0f\", $1/max * 100}' 2>/dev/null || echo 100"]
        stdout: SplitParser {
            onRead: data => {
                service.brightness = parseInt(data) || 100
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
            if (!brightPollProc.running) {
                brightPollProc.running = true
            }
        }
    }

    Component.onCompleted: {
        checkSupportProc.running = true
    }
}
