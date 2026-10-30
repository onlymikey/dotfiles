import Quickshell
import Quickshell.Io
import QtCore
import QtQuick

Item {
    id: service

    // Core Bluetooth states
    property bool enabled: false
    property bool scanning: false
    property string connectingMac: ""

    // Device lists populated from D-Bus
    property var devices: []
    property var pairedDevices: []
    property var availableDevices: []
    property var connectedDevices: []

    // Helper property to find the primary connected device (preferring audio devices) for visual highlights
    property var primaryConnectedAudioDevice: {
        for (var i = 0; i < devices.length; i++) {
            var dev = devices[i]
            if (dev.connected && (dev.type === "headphones" || dev.type === "speaker" || dev.type === "audio" || dev.type === "headset")) {
                return dev
            }
        }
        for (var j = 0; j < devices.length; j++) {
            if (devices[j].connected) {
                return devices[j]
            }
        }
        return null
    }

    function sendCommand(cmd) {
        if (!btServiceProc.running) {
            btServiceProc.running = true
        }
        if (btServiceProc.running) {
            btServiceProc.write(cmd + "\n")
        }
    }

    // Initialize/refresh the backend D-Bus listener
    function refresh() {
        sendCommand("refresh")
    }

    // Controller actions
    function startDiscovery() {
        service.scanning = true
        sendCommand("scan")
    }

    function stopDiscovery() {
        sendCommand("stop_scan")
    }

    function connectDevice(mac) {
        service.connectingMac = mac
        sendCommand("connect|" + mac)
    }

    function disconnectDevice(mac) {
        sendCommand("disconnect|" + mac)
    }

    function pairDevice(mac) {
        service.connectingMac = mac
        sendCommand("pair|" + mac)
    }

    function forgetDevice(mac) {
        sendCommand("forget|" + mac)
    }

    function powerOn() {
        service.enabled = true
        sendCommand("power|true")
    }

    function powerOff() {
        service.enabled = false
        sendCommand("power|false")
    }

    property int prevConnectedCount: 0

    // Persistent background process listening to D-Bus signals
    Process {
        id: btServiceProc
        command: ["python3", String(StandardPaths.writableLocation(StandardPaths.ConfigLocation)).replace("file://", "") + "/quickshell/services/parse_bluetooth.py"]
        running: true
        stdout: SplitParser {
            onRead: data => {
                try {
                    var state = JSON.parse(data.trim())
                    service.enabled = Boolean(state.powered)
                    service.scanning = Boolean(state.discovering)
                    if (state.connectingMac !== undefined) {
                        service.connectingMac = state.connectingMac || ""
                    }
                    service.devices = state.devices || []

                    var paired = []
                    var available = []
                    var connected = []
                    for (var i = 0; i < service.devices.length; i++) {
                        var d = service.devices[i]
                        if (d.connected) {
                            connected.push(d)
                        }
                        if (d.paired) {
                            paired.push(d)
                        } else {
                            available.push(d)
                        }
                    }
                    service.pairedDevices = paired
                    service.availableDevices = available
                    service.connectedDevices = connected

                    if (connected.length !== service.prevConnectedCount) {
                        service.prevConnectedCount = connected.length
                        audioRefreshTimer.restart()
                    }
                } catch (e) {
                    console.warn("Error parsing Bluetooth JSON: " + e)
                }
            }
        }
        stderr: SplitParser {
            onRead: data => console.warn("BluetoothService backend stderr: " + data.trim())
        }
        onExited: {
            btRestartTimer.start()
        }
    }

    Timer {
        id: audioRefreshTimer
        interval: 600
        repeat: false
        onTriggered: {
            if (typeof root !== "undefined" && root.audioService) {
                root.audioService.refresh()
            }
        }
    }

    Timer {
        id: btRestartTimer
        interval: 1000
        repeat: false
        onTriggered: {
            if (!btServiceProc.running) {
                btServiceProc.running = true
            }
        }
    }

    Component.onCompleted: {
        if (!btServiceProc.running) {
            btServiceProc.running = true
        }
    }
}
