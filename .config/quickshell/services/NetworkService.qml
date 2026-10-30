import Quickshell
import Quickshell.Io
import QtCore
import QtQuick

Item {
    id: service

    // Reactive network properties
    property bool wifiEnabled: false
    property bool ethernetEnabled: false
    property bool wifiScanning: false
    property var connectedNetwork: null
    property var availableNetworks: []
    property var savedNetworks: []
    property var ethernetDevices: []
    property var vpnConnections: []
    property bool airplaneMode: false

    // Initialize / refresh the backend process
    function refresh() {
        if (!netServiceProc.running) {
            netServiceProc.running = true
        } else {
            netServiceProc.write("refresh\n")
        }
    }

    // Controller actions written directly to the D-Bus daemon's stdin
    function scan() {
        if (netServiceProc.running) {
            service.wifiScanning = true
            netServiceProc.write("scan\n")
        }
    }

    function connectDevice(ssid, password) {
        if (netServiceProc.running) {
            netServiceProc.write("connect|" + ssid + "|" + (password || "") + "\n")
        }
    }

    // Disconnects active wireless connection
    function disconnectDevice() {
        if (netServiceProc.running) {
            netServiceProc.write("disconnect\n")
        }
    }

    function forgetDevice(ssid) {
        if (netServiceProc.running) {
            netServiceProc.write("forget|" + ssid + "\n")
        }
    }

    function toggleWifi(enabled) {
        service.wifiEnabled = enabled
        if (netServiceProc.running) {
            netServiceProc.write("toggle_wifi|" + (enabled ? "true" : "false") + "\n")
        }
    }

    function toggleEthernet(iface, enabled) {
        if (netServiceProc.running) {
            netServiceProc.write("toggle_ethernet|" + iface + "|" + (enabled ? "true" : "false") + "\n")
        }
    }

    function toggleAutoconnect(ssid, enabled) {
        if (service.connectedNetwork && service.connectedNetwork.ssid === ssid) {
            var updated = Object.assign({}, service.connectedNetwork)
            updated.autoconnect = enabled
            service.connectedNetwork = updated
        }
        if (netServiceProc.running) {
            netServiceProc.write("toggle_autoconnect|" + ssid + "|" + (enabled ? "true" : "false") + "\n")
        }
    }

    // Persistent Python subprocess querying NetworkManager D-Bus
    Process {
        id: netServiceProc
        command: ["python3", String(StandardPaths.writableLocation(StandardPaths.ConfigLocation)).replace("file://", "") + "/quickshell/services/parse_network.py"]
        running: true
        stdout: SplitParser {
            onRead: data => {
                try {
                    var state = JSON.parse(data.trim())
                    if (state.wifiEnabled === undefined) return
                    service.wifiEnabled = Boolean(state.wifiEnabled)
                    service.ethernetEnabled = Boolean(state.ethernetEnabled)
                    service.wifiScanning = Boolean(state.wifiScanning)
                    service.connectedNetwork = state.connectedNetwork || null
                    service.availableNetworks = state.availableNetworks || []
                    service.savedNetworks = state.savedNetworks || []
                    service.ethernetDevices = state.ethernetDevices || []
                    service.vpnConnections = state.vpnConnections || []
                    service.airplaneMode = Boolean(state.airplaneMode)
                } catch (e) {
                    console.warn("Error parsing Network JSON: " + e)
                }
            }
        }
        stderr: SplitParser {
            onRead: data => console.warn("NetworkService backend stderr: " + data.trim())
        }
        onExited: {
            netRestartTimer.start()
        }
    }

    Timer {
        id: netRestartTimer
        interval: 1000
        repeat: false
        onTriggered: {
            if (!netServiceProc.running) {
                netServiceProc.running = true
            }
        }
    }

    Component.onCompleted: {
        if (!netServiceProc.running) {
            netServiceProc.running = true
        }
    }
}
