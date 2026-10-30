import Quickshell
import Quickshell.Io
import QtCore
import QtQuick

Item {
    id: service

    property var monitors: []
    property string primaryMonitor: ""
    property string selectedMonitor: ""
    property string layoutMode: "extend" // "extend", "mirror", "primary_only", "external_only"
    property bool pendingConfirmation: false
    property int revertSeconds: 0

    readonly property int connectedCount: monitors ? monitors.length : 0
    readonly property int enabledCount: {
        var c = 0
        for (var i = 0; i < monitors.length; i++) {
            if (!monitors[i].disabled) c++
        }
        return c
    }

    readonly property string effectiveSecondaryMonitor: {
        if (selectedMonitor !== "" && selectedMonitor !== primaryMonitor) {
            for (var i = 0; i < monitors.length; i++) {
                if (monitors[i].name === selectedMonitor) return selectedMonitor
            }
        }
        for (var j = 0; j < monitors.length; j++) {
            if (monitors[j].name !== primaryMonitor) return monitors[j].name
        }
        return primaryMonitor
    }

    function sendCommand(payload) {
        if (!monitorProc.running) {
            monitorProc.running = true
        }
        var line = (typeof payload === "string") ? JSON.stringify({ action: payload }) : JSON.stringify(payload)
        monitorProc.write(line + "\n")
    }

    function refresh() {
        sendCommand({ action: "refresh" })
    }

    function applyMonitor(opts) {
        var cmd = {
            action: "apply_monitor",
            name: opts.name || "",
            mode: opts.mode || "",
            scale: opts.scale !== undefined ? opts.scale : 1.0,
            relation: opts.relation || "",
            displayMode: opts.displayMode || "",
            mirrorOf: opts.mirrorOf || "",
            enabled: opts.enabled !== undefined ? Boolean(opts.enabled) : true
        }
        sendCommand(cmd)
    }

    function setLayoutMode(mode, targetMonitor) {
        sendCommand({
            action: "set_layout_mode",
            layoutMode: mode,
            targetMonitor: targetMonitor || service.effectiveSecondaryMonitor
        })
    }

    function setPrimary(name) {
        sendCommand({
            action: "set_primary",
            name: name
        })
    }

    function prioritizeMode(priority, monitorName) {
        sendCommand({
            action: "prioritize_mode",
            priority: priority || "highrr",
            name: monitorName || ""
        })
    }

    function confirmChanges() {
        sendCommand({ action: "confirm" })
    }

    function revertChanges() {
        sendCommand({ action: "revert" })
    }

    // Persistent daemon process for Hyprlua monitor management
    Process {
        id: monitorProc
        command: ["python3", "-u", String(StandardPaths.writableLocation(StandardPaths.ConfigLocation)).replace("file://", "") + "/quickshell/services/parse_monitors.py"]
        running: true
        stdout: SplitParser {
            onRead: data => {
                var line = data.trim()
                if (!line) return
                try {
                    var parsed = JSON.parse(line)
                    var mons = parsed.monitors || []
                    service.monitors = mons
                    service.primaryMonitor = parsed.primaryMonitor || ""
                    service.layoutMode = parsed.layoutMode || "extend"
                    service.pendingConfirmation = Boolean(parsed.pendingConfirmation)
                    service.revertSeconds = Number(parsed.revertSeconds || 0)

                    // Ensure selectedMonitor is valid
                    var found = false
                    for (var i = 0; i < mons.length; i++) {
                        if (mons[i].name === service.selectedMonitor) {
                            found = true
                            break
                        }
                    }
                    if (!found && mons.length > 0) {
                        var sec = ""
                        for (var j = 0; j < mons.length; j++) {
                            if (!mons[j].isPrimary) {
                                sec = mons[j].name
                                break
                            }
                        }
                        service.selectedMonitor = sec !== "" ? sec : mons[0].name
                    }
                } catch (e) {
                    console.warn("MonitorService JSON parse error:", e)
                }
            }
        }
        stderr: SplitParser {
            onRead: data => console.warn("MonitorService stderr:", data.trim())
        }
        onExited: {
            restartTimer.start()
        }
    }

    Timer {
        id: restartTimer
        interval: 1000
        repeat: false
        onTriggered: {
            if (!monitorProc.running) {
                monitorProc.running = true
            }
        }
    }

    Component.onCompleted: {
        if (!monitorProc.running) {
            monitorProc.running = true
        }
    }
}
