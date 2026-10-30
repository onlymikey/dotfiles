import Quickshell
import Quickshell.Io
import QtCore
import QtQuick

Item {
    id: service

    property bool hasDevice: false
    property bool connected: false
    property string deviceName: "Teléfono Android"
    property string connectionType: "Desconectado"
    property int batteryLevel: -1
    property bool isCharging: false
    property string networkType: "Sin red"
    property string signalStrength: "Sin señal"
    property int signalLevel: 0
    property int notificationsCount: 0

    // KDE Connect
    property bool kdeconnectAvailable: false
    property bool kdeconnectPaired: false
    property bool kdeconnectReachable: false
    property string kdeconnectDeviceId: ""
    property bool canRing: false

    // ADB & scrcpy
    property bool adbAvailable: false
    property bool adbAuthorized: false
    property string adbDeviceId: ""
    property bool canScrcpy: false
    property bool scrcpyRunning: false

    readonly property string configDir: String(StandardPaths.writableLocation(StandardPaths.ConfigLocation)).replace("file://", "") + "/quickshell"

    function sendCommand(cmdObj) {
        if (phoneProc.running) {
            phoneProc.write(JSON.stringify(cmdObj) + "\n")
        }
    }

    function ringPhone() {
        sendCommand({ action: "ring", deviceId: service.kdeconnectDeviceId })
    }

    function toggleScrcpy() {
        sendCommand({ action: "scrcpy", deviceId: service.adbDeviceId })
    }

    function refresh() {
        sendCommand({ action: "refresh" })
    }

    Process {
        id: phoneProc
        command: ["python3", service.configDir + "/services/parse_phone.py"]
        running: true

        stdout: SplitParser {
            onRead: data => {
                var line = data.trim()
                if (!line) return
                try {
                    var s = JSON.parse(line)
                    service.hasDevice = Boolean(s.hasDevice)
                    service.connected = Boolean(s.connected)
                    if (s.deviceName) service.deviceName = s.deviceName
                    service.connectionType = s.connectionType || "Desconectado"
                    service.batteryLevel = (s.batteryLevel !== undefined) ? s.batteryLevel : -1
                    service.isCharging = Boolean(s.isCharging)
                    service.networkType = s.networkType || "Sin red"
                    service.signalStrength = s.signalStrength || "Sin señal"
                    service.signalLevel = (s.signalLevel !== undefined) ? s.signalLevel : 0
                    service.notificationsCount = (s.notificationsCount !== undefined) ? s.notificationsCount : 0

                    if (s.kdeconnect) {
                        service.kdeconnectAvailable = Boolean(s.kdeconnect.available)
                        service.kdeconnectPaired = Boolean(s.kdeconnect.paired)
                        service.kdeconnectReachable = Boolean(s.kdeconnect.reachable)
                        service.kdeconnectDeviceId = s.kdeconnect.deviceId || ""
                        service.canRing = Boolean(s.kdeconnect.canRing)
                    }

                    if (s.adb) {
                        service.adbAvailable = Boolean(s.adb.available)
                        service.adbAuthorized = Boolean(s.adb.authorized)
                        service.adbDeviceId = s.adb.deviceId || ""
                        service.canScrcpy = Boolean(s.adb.canScrcpy)
                        service.scrcpyRunning = Boolean(s.adb.scrcpyRunning)
                    }
                } catch (e) {
                    // Ignore JSON parse errors on partial chunk
                }
            }
        }

        onExited: {
            restartTimer.start()
        }
    }

    Timer {
        id: restartTimer
        interval: 3000
        repeat: false
        onTriggered: {
            if (!phoneProc.running) {
                phoneProc.running = true
            }
        }
    }
}
