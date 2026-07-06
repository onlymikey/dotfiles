import Quickshell
import Quickshell.Io
import QtCore
import QtQuick

Item {
    id: service

    // Reactive property indicating whether session restore is enabled
    property bool enabled: false

    // Reactive properties for systemd service deployment state
    property bool serviceInstalled: false
    property bool serviceEnabled: false
    property bool serviceHealthy: false

    // Function to capture the current desktop session
    function saveSession() {
        if (!service.enabled) return
        saveSessionProc.running = true
    }

    // Function to restore the previously saved session
    function restoreSession() {
        if (!service.enabled) return
        restoreSessionProc.running = true
    }

    function checkServiceState() {
        if (!checkServiceProc.running) {
            checkServiceProc.running = true
        }
    }

    function installService() {
        if (!installServiceProc.running) {
            installServiceProc.running = true
        }
    }

    Process {
        id: saveSessionProc
        command: ["python3", String(StandardPaths.writableLocation(StandardPaths.ConfigLocation)).replace("file://", "") + "/quickshell/services/session_helper.py", "capture"]
    }

    Process {
        id: restoreSessionProc
        command: ["python3", String(StandardPaths.writableLocation(StandardPaths.ConfigLocation)).replace("file://", "") + "/quickshell/services/session_helper.py", "restore"]
    }

    Process {
        id: checkServiceProc
        command: [
            "bash",
            "-c",
            "[ -f ~/.config/systemd/user/quickshell-session.service ] && echo -n 'installed ' || echo -n 'missing '; systemctl --user is-enabled quickshell-session.service &>/dev/null && echo -n 'enabled ' || echo -n 'disabled '; systemctl --user is-active quickshell-session.service &>/dev/null && echo 'active' || echo 'inactive'"
        ]
        stdout: SplitParser {
            onRead: data => {
                var parts = data.trim().split(" ")
                if (parts.length >= 3) {
                    service.serviceInstalled = (parts[0] === "installed")
                    service.serviceEnabled = (parts[1] === "enabled")
                    service.serviceHealthy = (parts[2] === "active")
                }
            }
        }
    }

    Process {
        id: installServiceProc
        command: [
            "bash",
            "-c",
            "mkdir -p ~/.config/systemd/user && cp '" + String(StandardPaths.writableLocation(StandardPaths.ConfigLocation)).replace("file://", "") + "/quickshell/systemd/quickshell-session.service' ~/.config/systemd/user/ && systemctl --user daemon-reload && systemctl --user enable --now quickshell-session.service"
        ]
        onExited: {
            service.checkServiceState()
        }
    }

    onEnabledChanged: {
        if (root && root.saveState) {
            root.saveState("session_restore", enabled ? "true" : "false")
        }
    }

    Component.onCompleted: {
        service.checkServiceState()
    }
}
