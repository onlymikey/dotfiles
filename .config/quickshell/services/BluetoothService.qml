import Quickshell
import Quickshell.Io
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

    // Helper property to find the primary connected audio device for visual highlights
    property var primaryConnectedAudioDevice: {
        for (var i = 0; i < devices.length; i++) {
            var dev = devices[i]
            if (dev.connected && (dev.type === "headphones" || dev.type === "speaker")) {
                return dev
            }
        }
        return null
    }

    // Initialize/refresh the backend D-Bus listener
    function refresh() {
        if (!btServiceProc.running) {
            btServiceProc.running = true
        }
    }

    Timer {
        id: scanTimer
        interval: 5000
        repeat: false
        onTriggered: {
            if (scanOffProc.running) {
                scanOffProc.running = false
            }
            scanOffProc.running = true
        }
    }

    // Controller actions
    function startDiscovery() {
        if (service.scanning) {
            console.log("BluetoothService: Scan already active, ignoring request.")
            return
        }
        
        console.log("BluetoothService: Starting discovery...")
        if (scanOnProc.running) {
            scanOnProc.running = false
        }
        scanOnProc.running = true
        scanTimer.restart()
    }

    function connectDevice(mac) {
        service.connectingMac = mac
        if (actionProc.running) {
            actionProc.running = false
        }
        actionProc.command = ["bash", "-c", "(echo 'trust " + mac + "'; echo 'connect " + mac + "'; sleep 2; echo 'quit') | bluetoothctl 2>/dev/null"]
        actionProc.running = true
    }

    function disconnectDevice(mac) {
        if (actionProc.running) {
            actionProc.running = false
        }
        actionProc.command = ["bash", "-c", "echo -e 'disconnect " + mac + "\\nquit' | bluetoothctl 2>/dev/null"]
        actionProc.running = true
    }

    function pairDevice(mac) {
        service.connectingMac = mac
        if (actionProc.running) {
            actionProc.running = false
        }
        actionProc.command = ["bash", "-c", "echo -e 'pair " + mac + "\\nquit' | bluetoothctl 2>/dev/null; sleep 2; echo -e 'trust " + mac + "\\nquit' | bluetoothctl 2>/dev/null; sleep 1; echo -e 'connect " + mac + "\\nquit' | bluetoothctl 2>/dev/null"]
        actionProc.running = true
    }

    function forgetDevice(mac) {
        if (actionProc.running) {
            actionProc.running = false
        }
        actionProc.command = ["bash", "-c", "echo -e 'remove " + mac + "\\nquit' | bluetoothctl 2>/dev/null"]
        actionProc.running = true
    }

    function powerOn() {
        if (actionProc.running) {
            actionProc.running = false
        }
        actionProc.command = ["bash", "-c", "echo -e 'power on\\nquit' | bluetoothctl 2>/dev/null"]
        actionProc.running = true
    }

    function powerOff() {
        if (actionProc.running) {
            actionProc.running = false
        }
        actionProc.command = ["bash", "-c", "echo -e 'power off\\nquit' | bluetoothctl 2>/dev/null"]
        actionProc.running = true
    }

    // Persistent background process listening to D-Bus signals
    Process {
        id: btServiceProc
        command: ["python3", "/home/mikey/.config/quickshell/services/parse_bluetooth.py"]
        running: true
        stdout: SplitParser {
            onRead: data => {
                try {
                    var state = JSON.parse(data.trim())
                    service.enabled = state.powered
                    service.scanning = state.discovering
                    service.devices = state.devices
                    
                    var paired = []
                    var available = []
                    var connected = []
                    for (var i = 0; i < state.devices.length; i++) {
                        var d = state.devices[i]
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
                } catch (e) {
                    console.warn("Error parsing Bluetooth JSON: " + e)
                }
            }
        }
        stderr: SplitParser {
            onRead: data => console.warn("BluetoothService backend stderr: " + data.trim())
        }
    }

    // Discovery helpers
    Process {
        id: scanOnProc
        command: ["bluetoothctl", "scan", "on"]
    }

    Process {
        id: scanOffProc
        command: ["bluetoothctl", "scan", "off"]
    }

    // Actions helper
    Process {
        id: actionProc
        onExited: {
            service.connectingMac = ""
        }
    }

    Component.onCompleted: refresh()
}
